# feat #10 같이 듣기 최종 보고서

## 작업 요약
Firebase Realtime Database 기반 같이 듣기 기능 구현 및 러닝 화면 UI/지도 개선

---

## 구현 내용

### 1. 같이 듣기 핵심 기능 (ListenTogetherViewModel + RealtimeDBService)
- **세션 생성 (호스트)**: 주변 러너 시트에서 "같이 듣기" 버튼 탭 → `listenSessions/{autoID}` 및 `incomingRequests/{guestUID}/{sessionID}` 동시 기록
- **요청 수신 (게스트)**: `incomingRequests/{uid}` 실시간 구독 → 수신 배너 표시
- **수락/거절**: 수락 시 세션 status `active` 변경, 게스트 음악 동기화 시작
- **음악 동기화**: `MPMediaItemPropertyTitle` 기반 라이브러리 검색 후 같은 곡 재생 + 레이턴시 보정
- **재생 상태 브로드캐스트**: 호스트 곡 변경 시 `onChange(musicVM.currentSong)` → Realtime DB 업데이트
- **세션 종료**: 어느 쪽이든 종료 시 status `ended` 변경, 양측 cleanup

### 2. 같이 듣기 UI
- **플로팅 음표 버튼**: 우상단 음표 원형 아이콘 + 참여자 수 배지 (세션 활성 시 표시)
- **참여자 시트**: 음표 버튼 탭 → 바텀시트에 카드뷰로 호스트/게스트 정보 표시
  - 프로필 이니셜 아바타, 이름, 역할(호스트/게스트) 배지
  - 현재 재생 곡 정보
  - 함께 들은 시간 (1초 단위 실시간 갱신, TimelineView)
- **수신 요청 배너**: 상단 슬라이드인 배너 (수락/거절 버튼)
- **카운트다운 우선**: 카운트다운 검은 화면(zIndex 20)이 플로팅 버튼(zIndex 11)보다 위

### 3. 러닝 화면 지도 개선
- **내 위치 버튼 (idle)**: +/- 버튼 아래 항상 표시, 탭 시 내 위치로 이동
- **내 위치 버튼 (러닝 중)**: 항상 표시, 추적 중이면 파란색/비추적이면 회색
- **지도 뚝뚝 끊김 수정**: `onMapCameraChange(.continuous)`에서 cameraPosition 강제 변경 제거, 제스처 종료 후(`onEnd`)에만 범위 초과 시 스냅백
- **3000m 초과 축소 스냅백**: 손 뗀 후 0.25초 딜레이 + spring 애니메이션으로 내 위치 기준 부드럽게 복귀

---

## 버그 수정

| 버그 | 원인 | 해결 |
|------|------|------|
| `MPMediaPropertyPredicate` 크래시 | `playbackStoreID`는 predicate 필터 불가 | `MPMediaItemPropertyTitle` 기반 검색으로 대체 |
| `ListenSession` 중복 선언 | `ListenSession.swift`와 `RunRecord.swift` 충돌 | `ListenSession.swift` 제거, `RunRecord.swift`에 통합 |
| 지도 pan 시 뚝뚝 끊김 | `.continuous`에서 cameraPosition 덮어쓰기가 MapKit 제스처와 충돌 | `onEnd`로만 스냅백 이동 |
| 3000m 초과 튕김 | 제스처 종료 직후 즉시 cameraPosition 변경으로 관성 이동과 충돌 | 0.25초 딜레이 후 spring 애니메이션 스냅백 |

---

## 변경 파일

| 파일 | 변경 내용 |
|------|----------|
| `Features/Running/ViewModel/ListenTogetherViewModel.swift` | 신규 — 같이 듣기 VM (세션 관리, 음악 동기화) |
| `Core/Firebase/RealtimeDBService.swift` | listenSessions / incomingRequests CRUD 추가 |
| `Models/RunRecord.swift` | `ListenSession` 구조체 확장 (전체 필드 + sessionStartDate) |
| `Features/Running/View/RunningView.swift` | 플로팅 버튼, 참여자 시트, 지도 개선, 내 위치 버튼 |
| `doc/fe/feat #10 같이 듣기.md` | 기능 계획서 |

---

## QA 결과

| 항목 | 결과 |
|------|------|
| 같이 듣기 요청 전송 및 수신 배너 표시 | ✅ |
| 수락 시 음악 동기화 시작 | ✅ |
| 거절 시 세션 종료 | ✅ |
| 플로팅 음표 버튼 표시 (세션 활성 시) | ✅ |
| 참여자 시트 — 이름, 역할, 곡, 함께 들은 시간 | ✅ |
| 카운트다운 시 버튼 검은 화면 아래로 | ✅ |
| idle 내 위치 버튼 | ✅ |
| 러닝 중 내 위치 버튼 항상 표시 | ✅ |
| 지도 pan 부드러움 (끊김 없음) | ✅ |
| 3000m 초과 시 내 위치로 스냅백 | ✅ |
| MPMediaPropertyPredicate 크래시 없음 | ✅ |
