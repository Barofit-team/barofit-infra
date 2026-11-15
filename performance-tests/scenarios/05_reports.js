// 시나리오 5: 리포트 조회. ReportController의 일일/주간 요약(Map<String,Object> 집계 응답).
import http from 'k6/http';
import { check, group } from 'k6';
import { BASE_URL, authHeaders, isoDate } from '../lib/config.js';
import { buildOptions } from '../lib/stages.js';

export const options = buildOptions();

export default function () {
  const today = new Date();
  const weekAgo = new Date(today.getTime() - 7 * 24 * 60 * 60 * 1000);

  group('일일 리포트', () => {
    const res = http.get(`${BASE_URL}/api/v1/reports/daily?date=${isoDate(today)}`, { headers: authHeaders() });
    check(res, { '200': (r) => r.status === 200 });
  });

  group('주간 리포트', () => {
    const res = http.get(`${BASE_URL}/api/v1/reports/weekly?startDate=${isoDate(weekAgo)}`, { headers: authHeaders() });
    check(res, { '200': (r) => r.status === 200 });
  });
}
