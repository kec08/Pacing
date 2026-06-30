# feat #06 음악 연동

## 목표
MusicKit을 통해 Apple Music 라이브러리 연동 — 앨범 커버 표시, 플레이리스트 목록, 곡 선택 및 실제 재생 제어

---

## 현재 상태 (feat/05 기준)
- `RunningMusicViewModel`: `MusicRecentlyPlayedRequest`로 최근 재생 곡 fetch 시도
- `musicSheet`: 앨범 커버 없이 더미 UI, 재생 버튼 동작 안 함
- MusicKit entitlement 미적용 (프로비저닝 이슈로 보류됨)
- 문제: `com.eunchan.Pacing` MusicKit 등록은 됐지만 entitlement 추가 시 빌드 실패

---

## 구현 목표

### 1. MusicKit Entitlement 해결
- `Pacing.entitlements`에 `com.apple.developer.musickit` 추가
- Xcode Signing & Capabilities → MusicKit capability 추가
- 프로비저닝 프로파일 갱신

### 2. 음악 뷰 개선 (`musicSheet`)
- **앨범 커버**: `song.artwork` → `ArtworkImage` 뷰로 실제 이미지 표시
- **현재 재생 곡**: `ApplicationMusicPlayer.shared.queue.currentEntry` 반영
- **재생/일시정지**: `ApplicationMusicPlayer.shared.play()` / `.pause()`
- **이전/다음 곡**: `ApplicationMusicPlayer.shared.skipToPreviousEntry()` / `.skipToNextEntry()`
- **재생 상태 연동**: `ApplicationMusicPlayer.shared.state.playbackStatus` 구독

### 3. 플레이리스트 목록
- `MusicLibraryRequest<Playlist>` 로 내 라이브러리 플레이리스트 fetch
- 음악 시트 하단에 플레이리스트 목록 표시
- 플레이리스트 탭 → 해당 플레이리스트 재생 시작

### 4. 러닝 카드 (홈 화면) 연동
- 현재 재생 중인 곡 앨범 커버 + 제목 표시

---

## 화면 구성

### 음악 시트 (musicSheet)
```
┌─────────────────────────┐  ← .ultraThinMaterial 글래스 배경
│         음악        완료  │     (뒤 지도가 블러 처리되어 비침)
├─────────────────────────┤
│                         │
│   [앨범 커버 200x200]    │
│                         │
│      곡 제목             │
│      아티스트명           │
│                         │
│   ◀◀    ▶/⏸    ▶▶     │
│                         │
│ ─── 내 플레이리스트 ───  │
│ ← [커버] [커버] [커버] → │  ← 가로 스크롤
│   러닝   밴드   인딘      │
└─────────────────────────┘
```

- 시트 배경: `.presentationBackground(.ultraThinMaterial)` (iOS 16.4+)
- 플레이리스트: 앨범 커버 이미지 + 이름 아래 표시, `ScrollView(.horizontal)` 가로 스크롤
- 각 플레이리스트 카드 크기: 100×100 커버 + 이름 텍스트

---

## 기술 스택
- `MusicKit` — Apple Music 라이브러리 접근
- `ApplicationMusicPlayer` — 재생 제어
- `MusicLibraryRequest<Playlist>` — 플레이리스트 목록
- `ArtworkImage` — 앨범 커버 이미지 뷰

---

## 작업 순서
1. MusicKit entitlement 추가 및 빌드 확인
2. `RunningMusicViewModel` 개선 — 재생 상태, 플레이리스트 fetch
3. `musicSheet` UI 개선 — 앨범 커버, 재생 컨트롤 동작
4. 플레이리스트 목록 섹션 추가
5. QA → 보고서 → 커밋/PR
