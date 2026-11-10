## 이 레포(서비스) 추가 규칙

- 레이어: `controller` → `service` → `repository` 순서로만 호출한다. `controller`에서 `repository`를
  직접 호출하지 않는다.
- 통합 테스트는 이 레포 자신에 둔다 (`src/integrationTest`, Testcontainers 기반). `barofit-infra`의
  통합 테스트와는 역할이 다르다 — 거긴 배포된 환경에 대한 전체 E2E만 다룬다.
- `barofit-common`의 test-fixtures(Testcontainers 베이스 클래스)를 재사용한다. 직접 Testcontainers
  설정을 새로 만들지 않는다.
