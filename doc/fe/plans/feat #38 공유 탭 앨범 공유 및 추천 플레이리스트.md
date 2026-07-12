# feat #38 공유 탭 앨범 공유 및 추천 플레이리스트

> **상태**: 승인 완료  
> **작성일**: 2026-07-12  
> **관련 이슈**: 생성 대기  
> **브랜치**: `feat/38-share-album-recommendations`

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
- 상세 곡 Row: 앨범 아트, 제목, 아티스트, 재생 시간
- 저장 버튼: 저장 상태에 따라 `플레이리스트 저장`, `저장됨`, `Apple Music에 저장` 등으로 상태 분기
- 빈 상태: 친구 공유 없음 / 추천 불가 / 권한 없음
- 로딩 상태: 섹션별 skeleton 또는 progress UI

## 4. 데이터 흐름

### 사용 데이터
- Firestore 컬렉션
  - `users/{uid}/friends/{friendUID}`: 친구 관계 확인
  - `sharedPlaylists/{playlistID}`: 친구 공유 플레이리스트 스냅샷 저장
  - `users/{uid}/savedSharedPlaylists/{playlistID}`: 앱 내부 저장 목록
- MusicKit
  - `MusicLibraryRequest<Playlist>`: 내 라이브러리 플레이리스트 조회
  - `playlist.with([.tracks])`: 플레이리스트 트랙 로드
  - `MusicPersonalRecommendationsRequest`: 개인화 추천 플레이리스트/스테이션 조회
  - `MusicCatalogChartsRequest`: 개인화 추천이 없을 때 fallback 추천 조회
  - `ApplicationMusicPlayer`: 추천 플레이리스트/스테이션 재생
  - `MusicLibrary.shared.add(...)`: 추천 플레이리스트를 Apple Music 라이브러리에 저장

### 핵심 설계 판단
- `친구가 듣고 있는 음악`은 Apple Music 친구 소셜 데이터를 직접 가져오는 방식이 아니라, 우리 앱에서 친구가 동기화한 플레이리스트 스냅샷을 기준으로 노출한다.
- 친구 플레이리스트 상세는 공유 시점의 트랙 스냅샷을 사용하고, 가능한 경우 `songStoreID`로 전체 재생을 연결한다.
- 저장 기능은 2단계로 분리한다.
  - 친구 플레이리스트: 앱 내부 저장
  - 추천 플레이리스트: Apple Music 라이브러리 저장

### 상태 관리
- ViewModel
  - `ShareViewModel`
  - `SharedPlaylistDetailViewModel`
  - `AppleMusicRecommendationService`
- Published 프로퍼티 예시
  - `friendSharedPlaylists`
  - `recommendedPlaylists`
  - `recommendedStations`
  - `isLoadingFriends`
  - `isLoadingRecommendations`
  - `musicAuthorizationStatus`
  - `errorMessage`

## 5. 작업 목록 (Tasks)

- [x] Task 1: 공유 탭 도메인 모델 정의
- [x] Task 2: FirestoreService 공유 플레이리스트 API 추가
- [x] Task 3: MusicKit 추천/저장/재생 서비스 추가
- [x] Task 4: 공유 탭 메인 UI 구현
- [x] Task 5: 플레이리스트 상세 화면 구현
- [x] Task 6: 내 라이브러리 플레이리스트 동기화 액션 추가
- [x] Task 7: 빌드 검증 및 문서화

## 6. 완료 기준 (Acceptance Criteria)

- [x] 공유 탭 진입 시 placeholder 대신 실제 음악 탐색 UI가 표시된다
- [x] 친구가 공유한 플레이리스트가 있을 경우 가로 카드 리스트로 표시된다
- [x] 친구 플레이리스트 카드를 누르면 상세 화면으로 이동한다
- [x] 상세 화면에서 트랙 목록을 확인할 수 있다
- [x] 상세 화면에서 플레이리스트 저장이 가능하다
- [x] 추천 플레이리스트 섹션이 노출된다
- [x] 추천 스테이션 섹션이 노출되거나 빈 상태 안내가 표시된다
- [x] Music 권한이 없거나 Apple Music 사용 불가 상태여도 화면이 깨지지 않는다
- [x] Debug 빌드가 통과한다

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

- 현재 `공유` 탭은 placeholder만 존재했기 때문에 이번 기능에서 첫 실제 화면 구현이 필요했다.
- Apple Music 개인화 추천과 차트 요청 타입은 MusicKit 기준으로 확인된다.
  - `MusicPersonalRecommendationsRequest`
  - `MusicCatalogChartsRequest`
  - `MusicLibrary.shared.add(...)`
- 다만 추천 결과는 사용자 계정, 국가/스토어프론트, 구독 상태, 실기기 여부에 따라 달라질 수 있다.
- 친구가 현재 듣는 플레이리스트를 Apple Music 친구 API로 직접 가져오는 방식은 이번 범위에서 채택하지 않았다.
- GitHub 이슈 생성은 현재 `gh auth` 만료로 지연 중이며, 이슈 초안은 별도 문서로 보관한다.

---

> **검토 의견** (개발자 작성):  
> 승인 여부: 승인 ✅

