#!/usr/bin/env node
// 소셜 로그인(social-login)을 거치지 않고, identity 서비스의 AccessTokenIssuer와 동일한
// 구조의 RS256 액세스 토큰을 로컬 개인키로 직접 서명해 발급한다.
//
// identity 서비스의 실제 발급 클레임(AccessTokenIssuer.java, BarofitTokenClaims.java)과 동일:
//   iss=barofit-identity, aud=[barofit-api], sub=<userId>, role, iat, exp, jti
// 실제 발급 정책(TokenPolicy.ACCESS_TOKEN_TTL=15분)과 무관하게, 부하 테스트 라운드 전체를
// 커버하도록 기본 만료를 120분으로 길게 잡는다. 리소스 서버는 서명·만료·iss/aud만 검증하므로
// 발급 시점 정책과 달라도 무방하다(baseline-k6-테스트계획.md "인증 전략" 참고).
//
// 사용법:
//   JWT_PRIVATE_KEY_PATH=./keys/jwt-private.pem JWT_PUBLIC_JWKS_PATH=./keys/jwt-jwks.json \
//     node scripts/mint-access-token.mjs <userId-uuid> [role=USER] [ttlMinutes=120]
import { readFileSync } from 'node:fs';
import { createSign, randomUUID } from 'node:crypto';

function base64url(input) {
  return Buffer.from(input).toString('base64url');
}

function main() {
  const [userId, role = 'USER', ttlMinutesArg = '120'] = process.argv.slice(2);
  if (!userId) {
    console.error('사용법: node mint-access-token.mjs <userId-uuid> [role=USER] [ttlMinutes=120]');
    process.exit(1);
  }

  const privateKeyPath = process.env.JWT_PRIVATE_KEY_PATH;
  const jwksPath = process.env.JWT_PUBLIC_JWKS_PATH;
  if (!privateKeyPath || !jwksPath) {
    console.error('JWT_PRIVATE_KEY_PATH, JWT_PUBLIC_JWKS_PATH 환경변수가 필요합니다 (barofit-infra/keys/ 참고).');
    process.exit(1);
  }

  const privateKeyPem = readFileSync(privateKeyPath, 'utf8');
  const jwks = JSON.parse(readFileSync(jwksPath, 'utf8'));
  const currentKid = process.env.JWT_CURRENT_KID || jwks.keys?.[0]?.kid;
  if (!currentKid) {
    console.error('kid를 찾을 수 없습니다. JWT_CURRENT_KID 환경변수로 직접 지정하세요.');
    process.exit(1);
  }

  const now = Math.floor(Date.now() / 1000);
  const ttlMinutes = Number(ttlMinutesArg);

  const header = { alg: 'RS256', kid: currentKid };
  const payload = {
    iss: 'barofit-identity',
    aud: ['barofit-api'],
    sub: userId,
    role,
    iat: now,
    exp: now + ttlMinutes * 60,
    jti: randomUUID(),
  };

  const signingInput = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(payload))}`;
  const signature = createSign('RSA-SHA256').update(signingInput).sign(privateKeyPem);
  const token = `${signingInput}.${signature.toString('base64url')}`;

  console.log(token);
}

main();
