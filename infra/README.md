# infra — 로컬 minikube Helm 구성

`barofit-infra` 레포(폴리레포 분리 후)의 Helm 차트 디렉토리. 서비스 코드는 각자 독립 레포
(`barofit-identity` 등)에 있고, 이 레포엔 Helm 차트와 `integration-tests`, 검증 스크립트만 둔다.

이미지는 각 서비스 레포(`barofit-identity` 등)에서 개별적으로 빌드/푸시한다(루트의
`scripts/build-and-push.sh`는 모노레포 시절 단일 Dockerfile+`ARG SERVICE_NAME` 분기 빌드용이라
분리 후에는 더 이상 쓰지 않음 — 각 서비스 레포 자신의 Dockerfile로 빌드).

```
infra/
├─ charts/          서비스별 독립 Helm 차트 (identity, routine, workout, analytics, report, gateway, postgres)
└─ umbrella/        7개 차트를 한 번에 설치하기 위한 편의용 umbrella 차트 (의존 결합 아님)
```

## 0. 사전 준비

- minikube, helm, kubectl, docker 설치
- Docker Hub 계정으로 `docker login` 1회 수행 (이 디렉토리의 어떤 파일에도 자격증명을 넣지 않음)
- 기존 `./keys/jwt-jwks.json`, `./keys/jwt-private.pem`, `.env` 가 로컬에 준비되어 있을 것
  (없다면 `./scripts/generate-jwt-keys.sh` 로 JWT 키를 먼저 생성)

## 1. minikube 시작 + 네임스페이스

```bash
minikube start --cpus=4 --memory=8192
kubectl create namespace barofit
```

## 2. 시크릿 생성 (helm install 전 선행, 차트에는 값이 없음)

```bash
# 1) JWT 키
kubectl -n barofit create secret generic barofit-jwt-keys \
  --from-file=jwt-jwks.json=./keys/jwt-jwks.json \
  --from-file=jwt-private.pem=./keys/jwt-private.pem

# 2) DB 자격증명 (.env 값 재사용)
kubectl -n barofit create secret generic barofit-postgres-credentials \
  --from-literal=POSTGRES_USER=postgres \
  --from-literal=POSTGRES_PASSWORD=postgres \
  --from-literal=DB_USERNAME=postgres \
  --from-literal=DB_PASSWORD=postgres

# 3) identity 전용 (.env 값 재사용, 비어 있는 값은 빈 문자열로)
kubectl -n barofit create secret generic identity-app-secrets \
  --from-literal=JWT_CURRENT_KID="" \
  --from-literal=GOOGLE_CLIENT_IDS="" \
  --from-literal=GOOGLE_WEB_CLIENT_ID="" \
  --from-literal=GOOGLE_CLIENT_SECRET="" \
  --from-literal=KAKAO_APP_KEYS="" \
  --from-literal=KAKAO_REST_API_KEY="" \
  --from-literal=KAKAO_CLIENT_SECRET="" \
  --from-literal=SOCIAL_REDIRECT_URIS="http://localhost:8081" \
  --from-literal=PROFILE_IMAGE_STORAGE="temporary" \
  --from-literal=PROFILE_IMAGE_PUBLIC_BASE_URL="https://temp-storage.barofit.invalid" \
  --from-literal=PROFILE_IMAGE_S3_BUCKET="" \
  --from-literal=PROFILE_IMAGE_S3_REGION=""

# 4) workout 전용
kubectl -n barofit create secret generic workout-app-secrets \
  --from-literal=ELEVENLABS_API_KEY="" \
  --from-literal=ELEVENLABS_VOICE_ID="" \
  --from-literal=OPENAI_API_KEY=""

# 5) workout <-> analytics 내부 토큰 (한 번만 생성, 양쪽이 같은 Secret을 참조)
kubectl -n barofit create secret generic barofit-analytics-internal-token \
  --from-literal=ANALYTICS_INTERNAL_TOKEN="$(openssl rand -hex 32)"
```

