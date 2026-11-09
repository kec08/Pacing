# feat #08 홈·마이 데이터 연동

## 목표
홈 탭과 마이 탭에 Mock 데이터 대신 Firestore 실제 데이터를 연동하여 러닝 통계와 기록이 올바르게 표시되도록 수정

---

## 현재 문제

### 홈 탭 (HomeViewModel)
- `loadDummyData()` 만 호출, Firestore 연동 코드 전혀 없음
- 이번 주 통계 (거리/시간/페이스) 하드코딩
- 최근 러닝 기록 Mock 3개 고정
- 같이 들은 사람 섹션 Mock (feat #08 이후 연결 예정)
- nickname UserDefaults에서만 읽음

### 마이 탭 (MyViewModel)
- Firestore 연동은 됐으나 통계 계산 누락
  - 총 거리 / 총 시간 / 평균 페이스가 화면에 반영 안 됨
  - 러닝 횟수만 올바르게 표시
- 폴백으로 `RunRecord.dummies` 사용 중 (실제 기록 없으면 Mock 노출)

---

## 구현 목표

### 1. HomeViewModel Firestore 연동
- `loadHomeData()` 에서 Firestore `fetchRunHistory(uid:)` 호출
- **이번 주 통계 계산**: 최근 7일 기록 필터링 → 총 거리 / 총 시간 / 평균 페이스 계산
- **최근 러닝 리스트**: 최신순 3개 표시
- **같이 들은 사람 섹션**: feat #09(같이 듣기) 전까지 숨김 처리
- nickname: UserDefaults 유지 (프로필 수정 기능 이후 Firestore 연동)

### 2. MyViewModel 통계 수정
- `applyData()` 에서 stats 계산 로직 검증 및 수정
  - `totalDistance`: 전체 기록 거리 합산
  - `totalTime`: 전체 기록 시간 합산
  - `avgPace`: 전체 기록 페이스 평균
  - `totalRuns`: 전체 기록 횟수
- 실제 기록 없을 때 Mock 폴백 제거 → 빈 상태 UI 표시

### 3. 빈 상태 UI
- 러닝 기록 없을 때: "아직 러닝 기록이 없어요" 안내 문구
- Mock 데이터 완전 제거

---

## 변경 파일
| 파일 | 변경 내용 |
|------|----------|
| `Features/Home/ViewModel/HomeViewModel.swift` | Firestore 연동, 통계 계산 |
| `Features/My/ViewModel/MyViewModel.swift` | 통계 계산 수정, Mock 폴백 제거 |
| `Features/Home/View/HomeView.swift` | 같이 들은 섹션 숨김, 빈 상태 UI |
| `Features/My/View/MyView.swift` | 빈 상태 UI |

---

## 작업 순서
1. MyViewModel 통계 계산 수정 + Mock 폴백 제거
2. MyView 빈 상태 UI 추가
3. HomeViewModel Firestore 연동 구현
4. HomeView 같이 들은 섹션 숨김 + 빈 상태 UI
5. QA → 보고서 → 커밋/PR
