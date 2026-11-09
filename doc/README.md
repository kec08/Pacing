# Pacing 문서

플랫폼별 기능 문서와 공통 개발 기준을 분리해 관리합니다. 새 기능 문서는 아래 구조에만 추가합니다.

```
doc/
├── ios/                       # iPhone/iOS 앱 기능 문서
│   ├── plans/                 # 기능 계획서
│   ├── issues/                # QA 및 이슈 기록
│   └── reports/               # 완료 보고서
├── watchos/                   # Apple Watch 앱 기능 문서
│   ├── plans/
│   ├── issues/
│   └── reports/
├── shared/                    # 두 앱이 함께 따르는 연동·데이터 기준
├── refactoring/               # 성능 및 리팩터링 기록
├── assets/                    # 문서 전용 이미지 자산
├── DESIGN_SYSTEM.md           # 브랜드 컬러·디자인 기준
├── WORKFLOW.md                # 개발 절차
├── BRANCH_STRATEGY.md         # 브랜치 규칙
└── COMMIT_CONVENTION.md       # 커밋 규칙
```

## 문서 작성 위치

| 작업 | 작성 위치 |
|---|---|
| iPhone 기능 계획 | `ios/plans/` |
| iPhone QA/완료 보고 | `ios/issues/`, `ios/reports/` |
| Watch 기능 계획 | `watchos/plans/` |
| Watch QA/완료 보고 | `watchos/issues/`, `watchos/reports/` |
| iPhone ↔ Watch 데이터 연동 | `shared/` |

## Firebase 원칙

Pacing은 Firebase를 기존 백엔드로 사용합니다. 별도 백엔드 문서 폴더는 만들지 않습니다. Firebase 스키마·권한·비용·동기화 변경이 필요한 경우에만 해당 플랫폼 계획서에 영향 범위와 연동 규칙을 기록합니다.

## 현재 주요 문서

- [Watch 앱 마스터 계획서](./watchos/plans/feat-159-watch-app-master-plan.md)
- [iOS 기능 계획서](./ios/plans/)
- [디자인 시스템](./DESIGN_SYSTEM.md)
- [개발 워크플로우](./WORKFLOW.md)
