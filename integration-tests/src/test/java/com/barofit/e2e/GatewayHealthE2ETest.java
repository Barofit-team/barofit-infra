package com.barofit.e2e;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

/** 게이트웨이와 5개 서비스가 전부 떠서 응답하는지 확인한다. */
class GatewayHealthE2ETest {

  @Test
  void gatewayItselfRespondsOk() {
    String body = GatewayClient.client().get().uri("/health").retrieve().body(String.class);
    assertThat(body).contains("\"UP\"");
  }

  @Test
  void identityHealthIsUp() {
    assertUp("/identity/actuator/health");
  }

  @Test
  void workoutHealthIsUp() {
    assertUp("/workout/actuator/health");
  }

  @Test
  void analyticsHealthIsUp() {
    assertUp("/analytics/actuator/health");
  }

  @Test
  void reportHealthIsUp() {
    assertUp("/report/actuator/health");
  }

  @Test
  void routineHealthIsUp() {
    // 게이트웨이의 catch-all(/)이 routine으로 가므로 /routine 접두사가 없다.
    assertUp("/actuator/health");
  }

  private void assertUp(String path) {
    String body = GatewayClient.client().get().uri(path).retrieve().body(String.class);
    assertThat(body).contains("\"UP\"");
  }
}
