# 브랜치 전략 (Branch Strategy)

## 브랜치 구조

```
main
 └── dev
      ├── feat/온보딩-로그인
      ├── feat/지도-러닝
      ├── feat/같이듣기-싱크
      ├── feat/홈탭
      ├── feat/마이탭
      ├── fix/이슈번호-설명
      └── hotfix/긴급수정-설명
```

## 브랜치 역할

| 브랜치 | 용도 | 배포 여부 | 직접 커밋 |
|--------|------|-----------|-----------|
| `main` | 실제 배포 (App Store / TestFlight 최종) | ✅ | ❌ (PR만) |
| `dev` | 개발 통합 브랜치, 다음 릴리즈 대상 | 내부 빌드 | ❌ (PR만) |
| `feat/*` | 기능 단위 개발 | ❌ | ✅ |
| `fix/*` | 버그 수정 (QA에서 발견된 이슈) | ❌ | ✅ |
| `hotfix/*` | main의 긴급 버그 수정 | ❌ | ✅ |

## 네이밍 규칙

### feat 브랜치
```
feat/[기능명]
feat/[이슈번호]-[기능명]   ← GitHub 이슈 연동 시
```

예시:
```
feat/onboarding
feat/running-map
feat/listen-sync
feat/home-tab
feat/my-tab
feat/12-nearby-runner-pin
```

### fix 브랜치
```
fix/[이슈번호]-[설명]
```

예시:
```
fix/23-location-update-crash
fix/31-musickit-auth-fail
```

### hotfix 브랜치
```
hotfix/[설명]
```

예시:
```
hotfix/realtime-db-disconnect
```

## 병합 규칙

### feat → dev
- PR 생성 후 코드 리뷰 완료 시 병합
- PR 템플릿 사용 (기능 요약, 테스트 방법, 스크린샷)
- Squash merge 권장 (feat 내 커밋 정리)

### dev → main
- 릴리즈 단위로만 병합
- QA 통과 후 진행
- Merge commit 사용 (이력 보존)

### hotfix → main & dev
- 긴급 수정은 main에 직접 병합 후 dev에도 cherry-pick

## 흐름 요약

```
feat/* ──────────────────────────────▶ dev ──────────▶ main
         PR + 리뷰 + QA 통과                릴리즈 단위

hotfix/* ────────────────────────────▶ main
                                        └──▶ dev (cherry-pick)
```

## GitHub 이슈 연동

브랜치명에 이슈 번호를 포함하면 GitHub에서 자동으로 이슈와 브랜치가 연결됩니다.

```
feat/12-nearby-runner-pin   →  closes #12 (PR 본문에 명시)
fix/23-location-crash       →  closes #23
```
