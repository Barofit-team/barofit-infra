"""Start/stop the configured Barofit resources during Asia/Seoul business hours."""
import json
import os
from datetime import datetime
from zoneinfo import ZoneInfo

import boto3


def _nodegroup(client, action):
    cluster, group = os.environ['CLUSTER_NAME'], os.environ['NODEGROUP_NAME']
    node = client.describe_nodegroup(clusterName=cluster, nodegroupName=group)['nodegroup']
    if action == 'status':
        return {'status': node['status'], 'scaling': node['scalingConfig']}
    if node['status'] != 'ACTIVE':
        raise RuntimeError('Node group is not ACTIVE; retry required')
    scaling = node['scalingConfig']
    minimum = max(scaling['minSize'], int(os.environ['START_MIN_SIZE'])) if action == 'start' else 0
    desired = max(scaling['desiredSize'], int(os.environ['START_DESIRED_SIZE']), minimum) if action == 'start' else 0
    if desired > scaling['maxSize']:
        raise RuntimeError('Configured morning size exceeds node group maximum')
    if scaling['minSize'] == minimum and scaling['desiredSize'] == desired:
        return {'result': 'unchanged', 'desired': desired}
    update = client.update_nodegroup_config(
        clusterName=cluster, nodegroupName=group,
        scalingConfig={'minSize': minimum, 'desiredSize': desired})
    return {'result': 'requested', 'desired': desired, 'updateId': update['update']['id']}


def _database(client, action):
    identifier = os.environ['DB_INSTANCE_ID']
    db = client.describe_db_instances(DBInstanceIdentifier=identifier)['DBInstances'][0]
    state = db['DBInstanceStatus']
    if action == 'status':
        return {'status': state}
    if action == 'start' and state in ('available', 'starting'):
        return {'result': 'unchanged', 'status': state}
    if action == 'stop' and state in ('stopped', 'stopping'):
        return {'result': 'unchanged', 'status': state}
    required = 'stopped' if action == 'start' else 'available'
    if state != required:
        raise RuntimeError('Database is in a transitional state; retry required')
    operation = client.start_db_instance if action == 'start' else client.stop_db_instance
    operation(DBInstanceIdentifier=identifier)
    return {'result': 'requested', 'action': action}


def handler(event, context):
    action = event.get('action')
    if action not in ('start', 'stop', 'status'):
        raise ValueError('Expected action=start, stop, or status')
    now = datetime.now(ZoneInfo('Asia/Seoul'))
    minute = now.hour * 60 + now.minute
    business_hours = 8 * 60 + 30 <= minute < 19 * 60
    # A delayed retry must never reopen resources after closing time, or close
    # resources after the next morning's start time.
    if action != 'status' and ((action == 'start') != business_hours):
        result = {'action': action, 'result': 'skipped_outside_action_window', 'time': now.isoformat()}
        print(json.dumps(result))
        return result
    eks, rds = boto3.client('eks'), boto3.client('rds')
    result = {'action': action, 'time': now.isoformat()}
    if action == 'start':
        result['rds'] = _database(rds, action)
        result['eks'] = _nodegroup(eks, action)
    else:
        result['eks'] = _nodegroup(eks, action)
        result['rds'] = _database(rds, action)
    print(json.dumps(result))
    return result
