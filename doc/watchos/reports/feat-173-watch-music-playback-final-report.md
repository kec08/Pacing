# feat #173 Watch 음악 탭 및 러닝 중 재생 제어 최종 개발 보고서

> **완료일**: 2026-09-22
> **관련 이슈**: [#173](https://github.com/kec08/Pacing/issues/173)
> **브랜치**: `feat/173-watch-music-playback`
> **PR**: [#174](https://github.com/kec08/Pacing/pull/174)

## 구현 요약

iPhone의 MusicKit 재생 상태를 WatchConnectivity로 전달하는 Repository 경로를 추가했습니다. Watch 첫 번째 탭은 최근 재생 목록을 표시하고 선택한 곡의 iPhone 재생을 요청합니다. 러닝 중 세 번째 탭은 시간·앨범 아트·곡 정보·이전/재생·일시정지/다음 제어만 표시하며, 앨범 아트를 탭하면 제어가 부드럽게 사라지고 아트가 확장됩니다.

## 변경 사항

- Watch `WatchMusicPlaybackRepository` 프로토콜 및 iPhone 동기화 구현
- iPhone의 현재 MusicKit 상태·최근 재생 이력을 Watch 스냅샷으로 발행
- Watch 명령을 iPhone의 기존 MusicKit 큐 제어에 연결
- 최근 재생 목록·빈 상태·접근성 레이블 구현
- 러닝 중 음악 화면의 앨범 아트 확장 전환과 Reduce Motion 대응

## 검증

- [x] Watch Simulator Debug 빌드 통과 (`CODE_SIGNING_ALLOWED=NO`)
- [x] `git diff --check` 통과
- [ ] iPhone Debug 빌드: 기존 프로젝트가 Watch 소스를 iOS 타깃에도 포함해 `WatchKit` 모듈을 찾지 못하는 구성 문제로 중단
- [x] 실기기 iPhone·Apple Watch에서 현재 곡 정보와 이전·재생/일시정지·다음 제어 동작 확인
- [x] 실기기 Watch에서 최근 재생 목록의 곡 선택 재생 동작 확인
- [ ] 실기기 앨범아트 표시: 미표시 현상 확인, [#180](https://github.com/kec08/Pacing/issues/180)으로 분리

## 남은 이슈

- 실제 Apple Music의 전체 최근 재생 이력 API는 권한·구독·카탈로그 상태에 영향을 받습니다. 이번 구현은 앱이 관찰한 재생 이력을 Watch에 전달합니다.
- Watch 독립 MusicKit 제어는 Repository의 별도 구현으로 후속 확장합니다.
- 현재 재생 곡과 최근 재생 목록의 앨범아트가 Watch에 표시되지 않는 실기기 문제는 [#180](https://github.com/kec08/Pacing/issues/180)에서 iPhone 이미지 데이터 전송·WatchConnectivity payload·Watch 디코딩 경로를 분리해 해결합니다.
