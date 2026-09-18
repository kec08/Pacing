# feat #18 같이 듣기 동기화 수정

> **상태**: 승인 완료  
> **작성일**: 2026-07-01  
> **관련 이슈**: #30  
> **브랜치**: `feat/18-listen-together-sync`

---

## 1. 목적 및 배경

현재 같이 듣기 요청/수락 연결은 동작하지만, 요청한 사람이 듣고 있는 노래가 상대 기기에서 실제로 동기화되지 않는 문제가 있다.

원인 후보는 게스트 동기화 로직이 `songStoreID`를 사용하지 않고 곡 제목으로 로컬 보관함만 검색하는 구조라는 점이다. 상대방 보관함에 동일 곡이 없거나 제목 매칭이 어긋나면 세션은 활성화되어도 재생 큐가 설정되지 않는다.

이번 수정은 같이 듣기 MVP의 핵심인 “요청자가 듣는 노래가 수락한 사용자에게 동일 곡/위치로 재생되는 것”을 안정화한다.

## 2. 사용자 시나리오

```
사용자 A가 러닝 중 주변 러너 B에게 같이 듣기를 요청한다
→ 사용자 B가 요청을 수락한다
→ 사용자 B 기기에서 사용자 A가 듣고 있던 곡이 동일 위치 근처에서 재생된다
→ 사용자 A가 곡을 변경하면 사용자 B도 변경된 곡으로 동기화된다
→ 사용자 A가 일시정지/재생하면 사용자 B도 상태가 따라간다
```

## 3. 화면 구성

### 주요 화면
- 러닝 화면: 같이 듣기 요청 수신 배너, 활성 세션 플로팅 버튼 유지
- 주변 러너 시트: 같이 듣기 요청 버튼 유지
- 같이 듣기 시트: 현재 활성 세션 상태 확인

### UI 요소
- 수신 요청 배너: 요청자, 곡명, 아티스트 표시
- 같이 듣기 플로팅 버튼: 활성 세션 진입점
- 같이 듣기 시트: 세션 종료 및 상태 확인

## 4. 데이터 흐름

### 사용 데이터
- Realtime DB 경로:
  - `listenSessions/{sessionID}`
  - `incomingRequests/{guestUID}/{sessionID}`
- MusicKit / MediaPlayer:
  - `RunningMusicViewModel.currentSongSnapshot()`
  - `MPMusicPlayerController.systemMusicPlayer`
  - `MPMusicPlayerController.setQueue(with: [String])`

### 상태 관리
- ViewModel:
  - `ListenTogetherViewModel`
  - `RunningMusicViewModel`
- Published 프로퍼티:
  - `incomingRequest`
  - `activeSession`
  - `isHost`
  - `sessionStartDate`
  - `currentSong`
  - `isPlaying`

## 5. 작업 목록 (Tasks)

- [ ] Task 1: 현재 같이 듣기 세션 생성/수락/브로드캐스트/동기화 흐름 점검
- [ ] Task 2: 세션 생성 시 `songStoreID`를 현재 MusicKit 곡 ID 기준으로 안정적으로 저장
- [ ] Task 3: 게스트 동기화 로직을 `songStoreID` 기반 큐 세팅 우선으로 변경
- [ ] Task 4: `songStoreID`가 없거나 재생 실패할 때 제목/아티스트 검색 fallback 유지
- [ ] Task 5: 호스트 곡 변경, 재생/일시정지 상태 변경 시 세션 브로드캐스트 안정화
- [ ] Task 6: 연결은 됐지만 곡 재생이 실패한 경우를 디버깅할 수 있도록 최소 로그 추가
- [ ] Task 7: 빌드 및 기능 QA 후 오류 사항 보고

## 6. 완료 기준 (Acceptance Criteria)

- [ ] 요청자가 같이 듣기를 보내면 세션 데이터에 곡 ID, 곡명, 아티스트, 위치가 저장된다
- [ ] 수락자는 요청자가 듣던 곡을 동일 위치 근처에서 재생한다
- [ ] 요청자가 곡을 바꾸면 수락자도 변경된 곡으로 이동한다
- [ ] 요청자의 재생/일시정지 상태가 수락자에게 반영된다
- [ ] 곡 ID 기반 재생이 실패해도 기존 제목 기반 fallback이 동작한다
- [ ] 빌드가 성공한다
- [ ] 실기기 QA가 필요한 MusicKit/Apple Music 제약은 보고서가 아니라 QA 단계에서 먼저 공유한다

## 7. 예상 소요 시간

| 작업 | 예상 시간 |
|------|-----------|
| 흐름 점검 및 원인 확인 | 0.5시간 |
| 동기화 로직 수정 | 1.5시간 |
| 브로드캐스트 안정화 | 0.5시간 |
| 빌드 및 QA | 0.5시간 |
| **합계** | 3시간 |

## 8. 특이 사항 / 기술 검토

- `MPMediaPropertyPredicate`는 `playbackStoreID` 직접 필터링이 제한적이므로, 게스트 재생은 `MPMusicPlayerController.setQueue(with: [songStoreID])`를 우선 사용한다.
- 현재 구현의 제목 기반 검색은 상대방 로컬 보관함에 같은 곡이 없으면 실패할 수 있다. 따라서 fallback으로만 유지한다.
- `serverTimestamp`는 Firebase 서버 타임스탬프라 밀리초 단위로 내려온다. 동기화 보정 시 초 단위 변환을 유지한다.
- MusicKit/Apple Music 재생은 시뮬레이터보다 실기기 QA가 필요하다. 빌드 후 사용자가 실기기에서 수락/재생/곡 변경 케이스를 확인해야 한다.
- 최종 보고서, 최종 커밋, 푸시, PR은 사용자 QA 및 명시 승인 후 진행한다.

---

> **검토 의견** (개발자 작성):  
> 승인 여부: 승인 ✅ / 수정 요청 🔄
