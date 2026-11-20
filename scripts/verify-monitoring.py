#!/usr/bin/env python3
"""Verify real Barofit log and metric ingestion through local port-forwards."""

import argparse
import json
import urllib.parse
import urllib.request


def query(base, path, expression):
    url = base.rstrip("/") + path + "?" + urllib.parse.urlencode({"query": expression})
    with urllib.request.urlopen(url, timeout=30) as response:
        body = json.load(response)
    if body.get("status") != "success":
        raise RuntimeError(f"Query failed: {body}")
    return body["data"]["result"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--loki-url", default="http://127.0.0.1:13100")
    parser.add_argument("--prometheus-url", default="http://127.0.0.1:19090")
    parser.add_argument("--require-app-db", action="store_true", help="Require all five applications and PostgreSQL exporter metrics")
    args = parser.parse_args()
    streams = query(args.loki_url, "/loki/api/v1/query_range", '{namespace="barofit"}')
    if not any(stream.get("values") for stream in streams):
        raise RuntimeError("No Barofit logs in Loki; generate app requests and retry")
    memory = query(
        args.prometheus_url,
        "/api/v1/query",
        'pod_memory_working_set_bytes{namespace="barofit",metrics_path="/metrics/resource"}'
        ' or on (namespace, pod) container_memory_working_set_bytes'
        '{namespace="barofit",pod!="",container="",metrics_path="/metrics/cadvisor"}',
    )
    if not any(float(sample["value"][1]) > 0 for sample in memory):
        raise RuntimeError("No Barofit pod memory samples; check kubelet resource target")
    pods = query(
        args.prometheus_url,
        "/api/v1/query",
        'kube_pod_status_ready{namespace="barofit",condition="true"}',
    )
    if not any(float(sample["value"][1]) == 1 for sample in pods):
        raise RuntimeError("No ready Barofit pods reported by kube-state-metrics")
    if args.require_app_db:
        for service in ("identity", "routine", "workout", "analytics", "report"):
            application = f"{service}-service"
            for metric in ("jvm_memory_used_bytes", "hikaricp_connections_max",
                           "http_server_requests_seconds_count", "http_server_requests_seconds_bucket"):
                samples = query(args.prometheus_url, "/api/v1/query",
                                f'{metric}{{namespace="barofit",application="{application}"}}')
                if not samples:
                    raise RuntimeError(f"Missing {metric} for {application}; generate HTTP traffic and check scrape target")
        database = query(args.prometheus_url, "/api/v1/query", 'pg_up{namespace="barofit"}')
        if not database or not all(float(sample["value"][1]) == 1 for sample in database):
            raise RuntimeError("PostgreSQL exporter cannot connect or has no samples")
        for metric in ("pg_stat_database_numbackends", "pg_stat_activity_count", "pg_database_size_bytes"):
            if not query(args.prometheus_url, "/api/v1/query", f'{metric}{{namespace="barofit",datname="barofit"}}'):
                raise RuntimeError(f"Missing PostgreSQL collector metric: {metric}")
        print("PASS: all five applications HTTP/JVM/Hikari histograms and PostgreSQL collectors")
    print(
        f"PASS: Loki {len(streams)} log streams, "
        f"Prometheus {len(memory)} pod memory series, {len(pods)} pod status series"
    )


if __name__ == "__main__":
    main()
