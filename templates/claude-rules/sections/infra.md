## 이 레포(barofit-infra) 추가 규칙

- `infra/charts`(Helm), `infra/umbrella`, `scripts/`를 변경하면 **반드시** minikube에 재배포하고
  `integration-tests`의 E2E까지 통과시켜야 완료다 (완료 기준 예외 없음).
- `integration-tests`는 게이트웨이를 경유한 HTTP 클라이언트로 배포된 환경을 호출하는 순수 E2E다.
  서비스 레포 자신의 단위·통합 테스트와 역할이 겹치지 않게 한다 (서비스 레포 내부 로직 검증을 여기서
  다시 하지 않는다).
- 차트·스크립트를 수정했으면 `infra/README.md`의 절차(시크릿 생성 → 이미지 빌드 → umbrella 설치 →
  상태 확인)가 여전히 맞는지 같이 확인한다.
- 이 레포는 `templates/claude-rules/`에 7개 레포 공통 CLAUDE.md/docs 템플릿 원본을 보관한다.
  규칙을 바꿀 땐 여기를 먼저 고치고 `scripts/sync-claude-rules.sh`로 재배포한다 (단, 이미 배포된
  레포들이 그 사이 독립적으로 수정한 내용을 덮어쓸 수 있으니 재배포 전엔 각 레포 상태를 확인한다).
