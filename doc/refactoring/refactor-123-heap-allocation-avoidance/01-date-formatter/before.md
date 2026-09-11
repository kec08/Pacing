# Before — DateFormatter Allocation

`RunHistoryCard`의 `dateString`, `startTimeString`은 호출할 때마다 각각 `DateFormatter`를 생성하고 locale·format을 설정했다. SwiftUI가 목록 셀을 다시 그릴 때마다 두 Foundation 객체의 힙 할당과 초기화가 반복된다.
