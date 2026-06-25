# 개발 워크플로우 (Development Workflow)

기능 하나가 `feat` 브랜치에서 시작해 `main`에 병합되기까지의 전체 11단계 프로세스입니다.

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
```

---

## 단계별 상세

### 1단계 — 계획서 작성
- 위치: `doc/plans/[feature]-plan.md`
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
- Base: `dev` ← Compare: `feat/*`
- PR 제목: `[feat] 기능명 (#이슈번호)`
- PR 본문: PR 템플릿 사용 (아래 참고)
- Closes #이슈번호 명시

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

## 릴리즈 흐름 (dev → main)

```
1. dev 브랜치 QA 통과 확인
2. CHANGELOG 업데이트
3. 버전 태그 생성: git tag v1.0.0
4. PR: main ← dev
5. 개발자 최종 승인 후 머지
6. TestFlight / App Store 제출
```
