# 러닝 음악 시트 현재 재생 곡 앨범 커버 매핑 수정 계획서

> **상태**: 개발 진행 중 / 실기기 QA 대기  
> **작성일**: 2026-08-18  
> **관련 이슈**: [#116 러닝 음악 시트 현재 재생 곡 앨범 커버 매핑](https://github.com/kec08/Pacing/issues/116)  
> **선행 이슈**: [#115 Apple Music 재생 동기화](https://github.com/kec08/Pacing/issues/115)  
> **예정 브랜치**: `fix/116-running-music-sheet-artwork-mapping`

---

## 1. 목적 및 배경

음악 탭에서 정상적으로 표시되는 현재 재생 곡의 앨범 커버가 러닝 음악 시트에서는 placeholder로 보이거나 이전 곡의 커버로 남는 문제를 해결한다.

현재 확인된 구조적 원인은 다음과 같다.

- 러닝 시트 상단은 `queueSongs`가 존재하면 `Song.artwork` 또는 곡별 보강 URL을 우선 사용한다.
- 음악 탭에서 시작한 재생은 러닝 ViewModel의 `queueSongs`와 별개로 `ApplicationMusicPlayer.queue.currentEntry`에서 읽는다.
- `Queue.Entry`의 `id`, `item` 내부 `Song.id`, 카탈로그 `Song.id`가 항상 동일하다고 보장되지 않아 현재 곡의 artwork를 바로 찾지 못할 수 있다.
- 현재 곡 보강 요청이 비동기인데 요청 식별자와 화면 표시 식별자가 완전히 결합되어 있지 않아, 전환 중 placeholder 또는 이전 결과가 표시될 가능성이 있다.

## 2. 사용자 시나리오

```text
사용자가 음악 탭에서 플레이리스트·앨범·추천 곡을 재생한 뒤
→ 러닝 탭의 음악 시트를 연다.
→ 현재 재생 중인 곡의 제목·아티스트와 일치하는 앨범 커버가 표시된다.

사용자가 러닝 음악 시트에서 다음/이전 곡 또는 슬라이드로 전환하면
→ 전환 중 이전 곡의 커버가 남지 않는다.
→ 현재 재생 엔트리와 동일한 곡의 커버가 표시된다.
→ 일시적으로 로딩되더라도 해당 곡에 귀속된 placeholder만 보이며, 다른 곡의 커버가 보이지 않는다.
```

## 3. 사전 분석 및 수정 방향

| 영역 | 현재 동작 | 수정 방향 |
|---|---|---|
| 현재 재생 기준 | 러닝 ViewModel의 `queueSongs`와 `ApplicationMusicPlayer` 엔트리 경로가 병존 | 재생 중인 경우 `Queue.Entry`를 현재 상태의 기준으로 고정하고, 러닝 로컬 큐는 매핑된 보조 정보로 사용 |
| 식별자 매핑 | `entry.id`를 곧바로 `Song.id`로 간주하거나 제목/아티스트로 부분 보강 | `entry.id` → `entry.item`의 `Song.id` → 카탈로그 ID 조회 → 제목/아티스트 검색 순서의 명시적 매핑 정책 적용 |
| artwork 조회 | `entry.artwork`, `Song.artwork`, 시스템 플레이어 artwork가 분산되어 있음 | 현재 엔트리 ID를 키로 한 resolved song/artwork 상태를 관리하고, 현재 엔트리 변경 시 이전 요청을 취소 |
| 러닝 시트 렌더링 | `queueSongs`가 있으면 snapshot artwork보다 큐의 `Song.artwork`를 먼저 표시 | 현재 재생 엔트리와 큐 곡의 식별자가 일치할 때만 큐 artwork를 사용하고, 그 외에는 현재 snapshot artwork를 사용 |
| 캐시 | 곡 ID·엔트리 ID·검색 결과의 캐시 키가 분리되어 정합성 확인이 어려움 | 캐시 키와 비동기 결과 적용 조건을 현재 재생 엔트리의 안정적인 키에 묶음 |

## 4. 데이터 흐름

```text
ApplicationMusicPlayer.queue.currentEntry
        ↓
현재 엔트리 안정 키(entry.id + title + artist)
        ↓
entry.item의 Song / playbackContext의 Song / 카탈로그 ID 조회
        ↓
현재 엔트리에 귀속된 artwork URL·UIImage resolved 상태
        ↓
RunningMusicViewModel.currentSongSnapshot()
        ↓
RunningView.musicSheet 앨범 커버
```

### 상태 관리 원칙

- View는 artwork 매핑·검색·취소 로직을 직접 수행하지 않는다.
- `RunningMusicViewModel`이 현재 엔트리, 매핑된 `Song`, artwork URL, 로딩 상태를 관리한다.
- 현재 엔트리가 바뀌면 이전 artwork Task를 취소하고 artwork를 즉시 초기화한다.
- 비동기 응답 적용 전 현재 엔트리 키를 재검증해 이전 곡의 응답이 새 곡에 적용되지 않게 한다.
- 플레이리스트 목록의 커버 매핑은 현재 정상 동작하므로 변경 범위를 현재 재생 곡 경로로 제한한다.

## 5. 작업 목록

- [x] Task 1: `Queue.Entry`, `Song`, `MPMediaItem`의 현재 사용 식별자와 artwork 우선순위를 정리하고 재현 로그 포인트를 확정한다.
- [x] Task 2: 러닝 ViewModel에 현재 ApplicationMusicPlayer 엔트리용 안정 키와 artwork 로딩 Task 취소/세대 검증을 추가한다.
- [x] Task 3: 카탈로그 `Song` 매핑을 `entry.item`·ID 조회·제목/아티스트 검색 순으로 통합하고, 성공한 결과를 현재 엔트리에 캐시한다.
- [x] Task 4: `currentSongSnapshot()`과 러닝 음악 시트가 현재 엔트리와 일치하는 artwork만 렌더링하도록 우선순위를 수정한다.
- [ ] Task 5: 곡 전환 시 제목·아티스트·앨범 커버가 하나의 현재 곡 상태로 함께 갱신되는지 단위 테스트 가능한 순수 매핑 로직을 검증한다.
- [x] Task 6: Debug 빌드를 수행한다. 실기기에서 플레이리스트·앨범·추천 곡 전환 매트릭스 QA는 개발자 확인 대기다.
- [ ] Task 7: QA 결과와 제한 사항을 이슈/최종 보고서에 기록하고, 개발자 검토 후 커밋·푸시·PR을 진행한다.

## 6. 예상 영향 파일

- `Pacing/Pacing/Features/Running/ViewModel/RunningMusicViewModel.swift`
- `Pacing/Pacing/Features/Running/View/RunningView.swift`
- `Pacing/Pacing/Core/Music/AppleMusicRecommendationService.swift` (식별자/카탈로그 보강이 공통 서비스 수정으로 필요한 경우에만)
- `Pacing/PacingTests/PacingTests.swift` 또는 음악 매핑 검증을 위한 관련 테스트 파일

기존 작업 트리에 이미 변경된 `Pacing/Pacing/Pacing.entitlements`, `doc/README.md`, 신규 문서는 보존하며 이번 수정 범위에 포함하지 않는다.

## 7. 완료 기준

- [ ] 음악 탭에서 플레이리스트를 재생한 뒤 러닝 음악 시트를 열면 현재 곡의 앨범 커버가 표시된다.
- [ ] 음악 탭에서 앨범 및 추천 곡을 재생한 경우에도 동일하게 표시된다.
- [ ] 러닝 시트에서 다음/이전/슬라이드 전환 시 제목·아티스트·커버가 동일 곡을 가리킨다.
- [ ] 곡 전환 중 이전 곡 artwork가 남지 않고, 로딩 실패 시 현재 곡에 귀속된 placeholder로 안전하게 대체된다.
- [ ] 플레이리스트 대표 앨범 이미지 매핑과 기존 음악 탭 UI가 회귀하지 않는다.
- [ ] 권한 거부, 카탈로그 조회 실패, artwork URL 누락, 네트워크 지연 상황에서 앱이 크래시하지 않는다.

## 8. QA 계획

| 시나리오 | 확인 항목 |
|---|---|
| 음악 탭 플레이리스트 재생 → 러닝 시트 진입 | 현재 엔트리의 제목·아티스트·커버 일치 |
| 음악 탭 앨범 재생 → 러닝 시트 진입 | `entry.item` 또는 카탈로그 보강 경로의 커버 표시 |
| 음악 탭 추천 곡 재생 → 러닝 시트 진입 | 엔트리 ID가 카탈로그 ID와 다를 때 제목/아티스트 fallback 표시 |
| 러닝 시트 다음/이전/슬라이드 | 이전 artwork 잔류 및 제목/커버 불일치 여부 |
| 빠른 연속 곡 전환 | 취소된 이전 요청이 새 곡 artwork를 덮어쓰지 않는지 확인 |
| artwork 누락/네트워크 실패 | 현재 곡 placeholder, 크래시 없음, 재생 제어 유지 |
| 다크모드·소형 화면 | 이미지 영역·placeholder·텍스트 레이아웃 유지 |

## 9. 기술 검토 사항

- MusicKit `Queue.Entry`가 제공하는 `id`와 카탈로그 `Song.id`의 의미가 재생 경로별로 다를 수 있으므로, ID 단독 매칭을 최종 표시 조건으로 사용하지 않는다.
- 제목/아티스트 검색은 동명이곡 오매칭 위험이 있어 ID와 `entry.item` 매핑을 우선하며, 검색 결과 적용 전 현재 엔트리 키를 재검증한다.
- Apple Music 실제 메타데이터와 이미지 응답은 실기기·권한·구독 상태에 의존하므로 시뮬레이터만으로 완료 판정하지 않는다.
- 이번 이슈에서는 플레이리스트 대표 커버 매핑이 정상이라는 전제하에 해당 경로를 불필요하게 리팩터링하지 않는다.

---

> **검토 의견** (개발자 작성):  
> 승인 여부: 승인 ✅ / 수정 요청 🔄
