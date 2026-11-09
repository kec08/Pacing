# feat #38 공유 탭 앨범 공유 및 추천 플레이리스트

> **상태**: 검토 대기  
> **작성일**: 2026-07-12  
> **관련 이슈**: 작성 예정  
> **브랜치**: `feat/[issue-number]-album-share`

---

## 1. 목적 및 배경

현재 `공유` 탭은 placeholder만 존재하며 실제 음악 공유 기능이 비어 있다. 친구 탭과 마이 프로필 상세가 연결된 이후에는 사용자가 친구가 어떤 음악을 듣는지 보고, 플레이리스트 단위로 탐색하고, 마음에 드는 플레이리스트를 바로 내 라이브러리 또는 앱 저장 목록으로 보관할 수 있어야 한다.

이번 기능의 목표는 `공유` 탭을 단순 홍보 화면이 아니라 실제 사용 가능한 음악 탐색 화면으로 전환하는 것이다. UX 기준은 다음 두 축으로 잡는다.

- 친구 중심: 친구가 최근 공유하거나 자주 듣는 플레이리스트를 확인
- 추천 중심: Apple Music 추천 플레이리스트/스테이션을 함께 노출

## 2. 사용자 시나리오

```text
사용자가 하단 공유 탭에 진입하면
→ 상단에서 친구가 듣고 있는 플레이리스트를 가로 카드로 확인하고
→ 카드를 누르면 플레이리스트 상세 화면으로 이동해 트랙 목록을 본다
→ 상세 화면에서 재생 또는 저장 버튼을 눌러 내 음악 흐름으로 가져온다
→ 아래 섹션에서는 Apple Music 추천 플레이리스트와 추천 스테이션을 탐색한다
```

## 3. 화면 구성

### 주요 화면
- 공유 탭 메인
  - 상단 헤더
  - 친구가 듣고 있는 음악 섹션
  - 나만을 위한 추천 플레이리스트 섹션
  - 추천 스테이션 섹션
  - 권한 미허용 / 구독 불가 / 빈 상태 안내
- 플레이리스트 상세 화면
  - 대표 커버 이미지
  - 플레이리스트명, 소유자, 업데이트 시점
  - 재생 버튼
  - 저장 버튼
  - 곡 목록

### UI 요소
- 친구 플레이리스트 카드: 커버, 제목, 친구 닉네임, 보조 정보
- 추천 카드: Apple Music 스타일의 대형 아트워크 카드
- 상세 곡 Row: 앨범 아트, 제목, 아티스트, 더보기 아이콘
- 저장 버튼: 저장 상태에 따라 `저장`, `저장됨`, `Apple Music에 추가` 등으로 상태 분기
- 빈 상태: 친구 공유 없음 / 추천 불가 / 권한 없음
- 로딩 상태: 섹션별 skeleton 또는 progress UI

## 4. 데이터 흐름

### 사용 데이터
- Firestore 컬렉션
  - `users/{uid}/friends/{friendUID}`: 친구 관계 확인
  - `users/{uid}/sharedPlaylists/{playlistID}`: 내가 공유한 플레이리스트 메타데이터 저장
  - `sharedPlaylists/{playlistID}`: 공유 플레이리스트 공용 문서
  - `sharedPlaylists/{playlistID}/tracks/{trackID}`: 공유 당시의 트랙 스냅샷
  - `users/{uid}/savedSharedPlaylists/{playlistID}`: 앱 내부 저장 목록
- MusicKit
  - `MusicLibraryRequest<Playlist>`: 내 라이브러리 플레이리스트 조회
  - `playlist.with([.tracks])`: 플레이리스트 트랙 로드
  - `MusicPersonalRecommendationsRequest`: 개인화 추천 플레이리스트/스테이션 조회 검토
  - `MusicCatalogChartsRequest`: 개인화 추천이 없을 때 차트/에디토리얼 fallback 검토
  - `MusicLibrary.shared.add(...)`: 추천 플레이리스트 또는 앨범/곡의 Apple Music 라이브러리 저장 검토

### 핵심 설계 판단
- `친구가 듣고 있는 음악`은 Apple Music의 친구 소셜 그래프를 직접 가져오는 방식이 아니라, 우리 앱에서 친구가 공유한 플레이리스트 문서를 기준으로 노출한다.
- 친구 플레이리스트 상세는 공유 시점의 트랙 스냅샷을 우선 사용한다. 필요 시 Apple Music 원본 플레이리스트와 연결 가능한 식별자를 함께 저장한다.
- 저장 기능은 2단계로 분리한다.
  - 1차: 앱 내부 저장 `savedSharedPlaylists`
  - 2차: 가능한 항목은 `MusicLibrary.shared.add(...)`로 Apple Music 라이브러리 추가

### 상태 관리
- ViewModel
  - `ShareViewModel`
  - `SharedPlaylistDetailViewModel`
  - 필요 시 `AppleMusicRecommendationService` 분리
- Published 프로퍼티 예시
  - `friendSharedPlaylists: [SharedPlaylistSummary]`
  - `recommendedPlaylists: [RecommendedPlaylistItem]`
  - `recommendedStations: [RecommendedStationItem]`
  - `isLoadingFriends`
  - `isLoadingRecommendations`
  - `musicAuthorizationStatus`
  - `errorMessage`

