#!/usr/bin/env bash
# 5개 서비스 레포(barofit-identity 등, 이 레포와 형제 디렉토리에 클론되어 있다고 가정)를
# 각각 돌며 자신의 scripts/build-and-push.sh를 호출해 이미지를 빌드·푸시한다.
#
# 사용법 (AWS ECR):
#   ECR_REGISTRY=<account-id>.dkr.ecr.<region>.amazonaws.com ./scripts/build-and-push.sh
# 사용법 (Docker Hub):
#   DOCKERHUB_USER=<hub-user> ./scripts/build-and-push.sh
#   DOCKERHUB_USER=<hub-user> TAG=my-tag ./scripts/build-and-push.sh
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -n "${ECR_REGISTRY:-}" ]; then
  IMAGE_PREFIX="${ECR_REGISTRY%/}"
elif [ -n "${DOCKERHUB_USER:-}" ]; then
  IMAGE_PREFIX="docker.io/${DOCKERHUB_USER}"
else
  echo "오류: ECR_REGISTRY 또는 DOCKERHUB_USER 환경변수 중 하나가 필요합니다." >&2
  exit 1
fi

TAG="${TAG:-$(git -C "$(dirname "$0")/.." rev-parse --short HEAD 2>/dev/null || date +%Y%m%d%H%M%S)}"
SIBLINGS_DIR="${SIBLINGS_DIR:-$(cd .. && pwd)}"
SERVICES=(identity routine workout analytics report)

export ECR_REGISTRY="${ECR_REGISTRY:-}" DOCKERHUB_USER="${DOCKERHUB_USER:-}" TAG PLATFORM="${PLATFORM:-}"
for svc in "${SERVICES[@]}"; do
  repo_dir="${SIBLINGS_DIR}/barofit-${svc}"
  if [ ! -d "$repo_dir" ]; then
    echo "건너뜀: ${repo_dir} 없음 (barofit-${svc} 레포를 형제 디렉토리에 clone 해두세요)" >&2
    continue
  fi
  "${repo_dir}/scripts/build-and-push.sh"
done

echo ""
echo "TAG=${TAG}"
echo "helm upgrade --install barofit infra/umbrella -n barofit \\"
echo "  --set global.imageTag=${TAG} \\"
for svc in "${SERVICES[@]}"; do
  echo "  --set ${svc}.image.repository=${IMAGE_PREFIX}/barofit-${svc} \\"
done
