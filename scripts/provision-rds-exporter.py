#!/usr/bin/env python3
"""Provision an RDS monitoring login using an ephemeral, TLS verified psql Job.

Credentials are read/written through stdin and never printed or written to disk.
The app's database users and privileges are not changed.
"""
import argparse
import base64
import json
import re
from pathlib import Path
import secrets
import subprocess
import time

ROLE = 'barofit_monitor'
SECRET = 'barofit-rds-exporter'
REMOTE_SECRET = 'barofit/prod/rds-exporter'
SQL = r'''
\getenv monitor_password MONITOR_PASSWORD
\getenv new_credentials NEW_CREDENTIALS
SET lock_timeout = '5s';
SET statement_timeout = '15s';
SELECT set_config('barofit.bootstrap_fresh', :'new_credentials', false);
DO $barofit$ BEGIN
  IF current_setting('barofit.bootstrap_fresh') = 'true' AND EXISTS
    (SELECT FROM pg_roles WHERE rolname = 'barofit_monitor') THEN
    RAISE EXCEPTION 'Existing role requires its original monitoring Secret';
  END IF;
END $barofit$;
BEGIN;
DO $barofit$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'barofit_monitor') THEN
    CREATE ROLE barofit_monitor LOGIN;
  END IF;
END $barofit$;
-- RDS administrators are not PostgreSQL superusers: do not ALTER superuser-only attributes.
-- New roles default to all privileged attributes false; refuse an elevated existing role.
DO $barofit$ BEGIN
  IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'barofit_monitor' AND
    (rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls)) THEN
    RAISE EXCEPTION 'Monitoring role must have no elevated attributes';
  END IF;
END $barofit$;
ALTER ROLE barofit_monitor WITH LOGIN CONNECTION LIMIT 5 PASSWORD :'monitor_password';
GRANT pg_monitor TO barofit_monitor;
GRANT CONNECT ON DATABASE barofit TO barofit_monitor;
ALTER ROLE barofit_monitor SET default_transaction_read_only = on;
ALTER ROLE barofit_monitor SET statement_timeout = '8s';
COMMIT;
'''


def run(command, data=None):
    result = subprocess.run(command, input=json.dumps(data).encode() if data is not None else None,
                            capture_output=True, timeout=90)
    if result.returncode:
        # stderr may contain credentials or a rendered SQL statement: never echo it.
        error_code = re.search(rb'An error occurred \(([A-Za-z0-9]+)\)', result.stderr)
        suffix = ' (' + error_code.group(1).decode() + ')' if error_code else ''
        raise RuntimeError('Command failed' + suffix + ': ' + ('kubectl ' + next((v for v in command if v in ['get', 'create', 'apply', 'delete']), 'request') if 'kubectl' in command[0] else command[0] + ' request'))
    output = result.stdout.strip()
    return json.loads(output) if output.startswith((b'{', b'[')) else None


def secret_object(name, namespace, values):
    return {'apiVersion': 'v1', 'kind': 'Secret', 'metadata': {'name': name, 'namespace': namespace},
            'type': 'Opaque', 'data': {k: base64.b64encode(v.encode()).decode() for k, v in values.items()}}


def job_object(namespace, host, admin_name, fresh):
    env = [{'name': k, 'value': v} for k, v in {
        'PGHOST': host, 'PGPORT': '5432', 'PGDATABASE': 'barofit',
        'PGSSLMODE': 'verify-full', 'PGSSLROOTCERT': '/etc/rds-ca/global-bundle.pem',
        'PGCONNECT_TIMEOUT': '5', 'NEW_CREDENTIALS': str(fresh).lower()}.items()]
    for name, secret, key in [('PGUSER', admin_name, 'username'), ('PGPASSWORD', admin_name, 'password'),
                              ('MONITOR_PASSWORD', admin_name, 'monitor_password')]:
        env.append({'name': name, 'valueFrom': {'secretKeyRef': {'name': secret, 'key': key}}})
    return {'apiVersion': 'batch/v1', 'kind': 'Job', 'metadata': {'name': admin_name, 'namespace': namespace},
            'spec': {'backoffLimit': 0, 'activeDeadlineSeconds': 180, 'ttlSecondsAfterFinished': 60,
                     'template': {'spec': {'restartPolicy': 'Never', 'automountServiceAccountToken': False,
                        'securityContext': {'runAsNonRoot': True, 'runAsUser': 999, 'fsGroup': 999},
                        'containers': [{'name': 'psql', 'image': 'postgres:16.13-alpine',
                            'command': ['sh', '-c', "exec psql -X -v ON_ERROR_STOP=1 <<'SQL'\n" + SQL + '\nSQL'],
                            'env': env, 'resources': {'requests': {'cpu': '10m', 'memory': '32Mi'},
                                                      'limits': {'cpu': '100m', 'memory': '128Mi'}},
                            'securityContext': {'allowPrivilegeEscalation': False, 'readOnlyRootFilesystem': True,
                                                'capabilities': {'drop': ['ALL']}},
                            'volumeMounts': [{'name': 'rds-ca', 'mountPath': '/etc/rds-ca', 'readOnly': True}]}],
                        'volumes': [{'name': 'rds-ca', 'configMap': {'name': 'rds-ca'}}]}}}}


