#!/usr/bin/env bash
# k6 baseline 시나리오를 순서대로 실행하고 raw summary를 results/에 남긴다.
#
# 주의: 06_auth_refresh가 쓰는 refresh token 풀은 1회성(회전/폐기)이다. smoke → baseline처럼
# "같은 세션에서 연달아" 실행하더라도, 이 스크립트를 실행할 때마다 scripts/seed-baseline-data.mjs로
# 매번 새로 시딩해야 한다 — 안 그러면 이전 실행에서 이미 써버린 토큰이 섞여 일부(또는 전부) VU가
# 즉시 실패한다(실측으로 확인한 문제: 재시딩 없이 두 번째 돌렸더니 0% 성공).
#
# 사용법:
#   ACCESS_TOKEN=<scripts/mint-access-token.mjs 출력> \
#   STAGE=smoke BASE_URL=http://localhost:30080 \
#   ./run-all.sh
set -euo pipefail

STAGE="${STAGE:-smoke}"
BASE_URL="${BASE_URL:-http://localhost:30080}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${ROOT_DIR}/results"
STAMP="$(date +%Y%m%d-%H%M%S)"

if [[ -z "${ACCESS_TOKEN:-}" ]]; then
  echo "ACCESS_TOKEN이 없습니다. scripts/mint-access-token.mjs로 먼저 발급하세요." >&2
  exit 1
fi

mkdir -p "$RESULTS_DIR"

SCENARIOS=(
  "00_health"
  "01_routine_templates_read"
  "02_routine_create"
  "03_workout_session_sync"
  "04_workout_records_statistics"
  "05_reports"
  "06_auth_refresh"
)

for name in "${SCENARIOS[@]}"; do
  echo "=== ${name} (${STAGE}) ==="
  k6 run \
    --env STAGE="$STAGE" \
    --env BASE_URL="$BASE_URL" \
    --env ACCESS_TOKEN="$ACCESS_TOKEN" \
    --env REFRESH_TOKENS_FILE="${ROOT_DIR}/.artifacts/refresh-tokens.json" \
    --summary-trend-stats="avg,min,med,max,p(90),p(95),p(99)" \
    --summary-export="${RESULTS_DIR}/${STAMP}-${STAGE}-${name}.json" \
    "${ROOT_DIR}/scenarios/${name}.js"
done

echo
echo "완료. raw summary: ${RESULTS_DIR}/${STAMP}-${STAGE}-*.json"
echo "사람이 읽을 비교 markdown(커밋 해시 + p50/p95/p99 + RPS + 에러율 + 직전 라운드 대비 변화율)은"
echo "이 raw summary를 바탕으로 작성해 /barofit/test/결과/ 에도 함께 남긴다(계획 문서 '결과 저장 규칙')."
