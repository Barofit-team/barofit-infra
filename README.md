# barofit-infra

**barofit** 백엔드의 Helm 차트·로컬 K8s 배포·통합 검증을 담는 레포입니다. 원래 `backend_baro`
모노레포에서 Phase 1(로컬 K8s/Helm 구축) 때 만든 `infra/`와, `integration-tests` 모듈을
폴리레포 전환 과정에서 이전했습니다(커밋 이력 보존).

서비스 코드는 여기 없습니다 — 각 서비스는 독립 레포([barofit-identity](https://github.com/Barofit-team/barofit-identity) 등)에 있고, 이 레포는 그 서비스들을 **배포(Helm)** 하고 **검증(integration-tests, 스크립트)** 하는 역할만 합니다.

## 디렉토리 구조

```
barofit-infra/
├─ infra/
│  ├─ charts/            서비스별 독립 Helm 차트(identity/routine/workout/analytics/report/gateway/postgres)
│  └─ umbrella/          7개 차트를 한 번에 설치하는 편의용 umbrella 차트
├─ integration-tests/    identity+routine을 묶어 검증하는 회귀 테스트(독립 Gradle 프로젝트)
├─ scripts/
│  ├─ build-and-push.sh      5개 서비스 레포(형제 디렉토리)를 순회하며 이미지 빌드·푸시
│  ├─ generate-jwt-keys.sh   로컬 개발용 JWT 키 생성
│  └─ verify-{services,workout,report}.cjs   minikube 배포 후 서비스 간 통신 스모크 테스트
└─ .env.example
```

## 로컬 minikube 배포

상세 절차(사전 준비, 시크릿 생성, 이미지 빌드, `helm upgrade --install`, 검증)는
[infra/README.md](infra/README.md)를 참고하세요.

이미지는 각 서비스 레포에서 개별적으로 빌드됩니다. 이 레포는 아래처럼 형제 디렉토리에 clone된
5개 서비스 레포를 순회하며 빌드/푸시만 오케스트레이션합니다:

```
<부모 디렉토리>/
├─ barofit-infra/        (이 레포)
├─ barofit-identity/
├─ barofit-routine/
├─ barofit-workout/
├─ barofit-analytics/
└─ barofit-report/
```

```bash
DOCKERHUB_USER=<hub-user> ./scripts/build-and-push.sh
```

## integration-tests

`identity`+`routine`을 하나의 Spring 컨텍스트로 묶어 MockMvc로 검증하는 회귀 테스트입니다
(배포된 환경을 HTTP로 호출하는 E2E가 아닙니다 — 전환은 추후 별도 작업).

```bash
cd integration-tests
./gradlew test   # Docker 필요(Testcontainers).
                 # barofit-identity, barofit-routine, barofit-common(barofit-runtime)이
                 # mavenLocal에 먼저 publishToMavenLocal 되어 있어야 함
```

## 관련 레포

- [barofit-common](https://github.com/Barofit-team/barofit-common) — 공유 라이브러리
- [barofit-identity](https://github.com/Barofit-team/barofit-identity) · [barofit-routine](https://github.com/Barofit-team/barofit-routine) · [barofit-workout](https://github.com/Barofit-team/barofit-workout) · [barofit-analytics](https://github.com/Barofit-team/barofit-analytics) · [barofit-report](https://github.com/Barofit-team/barofit-report)
- [backend_baro](https://github.com/Barofit-team/backend_baro) — 분리 이전 모노레포(참고용)
