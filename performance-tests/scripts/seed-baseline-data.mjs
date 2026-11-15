#!/usr/bin/env node
// 고정·재현 가능한 baseline 시드 데이터를 생성한다 (baseline-k6-테스트계획.md "시드 데이터 원칙").
// DB를 직접 건드리지 않고 SQL 파일만 만든다 — 실제 적용은 운영자가 명시적으로 실행한다:
//   kubectl exec -n barofit <postgres-pod> -- psql -U postgres -d barofit -f - < .artifacts/seed.sql
//
// 매 측정 라운드 전에 이 스크립트를 다시 실행하고 SQL을 재적용해 동일한 상태로 리셋한다.
// count는 06_auth_refresh.js가 쓰는 refresh token 풀 크기이기도 하므로, stress 단계 최대 VU 수
// (lib/stages.js 기준 100) 이상으로 넉넉히 잡아야 한다.
//
// 사용법: node scripts/seed-baseline-data.mjs [count=120]
import { writeFileSync, mkdirSync } from 'node:fs';
import { randomBytes, createHash, randomUUID } from 'node:crypto';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const OUT_DIR = path.resolve(__dirname, '..', '.artifacts');
const NICKNAME_PREFIX = 'k6-baseline-';

function base64url(buf) {
  return buf.toString('base64url');
}

function sha256Hex(input) {
  return createHash('sha256').update(input, 'utf8').digest('hex');
}

function isoNowPlus(days) {
  return new Date(Date.now() + days * 24 * 60 * 60 * 1000).toISOString();
}

function main() {
  const count = Number(process.argv[2] || 120);
  mkdirSync(OUT_DIR, { recursive: true });

  const users = [];
  const refreshTokens = [];

  for (let i = 0; i < count; i++) {
    const userId = randomUUID();
    const sessionId = randomUUID();
    const rawToken = base64url(randomBytes(32)); // RefreshTokenValues.generate()와 동일한 형식
    const tokenHash = sha256Hex(rawToken); // RefreshTokenValues.hash()와 동일(원문의 UTF-8 바이트를 SHA-256)

    users.push({ userId, nickname: `${NICKNAME_PREFIX}${i}` });
    refreshTokens.push({ userId, sessionId, rawToken, tokenHash });
  }

  const sqlLines = [
    '-- k6 baseline 성능 테스트용 고정 시드 데이터.',
    '-- 매 측정 라운드 전에 scripts/seed-baseline-data.mjs를 재실행하고 이 SQL을 다시 적용해 리셋한다.',
    '',
    `DELETE FROM identity.refresh_tokens WHERE user_id IN (SELECT id FROM identity.users WHERE nickname LIKE '${NICKNAME_PREFIX}%');`,
    `DELETE FROM identity.users WHERE nickname LIKE '${NICKNAME_PREFIX}%';`,
    '',
  ];

  for (const u of users) {
    sqlLines.push(
      `INSERT INTO identity.users (id, nickname, role, status, onboarded, created_at, updated_at) ` +
        `VALUES ('${u.userId}', '${u.nickname}', 'USER', 'ACTIVE', true, now(), now());`,
    );
  }
  sqlLines.push('');
  for (const t of refreshTokens) {
    sqlLines.push(
      `INSERT INTO identity.refresh_tokens (user_id, session_id, token_hash, expires_at, session_expires_at, created_at) ` +
        `VALUES ('${t.userId}', '${t.sessionId}', '${t.tokenHash}', '${isoNowPlus(30)}', '${isoNowPlus(90)}', now());`,
    );
  }

  const sqlPath = path.join(OUT_DIR, 'seed.sql');
  writeFileSync(sqlPath, sqlLines.join('\n') + '\n', 'utf8');

  const tokensPath = path.join(OUT_DIR, 'refresh-tokens.json');
  writeFileSync(tokensPath, JSON.stringify(refreshTokens.map((t) => t.rawToken), null, 2), 'utf8');

  const usersPath = path.join(OUT_DIR, 'users.json');
  writeFileSync(usersPath, JSON.stringify(users, null, 2), 'utf8');

  console.log(`생성됨: ${sqlPath} (사용자 ${users.length}명)`);
  console.log(`생성됨: ${tokensPath} (06_auth_refresh.js가 로드)`);
  console.log(`생성됨: ${usersPath}`);
  console.log('');
  console.log('다음 단계:');
  console.log('  1) 위 seed.sql을 postgres에 적용');
  console.log('  2) users.json의 userId 중 하나로 scripts/mint-access-token.mjs 실행 -> ACCESS_TOKEN');
  console.log('  3) run-all.sh로 시나리오 실행');
}

main();
