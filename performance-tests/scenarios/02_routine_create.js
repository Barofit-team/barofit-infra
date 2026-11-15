// 시나리오 2: 루틴 생성. RoutineController#create (POST /api/v1/routines).
// templateId 기본값은 RoutineRequests.Create의 Swagger 예시와 동일한 시드 템플릿 UUID.
// 반복 실행마다 새 루틴이 쌓인다 — 매 라운드 전 DB 리셋 전제와 맞물려 있다(계획 문서 "시드 데이터 원칙").
import http from 'k6/http';
import { check } from 'k6';
import { BASE_URL, authHeaders } from '../lib/config.js';
import { buildOptions } from '../lib/stages.js';

export const options = buildOptions();

const TEMPLATE_ID = __ENV.ROUTINE_TEMPLATE_ID || '00000000-0000-0000-0000-000000000001';

export default function () {
  const res = http.post(
    `${BASE_URL}/api/v1/routines`,
    JSON.stringify({ templateId: TEMPLATE_ID }),
    { headers: authHeaders() },
  );
  check(res, { '201 생성': (r) => r.status === 201 });
}
