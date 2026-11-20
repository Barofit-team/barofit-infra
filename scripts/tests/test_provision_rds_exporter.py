import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location('rds', Path(__file__).parents[1] / 'provision-rds-exporter.py')
rds = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rds)


class RdsProvisionTests(unittest.TestCase):
    def test_job_verifies_tls_and_references_ephemeral_credentials(self):
        job = rds.job_object('barofit', 'database.example', 'bootstrap-test', True)
        pod = job['spec']['template']['spec']
        container = pod['containers'][0]
        env = {item['name']: item for item in container['env']}
        self.assertEqual(env['PGSSLMODE']['value'], 'verify-full')
        self.assertEqual(env['PGSSLROOTCERT']['value'], '/etc/rds-ca/global-bundle.pem')
        self.assertEqual(env['PGPASSWORD']['valueFrom']['secretKeyRef']['name'], 'bootstrap-test')
        self.assertEqual(env['MONITOR_PASSWORD']['valueFrom']['secretKeyRef']['name'], 'bootstrap-test')
        self.assertFalse(pod['automountServiceAccountToken'])
        self.assertEqual(job['spec']['backoffLimit'], 0)
        self.assertEqual(job['spec']['activeDeadlineSeconds'], 180)

    def test_role_cannot_write_or_administer_database(self):
        self.assertIn('rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls', rds.SQL)
        self.assertIn('Monitoring role must have no elevated attributes', rds.SQL)
        self.assertIn('CONNECTION LIMIT 5', rds.SQL)
        self.assertIn('GRANT pg_monitor', rds.SQL)
        self.assertIn('default_transaction_read_only = on', rds.SQL)
        self.assertNotIn('GRANT ALL', rds.SQL)
        self.assertNotIn('GRANT SELECT', rds.SQL)
        self.assertIn('Existing role requires its original monitoring Secret', rds.SQL)
        self.assertIn("PASSWORD :'monitor_password'", rds.SQL)
        self.assertLess(rds.SQL.index('BEGIN;'), rds.SQL.index('ALTER ROLE'))
        self.assertIn('COMMIT;', rds.SQL)
        # Kubelet expands $$ in command/args: tagged dollar quoting must survive it.
        self.assertNotIn('$$', rds.SQL)
        self.assertIn('DO $barofit$ BEGIN', rds.SQL)

    def test_secret_has_no_last_applied_annotation(self):
        obj = rds.secret_object('test', 'barofit', {'password': 'example'})
        self.assertNotIn('annotations', obj['metadata'])
        self.assertNotIn('stringData', obj)


if __name__ == '__main__':
    unittest.main()
