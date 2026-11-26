# k6 baseline 성능 테스트

계획 문서: `/barofit/test/계획/baseline-k6-테스트계획.md` (이 레포 바깥, barofit 작업 폴더 전체 공유 문서)
관련 이슈: [barofit-infra#12](https://github.com/Barofit-team/barofit-infra/issues/12)

## 전제조건

- `minikube start --cpus=4 --memory=8192` 후 `infra/umbrella` 설치 상태 (infra/README.md)
- 게이트웨이 NodePort `30080`으로 접근 가능
- `keys/jwt-private.pem`, `keys/jwt-jwks.json` 로컬 준비(없으면 `scripts/generate-jwt-keys.sh`)
- Node.js 20+ (헬퍼 스크립트용, 외부 npm 의존성 없음 — 전부 Node 내장 `crypto`만 사용)
- k6 (`brew install k6` 등)

## 실행 순서

```bash
# 1) 고정 시드 데이터 생성 (매 라운드 전 재실행 -> 동일 상태로 리셋)
node scripts/seed-baseline-data.mjs 120
# -> .artifacts/seed.sql, .artifacts/refresh-tokens.json, .artifacts/users.json

# 2) 위 SQL을 postgres에 적용 (-i 없으면 stdin이 안 전달돼 아무 일도 안 일어난다 — 실측으로 확인함)
kubectl exec -i -n barofit <postgres-pod> -- psql -U postgres -d barofit -f - < .artifacts/seed.sql

# 3) users.json의 첫 사용자로 액세스 토큰 발급(스모크/루틴/운동기록/리포트 시나리오가 공유해서 쓴다)
JWT_PRIVATE_KEY_PATH=./keys/jwt-private.pem JWT_PUBLIC_JWKS_PATH=./keys/jwt-jwks.json \
  node scripts/mint-access-token.mjs "$(node -e "console.log(require('./.artifacts/users.json')[0].userId)")"

# 4) 전체 시나리오 실행 (STAGE=smoke|baseline|stress)
ACCESS_TOKEN=<위 출력> STAGE=smoke ./run-all.sh
```

## 구조

```
performance-tests/
  lib/
    config.js   BASE_URL, ACCESS_TOKEN, 공통 헤더
    stages.js   smoke/baseline/stress 3단계 부하 프로파일 (STAGE 환경변수로 선택)
    uuid.js     세션 ID 생성용 uuidv4
  scenarios/    7개 독립 시나리오 (00_health ~ 06_auth_refresh)
  scripts/
    seed-baseline-data.mjs   고정 시드 SQL + refresh token 풀 생성
    mint-access-token.mjs    RS256 테스트 액세스 토큰 직접 발급(소셜 로그인 우회)
    watch-hpa.sh             HPA 적용 전/후 비교용 — 레플리카 수·HPA 상태·FailedScheduling
                             이벤트를 주기적으로 폴링해 CSV/로그로 남긴다(run-all.sh와 별도
                             터미널에서 병행 실행). 사용법은 스크립트 상단 주석 참고.
  run-all.sh    시나리오를 순서대로 실행하고 raw summary를 results/에 저장
  results/      raw k6 summary(.json). git에는 올리지 않는다
  .artifacts/   시드 SQL, 토큰 — 자격증명과 동급이라 git에 올리지 않는다
```

## 시나리오 ↔ 계획 문서 매핑

| 파일 | 계획 문서 시나리오 # | 엔드포인트 | 인증 |
|---|---|---|---|
| `00_health.js` | 0 (웜업, 집계 제외) | `/health`, `/{svc}/actuator/health` | 불필요 |
| `01_routine_templates_read.js` | 1 | `GET /api/v1/routine-templates` | 불필요 |
| `02_routine_create.js` | 2 | `POST /api/v1/routines` | 필요 |
| `03_workout_session_sync.js` | 3 | `PUT /api/v1/workout-sessions/{id}` | 필요 |
| `04_workout_records_statistics.js` | 4 | `/workout-records`, `/calendar`, `/statistics/summary` | 필요 |
| `05_reports.js` | 5 | `/reports/daily`, `/reports/weekly` | 필요 |
| `06_auth_refresh.js` | 6 | `POST /api/v1/auth/refresh` | refresh token 풀 |

계획 문서 작성 시점의 가정과 실제 코드가 다른 부분을 이번 스크립트 작성 중 바로잡았다:
운동세션 생성은 `POST`가 아니라 **`PUT /api/v1/workout-sessions/{sessionId}`** (기기가 세션 UUID를
직접 생성해 보낸다)이며, 최초 저장 시 workout 서비스가 routine 서비스를 내부 호출해 소유권을
검증한다 — 그래서 시나리오 3이 유독 느리면 routine 쪽도 함께 봐야 한다.

## 알려진 단순화(1차 baseline 범위)

- 시나리오 1·2·4·5는 **모든 VU가 같은 액세스 토큰(=같은 테스트 사용자)을 공유**한다. 엔드포인트
  자체의 동시성 하의 지연을 보는 게 목적이라 1차엔 충분하다고 판단했다. 사용자별 데이터 격리/락
  경쟁까지 보려면 사용자 N명을 만들어 VU별로 분산하는 2차 개선이 필요하다.
- 시나리오 6(인증 리프레시)만 예외적으로 VU별 refresh token 풀을 쓴다 — 토큰이 매 호출마다
  회전(rotation)해서 공유하면 동시 요청 중 하나만 성공하기 때문이다. 풀 크기(`seed-baseline-data.mjs`
  의 count)는 stress 단계 최대 VU 수(`lib/stages.js` 기준 100) 이상으로 유지해야 한다.
- 시나리오 3은 `routineSnapshot`에 `{}`를 보내면 `400 INVALID_WORKOUT`("시작 시점의 루틴 상세
  스냅샷이 필요합니다")로 거절당한다 — 실제 클러스터에 돌려보고 확인한 뒤 바로잡았다. 루틴 생성
  POST 응답 자체가 `Detail` 타입이라 그걸 그대로 `routineSnapshot`으로 재사용하면 된다
  (`setup()`에서 처리). `sets: []`는 검증 없이 통과한다.
- thresholds(pass/fail 게이트)는 아직 걸지 않았다 — 지금은 수치를 측정·기록하는 단계이고, CI 게이트로
  쓰는 건 baseline 수치가 쌓인 뒤의 다음 단계다.

## 결과 기록

`run-all.sh`가 `results/`에 raw k6 summary(JSON)를 남긴다. 이걸 바탕으로 커밋 해시·시드 스펙·
p50/p95/p99·RPS·에러율·직전 라운드 대비 변화율을 담은 사람이 읽을 markdown을 작성해
`/barofit/test/결과/`에도 같이 남긴다 (계획 문서 "결과 저장 규칙").
