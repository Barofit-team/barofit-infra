#!/usr/bin/env bash
# barofit 폴리레포 7개에 CLAUDE.md + docs/CONTRIBUTING.md + docs/TESTING.md를 배포한다.
#
# 원본은 이 레포(barofit-infra)의 templates/claude-rules/ 에 있다.
# CLAUDE.md = BASE.md + sections/<type>.md 를 이어붙여 생성한다.
# docs/CONTRIBUTING.md, docs/TESTING.md는 그대로 복사한다.
#
# 복제 후 각 레포는 독립적으로 수정해도 된다 — 동기화를 강제하거나 drift를 감지하지 않는다.
# 재실행하면 대상 레포의 CLAUDE.md/docs를 덮어쓰므로, 각 레포가 이미 독립적으로 수정한 내용이
# 있다면 재실행 전에 그 내용을 먼저 확인한다.
#
# 사용법: ./scripts/sync-claude-rules.sh [레포이름 ...]
#   인자 없이 실행하면 7개 레포 전체에 배포한다.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/../templates/claude-rules"
BAROFIT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)" # /Users/mac/ktg/github/barofit

# 레포 이름:타입(BASE.md에 이어붙일 sections/<type>.md) 목록
# macOS 기본 bash(3.2)는 연관 배열(declare -A)을 지원하지 않아 "repo:type" 문자열로 관리한다.
ALL_REPO_TYPES="
barofit-identity:service
barofit-routine:service
barofit-workout:service
barofit-analytics:service
barofit-report:service
barofit-common:common
barofit-infra:infra
"

targets="$*"

for repo_type in $ALL_REPO_TYPES; do
  repo="${repo_type%%:*}"
  type="${repo_type##*:}"

  if [ -n "$targets" ]; then
    case " $targets " in
    *" $repo "*) ;;
    *) continue ;;
    esac
  fi

  target_dir="$BAROFIT_ROOT/$repo"
  if [ ! -d "$target_dir" ]; then
    echo "skip: $target_dir 없음" >&2
    continue
  fi

  cat "$TEMPLATE_DIR/BASE.md" "$TEMPLATE_DIR/sections/$type.md" >"$target_dir/CLAUDE.md"

  mkdir -p "$target_dir/docs"
  cp "$TEMPLATE_DIR/docs/CONTRIBUTING.md" "$target_dir/docs/CONTRIBUTING.md"
  cp "$TEMPLATE_DIR/docs/TESTING.md" "$target_dir/docs/TESTING.md"

  echo "synced: $repo ($type)"
done
