# feat #11 음악 플레이어 UI 개선 기획서

## 목표
음악 시트를 Apple Music 스타일로 재설계 — 재생 시간 스크러버, 음량 조절, 플레이리스트 토글

---

## 현재 상태
- 앨범 커버 + 곡 정보 + 재생 컨트롤 + 하단 플레이리스트 스크롤 (항상 노출)
- 재생 시간 표시 없음
- 음량 조절 없음
- 플레이리스트가 공간을 항상 차지해 플레이어가 좁아 보임

---

## 변경 목표 UI (Apple Music 스타일)

```
┌─────────────────────────┐
│         음악       완료  │  ← 네비게이션 바
├─────────────────────────┤
│                         │
│    [앨범커버 (대형)]     │  ← 240×240, 그림자, 재생 시 약간 커짐
│                         │
│  곡 제목 (bold)         │
│  아티스트 (secondary)   │
│                         │
│  ──●──────────────────  │  ← 재생 진행 슬라이더 (드래그 가능)
│  0:45              -2:10│  ← 경과 / 남은 시간
│                         │
│  ◀◀    ⏸/▶    ▶▶       │  ← 재생 컨트롤
│                         │
│  🔈 ──────●──────── 🔊  │  ← 음량 슬라이더
│                         │
│        [≡ 플레이리스트] │  ← 글래스 버튼 (항상 하단 고정)
└─────────────────────────┘
          ↓ 버튼 탭 시
┌─────────────────────────┐
│  내 플레이리스트         │
│  ┌──┐ ┌──┐ ┌──┐ ┌──┐  │  ← 기존 가로 스크롤 카드뷰
│  └──┘ └──┘ └──┘ └──┘  │
│  [닫기]                 │
└─────────────────────────┘ (아래서 슬라이드업 애니메이션)
```

---

## 구현 상세

### 1. 재생 진행 슬라이더 (Scrubber)
- `MPMusicPlayerController.systemMusicPlayer.currentPlaybackTime` 을 1초마다 폴링 (`TimelineView` 또는 `Timer`)
- `MPNowPlayingInfoCenter` / `nowPlayingItem.playbackDuration` 으로 전체 길이 가져오기
- SwiftUI `Slider` 커스텀 — 트랙 높이 4pt, thumb 작게
- 드래그 중에는 폴링 일시정지, `onEditingChanged(false)` 시 `player.currentPlaybackTime = value` 세크

### 2. 시간 표시
- 경과 시간: `Int(currentTime)` → `m:ss` 포맷
- 남은 시간: `-(duration - currentTime)` → `-m:ss` 포맷

### 3. 음량 슬라이더
- `MPVolumeView`는 SwiftUI에서 직접 사용 불가 → `UIViewRepresentable`로 래핑
- 또는 `AVAudioSession.sharedInstance().outputVolume` 읽고 `MPVolumeView` Slider로 제어
- 좌: 🔈 아이콘, 우: 🔊 아이콘

### 4. 플레이리스트 토글 버튼
- 하단 고정 글래스 버튼 (`ultraThinMaterial` 배경)
- 아이콘: `list.bullet` + "플레이리스트" 텍스트
- 탭 시 `withAnimation(.spring)` 으로 플레이리스트 섹션 슬라이드업
- 활성 시 버튼 색 변경 (main500)

### 5. 앨범 커버 애니메이션
- 재생 중: `scaleEffect(1.0)`, 일시정지: `scaleEffect(0.92)` — 부드럽게 전환

---

## 변경 파일
| 파일 | 내용 |
|------|------|
| `Features/Running/View/RunningView.swift` | `musicSheet` 전체 재설계 |
| `Features/Running/ViewModel/RunningMusicViewModel.swift` | `currentPlaybackTime`, `playbackDuration` 프로퍼티 추가 |

---

## 미구현 범위
- 가사 표시 (LyricsKit / MusicKit 별도 API 필요, 차후 기능)
- 이퀄라이저

---

## 완료 기준
- [ ] 재생 슬라이더 드래그로 원하는 위치 이동
- [ ] 경과/남은 시간 1초마다 갱신
- [ ] 음량 슬라이더로 시스템 음량 조절
- [ ] 플레이리스트 버튼 탭 시 애니메이션으로 나타남/사라짐
- [ ] 앨범 커버 재생/일시정지 시 크기 전환 애니메이션
