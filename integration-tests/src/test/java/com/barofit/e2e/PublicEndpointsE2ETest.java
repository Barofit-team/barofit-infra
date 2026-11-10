package com.barofit.e2e;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import tools.jackson.databind.JsonNode;

/** 인증 없이 열려 있어야 하는 경로들이 실제로 토큰 없이 통과하는지 확인한다. */
class PublicEndpointsE2ETest {

  @Test
  void jwksEndpointIsPublicAndReturnsKeys() {
    JsonNode body =
        GatewayClient.client().get().uri("/.well-known/jwks.json").retrieve().body(JsonNode.class);
    assertThat(body.path("keys").isArray()).isTrue();
    assertThat(body.path("keys")).isNotEmpty();
  }

  @Test
  void exerciseCatalogIsPublic() {
    assertThat(GatewayClient.statusOf("/api/v1/exercises", null)).isEqualTo(200);
  }

  @Test
  void routineTemplatesArePublic() {
    assertThat(GatewayClient.statusOf("/api/v1/routine-templates", null)).isEqualTo(200);
  }
}
