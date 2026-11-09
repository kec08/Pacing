# feat #08 홈·마이 데이터 연동 최종 보고서

## 작업 요약
홈 탭과 마이 탭에서 Mock 데이터를 제거하고 Firestore 실제 데이터로 전환.
마이 탭 최근 활동 5개 미리보기 + 더보기 토글 UI 추가.

---

## 구현 내용

### 1. HomeViewModel Firestore 연동
- `loadDummyData()` 완전 제거
- `loadHomeData()` — Firebase Auth UID 기반으로 `fetchRunHistory(uid:limit:100)` 호출
- `calcWeeklyStats(from:)` — 이번 주 기록 필터링 후 총 거리 / 총 시간 / 평균 페이스 계산
- `recentRuns`: 최신순 3개
- `recentListenSessions`: feat #09(같이 듣기) 전까지 빈 배열 유지

### 2. MyViewModel 수정
- `RunRecord.dummies` 폴백 완전 제거
- 로그인 상태 아닐 때 빈 배열로 처리

### 3. MyView 5개 미리보기 + 더보기 토글
- `@State showAllHistory = false`
- 기본: 최근 5개 표시
- 5개 초과 시 "더보기 (n개)" 버튼 노출, 탭 시 전체 표시
- "접기" 버튼으로 다시 5개로 축소, `.easeInOut(0.25)` 애니메이션

### 4. FirestoreService 타입 캐스팅 수정 (issue-05)
- `as? Int` / `as? Double` 직접 캐스팅 → `(NSNumber)?.intValue` / `(NSNumber)?.doubleValue` 로 변경
- Firestore SDK가 숫자를 Int64로 반환하는 경우 포함 모든 타입 호환

---

## 변경 파일
| 파일 | 변경 내용 |
|------|----------|
| `Features/Home/ViewModel/HomeViewModel.swift` | Mock 제거, Firestore 연동, 주간 통계 계산 |
| `Features/My/ViewModel/MyViewModel.swift` | Mock 폴백 제거 |
| `Features/My/View/MyView.swift` | 5개 미리보기 + 더보기 토글 |
| `Core/Firebase/FirestoreService.swift` | NSNumber 경유 숫자 파싱 (issue-05 수정) |

---

## 이슈
- [issue-05] Firestore 숫자 타입 캐스팅 실패로 러닝 데이터 0 표시 → NSNumber 캐스팅으로 수정 완료

---

## QA 결과
| 항목 | 결과 |
|------|------|
| 홈 탭 이번 주 통계 Firestore 연동 | ✅ |
| 홈 탭 최근 러닝 3개 표시 | ✅ |
| 마이 탭 기간별 통계 Firestore 연동 | ✅ |
| 마이 탭 Mock 데이터 미노출 | ✅ |
| 마이 탭 최근 활동 5개 미리보기 | ✅ |
| 더보기/접기 토글 애니메이션 | ✅ |
| 러닝 기록 없을 때 빈 상태 UI | ✅ |
| Firestore 숫자 타입 안정성 | ✅ (issue-05 수정) |

---

## 비고
- 시뮬레이터에서 GPS 미작동 상태로 저장된 기존 기록은 distance=0, avgPace=0으로 실제 저장된 값이며 코드 이슈가 아님
- 같이 들은 사람 섹션(listenSessions)은 feat #09 이후 연동 예정
