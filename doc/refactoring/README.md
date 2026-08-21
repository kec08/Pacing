# 리팩토링 기록

리팩토링 단위별로 계획, 측정 코드, 변경 대상별 Before/After를 독립적으로 관리한다.

| 리팩토링 | 범위 | 성능 기록 |
| --- | --- | --- |
| [Refactor 117](./refactor-117-static-dispatch-lazy-in-place/) | Static Dispatch·Lazy Evaluation·In-Place Mutation | [통계](./refactor-117-static-dispatch-lazy-in-place/01-run-statistics/after.md), [경로](./refactor-117-static-dispatch-lazy-in-place/02-route-bounds/after.md) |

## 폴더 규칙

```text
doc/refactoring/
├── README.md
└── refactor-{번호}-{주제}/
    ├── README.md                 # 목표, 작업 범위, QA
    ├── benchmark.swift           # 재현 가능한 측정 코드
    └── {순번}-{개선-대상}/
        ├── before.md             # 기존 병목, 측정 조건, 기준선
        └── after.md              # 변경, 결과, 포트폴리오 요약
```

Before/After는 리팩토링 전체가 아니라 실제 수정한 계산 경로나 컴포넌트 단위로 작성한다.
