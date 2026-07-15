# feat #10 같이 듣기 (Listen Together)

## 목표
주변 러너와 Apple Music을 실시간으로 동기화해서 같이 들을 수 있는 기능 구현

---

## 현재 상태
- 주변 러너 시트에 "같이 듣기" 버튼 UI는 존재하나 동작 없음 (feat #07에서 placeholder 처리)
- Realtime DB `listenSessions` 구조는 기획서에 정의돼 있으나 미구현
- `RunningMusicViewModel` 에서 MusicKit 재생 제어 가능

---

## 구현 목표

### 1. Realtime DB 세션 관리 (RealtimeDBService 확장)
- `createListenSession(hostUID:guestUID:songID:position:)` — 세션 생성
- `listenToSession(sessionID:)` — 세션 실시간 구독
- `updateSessionSong(sessionID:songID:position:timestamp:)` — 곡/위치 브로드캐스트
- `endSession(sessionID:)` — 세션 종료

### 2. 같이 듣기 요청/수락 플로우
- 주변 러너 시트 "같이 듣기" 탭 → Realtime DB에 `status: pending` 세션 생성
- 상대방 화면에 요청 알림 배너 표시 (수락 / 거절)
- 수락 → `status: active` 로 변경, 호스트 현재 곡 ID + 재생 위치 + 타임스탬프 전송
- 게스트: 동일 곡 동일 위치에서 재생 시작 (MusicKit)

### 3. 실시간 싱크
- 호스트의 재생/일시정지/곡 변경 → Realtime DB 업데이트
- 게스트: 세션 구독 중 변경 감지 → MusicKit 동기화
- 싱크 오차: 네트워크 레이턴시 100~300ms 허용 (MVP)

### 4. 세션 중 UI
- 러닝 화면 상단에 "🎵 [닉네임]과 함께 듣는 중" 배너 표시
- 배너 탭 → 세션 종료 확인 팝업

### 5. 세션 종료
- 배너에서 종료 또는 러닝 종료 시 자동 세션 해제
- 양쪽 모두 각자 독립 재생으로 복귀

---

## 변경 파일
| 파일 | 변경 내용 |
|------|----------|
| `Core/Firebase/RealtimeDBService.swift` | 세션 생성/구독/업데이트/종료 메서드 추가 |
| `Features/Running/ViewModel/ListenTogetherViewModel.swift` | 신규 — 세션 상태 관리, MusicKit 싱크 로직 |
| `Features/Running/View/RunningView.swift` | 같이 듣기 버튼 연결, 요청 알림 배너, 함께 듣는 중 배너 |
| `Features/Running/View/NearbyRunnerSheet` (RunningView 내) | "같이 듣기" 버튼 실제 동작 연결 |

---

## 작업 순서
1. `RealtimeDBService` 세션 CRUD 메서드 구현
2. `ListenTogetherViewModel` 구현 (세션 상태, 수신 요청 관리, MusicKit 싱크)
3. 주변 러너 시트 "같이 듣기" 버튼 → 세션 생성 연결
4. 요청 수신 배너 UI (수락/거절)
5. 함께 듣는 중 배너 UI
6. 세션 종료 처리
7. QA → 이슈 → 보고서 → 커밋 → PR

---

## Realtime DB 구조
```
listenSessions / {sessionID} /
  hostUID: String
  guestUID: String
  songID: String
  playbackPosition: Double   // 초 단위
  timestamp: Long            // 서버 타임스탬프 (싱크 보정용)
  status: String             // pending / active / ended
```

---

## 주의사항
- MusicKit `ApplicationMusicPlayer`의 `playbackTime` 설정으로 재생 위치 맞추기
- 네트워크 레이턴시 보정: `Date().timeIntervalSince1970 - timestamp` 만큼 position 앞당겨서 재생
- 세션 중 앱 백그라운드 진입 시 세션 유지 (백그라운드 위치 권한 활용)
- 두 사람 중 한 명이 러닝 종료하면 세션 자동 해제
