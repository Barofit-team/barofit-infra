// 시나리오 4: 운동기록·통계 조회. analytics 서비스의 조회 3종을 한 반복에서 함께 호출한다
// (N+1/집계 쿼리 의심 지점 — 전략문서가 지목한 "DB 효율성" 확인 대상).
import http from 'k6/http';
import { check, group } from 'k6';
import { BASE_URL, authHeaders, isoDate } from '../lib/config.js';
import { buildOptions } from '../lib/stages.js';

export const options = buildOptions();

export default function () {
  const today = new Date();
  const weekAgo = new Date(today.getTime() - 7 * 24 * 60 * 60 * 1000);

  group('운동기록 목록', () => {
    const res = http.get(`${BASE_URL}/api/v1/workout-records?page=0&size=20`, { headers: authHeaders() });
    check(res, { '200': (r) => r.status === 200 });
  });

  group('월별 캘린더', () => {
    const res = http.get(
      `${BASE_URL}/api/v1/calendar?year=${today.getFullYear()}&month=${today.getMonth() + 1}`,
      { headers: authHeaders() },
    );
    check(res, { '200': (r) => r.status === 200 });
  });

  group('기간 통계 합계', () => {
    const res = http.get(
      `${BASE_URL}/api/v1/statistics/summary?startDate=${isoDate(weekAgo)}&endDate=${isoDate(today)}`,
      { headers: authHeaders() },
    );
    check(res, { '200': (r) => r.status === 200 });
  });
}
