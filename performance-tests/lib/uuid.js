// k6(goja) 런타임에는 crypto.randomUUID가 없을 수 있어 Math.random 기반으로 직접 만든다.
// 부하 테스트용 세션 ID 생성 목적이라 암호학적 강도는 필요하지 않다.
export function uuidv4() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}
