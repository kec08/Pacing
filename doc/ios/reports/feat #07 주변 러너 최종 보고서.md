# feat #07 주변 러너 최종 보고서

## 개요
Firebase Realtime Database를 이용해 앱 실행 중 내 위치와 현재 곡 정보를 브로드캐스트하고, 1km 반경 내 러너를 지도 핀과 시트로 표시하는 기능 구현

---

## 구현 완료 항목

### 1. RealtimeDBService (신규)
- `activeRunners/{uid}` 경로에 5초 간격 브로드캐스트
- `onDisconnectRemoveValue()` — 앱 종료/네트워크 끊김 시 자동 삭제
- `updateChildValues` 로 부분 업데이트 (좌표 없어도 곡 정보 업로드 가능)
- `observe(.value)` 로 실시간 러너 목록 수신
- Firebase DB URL 명시 지정 (GoogleService-Info.plist에 DATABASE_URL 없음 대응)

### 2. NearbyRunnerViewModel (신규)
- 반경 1km 고정 클라이언트 사이드 필터링
- 필터: 친구 / 가까운 러너 (친구는 feat #08에서 연결 예정)
- 본인 포함 표시 — 닉네임 "나", 파란 틴트 카드로 구분
- `formattedDistance()` — m/km 자동 변환

### 3. 지도 핀 카드뷰
- 말풍선 카드 형태: 닉네임 + 곡제목(bold) + 아티스트
- 내 핀: 메인컬러 틴트 배경으로 구분
- 탭으로 접기/펼치기 (`scaleEffect` + `opacity` 애니메이션)
- 접힌 상태: 아바타 원형 + 음표 뱃지 (곡 재생 중일 때만)

### 4. 주변 러너 시트
- 친구 / 가까운 러너 세그먼트 피커
- 러너 카드: 아바타 + 닉네임 + 곡제목(semibold) + 아티스트 + 거리
- "같이 듣기" 버튼 UI (feat #08 예약)
- 배경 완전 불투명 + 라이트모드 고정

### 5. 브로드캐스트 범위 확대
- 러닝 중에만 → RunningView 진입 시(`onAppear`) 즉시 시작
- 곡 변경 시 즉시 재업로드 (`onChange(musicVM.currentSong)`)
- RunningView 이탈 시 브로드캐스트 중지

### 6. 익명 로그인 추가
- `게스트로 시작` 버튼 — 동일 Apple ID 두 기기 테스트용
- `signInAnonymously()` → Firebase 익명 UID 발급

---

## 해결한 이슈
| 이슈 | 원인 | 해결 |
|------|------|------|
| DB 연결 강제 종료 | GoogleService-Info.plist에 DATABASE_URL 없음 | URL 명시 지정 |
| 곡 정보 미업로드 | coord guard가 전체 업로드 차단 | coord optional 처리 + updateChildValues |
| 두 기기 UID 충돌 | 동일 Apple ID → 동일 UID | 익명 로그인 추가 |

---

## 미구현 / 다음 단계
- **친구 필터** — 친구 목록 시스템 필요 (feat #08 이후 설계)
- **"같이 듣기"** — feat #08에서 실시간 음악 동기화 세션 구현
- **프로필 사진** — Firebase Storage 연동 후 핀 아바타에 적용
- **마이탭 러닝 통계** — 러닝 종료 후 데이터 반영 누락 (별도 이슈 처리 예정)

---

## 변경 파일
| 파일 | 변경 유형 |
|------|----------|
| `Core/Firebase/RealtimeDBService.swift` | 신규 |
| `Features/Running/ViewModel/NearbyRunnerViewModel.swift` | 신규 |
| `Features/Running/View/RunningView.swift` | 수정 (브로드캐스트, 핀, 시트) |
| `Features/Running/ViewModel/RunningViewModel.swift` | 수정 (musicViewModel 추가) |
| `Core/Auth/AuthViewModel.swift` | 수정 (익명 로그인) |
| `Features/Auth/View/LoginView.swift` | 수정 (게스트 버튼) |
