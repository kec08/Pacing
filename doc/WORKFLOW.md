# 개발 워크플로우 (Development Workflow)

기능 하나가 `feat` 브랜치에서 시작해 `dev`에 병합되고, `staging` 실기기 QA를 거쳐 `main`에 반영되기까지의 전체 프로세스입니다.

---

## 전체 흐름

```
1. 계획서 작성
      ↓
2. 계획서 검토 (개발자 승인)
      ↓
3. GitHub 이슈 작성
      ↓
4. 브랜치 분기 (dev → feat/*)
      ↓
5. 기능 개발 (작은 단위 커밋)
      ↓
6. QA 진행 및 이슈 보고
      ↓
7. 에러 수정 (fix 브랜치 또는 현재 feat에서)
      ↓
8. 최종 개발 보고 및 검토
      ↓
9. 최종 커밋 메시지 작성 및 Push
      ↓
10. PR 생성 및 메시지 작성
      ↓
11. 개발자 코드 리뷰 후 머지 (dev ← feat/*)
      ↓
12. 릴리즈 후보 QA (staging ← dev)
      ↓
13. 운영 반영 (main ← staging)
```

---

## 단계별 상세

### 1단계 — 계획서 작성
- 위치: `doc/ios/plans/[feature]-plan.md`
- 포함 내용:
  - 기능 목적 및 사용자 시나리오
  - 화면 구성 및 UI 설명
  - 데이터 흐름 (API, DB 구조)
  - 작업 분리 (Task 목록)
  - 예상 소요 시간

### 2단계 — 계획서 검토
- 개발자가 계획서 내용을 확인하고 승인
- 수정 사항 있으면 계획서 업데이트 후 재검토
- **승인 전 브랜치 생성 및 개발 시작 금지**

### 3단계 — GitHub 이슈 작성
- 이슈 제목: `[feat] 기능명` / `[fix] 버그 설명`
- 이슈 본문: 계획서 요약 + 완료 기준 (Acceptance Criteria)
- 라벨: `feature` / `bug` / `enhancement`
- 담당자 (Assignee) 지정

### 4단계 — 브랜치 분기
```bash
git checkout dev
git pull origin dev
git checkout -b feat/[이슈번호]-[기능명]
```

### 5단계 — 기능 개발
- **작은 단위**로 커밋 (하나의 커밋 = 하나의 논리적 변경)
- 커밋 규칙은 `COMMIT_CONVENTION.md` 참고
- 개발 중 계획서와 다른 방향이 되면 계획서 먼저 업데이트

### 6단계 — QA 진행 및 이슈 보고
- 개발 완료 후 기능별 QA 체크리스트 실행
- 발견된 이슈는 `doc/issues/[이슈번호]-report.md`에 기록
- 이슈 보고서 포함 내용:
  - 재현 방법 (Steps to Reproduce)
  - 예상 동작 vs 실제 동작
  - 스크린샷 또는 로그
  - 심각도 (Critical / Major / Minor)
- 앱 아이콘 관련 변경이 있으면 아래 항목을 추가 확인
  - `Pacing/Pacing/Assets.xcassets/AppIcon.appiconset/Contents.json`의 `filename`이 실제 존재 파일과 정확히 일치하는지
  - AppIcon 기본 1024 슬롯이 비어 있지 않은지
  - 브랜치 병합 전 `origin/dev`의 AppIcon 구조와 충돌 여부가 없는지

### 7단계 — 에러 수정
- 현재 feat 브랜치에서 직접 수정 (Minor 이슈)
- 별도 `fix/이슈번호-설명` 브랜치 생성 (Major 이슈)
- 수정 완료 후 6단계 QA 재실행

### 8단계 — 최종 개발 보고 및 검토
- 위치: `doc/reports/[feature]-final-report.md`
- 포함 내용:
  - 구현된 기능 요약
  - 계획서 대비 변경 사항
  - 알려진 제한사항 (Known Limitations)
  - 테스트 결과 요약

### 9단계 — 최종 커밋 및 Push
```bash
git add .
git commit -m "feat: [기능명] 최종 구현 완료 (#이슈번호)"
git push origin feat/[이슈번호]-[기능명]
```

