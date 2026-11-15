// 시나리오 6: 인증 리프레시. AuthController#refresh (POST /api/v1/auth/refresh).
//
// 주의: identity 서비스는 refresh 토큰을 매 호출마다 회전(rotation)시킨다 — 한 번 쓴 토큰은
// 즉시 폐기되고 응답으로 새 토큰을 내려준다(재사용 시 세션 전체 폐기, AuthService 참고).
// 그래서 모든 VU가 같은 토큰 하나를 공유하면 동시 요청 중 하나만 성공하고 나머지는 실패한다.
// → VU마다 "독립된 회전 체인"을 쓴다: scripts/seed-baseline-data.mjs가 미리 심어둔 refresh token
//   풀(.artifacts/refresh-tokens.json)에서 (__VU - 1) 번째 토큰을 집어, 응답으로 받은 새 토큰을
//   그 VU가 계속 이어서 쓴다. 풀 크기가 동시 VU 수보다 작으면 일부 VU가 충돌한다 — stress 단계의
//   최대 VU 수 이상으로 시드하라(seed-baseline-data.mjs의 count 인자).
import http from 'k6/http';
import { check } from 'k6';
import { SharedArray } from 'k6/data';
import { BASE_URL } from '../lib/config.js';
import { buildOptions } from '../lib/stages.js';

export const options = buildOptions();

const TOKENS_FILE = __ENV.REFRESH_TOKENS_FILE || '../.artifacts/refresh-tokens.json';

const seedTokens = new SharedArray('refresh-tokens', function () {
  return JSON.parse(open(TOKENS_FILE));
});

// 모듈 top-level 변수는 k6에서 VU별로 독립된 JS 인스턴스를 가지므로 VU 간에 섞이지 않는다.
let currentToken = null;

export default function () {
  if (currentToken === null) {
    if (seedTokens.length === 0) {
      throw new Error('refresh-tokens.json이 비어 있습니다. seed-baseline-data.mjs를 먼저 실행하세요.');
    }
    const idx = (__VU - 1) % seedTokens.length;
    currentToken = seedTokens[idx];
  }

  const res = http.post(
    `${BASE_URL}/api/v1/auth/refresh`,
    JSON.stringify({ refreshToken: currentToken }),
    { headers: { 'Content-Type': 'application/json' } },
  );

  const ok = check(res, { '200 재발급': (r) => r.status === 200 });
  if (ok) {
    currentToken = res.json('refreshToken');
  }
}
