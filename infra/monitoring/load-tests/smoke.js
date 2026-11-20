import http from 'k6/http';
import { check, sleep } from 'k6';

// Read-only gateway health smoke. Business scenarios require test accounts/data.
export const options = {
  vus: Number(__ENV.VUS || 2),
  duration: __ENV.DURATION || '30s',
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<1000'],
    checks: ['rate>0.99'],
  },
};

export default function () {
  const response = http.get(`${__ENV.BASE_URL || 'http://localhost:18080'}/health`, {
    tags: { name: 'gateway-health' },
  });
  check(response, { 'health returns 200': (r) => r.status === 200 });
  sleep(1);
}