def provision(args):
    aws = ['aws', '--profile', args.profile, '--region', args.region, 'secretsmanager']
    k = [args.kubectl, '--kubeconfig', args.kubeconfig, '--context', args.context,
         '--request-timeout=20s', '-n', args.namespace]
    admin = json.loads(run(aws + ['get-secret-value', '--secret-id', 'barofit/prod/postgres'])['SecretString'])
    existing = run(k + ['get', 'secret', SECRET, '--ignore-not-found', '-o', 'json'])
    listed = run(aws + ['list-secrets', '--filters', 'Key=name,Values=' + REMOTE_SECRET])
    exists = any(s['Name'] == REMOTE_SECRET for s in listed['SecretList'])
    if existing:
        monitor = {key: base64.b64decode(value).decode() for key, value in existing['data'].items()}
    elif exists:
        monitor = json.loads(run(aws + ['get-secret-value', '--secret-id', REMOTE_SECRET])['SecretString'])
    else:
        monitor = {'username': ROLE, 'password': secrets.token_urlsafe(32)}
    if monitor['username'] != ROLE:
        raise RuntimeError('Unexpected monitoring username')
    run(k + ['apply', '-f', '-', '-o', 'json'], {'apiVersion': 'v1', 'kind': 'ConfigMap',
        'metadata': {'name': 'rds-ca', 'namespace': args.namespace},
        'data': {'global-bundle.pem': Path(args.ca_file).read_text()}})
    name = 'rds-exporter-bootstrap-' + secrets.token_hex(4)
    admin_values = {'username': admin.get('POSTGRES_USER', admin.get('DB_USERNAME')),
                    'password': admin.get('POSTGRES_PASSWORD', admin.get('DB_PASSWORD')),
                    'monitor_password': monitor['password']}
    if not all(admin_values.values()):
        raise RuntimeError('Missing RDS administrator credentials')
    run(k + ['create', '-f', '-', '-o', 'json'], secret_object(name, args.namespace, admin_values))
    try:
        run(k + ['create', '-f', '-', '-o', 'json'], job_object(args.namespace, args.host, name, not existing and not exists))
        for _ in range(45):
            status = run(k + ['get', 'job', name, '-o', 'json'])['status']
            if status.get('succeeded'):
                break
            if status.get('failed'):
                diagnostic = subprocess.run(k + ['logs', 'job/' + name], capture_output=True, text=True, timeout=30)
                lines = [line for line in diagnostic.stdout.splitlines() if line.startswith(('ERROR:', 'FATAL:', 'psql:'))]
                safe = ' / '.join(lines)[:500]
                for value in list(admin_values.values()) + [monitor['password']]:
                    safe = safe.replace(value, '[REDACTED]')
                raise RuntimeError('RDS role setup failed: ' + safe)
            time.sleep(4)
        else:
            raise RuntimeError('RDS role setup timed out; check scheduling and TLS connectivity')
    finally:
        try:
            run(k + ['delete', 'job', name, '--ignore-not-found', '--wait=true', '-o', 'name'])
        finally:
            run(k + ['delete', 'secret', name, '--ignore-not-found', '-o', 'name'])
    if not existing:
        run(k + ['create', '-f', '-', '-o', 'json'], secret_object(SECRET, args.namespace, monitor))
    payload = {'SecretString': json.dumps(monitor)}
    payload['SecretId' if exists else 'Name'] = REMOTE_SECRET
    # macOS cannot reliably reopen a pipe through /dev/stdin in AWS CLI paramfiles.
    # The AWS CLI Python runtime includes botocore; pass the payload over stdin to the SDK.
    sdk = '''import sys,json
try:
 import botocore.session
except ModuleNotFoundError:
 import awscli
 import botocore.session
v=json.load(sys.stdin)
s=botocore.session.Session(profile=v['profile'])
c=s.create_client('secretsmanager',region_name=v['region'])
try:
 getattr(c,v['action'])(**v['payload'])
except Exception as e:
 code=getattr(e,'response',{}).get('Error',{}).get('Code','SDKError')
 print(code);sys.exit(1)
'''
    result = subprocess.run([args.aws_python, '-c', sdk], input=json.dumps({
        'profile': args.profile, 'region': args.region,
        'action': 'put_secret_value' if exists else 'create_secret', 'payload': payload}).encode(),
        capture_output=True, timeout=60)
    if result.returncode:
        raise RuntimeError('Secrets Manager write failed; credentials remain in the Kubernetes Secret')
    print('PASS: RDS pg_monitor login provisioned, credentials backed by Secrets Manager; bootstrap Job and admin Secret removed.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--kubectl', required=True)
    parser.add_argument('--kubeconfig', required=True)
    parser.add_argument('--context', required=True)
    parser.add_argument('--aws-python', default='python3', help='Python runtime with botocore installed')
    parser.add_argument('--profile', default='barofit')
    parser.add_argument('--region', default='ap-northeast-2')
    parser.add_argument('--namespace', default='barofit')
    parser.add_argument('--host', required=True)
    parser.add_argument('--ca-file', required=True)
    try:
        provision(parser.parse_args())
    except (RuntimeError, subprocess.TimeoutExpired, KeyError, ValueError) as error:
        raise SystemExit('Provisioning failed; credentials were not logged. ' + str(error))
