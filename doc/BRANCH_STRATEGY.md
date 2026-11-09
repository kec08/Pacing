# 브랜치 전략 (Branch Strategy)

## 브랜치 구조

```
main
 └── staging
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
| `main` | 실제 운영 배포 기준 (App Store) | ✅ | ❌ (PR만) |
| `staging` | 배포 후보 통합 및 실기기·TestFlight QA | TestFlight QA | ❌ (PR만) |
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

### staging → main
- `staging`에서 QA를 통과한 릴리즈 후보만 병합
- Merge commit 사용 (이력 보존)

### dev → staging
- 실기기·TestFlight 검증이 필요한 릴리즈 후보만 PR로 병합
- `staging`은 `dev`의 모든 최신 변경을 자동 반영하는 브랜치가 아니라, QA 대상으로 확정한 커밋을 보관한다
- 직접 커밋·직접 병합 금지
- iPhone과 Apple Watch를 함께 설치해 컴패니언 연결, 권한, 실제 러닝 흐름을 확인한다

### staging에서 버그가 발견된 경우
- `staging`에서 직접 수정하지 않는다
- `dev`에서 `fix/[이슈번호]-[설명]` 브랜치를 분기해 수정·검증한다
- `fix/* → dev` 머지 후, 해당 수정이 포함된 `dev → staging` PR로 QA 후보를 갱신한다

### hotfix → main & dev
- 긴급 수정은 main에 직접 병합 후 dev에도 cherry-pick

## 흐름 요약

```
feat/* ──────────────────────────────▶ dev ──────────▶ staging ──────────▶ main
         PR + 리뷰 + 개발 통합 확인              실기기·TestFlight QA        릴리즈 확정

hotfix/* ────────────────────────────▶ main
                                        └──▶ dev / staging (cherry-pick 또는 PR)
```

## GitHub 이슈 연동

브랜치명에 이슈 번호를 포함하면 GitHub에서 자동으로 이슈와 브랜치가 연결됩니다.

```
feat/12-nearby-runner-pin   →  closes #12 (PR 본문에 명시)
fix/23-location-crash       →  closes #23
```