## 3. 이미지 빌드 & 푸시 (Docker Hub, public)

```bash
DOCKERHUB_USER=<hub-user> ./scripts/build-and-push.sh
```

출력된 `helm upgrade --install ...` 커맨드를 그대로 복사해서 4단계에 사용한다(TAG와 repository가 자동으로 채워져 나옴).

## 4. umbrella 차트로 전체 설치

```bash
helm dependency update infra/umbrella
helm upgrade --install barofit infra/umbrella -n barofit \
  --set global.imageTag=<TAG> \
  --set identity.image.repository=docker.io/<hub-user>/barofit-identity \
  --set routine.image.repository=docker.io/<hub-user>/barofit-routine \
  --set workout.image.repository=docker.io/<hub-user>/barofit-workout \
  --set analytics.image.repository=docker.io/<hub-user>/barofit-analytics \
  --set report.image.repository=docker.io/<hub-user>/barofit-report
```

개별 서비스만 다시 설치/디버깅하고 싶으면 umbrella 없이 해당 차트만 단독으로도 설치 가능
(차트 간 템플릿 의존성이 없음):

```bash
helm upgrade --install identity-service infra/charts/identity -n barofit \
  --set image.repository=docker.io/<hub-user>/barofit-identity --set image.tag=<TAG>
```

## 5. 상태 확인

```bash
kubectl -n barofit get pods -w
kubectl -n barofit get pvc                                    # postgres PVC Bound 확인
kubectl -n barofit logs deploy/identity-service   | grep "Flyway migrated schema"
kubectl -n barofit logs deploy/analytics-service  | grep "Flyway migrated schema 'analytics'"
kubectl -n barofit exec -it deploy/identity-service -- cat /app/secrets/jwt-jwks.json
```

문제가 있으면 `kubectl -n barofit describe pod <name>`으로 `wait-for-postgres` initContainer나
probe 실패 여부를 먼저 확인한다.

## 6. 게이트웨이 통신 확인

```bash
minikube service gateway -n barofit --url
GW_URL=$(minikube service gateway -n barofit --url)

curl $GW_URL/health
curl $GW_URL/identity/actuator/health
curl $GW_URL/workout/actuator/health
curl $GW_URL/analytics/actuator/health
curl $GW_URL/report/actuator/health

# 라우팅 경유 실제 API 호출 확인
curl $GW_URL/api/v1/exercises

# 서비스 간 내부 호출 로그 확인
kubectl -n barofit logs deploy/routine-service | grep -i identity
```

## 7. HTTP E2E 테스트 (integration-tests)

`integration-tests` 모듈은 Spring 컨텍스트나 Testcontainers 없이, 위 6번처럼 게이트웨이를 실제
HTTP로 호출해서 배포된 환경 전체를 검증한다 (각 서비스 자신의 단위·통합 테스트는 각 서비스 레포에
있다 — `docs/TESTING.md` 참고). minikube service 터널을 띄워둔 채로 그 URL을 넘긴다.

```bash
# 터널은 떠 있는 동안 포그라운드를 차지하므로 별도 터미널에서:
minikube service gateway -n barofit --url
# 위에서 나온 URL(예: http://127.0.0.1:12345)을 아래에 넘긴다

cd integration-tests
./gradlew test -Dbarofit.e2e.gateway-url=http://127.0.0.1:12345
```

인증 토큰은 `./keys/jwt-private.pem`(위 2단계에서 Secret으로 올린 바로 그 키)으로 직접 서명한다 —
따로 로그인할 필요 없다. 키 위치가 다르면 `-Dbarofit.e2e.keys-dir=<경로>`로 지정한다 (기본값
`../keys`).

전부 정상이면 Phase 1(모노레포 내 구축) + Phase 3(폴리레포 분리 후 재배포 검증)까지 완료다.
