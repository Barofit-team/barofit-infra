// 시나리오 0: 헬스체크/웜업. 다른 시나리오보다 먼저, 단독으로 돌려서 전체 서비스 기동을 확인한다.
// 이 시나리오의 수치는 baseline 비교 대상에서 제외한다(계획 문서 참고).
import http from 'k6/http';
import { check } from 'k6';
import { BASE_URL } from '../lib/config.js';
import { buildOptions } from '../lib/stages.js';

export const options = buildOptions();

// routine은 전용 prefix가 없어 게이트웨이 기본(catch-all) 경로로 그대로 노출된다.
const TARGETS = [
  '/health',
  '/identity/actuator/health',
  '/workout/actuator/health',
  '/analytics/actuator/health',
  '/report/actuator/health',
  '/actuator/health',
];

export default function () {
  for (const path of TARGETS) {
    const res = http.get(`${BASE_URL}${path}`);
    check(res, { [`${path} -> 200`]: (r) => r.status === 200 });
  }
}
