# feat #11 음악 플레이어 UI 개선 최종 보고서

## 작업 요약
음악 시트를 Apple Music 스타일로 재설계 — 재생 시간 스크러버, 음량 조절, 플레이리스트 토글 버튼 추가

---

## 구현 내용

### 1. 재생 시간 스크러버 (RunningView + RunningMusicViewModel)
- `RunningMusicViewModel`에 재생 시간 접근 추가
  - `currentPlaybackTime` / `playbackDuration` 계산 프로퍼티
  - `seek(to:)` — 드래그 종료 시 해당 위치로 이동 (0 ~ duration 클램프)
- `TimelineView(.periodic(from:.now, by:0.5))`로 0.5초마다 진행률 갱신
- `Slider` 드래그 중에는 `isSeeking`/`seekValue`로 임시 표시, 손 뗄 때(`onEditingChanged(false)`) 실제 seek
- 경과 시간(`2:08`) / 남은 시간(`-1:09`) 표시 (`formatPlaybackTime`)

### 2. 음량 조절 슬라이더
- `MPVolumeView`를 `UIViewRepresentable`(`VolumeSliderView`)로 래핑
- 트랙 컬러 `main500` 적용, 커스텀 thumb(16pt 흰 원 + 그림자)로 교체
- 좌 🔈 / 우 🔊 아이콘, 아이콘 대비 바 정렬 `offset(y:5)` 미세 조정

### 3. 플레이리스트 토글 버튼
- 하단 고정 글래스 버튼(`ultraThinMaterial`) — `music.note.list` + "플레이리스트"
- 탭 시 `withAnimation(.spring)`으로 플레이리스트 섹션 슬라이드업
- 활성 시 main500 텍스트 + 핑크 테두리
- 카드 탭 시 해당 플레이리스트 재생 + 목록 자동 닫힘
- 완료 버튼 시 시트 닫힘 + 플레이리스트 상태 초기화

### 4. 앨범 커버 애니메이션
- 260×260 대형 표시
- 재생 중 `scale(1.0)` / 일시정지 `scale(0.88)` + 그림자 변화, spring 전환

---

## 버그 수정

| 버그 | 원인 | 해결 |
|------|------|------|
| 곡 넘김 후 스크러버가 이전 드래그 위치로 남음 | 곡 변경 시 `isSeeking`/`seekValue` 미초기화 | `.onChange(of: currentSong?.id)`에서 리셋 |
| 음량 thumb과 트랙 세로 정렬 어긋남 | MPVolumeView 기본 thumb 위치 | 커스텀 thumb + `offset(y:5)` |

---

## 변경 파일
| 파일 | 변경 내용 |
|------|----------|
| `Features/Running/View/RunningView.swift` | `musicSheet` 전체 재설계, `VolumeSliderView` 추가 |
| `Features/Running/ViewModel/RunningMusicViewModel.swift` | `currentPlaybackTime`, `playbackDuration`, `seek(to:)` 추가 |

---

## 이슈
- [issue-09] 음악 플레이어 재생 시간·음량 조절 미지원

---

## QA 결과
| 항목 | 결과 |
|------|------|
| 앨범 커버 대형 표시 + 재생/일시정지 scale 애니메이션 | ✅ |
| 스크러버 0.5초마다 자동 갱신 | ✅ |
| 스크러버 드래그로 위치 이동 | ✅ |
| 경과/남은 시간 표시 | ✅ |
| 곡 넘김 시 스크러버 초기화 | ✅ |
| 음량 슬라이더로 시스템 음량 조절 | ✅ |
| 음량 바·아이콘 정렬 | ✅ |
| 플레이리스트 버튼 토글 애니메이션 | ✅ |
| 활성 시 핑크 테두리 | ✅ |
| 카드 탭 시 재생 + 목록 닫힘 | ✅ |
| 완료 시 상태 초기화 | ✅ |

---

## 미구현 범위
- 가사 표시 (MusicKit 별도 API 필요, 차후 기능)
- 이퀄라이저
