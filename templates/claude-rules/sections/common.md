## 이 레포(barofit-common) 추가 규칙

- 이 레포는 5개 서비스 레포가 `mavenLocal()`로 의존한다. **퍼블릭 API(공개 클래스·메서드)를 바꾸면 모든
  서비스 레포에 영향**이 간다 — 하위호환을 깨는 변경인지 먼저 따져본다.
- 변경 후에는 `./gradlew publishToMavenLocal`로 반영하고, 영향받는 서비스 레포 최소 1곳에서 재빌드까지
  확인한다.
- `common`(에러 처리) / `runtime`(보안·설정) / test-fixtures 모듈의 경계를 지킨다 — 서비스별 전용
  로직은 여기 두지 않는다.
