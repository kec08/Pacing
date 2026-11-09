# issue-09 음악 플레이어 재생 시간·음량 조절 미지원

## 증상
- 음악 시트에 재생 진행 슬라이더가 없어 현재 재생 위치 확인 및 이동 불가
- 시스템 음량 조절 UI가 없어 앱 내에서 볼륨 변경 불가
- 플레이리스트 목록이 항상 노출되어 플레이어 공간이 좁음

## 원인
- `musicSheet`에 `Slider` 및 `MPVolumeView` 미구현
- `RunningMusicViewModel`에 `currentPlaybackTime` / `playbackDuration` 프로퍼티 없음

## 해결 방향
- `TimelineView(.periodic(from:by:1))` 로 1초마다 재생 시간 갱신
- `MPMusicPlayerController.systemMusicPlayer.currentPlaybackTime` 읽기/쓰기
- `MPVolumeView` → `UIViewRepresentable` 래핑으로 시스템 음량 슬라이더 제공
- 플레이리스트는 하단 글래스 버튼으로 토글

## 관련 feat
feat #11 음악 플레이어 UI 개선
