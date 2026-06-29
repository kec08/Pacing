# feat #09 러닝 측정 및 지도 개선 최종 보고서

## 작업 요약
러닝 데이터 측정 정확도 개선, 경로 표시 개선, 지도 인터랙션 추가

---

## 구현 내용

### 1. 러닝 측정 정확도 개선 (RunningViewModel)
- **일시정지/재개 스파이크 방지**: `pause()` · `resume()` 시 `lastLocation = nil` 처리
- **GPS 스파이크 필터**: 10 m/s(36 km/h) 초과 이동은 GPS 오류로 판단, 해당 업데이트 무시
- **페이스 스무딩**: 순간 페이스 대신 최근 5개 샘플 이동평균으로 표시
- **1분 미만 러닝 저장 방지**: `elapsedSeconds < 60`이면 `saveRecord()` 즉시 리턴

### 2. 경로 이어 그리기 수정 (LocationManager)
- `startTracking()`에서 `routeCoordinates = []` 제거
- 경로 초기화는 `resetRoute()` (새 러닝 시작 시)에서만 수행

### 3. 경로 그라데이션 (RunningView)
- 단색 `Color.main500` → `LinearGradient([main500, 파란색])` 으로 변경
- 선 두께 4 → 5pt

### 4. 지도 인터랙션 추가 (RunningView)
- `interactionModes: []` → `[.pan, .zoom]`으로 변경해 손 제스처 허용
- 카메라 애니메이션: `.linear` → `.interpolatingSpring(stiffness:40, damping:12)`
- 줌 범위 제한: 100m ~ 3000m (`onMapCameraChange(frequency:.continuous)`)
- 버튼 분기:
  - **idle**: +/- 줌 버튼 표시
  - **러닝 중**: +/- 숨기고, pan 시 내 위치 버튼만 표시
- 내 위치 추적(`isFollowingUser`) 상태 관리: 사용자 pan 시 해제, 버튼 탭 시 재활성

---

## 이슈
- [issue-06] 일시정지 후 재개 시 거리·페이스 스파이크 → `lastLocation = nil` 수정
- [issue-07] GPS 스파이크로 페이스 순간 튀는 현상 → 필터 + 스무딩 적용
- [issue-08] 일시정지 후 재개 시 경로 처음부터 다시 그려지는 버그 → `startTracking()` 초기화 제거

---

## 변경 파일
| 파일 | 변경 내용 |
|------|----------|
| `Features/Running/ViewModel/RunningViewModel.swift` | 스파이크 방지, GPS 필터, 페이스 스무딩, 1분 미만 저장 방지 |
| `Core/Location/LocationManager.swift` | `startTracking()` routeCoordinates 초기화 제거 |
| `Features/Running/View/RunningView.swift` | 그라데이션 경로, 지도 제스처, 줌 버튼, 내 위치 버튼 |

---

## QA 결과
| 항목 | 결과 |
|------|------|
| 일시정지 후 재개 시 거리 스파이크 없음 | ✅ |
| 페이스 이동평균 스무딩 | ✅ |
| 36km/h 초과 GPS 점프 무시 | ✅ |
| 경로 일시정지 후 이어 그리기 | ✅ |
| 경로 그라데이션 (main500 → 파란색) | ✅ |
| 핀치 줌 + 드래그 pan 동작 | ✅ |
| 줌 100m~3000m 범위 제한 | ✅ |
| 러닝 중 내 위치 버튼만 표시 | ✅ |
| 1분 미만 러닝 저장 안 됨 | ✅ |
