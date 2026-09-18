# feat #40 음악 탭 세부 수정 최종 보고서

## 작업 요약
음악 탭의 친구 플레이리스트 재생 안정성을 보강하고, 러닝 음악 시트에서 플레이리스트 선택과 곡 리스트 전환 UX를 분리해 정리했습니다.

---

## 구현 내용

### 1. 친구 플레이리스트 재생 fallback 보강
- 공유 플레이리스트 곡 재생 시 기존 `songStoreID` 기반 catalog 조회가 실패해도
  - 곡명 + 아티스트 기반 catalog 검색 fallback으로 재생 가능하도록 보강
- 단일 곡 재생과 전체 재생 모두 같은 fallback 경로를 타도록 정리
- `songStoreID`가 비어 있는 공유 곡도 title/artist 기준 fallback을 타도록 분기 수정

### 2. 친구 플레이리스트 커버 이미지 fallback 정리
- `SharedPlaylistSummary`에 `effectiveArtworkURL` 계산 프로퍼티 추가
- 플레이리스트 자체 artwork가 비어 있으면 첫 트랙 artwork를 대표 이미지로 사용
- 친구 카드와 상세 화면 앨범아트에서 동일 규칙 사용

### 3. 러닝 음악 시트 플레이리스트 UX 개편
- 좌상단 글래스 버튼으로 플레이리스트 선택 패널 진입
- 상단 패널은 기존처럼 `내 플레이리스트` 목록을 보여주되, 열기 트리거만 좌상단 버튼으로 이동
- 하단 버튼은 `리스트 + 햄버거바 아이콘` 역할로 변경
- 하단 버튼 탭 시 현재 선택한 플레이리스트의 곡 목록이 아래에서 리스트 형식으로 펼쳐지도록 구현
- 리스트에서 곡 탭 시 해당 곡으로 전환되고 패널은 닫히도록 처리

### 4. 로딩/상태 전환 정리
- 노래 탭 `load()`에서 최초 로딩과 재진입/새로고침 동작을 분리
- 이미 로딩된 상태에서 다시 불러올 때 전체 스켈레톤이 과하게 다시 뜨지 않도록 조정
- 추천 데이터는 병렬로 유지하고, 친구 플레이리스트 로딩은 동기화 이후 순서 보장하도록 정리

### 5. 미니 플레이어 노출 조건 보정
- 시스템 플레이어 상태가 `stopped`일 때는 노래 탭 오버레이 내용을 정리하도록 보완
- 재생 종료 후 미니 플레이어가 필요 이상으로 남아 있는 경우를 줄이는 방향으로 정리

---

## 변경 파일
| 파일 | 변경 내용 |
|------|----------|
| `Pacing/Pacing/Core/Music/AppleMusicRecommendationService.swift` | 공유 플레이리스트 재생 fallback 추가 |
| `Pacing/Pacing/Models/SharedPlaylistModels.swift` | 플레이리스트 artwork fallback 계산 프로퍼티 추가 |
| `Pacing/Pacing/Features/Share/ViewModel/SharedPlaylistDetailViewModel.swift` | 공유 곡 재생 분기 수정 |
| `Pacing/Pacing/Features/Share/ViewModel/SongViewModel.swift` | 노래 탭 로딩 흐름 정리 |
| `Pacing/Pacing/Features/Share/View/SongView.swift` | 친구 카드 artwork fallback, 미니 플레이어 stopped 처리 |
| `Pacing/Pacing/Features/Share/View/SharedPlaylistDetailView.swift` | 상세 화면 artwork fallback 적용 |
| `Pacing/Pacing/Features/Running/ViewModel/RunningMusicViewModel.swift` | 현재 선택 플레이리스트명 상태 추가 |
| `Pacing/Pacing/Features/Running/View/RunningView.swift` | 좌상단 플레이리스트 선택, 하단 곡 리스트 패널 UX 개편 |

---

## QA 결과
| 항목 | 결과 |
|------|------|
| 친구 플레이리스트 재생 fallback 로직 반영 | 코드 반영 완료 |
| 친구 플레이리스트 대표 이미지 fallback 적용 | 코드 반영 완료 |
| 러닝 음악 시트 좌상단 플레이리스트 선택 버튼 | 코드 반영 완료 |
| 하단 리스트 버튼으로 현재 플레이리스트 곡 목록 노출 | 코드 반영 완료 |
| 곡 선택 시 해당 곡 전환 | 코드 반영 완료 |
| 노래 탭 재로딩 시 전체 스켈레톤 과다 노출 완화 | 코드 반영 완료 |
| `xcodebuild` 기반 실제 빌드 검증 | 환경 제약으로 미실행 |

---

## 확인된 이슈 / 제한사항
- 현재 환경의 active developer directory가 `CommandLineTools`로 잡혀 있어 `xcodebuild`를 실행할 수 없었습니다.
- 따라서 실제 시뮬레이터 빌드와 MusicKit 런타임 동작은 Xcode가 연결된 로컬 환경에서 추가 확인이 필요합니다.

---

## 후속 확인 권장
1. 친구 플레이리스트에서 곡 탭 시 fallback 검색이 실제로 원하는 곡을 정확히 매칭하는지 확인
2. 러닝 음악 시트에서 플레이리스트 선택 후 하단 리스트가 선택된 플레이리스트 기준으로 유지되는지 확인
3. 재생 종료 시 미니 플레이어가 의도대로 사라지는지 실제 기기에서 확인
