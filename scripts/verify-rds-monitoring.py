#!/usr/bin/env python3
"""Verify RDS metrics through the Kubernetes API service proxy (no public Prometheus)."""
import argparse
import json
import subprocess
import urllib.parse

METRICS = ['pg_stat_database_numbackends', 'pg_settings_max_connections',
           'pg_stat_database_xact_commit', 'pg_stat_database_xact_rollback',
           'pg_stat_database_blks_hit', 'pg_stat_database_blks_read',
           'pg_stat_database_deadlocks', 'pg_stat_database_temp_bytes',
           'pg_stat_database_tup_returned', 'pg_stat_database_tup_inserted',
           'pg_stat_database_tup_updated', 'pg_stat_database_tup_deleted',
           'pg_database_size_bytes', 'pg_stat_activity_count', 'pg_stat_activity_max_tx_duration']


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--kubectl', required=True)
    p.add_argument('--kubeconfig', required=True)
    p.add_argument('--context', required=True)
    args = p.parse_args()
    command = [args.kubectl, '--kubeconfig', args.kubeconfig, '--context', args.context,
               '--request-timeout=25s', 'get', '--raw']
    base = '/api/v1/namespaces/monitoring/services/http:monitoring-prometheus:9090/proxy/api/v1/query?'
    for metric in ['pg_up', 'pg_exporter_last_scrape_error'] + METRICS:
        expression = metric + '{namespace="barofit",service="rds-postgres-exporter"}'
        result = subprocess.run(command + [base + urllib.parse.urlencode({'query': expression})],
                                check=True, capture_output=True, timeout=35)
        data = json.loads(result.stdout)
        samples = data.get('data', {}).get('result', [])
        if data.get('status') != 'success' or not samples:
            raise SystemExit('FAIL: Missing metric ' + metric)
        if metric in ['pg_up', 'pg_exporter_last_scrape_error']:
            expected = 1 if metric == 'pg_up' else 0
            if not all(float(s['value'][1]) == expected for s in samples):
                raise SystemExit('FAIL: Unexpected ' + metric)
        print('PASS:', metric, 'samples:', len(samples))
    print('PASS: RDS connection and all dashboard source metrics are collected.')


if __name__ == '__main__':
    main()