## 5. 작업 목록 (Tasks)

- [ ] Task 1: 공유 탭 도메인 모델 정의
  - `SharedPlaylistSummary`
  - `SharedPlaylistTrack`
  - `RecommendationSectionItem`
- [ ] Task 2: FirestoreService 공유 플레이리스트 API 추가
  - 공유 플레이리스트 저장
  - 친구 공유 플레이리스트 목록 조회
  - 저장한 공유 플레이리스트 목록 조회
- [ ] Task 3: MusicKit 추천/저장 서비스 추가
  - 개인화 추천 조회
  - 추천 스테이션 조회 또는 fallback 구성
  - 라이브러리 저장 가능 여부 분기
- [ ] Task 4: 공유 탭 메인 UI 구현
  - placeholder 제거
  - 친구가 듣고 있는 음악 섹션
  - 추천 플레이리스트/스테이션 섹션
  - 권한/빈 상태/에러 상태
- [ ] Task 5: 플레이리스트 상세 화면 구현
  - 커버/메타/재생/저장 버튼
  - 트랙 목록
  - 공유 출처 또는 업데이트 시점 표시
- [ ] Task 6: 러닝 음악/마이 데이터와 연결
  - 내 라이브러리 플레이리스트 중 공유 가능한 항목 선택 흐름 검토
  - 친구 프로필/최근 청취 데이터와 충돌 없이 연결
- [ ] Task 7: QA 및 문서화
  - 권한별 시나리오 점검
  - 실기기 Apple Music 계정 상태 점검
  - 최종 보고서 작성

## 6. 완료 기준 (Acceptance Criteria)

- [ ] 공유 탭 진입 시 placeholder 대신 실제 음악 탐색 UI가 표시된다
- [ ] 친구가 공유한 플레이리스트가 있을 경우 가로 카드 리스트로 표시된다
- [ ] 친구 플레이리스트 카드를 누르면 상세 화면으로 이동한다
- [ ] 상세 화면에서 트랙 목록을 확인할 수 있다
- [ ] 상세 화면에서 저장 버튼으로 앱 내부 저장이 가능하다
- [ ] 저장 가능한 항목은 Apple Music 라이브러리 추가까지 동작하거나, 불가 시 명확한 안내가 표시된다
- [ ] Apple Music 추천 플레이리스트 또는 fallback 추천 섹션이 노출된다
- [ ] 추천 스테이션 섹션이 노출되거나, 계정/국가/권한 제약 시 대체 UI가 표시된다
- [ ] Music 권한이 없거나 Apple Music 사용 불가 상태여도 화면이 깨지지 않는다
- [ ] 다크 배경 기반의 현재 공유 탭 레퍼런스 톤을 유지하면서도 읽기성과 터치 영역이 확보된다

## 7. 예상 소요 시간

| 작업 | 예상 시간 |
|------|-----------|
| 모델 및 Firestore API | 2시간 |
| MusicKit 추천/저장 연동 | 3시간 |
| 공유 탭 메인 UI | 3시간 |
| 플레이리스트 상세 UI | 2시간 |
| QA 및 문서화 | 2시간 |
| **합계** | 12시간 |

## 8. 특이 사항 / 기술 검토

- 현재 `공유` 탭은 [SharePlaceholderView](/Users/kim-eunchan/Documents/Pacing/Pacing/Pacing/Features/Share/View/SharePlaceholderView.swift)만 존재하므로 이번 기능에서 첫 실제 화면 구현이 필요하다.
- 현재 프로젝트에는 [RunningMusicViewModel](/Users/kim-eunchan/Documents/Pacing/Pacing/Pacing/Features/Running/ViewModel/RunningMusicViewModel.swift) 기준으로 MusicKit 권한 요청, 라이브러리 플레이리스트 조회, 재생 흐름이 이미 들어가 있다. 공유 탭은 이 흐름을 재사용하되 ViewModel 책임은 분리한다.
- Apple Music 개인화 추천과 차트 요청 타입은 Apple 공식 MusicKit 문서 및 iOS SDK 인터페이스 기준으로 확인된다.
  - `MusicPersonalRecommendationsRequest`
  - `MusicCatalogChartsRequest`
  - `MusicLibrary.shared.add(...)`
- 다만 추천 결과는 사용자 계정, 국가/스토어프론트, 구독 상태, 실기기 여부에 따라 달라질 수 있다. 따라서 simulator 기준 고정 데이터처럼 보장하면 안 된다.
- 친구가 현재 듣는 플레이리스트를 Apple Music 친구 API로 직접 가져오는 방식은 이번 범위에서 채택하지 않는다. 앱 내 공유 데이터로 통제해야 UX와 데이터 일관성이 유지된다.
- 저장 기능은 두 단계로 나누는 것이 안전하다.
  - 앱 내부 저장은 항상 지원 가능
  - Apple Music 라이브러리 저장은 권한/구독/항목 타입에 따라 조건부 지원
- 구현 시작 전 GitHub 이슈 제목은 아래 안으로 잡는 것이 적절하다.
  - `[feat] 공유 탭 앨범 공유 및 추천 플레이리스트`

---

> **검토 의견** (개발자 작성):  
> 승인 여부: 수정 요청 🔄 / 승인 ✅