### 10단계 — PR 생성 및 메시지 작성
- **실기기 QA 완료 전에는 PR을 생성하지 않는다.** 개발자가 실기기에서 완료 기준을 검증한 뒤에만 다음 항목을 진행한다.
- Base: `dev` ← Compare: `feat/*`
- PR 제목: `[feat] 기능명 (#이슈번호)`
- PR 본문: PR 템플릿 사용 (아래 참고)
- Closes #이슈번호 명시
- ⚠️ `feat → dev` 머지 시 GitHub 이슈 자동 닫기 **미동작** (main 머지 시에만 자동 닫힘) → PR 머지 후 이슈 **수동으로 Close**
- AppIcon 관련 파일을 수정했다면 PR 생성 전 `origin/dev`를 먼저 반영해 `Contents.json` 충돌을 선해소한다

**PR 템플릿:**
```markdown
## 개요
이 PR에서 구현한 내용을 간략히 설명합니다.

## 변경 사항
- [ ] 항목 1
- [ ] 항목 2

## 테스트 방법
1. 앱 실행
2. 해당 화면 진입
3. 확인 항목

## 스크린샷
| Before | After |
|--------|-------|
|        |       |

## 관련 이슈
Closes #이슈번호
```

### 11단계 — 개발자 머지
- 개발자가 코드 리뷰 후 직접 머지
- 머지 전 CI 빌드 통과 확인
- 머지 완료 후 feat 브랜치 삭제

---

## 배포 전 QA 흐름 (dev → staging)

`staging`은 배포 후보만 검증하는 공용 브랜치입니다. 기능 개발이나 버그 수정은 여기서 하지 않습니다.

1. 개발자가 QA 대상으로 확정한 `dev` 변경을 `staging`에 PR로 병합한다.
2. `staging` 커밋으로 Archive를 생성하고 TestFlight에 업로드한다.
3. iPhone과 페어링된 Apple Watch 실기기에서 아래 항목을 확인한다.
4. QA 통과 후에만 `staging → main` PR을 생성한다.

### iPhone 공통 QA

- [ ] 앱 설치·업데이트·로그인·로그아웃이 정상 동작한다.
- [ ] 권한 요청, 네트워크 오류, 빈 상태와 로딩 상태가 사용자에게 명확히 표시된다.
- [ ] 라이트/다크 모드와 주요 화면 크기에서 레이아웃이 깨지지 않는다.
- [ ] 실제 계정 및 네트워크에서 Firebase 읽기·쓰기가 정상 동작한다.

### Apple Watch QA

- [ ] iPhone 앱 설치 후 페어링된 Apple Watch에 Watch 앱이 정상 설치된다.
- [ ] Watch 앱의 아이콘, 앱 이름, 컴패니언 iOS 앱 연결이 정상이다.
- [ ] iPhone과 Watch 양쪽에서 실행·재실행 후 화면 상태가 안정적이다.
- [ ] HealthKit, 위치, 알림, 음악 등 새로 추가한 권한의 허용·거절 흐름을 각각 확인한다.
- [ ] 실제 러닝 중 거리·페이스·시간·음악·같이 듣기 등 해당 릴리즈 기능이 양쪽 기기에서 일관되게 동작한다.
- [ ] 운동 종료, 통신 단절, 앱 백그라운드/재실행 상황에서 기록 손실이나 비정상 상태가 없는지 확인한다.

### staging QA에서 문제를 발견한 경우

- 문제를 GitHub 이슈와 QA 보고서에 기록한다.
- `staging`에서 직접 고치지 않는다.
- `dev` 기준 `fix/[이슈번호]-[설명]` 브랜치에서 수정한 뒤 `dev`에 먼저 병합한다.
- 수정이 포함된 `dev → staging` PR로 다시 TestFlight QA를 수행한다.

---

## 릴리즈 흐름 (staging → main)

```
1. staging 실기기·TestFlight QA 통과 확인
2. CHANGELOG 업데이트
3. 버전 태그 생성: git tag v1.0.0
4. PR: main ← staging
5. 개발자 최종 승인 후 머지
6. App Store 제출 또는 운영 배포
```
