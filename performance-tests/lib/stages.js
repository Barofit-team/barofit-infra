// baseline-k6-테스트계획.md의 3단계 부하 프로파일. STAGE 환경변수(smoke|baseline|stress)로 고른다.
// baseline 단계는 라운드 간 비교 기준점이므로 값을 절대 바꾸지 않는다.

const PROFILES = {
  smoke: {
    executor: 'constant-vus',
    vus: 1,
    duration: '30s',
  },
  baseline: {
    executor: 'constant-vus',
    vus: 10,
    duration: '1m',
  },
  stress: {
    executor: 'ramping-vus',
    startVUs: 0,
    stages: [
      { target: 10, duration: '30s' },
      { target: 50, duration: '2m' },
      { target: 100, duration: '2m' },
      { target: 0, duration: '30s' },
    ],
  },
};

export function currentStageName() {
  return __ENV.STAGE || 'smoke';
}

/**
 * 시나리오 파일에서 `export const options = buildOptions();` 형태로 사용한다.
 * thresholds는 아직 정하지 않았다(1차는 측정·기록이 목적이라 pass/fail 게이트를 걸지 않는다).
 */
export function buildOptions() {
  const name = currentStageName();
  const profile = PROFILES[name];
  if (!profile) {
    throw new Error(`알 수 없는 STAGE: ${name} (smoke|baseline|stress 중 하나여야 합니다)`);
  }
  const scenario =
    profile.executor === 'ramping-vus'
      ? { executor: 'ramping-vus', startVUs: profile.startVUs, stages: profile.stages, exec: 'default' }
      : { executor: 'constant-vus', vus: profile.vus, duration: profile.duration, exec: 'default' };

  return { scenarios: { [name]: scenario } };
}
