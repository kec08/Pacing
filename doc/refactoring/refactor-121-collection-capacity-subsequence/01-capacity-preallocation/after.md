# After — Collection Capacity Pre-allocation

문서·스냅샷 개수 또는 결과 상한을 이용해 `reserveCapacity`를 적용했다. 친구 활동, 친구 목록, 친구 요청, 공유 플레이리스트, 활성 러너, 리슨 세션 결과 배열이 대상이다.

100,000개 입력의 순수 벤치마크에서 `0.18012 ms → 0.06877 ms`로 **61.8% 개선**됐다.
