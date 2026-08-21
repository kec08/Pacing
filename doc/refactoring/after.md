# Refactor 117 After

측정일: 2026-08-22

관련 이슈: [#119](https://github.com/kec08/Pacing/issues/119)

## 변경 사항

- `AppDelegate`를 `final class`로 변경해 상속 가능성을 제거했다.
- `RunStatisticsCalculator`를 정적 타입으로 분리하고, `lazy` 단일 순회에서 통계 누적값을 직접 변경하도록 바꿨다.
- `RunRouteBounds`를 정적 타입으로 분리하고, 위도·경도 배열 복사 없이 단일 순회에서 최소·최대값을 직접 변경하도록 바꿨다.
- 경로 세그먼트와 내 기록 차트 결과는 `reserveCapacity` 후 직접 `append`하도록 유지했다.

## 측정 결과

동일한 입력·컴파일 옵션·반복 조건으로 측정했다.

| 경로 | Before | After | 개선율 |
| --- | ---: | ---: | ---: |
| 주간 러닝 통계 집계 | 0.52980 ms ±0.02245 | 0.08672 ms ±0.00780 | 83.6% |
| 경로 경계 계산 | 0.80428 ms ±0.01138 | 0.09730 ms ±0.00509 | 87.9% |

개선율은 `(Before - After) / Before × 100`으로 계산했다. 모든 측정에서 checksum이 일치했다.

## 포트폴리오용 요약

기존 주간 통계 집계는 `filter` 중간 배열을 생성한 뒤 네 번 순회했으며, 100,000개 기록 기준 평균 0.52980 ms가 걸렸다. `lazy` 단일 순회와 누적값 직접 변경으로 평균 0.08672 ms로 줄어 **약 83.6% 개선**됐다.

경로 화면은 위도·경도 배열을 따로 만들고 최소·최대를 계산했다. 공통 `RunRouteBounds`에서 한 번만 순회해 지역을 계산한 결과, 100,000개 좌표 기준 평균 0.80428 ms에서 0.09730 ms로 줄어 **약 87.9% 개선**됐다. 이 구현은 러닝 상세·요약·썸네일 화면에 공통 적용된다.

Static Dispatch의 `final` 변경은 앱 시작·UI 경로에서 독립적인 호출 비용을 안정적으로 분리 측정하기 어려워 별도 퍼센트를 산출하지 않았다. 대신 상속 불가 의도를 코드에 명시해 컴파일러가 정적 디스패치를 선택할 수 있는 조건을 만들었다.

## 검증 상태

- `swiftc -O doc/refactoring/benchmark.swift`: 통과
- 벤치마크 checksum 비교: 통과
- `git diff --check`: 통과
- `xcodebuild build-for-testing`: iOS 26 Simulator SDK에서 앱·유닛 테스트·UI 테스트 타깃 컴파일 통과
- XCTest 실행: iPhone 17 Simulator가 테스트 시작 시 Shutdown으로 전환돼 `test-without-building`을 끝까지 실행하지 못함
- 실기기/Instruments 프로파일링: 개발자 환경에서 추가 확인 필요
