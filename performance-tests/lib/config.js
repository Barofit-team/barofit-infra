// 공통 설정. 모든 시나리오가 import 한다.

export const BASE_URL = __ENV.BASE_URL || 'http://localhost:30080';
export const ACCESS_TOKEN = __ENV.ACCESS_TOKEN || '';

export function authHeaders(extra) {
  if (!ACCESS_TOKEN) {
    throw new Error('ACCESS_TOKEN이 없습니다. scripts/mint-access-token.mjs로 먼저 발급하세요.');
  }
  return Object.assign(
    { Authorization: `Bearer ${ACCESS_TOKEN}`, 'Content-Type': 'application/json' },
    extra || {},
  );
}

export function isoDate(date) {
  return date.toISOString().slice(0, 10);
}
