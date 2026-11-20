import importlib.util
import json
import os
from datetime import datetime
from pathlib import Path
from types import ModuleType
import unittest
from unittest.mock import MagicMock, patch

ROOT = Path(__file__).resolve().parents[1]


class BusinessHoursTest(unittest.TestCase):
    def setUp(self):
        self.eks, self.rds = MagicMock(), MagicMock()
        boto = ModuleType('boto3')
        boto.client = MagicMock(side_effect=lambda name: {'eks': self.eks, 'rds': self.rds}[name])
        self.environment = patch.dict(os.environ, {
            'CLUSTER_NAME': 'barofit-prod', 'NODEGROUP_NAME': 'barofit-prod-ng',
            'DB_INSTANCE_ID': 'barofit-prod-postgres', 'START_MIN_SIZE': '1',
            'START_DESIRED_SIZE': '1'})
        self.environment.start()
        self.addCleanup(self.environment.stop)
        with patch.dict('sys.modules', {'boto3': boto}):
            spec = importlib.util.spec_from_file_location('schedule_handler', ROOT / 'handler.py')
            self.module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(self.module)
        self.eks.describe_nodegroup.return_value = {'nodegroup': {
            'status': 'ACTIVE', 'scalingConfig': {'minSize': 1, 'maxSize': 2, 'desiredSize': 1}}}
        self.eks.update_nodegroup_config.return_value = {'update': {'id': 'update-id'}}
        self.database('available')

    def database(self, status):
        self.rds.describe_db_instances.return_value = {'DBInstances': [{'DBInstanceStatus': status}]}

    def at(self, hour, minute, action):
        clock = MagicMock()
        # A Saturday confirms there is no unintended weekdays-only restriction.
        clock.now.return_value = datetime(2026, 11, 21, hour, minute)
        with patch.object(self.module, 'datetime', clock):
            return self.module.handler({'action': action}, None)

    def test_schedules_and_packaged_code_match_source(self):
        t = json.loads((ROOT / 'business-hours.template.json').read_text())
        self.assertEqual(t['Resources']['Function']['Properties']['Code']['ZipFile'],
                         (ROOT / 'handler.py').read_text())
        for key, cron in [('StartSchedule', 'cron(30 8 * * ? *)'),
                          ('StopSchedule', 'cron(0 19 * * ? *)')]:
            p = t['Resources'][key]['Properties']
            self.assertEqual(p['ScheduleExpression'], cron)
            self.assertEqual(p['ScheduleExpressionTimezone'], 'Asia/Seoul')
            self.assertEqual(p['FlexibleTimeWindow'], {'Mode': 'OFF'})
            self.assertEqual(p['State'], 'ENABLED')

    def test_start_is_idempotent_for_already_running_resources(self):
        result = self.at(8, 30, 'start')
        self.assertEqual(result['eks']['result'], 'unchanged')
        self.eks.update_nodegroup_config.assert_not_called()
        self.rds.start_db_instance.assert_not_called()

    def test_start_restores_nodes_and_stopped_database(self):
        self.eks.describe_nodegroup.return_value['nodegroup']['scalingConfig'].update(minSize=0, desiredSize=0)
        self.database('stopped')
        self.at(8, 30, 'start')
        self.rds.start_db_instance.assert_called_once_with(DBInstanceIdentifier='barofit-prod-postgres')
        self.assertEqual(self.eks.update_nodegroup_config.call_args.kwargs['scalingConfig'],
                         {'minSize': 1, 'desiredSize': 1})

    def test_stop_scales_to_zero_and_preserves_maximum(self):
        self.at(19, 0, 'stop')
        config = self.eks.update_nodegroup_config.call_args.kwargs['scalingConfig']
        self.assertEqual(config, {'minSize': 0, 'desiredSize': 0})
        self.rds.stop_db_instance.assert_called_once_with(DBInstanceIdentifier='barofit-prod-postgres')

    def test_late_start_retry_cannot_reopen_at_night(self):
        result = self.at(19, 0, 'start')
        self.assertEqual(result['result'], 'skipped_outside_action_window')
        self.eks.describe_nodegroup.assert_not_called()

    def test_late_stop_retry_cannot_close_in_business_hours(self):
        result = self.at(8, 30, 'stop')
        self.assertEqual(result['result'], 'skipped_outside_action_window')
        self.rds.describe_db_instances.assert_not_called()

    def test_before_opening_start_is_skipped(self):
        self.assertEqual(self.at(8, 29, 'start')['result'], 'skipped_outside_action_window')

    def test_start_preserves_manual_capacity_increase(self):
        self.eks.describe_nodegroup.return_value['nodegroup']['scalingConfig']['desiredSize'] = 2
        self.at(9, 0, 'start')
        self.eks.update_nodegroup_config.assert_not_called()

    def test_failed_node_update_does_not_stop_database(self):
        self.eks.describe_nodegroup.return_value['nodegroup']['status'] = 'UPDATING'
        with self.assertRaises(RuntimeError):
            self.at(19, 0, 'stop')
        self.rds.stop_db_instance.assert_not_called()

    def test_transitional_database_retries_instead_of_invalid_request(self):
        self.database('starting')
        with self.assertRaises(RuntimeError):
            self.module._database(self.rds, 'stop')
        self.rds.stop_db_instance.assert_not_called()

    def test_status_only_reads_without_changing_resources(self):
        self.at(22, 0, 'status')
        self.eks.update_nodegroup_config.assert_not_called()
        self.rds.start_db_instance.assert_not_called()
        self.rds.stop_db_instance.assert_not_called()


if __name__ == '__main__':
    unittest.main()
