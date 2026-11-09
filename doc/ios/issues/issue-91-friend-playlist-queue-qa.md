# #91 친구 플레이리스트·앨범 개별 곡 연속 재생 QA 보고서

> **심각도**: Major 🟠
> **발견일**: 2026-08-05
> **발견 브랜치**: `fix/91-friend-playlist-queue`
> **상태**: 수정 완료 · 실기기 재생·표시 동기화 QA 대기

---

## 증상 요약

친구 플레이리스트 또는 앨범 상세에서 개별 곡을 선택하면 해당 곡만 큐에 담겨, 곡 종료 후 다음 수록곡으로 이어서 재생되지 않는다.

## 재현 방법

1. 친구 플레이리스트 또는 앨범 상세 화면에 진입한다.
2. 수록곡 중 중간 곡을 선택해 재생한다.
3. 현재 곡이 끝날 때까지 기다린다.
4. 재생이 종료되고 다음 곡으로 넘어가지 않는 것을 확인한다.

## 예상 동작

선택한 곡부터 상세 화면의 남은 수록곡이 순서대로 재생된다.

## 실제 동작

선택한 한 곡만 재생 큐에 설정되어, 곡 종료 시 재생이 멈춘다.

## 원인 분석

`SharedPlaylistDetailViewModel.play(track:)`이 공유 목록에서는 단일 `SharedPlaylistTrack`, 앨범·추천 목록에서는 단일 `songStoreID`만 재생 서비스로 전달했다. 두 경로 모두 `ApplicationMusicPlayer`에 길이 1의 큐를 구성했다.

## 수정 내용

- 선택 곡의 위치부터 마지막 곡까지를 하나의 큐로 구성하는 재생 API를 추가했다.
- 친구 플레이리스트·앨범 상세의 개별 곡 선택을 공통 큐 재생 API로 통합했다.
- 선택 곡을 해석할 수 없을 때 다음 곡을 임의로 재생하지 않고 기존 오류 상태로 처리한다.
- `ApplicationMusicPlayer`의 현재 큐 항목 변경을 구독해, 수록곡 강조 표시와 미니플레이어가 실제 재생 곡을 반영하도록 연결한다.
- 노래 탭의 하단 미니플레이어는 이전 곡이 왼쪽으로 나가고 다음 곡이 오른쪽에서 들어오는 전환을 적용한다.
- 친구 앨범·플레이리스트 수록곡의 재생 강조 표시는 부드럽게 전환한다.

## 검증 결과

| 항목 | 결과 |
|---|---|
| 변경 파일 `git diff --check` | ✅ 통과 |
| Debug Simulator 빌드 (`xcodebuild`, 코드 서명 비활성화) | ✅ 통과 |
| 친구 플레이리스트에서 중간 곡 선택 후 연속 재생 | ⏳ Apple Music 계정이 연결된 실기기 QA 필요 |
| 친구 앨범에서 중간 곡 선택 후 연속 재생 | ⏳ Apple Music 계정이 연결된 실기기 QA 필요 |
| 다음 곡 전환 시 수록곡 강조·미니플레이어 제목/커버 동기화 | ⏳ Apple Music 계정이 연결된 실기기 QA 필요 |
| 노래 탭 미니플레이어의 좌→우 곡 전환 애니메이션 | ⏳ 실기기 QA 필요 |
| 친구 앨범·플레이리스트 목록의 재생 강조 애니메이션 | ⏳ 실기기 QA 필요 |
| 전체 재생·미니플레이어 다음 곡 회귀 | ⏳ 실기기 QA 필요 |

## 관련 파일

- `Pacing/Pacing/Core/Music/AppleMusicRecommendationService.swift`: 선택 곡부터 시작하는 연속 재생 큐 구성
- `Pacing/Pacing/Features/Share/ViewModel/SharedPlaylistDetailViewModel.swift`: 개별 곡 탭에서 전체 수록곡 큐 전달 및 현재 재생 곡 강조 동기화
- `Pacing/Pacing/Features/Share/View/SongView.swift`: 미니플레이어 제목·아티스트·커버 동기화
- `Pacing/Pacing/Features/Share/View/SharedPlaylistDetailView.swift`: 수록곡 재생 강조 애니메이션
