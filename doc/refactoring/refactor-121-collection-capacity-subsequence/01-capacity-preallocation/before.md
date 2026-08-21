# Before — Collection Capacity Pre-allocation

Firestore·RealtimeDB 매핑 경로가 빈 배열에서 `append`를 시작했다. 입력 문서·스냅샷 개수를 알 수 있어도 버퍼 확장이 반복될 수 있었다.
