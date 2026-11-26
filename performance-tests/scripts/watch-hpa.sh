#!/usr/bin/env bash
# HPA 적용 전/후 비교 테스트용 — 레플리카 수·HPA 상태·FailedScheduling 이벤트를 주기적으로
# 폴링해 CSV/로그로 남긴다. HPA가 아직 없는 "Before" 라운드에서도 그대로 쓸 수 있다
# (그 경우 hpa_current/hpa_desired/cpu_pct 컬럼은 비어 있고, replicas 컬럼만 의미를 가진다 —
# "부하가 커져도 레플리카가 안 바뀐다"는 걸 증빙하는 용도).
#
# 사용법:
#   NAMESPACE=barofit INTERVAL=15 DURATION_MIN=50 ./scripts/watch-hpa.sh <라벨(Before|After)>
#
# 종료: DURATION_MIN이 지나면 자동 종료. 그 전에 중단하려면 Ctrl+C(지금까지 수집한 내용은 남는다).
set -euo pipefail

LABEL="${1:-watch}"
NAMESPACE="${NAMESPACE:-barofit}"
INTERVAL="${INTERVAL:-15}"
DURATION_MIN="${DURATION_MIN:-50}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="${ROOT_DIR}/results"
STAMP="$(date +%Y%m%d-%H%M%S)"

mkdir -p "$RESULTS_DIR"
CSV_FILE="${RESULTS_DIR}/${STAMP}-${LABEL}-hpa-watch.csv"
EVENTS_FILE="${RESULTS_DIR}/${STAMP}-${LABEL}-failed-scheduling.log"

echo "timestamp,service,replicas_desired,replicas_ready,hpa_current,hpa_desired,cpu_current_pct,cpu_target_pct" > "$CSV_FILE"
: > "$EVENTS_FILE"

END_TS=$(( $(date +%s) + DURATION_MIN * 60 ))
SEEN_EVENT_UIDS_FILE="$(mktemp)"
trap 'rm -f "$SEEN_EVENT_UIDS_FILE"' EXIT

echo "=== HPA/레플리카 폴링 시작 (label=${LABEL}, interval=${INTERVAL}s, duration=${DURATION_MIN}m) ==="
echo "CSV: ${CSV_FILE}"
echo "FailedScheduling 로그: ${EVENTS_FILE}"

while [[ "$(date +%s)" -lt "$END_TS" ]]; do
  NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  # 1) Deployment 레플리카 (spec=desired, status.readyReplicas=ready)
  kubectl get deploy -n "$NAMESPACE" -o json 2>/dev/null | jq -r --arg ts "$NOW" '
    .items[] |
    [$ts, .metadata.name, (.spec.replicas // 0), (.status.readyReplicas // 0)] | @csv
  ' | while IFS=, read -r ts svc desired ready; do
    svc="${svc//\"/}"
    echo "${ts},${svc},${desired},${ready},,,," >> "$CSV_FILE"
  done

  # 2) HPA 현재/목표 (있으면 덮어써서 같은 타임스탬프에 더 상세한 행 추가)
  if kubectl get hpa -n "$NAMESPACE" >/dev/null 2>&1; then
    kubectl get hpa -n "$NAMESPACE" -o json 2>/dev/null | jq -r --arg ts "$NOW" '
      .items[] |
      [
        $ts,
        .spec.scaleTargetRef.name,
        .status.desiredReplicas // 0,
        .status.currentReplicas // 0,
        (.status.currentMetrics[0].resource.current.averageUtilization // ""),
        (.spec.metrics[0].resource.target.averageUtilization // "")
      ] | @csv
    ' | while IFS=, read -r ts svc hdesired hcurrent cpucur cputgt; do
      svc="${svc//\"/}"
      echo "${ts},${svc},,,${hcurrent},${hdesired},${cpucur},${cputgt}" >> "$CSV_FILE"
    done
  fi

  # 3) FailedScheduling 이벤트 (중복 방지: UID 기준)
  kubectl get events -n "$NAMESPACE" --field-selector reason=FailedScheduling -o json 2>/dev/null \
    | jq -r '.items[] | [.metadata.uid, .lastTimestamp, .involvedObject.name, .message] | @tsv' \
    | while IFS=$'\t' read -r uid ts obj msg; do
        if ! grep -qF "$uid" "$SEEN_EVENT_UIDS_FILE" 2>/dev/null; then
          echo "$uid" >> "$SEEN_EVENT_UIDS_FILE"
          echo "${ts} [${obj}] ${msg}" >> "$EVENTS_FILE"
        fi
      done

  sleep "$INTERVAL"
done

echo "=== 폴링 종료. CSV: ${CSV_FILE} / 이벤트 로그: ${EVENTS_FILE} ==="
