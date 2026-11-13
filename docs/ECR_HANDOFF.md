# ECR 이미지 배포 진행 현황 및 팀 전달 사항

> 작성일: 2026-11-12 / 대상: 백엔드·CI/CD·인프라 담당 팀원

## 1. 진행 현황

| 항목 | 상태 | 비고 |
| :--- | :---: | :--- |
| `barofit-common` `publishToMavenLocal` | ✅ | `~/.m2/repository/com/barofit/barofit-runtime/0.0.1-SNAPSHOT` |
| 폴더 구조 정리 (`backend/` 제거, 서비스 레포를 `barofit-infra`와 같은 깊이로 이동) | ✅ | `barofit-infra/README.md`의 형제 디렉토리 구조와 일치 |
| Terraform으로 ECR 리포지토리 5개 생성 | ✅ | `barofit-infra/terraform/ecr/` |
| 빌드 스크립트 ECR 지원 (`ECR_REGISTRY`, `linux/amd64`) | ✅ | 인프라 일괄 스크립트 + 5개 서비스 스크립트 |
| 5개 서비스 이미지 빌드 및 ECR 푸시 | ✅ | 태그 `80c8f67` |
| Helm `values.yaml`에 ECR 주소 기본값 등록 | ⏳ 미정 | 현재는 `--set`으로 주입 |
| EKS/클러스터 배포 및 E2E 검증 | ⏳ 미진행 | |
| GitHub Actions CI/CD (ECR 푸시 자동화) | ⏳ 미진행 | |

## 2. ECR 정보

- 레지스트리: `373514675861.dkr.ecr.ap-northeast-2.amazonaws.com` (리전 `ap-northeast-2`)
- 리포지토리: `barofit-identity`, `barofit-routine`, `barofit-workout`, `barofit-analytics`, `barofit-report`
- 현재 푸시된 태그: `80c8f67` (git 커밋 해시 7자리)
- 수명주기 정책: 리포지토리당 최근 15개 이미지만 유지, 푸시 시 보안 스캔 활성화
- 태그 변경 가능(MUTABLE), `force_delete=true` (테스트 환경 기준 — 운영 전 재검토 필요)

## 3. 변경된 파일

- 신규: `terraform/ecr/{main.tf,variables.tf,outputs.tf,README.md}`
- 수정: `scripts/build-and-push.sh`, 각 서비스 레포의 `scripts/build-and-push.sh` (5개)
- 수정: `.gitignore` (Terraform state/tfvars 제외)
- 기존 `DOCKERHUB_USER` 방식도 그대로 동작한다. `ECR_REGISTRY`가 우선한다.
- 참고: 서비스 레포는 각각 독립 git 레포이므로 스크립트 변경은 레포별로 커밋·PR이 필요하다.

## 4. 재현 절차

```bash
# 1) ECR 리포지토리 생성 (최초 1회)
cd barofit-infra/terraform/ecr
terraform init && terraform apply

# 2) ECR 로그인 (토큰 12시간 유효)
ECR_REGISTRY=$(terraform output -raw ecr_registry)
AWS_REGION=$(terraform output -raw aws_region)
aws ecr get-login-password --region "$AWS_REGION" | \
  docker login --username AWS --password-stdin "$ECR_REGISTRY"

# 3) 전체 빌드 & 푸시 (barofit-common을 먼저 publishToMavenLocal 해둘 것)
cd ../..
ECR_REGISTRY="$ECR_REGISTRY" ./scripts/build-and-push.sh
```

배포 명령 (스크립트 출력의 마지막 줄 `\` 제거 후 실행):

```bash
helm upgrade --install barofit infra/umbrella -n barofit \
  --set global.imageTag=80c8f67 \
  --set identity.image.repository=373514675861.dkr.ecr.ap-northeast-2.amazonaws.com/barofit-identity \
  --set routine.image.repository=373514675861.dkr.ecr.ap-northeast-2.amazonaws.com/barofit-routine \
  --set workout.image.repository=373514675861.dkr.ecr.ap-northeast-2.amazonaws.com/barofit-workout \
  --set analytics.image.repository=373514675861.dkr.ecr.ap-northeast-2.amazonaws.com/barofit-analytics \
  --set report.image.repository=373514675861.dkr.ecr.ap-northeast-2.amazonaws.com/barofit-report
```

## 5. 팀원에게 전달/확인 요청 사항

### CI/CD 담당
1. **barofit-common 의존성**: 현재 Dockerfile이 `COPY .m2-cache`로 로컬 Maven 캐시를 사용한다. CI에서는 `barofit-common`을 checkout 후 `publishToMavenLocal` 하고 `.m2-cache`를 만들어야 한다(스크립트가 처리). GitHub Packages 전환 시 이 블록과 Dockerfile 줄을 제거한다.
2. **인증**: CI는 장기 Access Key 대신 GitHub OIDC + IAM Role(`ecr:GetAuthorizationToken`, `ecr:BatchCheckLayerAvailability`, `ecr:PutImage`, `ecr:InitiateLayerUpload`, `ecr:UploadLayerPart`, `ecr:CompleteLayerUpload`) 사용을 권장한다.
3. **태그 규칙**: 로컬 수동 푸시와 CI 푸시가 충돌하지 않도록 규칙 합의 필요(현재: 커밋 해시 7자리). `latest` 사용 여부도 결정.
4. 기존 `ci.yml`은 spotlessCheck/test만 수행. 이미지 빌드·푸시 단계 추가 필요.

### 인프라/배포 담당
1. **Terraform state**: 현재 로컬 state. 팀 공유를 위해 S3 backend + DynamoDB lock 전환 필요(state는 커밋 금지).
2. **EKS 노드 ECR pull 권한**: 노드 IAM Role에 `AmazonEC2ContainerRegistryReadOnly` 필요.
3. **Helm values**: ECR 주소를 values에 기본 등록할지 결정. 등록 시 `pullPolicy`와 태그 전략도 정리.
4. **시크릿/환경변수** (`.env.example`, `infra/README.md` 참고): DB 자격증명, JWT 키(`keys/`), 소셜 로그인 키, `OPENAI_API_KEY`, `ELEVENLABS_*`, `ANALYTICS_INTERNAL_TOKEN`. 운영은 AWS Secrets Manager/ExternalSecrets 등 검토. 평문 커밋 금지.
5. **DB**: 운영은 RDS(PostgreSQL) 사용 여부 결정 (`DB_URL` 등 주입).
6. **아키텍처**: 이미지는 `linux/amd64`로 빌드됨. Graviton(ARM) 노드를 쓰면 재빌드 필요.

### 공통
- 서비스 레포들을 `barofit-infra`와 같은 깊이에 clone 해야 일괄 스크립트가 동작한다(`SIBLINGS_DIR`로 변경 가능).
- `barofit-infra` 차트·스크립트 변경 시 `CLAUDE.md` 규칙에 따라 minikube 재배포 + E2E 통과가 완료 조건이다. 이번 스크립트 변경은 아직 E2E 검증 전이다.
- `barofit-pose`는 앱 내장 모듈이라 ECR 대상이 아니다.

## 6. 다음 할 일

- [ ] ECR 이미지로 클러스터(minikube 또는 EKS)에 Helm 배포 후 E2E 검증
- [ ] Helm values에 ECR 주소 기본값 반영 여부 결정
- [ ] CI/CD에 ECR 푸시 워크플로우 추가 (OIDC)
- [ ] Terraform remote state 전환
- [ ] 각 서비스 레포 스크립트 변경 커밋/PR
