# Pacing — 문서 디렉토리

## 구조

```
doc/
├── README.md                   # 이 파일
├── BRANCH_STRATEGY.md          # 브랜치 전략 및 네이밍 규칙
├── WORKFLOW.md                 # 개발 전체 흐름 (11단계 프로세스)
├── COMMIT_CONVENTION.md        # 커밋 메시지 규칙
│
└── feat #00 기능명/             # 기능 개발 시작 시 생성
    ├── FE-plan.md              # FE 기획서 (화면, 컴포넌트, 상태 관리)
    └── BE-plan.md              # BE 기획서 (DB 설계, 보안 규칙, API)
```

## 기능 폴더 생성 규칙

기능 개발 시작 전, 해당 기능의 GitHub 이슈 번호에 맞춰 폴더를 생성합니다.

```
feat #01 온보딩-로그인/
feat #02 홈탭/
feat #03 러닝탭/
...
```

각 폴더 안에 `FE-plan.md` / `BE-plan.md` 작성 후 개발자 검토 → 승인 → 개발 시작.

## 문서 참조

| 문서 | 설명 |
|------|------|
| [BRANCH_STRATEGY.md](./BRANCH_STRATEGY.md) | 브랜치 구조, 네이밍, 병합 규칙 |
| [WORKFLOW.md](./WORKFLOW.md) | 기능 개발 전체 11단계 프로세스 |
| [COMMIT_CONVENTION.md](./COMMIT_CONVENTION.md) | 커밋 메시지 작성 규칙 |
