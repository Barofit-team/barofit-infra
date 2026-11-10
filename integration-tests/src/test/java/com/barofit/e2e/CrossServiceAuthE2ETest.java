package com.barofit.e2e;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.LocalDate;
import java.util.UUID;
import org.junit.jupiter.api.Test;

/**
 * identity가 서명한 토큰이 게이트웨이를 거쳐 5개 서비스 전부에서 똑같이 신뢰되는지 확인한다.
 *
 * <p>모노레포 시절의 SocialLoginRoutineTests는 identity의 소셜 로그인 내부 클래스를 Mockito로 직접 mock해서 "소셜 로그인 → 루틴
 * 접근"을 한 Spring 컨텍스트에서 검증했다. 지금은 배포된 환경을 블랙박스로 HTTP 호출만 하므로 그 내부 클래스에 접근할 수 없다 — 대신 "이미 로그인된 사용자의
 * 토큰이 서비스 경계를 넘어 신뢰되는가"라는, 분리 후에도 실제로 검증 가능한 핵심만 다룬다.
 *
 * <p>인증 성공 여부는 HTTP 상태코드가 아니라 ProblemDetail의 {@code code} 필드로 구분한다 — 예를 들어 identity의 {@code
 * /users/me}는 토큰이 유효해도 그 사용자가 DB에 없으면 ({@code AUTH_USER_WITHDRAWN}로) 여전히 401을 돌려주므로, "인증 자체가
 * 통과했는가"는 {@code AUTH_INVALID_TOKEN}이 아닌지로 판단해야 한다.
 */
class CrossServiceAuthE2ETest {

  private static final String INVALID_TOKEN = "AUTH_INVALID_TOKEN";

  @Test
  void identityAcceptsValidTokenButRejectsMissingOrForgedOnes() {
    assertAuthBoundary("/api/v1/users/me");
  }

  @Test
  void routineAcceptsValidTokenButRejectsMissingOrForgedOnes() {
    assertAuthBoundary("/api/v1/routines");
  }

  @Test
  void workoutAcceptsValidTokenButRejectsMissingOrForgedOnes() {
    assertAuthBoundary("/api/v1/workout-sessions/streak");
  }

  @Test
  void analyticsAcceptsValidTokenButRejectsMissingOrForgedOnes() {
    LocalDate start = LocalDate.now().minusDays(1);
    LocalDate end = LocalDate.now();
    assertAuthBoundary("/api/v1/statistics/summary?startDate=" + start + "&endDate=" + end);
  }

  @Test
  void reportAcceptsValidTokenButRejectsMissingOrForgedOnes() {
    LocalDate today = LocalDate.now();
    assertAuthBoundary(
        "/api/v1/reports/calendar?year=" + today.getYear() + "&month=" + today.getMonthValue());
  }

  /** 토큰 없음/위조 서명은 AUTH_INVALID_TOKEN이어야 하고, 올바른 서명은 그 코드가 아니어야 한다. */
  private void assertAuthBoundary(String path) {
    UUID userId = UUID.randomUUID();

    assertThat(GatewayClient.errorCodeOf(path, null)).isEqualTo(INVALID_TOKEN);
    assertThat(GatewayClient.errorCodeOf(path, TestAuth.accessTokenSignedWithWrongKey(userId)))
        .isEqualTo(INVALID_TOKEN);
    assertThat(GatewayClient.errorCodeOf(path, TestAuth.accessToken(userId)))
        .isNotEqualTo(INVALID_TOKEN);
  }
}
