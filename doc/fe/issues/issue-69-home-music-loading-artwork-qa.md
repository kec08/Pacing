# #69 홈 로딩 안정화 및 친구 플레이리스트 커버 이미지 복구 QA 보고서

> **심각도**: Major 🟠  
> **발견일**: 2026-07-29  
> **발견 브랜치**: `feat/69-home-music-loading-artwork`  
> **상태**: 추가 수정 완료 / 기존 PR #70 닫힘 / 실기기 확인 대기

---

## 증상 요약

홈 탭에서 러닝 기록 또는 같이 듣기 세션 중 하나의 데이터 요청이 완료되지 않으면 전체 섹션의 스켈레톤이 계속 표시됐다. 친구 플레이리스트는 빈 문자열 커버 URL을 유효값으로 처리해 앨범 커버가 있어도 기본 음표 이미지가 표시될 수 있었다.

## 재현 방법 (Steps to Reproduce)

1. 로그인한 상태로 홈 탭에 진입한다.
2. Realtime DB `listenSessions` 응답이 지연되거나 실패한 상태를 만든다.
3. 홈의 러닝·같이 듣기 섹션이 모두 계속 스켈레톤으로 표시되는지 확인한다.
4. 커버 URL이 비어 있는 친구 공유 플레이리스트를 노래 탭과 상세 화면에서 확인한다.

## 예상 동작

- 홈의 각 섹션은 다른 요청과 독립적으로 콘텐츠, 빈 상태 또는 오류 상태로 전환한다.
- Realtime DB 응답이 없으면 10초 후 해당 섹션만 재시도 UI로 전환한다.
- 친구 플레이리스트는 유효한 대표·수록곡 커버 URL을 사용하고, 빈 문자열은 누락값으로 처리해 첫 유효 수록곡 커버로 폴백한다.

## 실제 동작

- 수정 전에는 단일 `isLoading` 상태 때문에 하나의 요청이 지연되면 홈 전체 스켈레톤이 유지됐다.
- 수정 전에는 `artworkURL == ""`이 nil이 아니어서 수록곡 커버 폴백이 실행되지 않았다.

## 원인 분석

- 홈 ViewModel이 Firestore와 Realtime DB 요청을 모두 기다린 뒤에만 로딩 상태를 해제했다.
- Realtime DB 단건 조회에 취소 콜백·응답 시간 제한이 없었다.
- 공유 플레이리스트 모델이 빈 문자열을 유효한 커버 URL로 간주했다.

## 수정 내용

- 홈 데이터를 러닝·같이 듣기 섹션별 비동기 작업과 로딩·오류 상태로 분리했다.
- Realtime DB 단건 조회에 취소 콜백과 10초 타임아웃을 적용했다.
- 홈 오류 카드에 44pt 이상 재시도 버튼을 제공했다.
- 공유 플레이리스트와 수록곡의 빈 문자열 커버 URL을 누락값으로 정규화하고, Apple Music 카탈로그로 누락된 수록곡 커버를 최대 8곡까지 보강한다.
- 이미지 로더가 URL 변경 시 이전 이미지를 지우고, 취소된 요청 결과가 새 카드에 반영되지 않도록 했다.
- 친구가 최근에 들은 음악을 Firestore `recentSongs`에서 조회해, 홈의 같이 들은 러너 섹션을 작은 앨범 카드로 교체했다.
- 개별 Apple Music 카탈로그 검색 실패를 곡 단위로 처리해, 한 곡 실패가 전체 수록곡 커버 보강을 막지 않도록 했다.

## 검증 결과

| 항목 | 결과 | 근거 |
|---|---|---|
| 변경 Swift 파일 구문 검사 | ✅ 통과 | `swiftc -parse` |
| 변경 파일 공백 오류 검사 | ✅ 통과 | `git diff --check` |
| iOS Simulator Debug 빌드 | ✅ 통과 | `xcodebuild ... build CODE_SIGNING_ALLOWED=NO` |
| 친구 최근 음악 홈 카드 컴파일·빌드 | ✅ 통과 | 2026-07-29 추가 수정 빌드 |
| 실제 Firebase 지연·타임아웃 UI | ⏳ 실기기 확인 필요 | 인증된 Firebase 세션 필요 |
| 친구 플레이리스트 실제 커버 표시 | ⏳ 실기기 확인 필요 | Apple Music 권한·카탈로그 데이터 필요 |

## 관련 파일

- `Pacing/Pacing/Features/Home/ViewModel/HomeViewModel.swift`: 홈 섹션별 상태와 독립 비동기 로드
- `Pacing/Pacing/Features/Home/View/HomeView.swift`: 오류·재시도 UI
- `Pacing/Pacing/Core/Firebase/RealtimeDBService.swift`: Realtime DB 취소·타임아웃 처리
- `Pacing/Pacing/Models/SharedPlaylistModels.swift`: 빈 커버 URL 폴백
- `Pacing/Pacing/Core/Music/AppleMusicRecommendationService.swift`: 누락 수록곡 커버 보강
- `Pacing/Pacing/Features/Share/View/SongView.swift`: 취소 안전 이미지 로드
- `Pacing/Pacing/Features/Home/View/HomeView.swift`: 친구 최근 음악 미니 카드 UI
- `Pacing/Pacing/Core/Firebase/FirestoreService.swift`: 친구 최근 음악 조회
