package com.barofit.e2e;

import java.util.regex.Pattern;
import org.springframework.web.client.RestClient;

/**
 * minikube에 배포된 환경의 게이트웨이를 가리키는 공용 HTTP 클라이언트.
 *
 * <p>게이트웨이 URL은 {@code barofit.e2e.gateway-url} 시스템 프로퍼티로 주입한다 ({@code minikube service gateway -n
 * barofit --url} 결과를 그대로 넘기면 된다).
 */
final class GatewayClient {

  private static final String URL_PROPERTY = "barofit.e2e.gateway-url";

  private GatewayClient() {}

  static RestClient client() {
    return RestClient.builder().baseUrl(baseUrl()).build();
  }

  private static final Pattern CODE_FIELD = Pattern.compile("\"code\"\\s*:\\s*\"([^\"]+)\"");

  /** 에러 상태에서도 예외를 던지지 않고 상태 코드만 돌려준다 (401/404 등을 검증용으로 쓰기 위함). */
  static int statusOf(String path, String bearerTokenOrNull) {
    var request = client().get().uri(path);
    if (bearerTokenOrNull != null) {
      request = request.header("Authorization", "Bearer " + bearerTokenOrNull);
    }
    return request.exchange((req, res) -> res.getStatusCode().value());
  }

  /**
   * ProblemDetail 응답의 {@code code} 필드를 돌려준다(2xx면 null). 인증 실패("AUTH_INVALID_TOKEN")와 인증은 통과했지만 리소스가
   * 없는 등의 업무 로직 오류(둘 다 401/404일 수 있음)를 구분하는 데 쓴다.
   */
  static String errorCodeOf(String path, String bearerTokenOrNull) {
    var request = client().get().uri(path);
    if (bearerTokenOrNull != null) {
      request = request.header("Authorization", "Bearer " + bearerTokenOrNull);
    }
    return request.exchange((req, res) -> {
      if (res.getStatusCode().is2xxSuccessful()) {
        return null;
      }
      String body = new String(res.getBody().readAllBytes());
      var matcher = CODE_FIELD.matcher(body);
      return matcher.find() ? matcher.group(1) : "UNKNOWN(" + body + ")";
    });
  }

  private static String baseUrl() {
    String url = System.getProperty(URL_PROPERTY);
    if (url == null || url.isBlank()) {
      throw new IllegalStateException(
          URL_PROPERTY
              + " 시스템 프로퍼티가 없습니다. `minikube service gateway -n barofit --url` 결과를 넘기세요"
              + " (예: ./gradlew test -Dbarofit.e2e.gateway-url=http://127.0.0.1:12345)");
    }
    return url;
  }
}
