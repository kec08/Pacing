# Heap Allocation Avoidance 리팩토링 계획서

> 상태: 구현·벤치마크 완료 / 컴파일 QA 진행 중
> 작성일: 2026-08-22
> 관련 이슈: [#123 Heap Allocation Avoidance 최적화](https://github.com/kec08/Pacing/issues/123)
> 브랜치: `refactor/123`

## 대상

| 대상 코드 | Before 병목 | 변경 방향 |
| --- | --- | --- |
| `RunHistoryCard` 날짜·시간 표시 | SwiftUI body 재평가마다 `DateFormatter` 2개 생성 | 메인 액터 정적 캐시 재사용 |

## 검증 기준

- 동일 날짜에서 before/after 문자열이 같아야 한다.
- 릴리스 최적화 벤치마크로 포맷터 생성·사용 비용을 비교한다.
- UI 렌더링·네트워크 시간은 측정 범위에서 제외한다.

## 측정 결과

릴리스 최적화(`-O`)에서 1,000개 날짜를 15개 표본(표본당 5회)으로 측정했다. 세 번 독립 실행한 중앙값을 기록했으며, before/after가 만든 2,000개 문자열 배열 전체의 동등성을 `precondition`으로 검증했다.

| 대상 | Before | After | 개선 |
| --- | ---: | ---: | ---: |
| `RunHistoryCard` 날짜·시간 포맷 | 48.54903 ms | 2.77150 ms | 94.3% |
