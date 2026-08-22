# After — DateFormatter Allocation

날짜·시간 형식별 `DateFormatter`를 `@MainActor` 정적 캐시로 한 번 생성해 재사용한다. `RunHistoryCard`는 메인 액터의 SwiftUI 렌더링 경로에서만 이를 사용하므로, `DateFormatter`의 동시 접근을 만들지 않는다.

릴리스 최적화(`-O`)에서 1,000개 날짜를 포맷한 순수 벤치마크를 세 번 독립 실행했다. 중앙값은 `48.54903 ms → 2.77150 ms`로, **94.3% 개선**이다. before/after가 만든 날짜·시간 문자열 2,000개 전체가 같은지 `precondition`으로 검증했다.

이 값은 `DateFormatter` 생성·설정과 문자열 생성 구간의 마이크로벤치마크다. SwiftUI 레이아웃·텍스트 렌더링 시간은 포함하지 않는다.
