# After — Collection Capacity Pre-allocation

문서·스냅샷 개수 또는 결과 상한을 이용해 `reserveCapacity`를 적용했다. 친구 활동, 친구 목록, 친구 요청, 공유 플레이리스트, 활성 러너, 리슨 세션 결과 배열이 대상이다.

릴리스 최적화(`-O`)로 100,000개 `TrackPayload`를 생성한 뒤, 각 항목의 ID·제목·아티스트를 실제로 읽는 벤치마크를 세 번 독립 실행했다. 중앙값은 `1.13684 ms → 0.95025 ms`로, **16.4% 개선**이다.

이 값은 배열 생성·append 구간의 마이크로벤치마크이며, Firestore·RealtimeDB 네트워크 시간은 포함하지 않는다.
