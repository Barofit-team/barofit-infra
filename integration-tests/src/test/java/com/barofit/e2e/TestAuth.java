package com.barofit.e2e;

import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.JWSHeader;
import com.nimbusds.jose.crypto.RSASSASigner;
import com.nimbusds.jose.jwk.JWKSet;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.SignedJWT;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyFactory;
import java.security.KeyPairGenerator;
import java.security.NoSuchAlgorithmException;
import java.security.interfaces.RSAPrivateKey;
import java.security.spec.InvalidKeySpecException;
import java.security.spec.PKCS8EncodedKeySpec;
import java.text.ParseException;
import java.time.Instant;
import java.util.Base64;
import java.util.Date;
import java.util.UUID;

/**
 * 실제 배포(K8s Secret {@code barofit-jwt-keys})에 쓰인 바로 그 키로 토큰을 직접 서명한다. 소셜 로그인 핸드셰이크는 블랙박스 환경에서 재현할 수
 * 없으므로, "이미 로그인된 사용자"를 가정하고 서비스 간 토큰 신뢰를 검증하는 용도로만 쓴다.
 */
final class TestAuth {

  private static final String KEYS_DIR_PROPERTY = "barofit.e2e.keys-dir";
  private static final String ISSUER = "barofit-identity";
  private static final String AUDIENCE = "barofit-api";

  private static final RSAPrivateKey PRIVATE_KEY = loadPrivateKey();
  private static final String KID = loadKid();

  private TestAuth() {}

  static String accessToken(UUID userId) {
    return accessToken(userId, "USER");
  }

  static String accessToken(UUID userId, String role) {
    try {
      Instant now = Instant.now();
      JWTClaimsSet claims =
          new JWTClaimsSet.Builder()
              .issuer(ISSUER)
              .audience(AUDIENCE)
              .subject(userId.toString())
              .claim("role", role)
              .issueTime(Date.from(now))
              .expirationTime(Date.from(now.plusSeconds(900)))
              .build();
      SignedJWT jwt =
          new SignedJWT(new JWSHeader.Builder(JWSAlgorithm.RS256).keyID(KID).build(), claims);
      jwt.sign(new RSASSASigner(PRIVATE_KEY));
      return jwt.serialize();
    } catch (Exception e) {
      throw new IllegalStateException("테스트 토큰 서명 실패", e);
    }
  }

  /** 실제 배포 키와 무관한 서명 — 서비스가 서명을 실제로 검증하는지(아무 Bearer나 통과시키지 않는지) 확인용. */
  static String accessTokenSignedWithWrongKey(UUID userId) {
    try {
      var keyPair = KeyPairGenerator.getInstance("RSA");
      keyPair.initialize(2048);
      Instant now = Instant.now();
      JWTClaimsSet claims =
          new JWTClaimsSet.Builder()
              .issuer(ISSUER)
              .audience(AUDIENCE)
              .subject(userId.toString())
              .claim("role", "USER")
              .issueTime(Date.from(now))
              .expirationTime(Date.from(now.plusSeconds(900)))
              .build();
      SignedJWT jwt =
          new SignedJWT(new JWSHeader.Builder(JWSAlgorithm.RS256).keyID(KID).build(), claims);
      jwt.sign(
          new RSASSASigner(
              (java.security.interfaces.RSAPrivateKey) keyPair.generateKeyPair().getPrivate()));
      return jwt.serialize();
    } catch (Exception e) {
      throw new IllegalStateException("테스트 토큰 서명 실패", e);
    }
  }

  private static RSAPrivateKey loadPrivateKey() {
    try {
      String pem = Files.readString(keysDir().resolve("jwt-private.pem"));
      String base64 =
          pem.replace("-----BEGIN PRIVATE KEY-----", "")
              .replace("-----END PRIVATE KEY-----", "")
              .replaceAll("\\s", "");
      byte[] bytes = Base64.getDecoder().decode(base64);
      KeyFactory factory = KeyFactory.getInstance("RSA");
      return (RSAPrivateKey) factory.generatePrivate(new PKCS8EncodedKeySpec(bytes));
    } catch (IOException e) {
      throw new UncheckedIOException(e);
    } catch (NoSuchAlgorithmException | InvalidKeySpecException e) {
      throw new IllegalStateException(e);
    }
  }

  private static String loadKid() {
    try {
      JWKSet jwks = JWKSet.load(keysDir().resolve("jwt-jwks.json").toFile());
      return jwks.getKeys().get(0).getKeyID();
    } catch (IOException | ParseException e) {
      throw new IllegalStateException(e);
    }
  }

  private static Path keysDir() {
    String configured = System.getProperty(KEYS_DIR_PROPERTY, "../keys");
    Path dir = Path.of(configured);
    if (!Files.isDirectory(dir)) {
      throw new IllegalStateException(
          KEYS_DIR_PROPERTY
              + "("
              + dir.toAbsolutePath()
              + ")가 없습니다. scripts/generate-jwt-keys.sh로 먼저 키를 만들고 배포하세요");
    }
    return dir;
  }
}
