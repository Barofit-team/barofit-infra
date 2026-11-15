// 시나리오 3: 운동세션 동기화. WorkoutSessionController#sync (PUT /api/v1/workout-sessions/{sessionId}).
// 첫 저장(revision=1)은 workout 서비스가 routine 서비스를 내부 호출해 소유권을 검증한다
// (cross-service 호출이 섞여 있어 병목 추적 시 "이 시나리오만 유독 느리다"면 routine 쪽도 같이 봐야 한다).
// setup()에서 전용 루틴을 하나 만들어 모든 반복이 같은 routineId를 재사용한다.
import http from 'k6/http';
import { check } from 'k6';
import { BASE_URL, authHeaders } from '../lib/config.js';
import { buildOptions } from '../lib/stages.js';
import { uuidv4 } from '../lib/uuid.js';

export const options = buildOptions();

const TEMPLATE_ID = __ENV.ROUTINE_TEMPLATE_ID || '00000000-0000-0000-0000-000000000001';

export function setup() {
  const res = http.post(
    `${BASE_URL}/api/v1/routines`,
    JSON.stringify({ templateId: TEMPLATE_ID }),
    { headers: authHeaders() },
  );
  if (res.status !== 201) {
    throw new Error(`setup용 루틴 생성 실패: ${res.status} ${res.body}`);
  }
  return { routineId: res.json('id') };
}

export default function (data) {
  const sessionId = uuidv4();
  const now = new Date();
  const body = {
    routineId: data.routineId,
    routineSnapshot: {},
    status: 'COMPLETED',
    revision: 1,
    startedAt: new Date(now.getTime() - 60000).toISOString(),
    endedAt: now.toISOString(),
    activeDurationSeconds: 60,
    sets: [],
  };
  const res = http.put(
    `${BASE_URL}/api/v1/workout-sessions/${sessionId}`,
    JSON.stringify(body),
    { headers: authHeaders() },
  );
  // 정확한 성공 상태 코드는 첫 실제 실행에서 확인 필요(컨트롤러에 @ResponseStatus 명시가 없어 기본 200으로 가정).
  check(res, { '200 동기화': (r) => r.status === 200 });
}
