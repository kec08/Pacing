# Pacing — 문서 디렉토리

## 구조

```
doc/
├── README.md                        # 이 파일
├── BRANCH_STRATEGY.md               # 브랜치 전략 및 네이밍 규칙
├── WORKFLOW.md                      # 개발 전체 흐름 (11단계 프로세스)
├── COMMIT_CONVENTION.md             # 커밋 메시지 규칙
├── DESIGN_SYSTEM.md                 # 컬러 토큰 및 디자인 가이드
│
├── fe/                              # FE 기획서 모음
│   ├── plans/                       # FE 기능 계획서
│   │   └── feat #01 기반셋업-온보딩.md
│   ├── issues/                      # FE QA 이슈 보고서
│   └── reports/                     # FE 최종 개발 보고서
│
└── be/                              # BE 기획서 모음
    └── feat #01 기반셋업-온보딩.md
```

## 기획서 작성 규칙

기능 개발 시작 전, GitHub 이슈 번호에 맞춰 `fe/` 또는 `be/` 폴더에 파일을 생성합니다.

```
fe/plans/feat #01 기반셋업-온보딩.md
be/feat #01 기반셋업-온보딩.md
fe/plans/feat #02 홈탭.md
be/feat #02 홈탭.md
```

기획서 작성 → 개발자 검토 → 승인 → 이슈 생성 → 개발 시작.

## 문서 참조

| 문서 | 설명 |
|------|------|
| [BRANCH_STRATEGY.md](./BRANCH_STRATEGY.md) | 브랜치 구조, 네이밍, 병합 규칙 |
| [WORKFLOW.md](./WORKFLOW.md) | 기능 개발 전체 11단계 프로세스 |
| [COMMIT_CONVENTION.md](./COMMIT_CONVENTION.md) | 커밋 메시지 작성 규칙 |
