# feat #06 음악 연동 최종 보고서

## 개요

| 항목 | 내용 |
|------|------|
| 브랜치 | `feat/06-music` |
| 작업 기간 | 2026-06-25 ~ 2026-06-26 |
| 담당 | kimeunchan |

---

## 구현 내용

### 1. 음악 시트 UI 전면 개선
- 시트 배경: `.presentationBackground(.ultraThinMaterial)` 글래스 효과 적용
- 앨범 커버 영역: 220×220 크기, `RoundedRectangle(cornerRadius: 20)` 클리핑, 그림자 자연스럽게
- 플레이리스트 미선택 상태도 동일한 레이아웃 (플레이스홀더 커버 + 텍스트) 로 통일

### 2. 앨범 커버 캐러셀
- `TabView` + `.page` 스타일로 가로 스와이프 선택
- 스와이프 방향 감지 (`isGoingForward`) → 텍스트 슬라이드 방향 동기화
- 이전/다음 버튼 탭 시 캐러셀도 함께 슬라이드

### 3. 곡 정보 애니메이션
- 제목/아티스트 텍스트에 `.asymmetric` transition 적용
- 다음 곡: 오른쪽에서 진입 / 왼쪽으로 퇴장
- 이전 곡: 왼쪽에서 진입 / 오른쪽으로 퇴장

### 4. 플레이리스트 목록
- `MusicLibraryRequest<Playlist>` 로 내 Apple Music 라이브러리 플레이리스트 fetch
- 시트 하단 가로 스크롤 (`ScrollView(.horizontal)`)
- 플레이리스트 탭 → 해당 플레이리스트 재생 시작

### 5. 실제 재생 제어 (`RunningMusicViewModel`)
- `MPMusicPlayerController.systemMusicPlayer` 기반 재생
- 플레이리스트 선택 시 `MPMediaQuery`로 매칭 후 `MPMediaItemCollection` 큐 설정
- `cachedMediaItems`에 현재 플레이리스트 아이템 캐시 → 곡 전환 시 즉시 `player.nowPlayingItem` 변경
- 재생/일시정지/이전/다음 컨트롤
- `MPMusicPlayerControllerNowPlayingItemDidChange` 알림 구독 → 상태 자동 동기화

### 6. 곡 전환 끊김 최소화
- `play(at:)` 호출 시 UI 업데이트 선행 후 150ms 후 재생 명령 → TabView 애니메이션과 충돌 방지
- `isManualSeeking` 플래그로 노티피케이션이 인덱스를 덮어쓰는 현상 방지

---

## 미완 항목

| 항목 | 사유 |
|------|------|
| MusicKit entitlement 정식 등록 | Developer Portal MusicKit 활성화 후 프로비저닝 프로파일 갱신 필요 — 배포 시 처리 |
| `Client is not entitled to account store` 경고 | entitlement 미등록으로 인한 시스템 경고 — 재생 자체는 동작 |

---

## 주요 파일 변경 목록

| 파일 | 변경 내용 |
|------|-----------|
| `Features/Running/ViewModel/RunningMusicViewModel.swift` | 전면 재작성 — MPMusicPlayerController 기반 재생, 캐시, 방향 추적 |
| `Features/Running/View/RunningView.swift` | 음악 시트 UI 전면 개선 — 글래스 배경, 캐러셀, 방향별 애니메이션 |

---

## QA 결과

| 항목 | 결과 |
|------|------|
| 플레이리스트 목록 표시 | ✅ Apple Music 라이브러리 플레이리스트 정상 표시 |
| 앨범 커버 표시 | ✅ ArtworkImage로 실제 커버 이미지 표시 |
| 플레이리스트 선택 → 재생 | ✅ 첫 번째 곡부터 재생 시작 |
| 앨범 커버 스와이프 → 곡 이동 | ✅ 자연스러운 슬라이드 + 곡 전환 |
| 이전/다음 버튼 → 곡 이동 | ✅ 캐러셀 슬라이드 + 곡 전환 |
| 텍스트 전환 방향 동기화 | ✅ 이전/다음 방향에 맞게 슬라이드 |
| 재생/일시정지 | ✅ 정상 동작 |
| 글래스 배경 시트 | ✅ ultraThinMaterial 적용 |
