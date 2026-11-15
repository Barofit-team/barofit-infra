// 시나리오 1: 루틴템플릿 조회. RoutineTemplateController#list — 인증 불필요(공개 API).
import http from 'k6/http';
import { check } from 'k6';
import { BASE_URL } from '../lib/config.js';
import { buildOptions } from '../lib/stages.js';

export const options = buildOptions();

export default function () {
  const res = http.get(`${BASE_URL}/api/v1/routine-templates`);
  check(res, { '200 응답': (r) => r.status === 200 });
}
