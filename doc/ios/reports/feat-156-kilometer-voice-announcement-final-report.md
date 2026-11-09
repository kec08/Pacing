# #156 1km 구간 음성 안내 최종 보고서

## 개요

러닝 중 1km 경계를 통과할 때마다 거리, 누적 시간, km당 평균 페이스를 한국어 음성으로 알려주는 기능을 추가했다. 러닝 화면을 보지 않아도 현재 진행 상태를 직관적으로 파악할 수 있도록 짧은 안내 문구와 이어폰 출력 정책을 적용했다.

## 변경 사항

- 기존 1km 랩 확정 시점에 음성 안내를 연결했다.
- 안내 문구를 `km → 시간 → km당 페이스` 순서로 통일했다.
  - 예: “2킬로미터. 10분 52초. 킬로미터당 페이스 5분 27초.”
- `LapVoiceAnnouncing` 프로토콜과 `LapVoiceAnnouncementService`를 분리해 ViewModel의 측정 로직과 음성 출력을 분리했다.
- 설치된 한국어 시스템 음성 중 Premium, Enhanced, 기본 순으로 가장 높은 품질을 자동 선택한다.
- 짧은 TTS 안내에 적합한 `AVAudioSession.Mode.voicePrompt`와 음악 ducking을 적용했다.
- 유선 이어폰·AirPods·Bluetooth 이어폰 등 iOS가 선택한 현재 오디오 출력 경로를 유지한다.
- pause/reset 시 진행 중인 음성 안내를 중지한다.

## 기술적 고려 사항

- ViewModel은 1km 경계와 지표 값만 전달하고, 음성 합성·오디오 세션은 전용 서비스가 담당한다.
- iOS 시스템 보이스의 품질은 기기 설정과 다운로드 상태에 따라 다르다. 앱은 Premium/Enhanced 보이스를 자동 설치할 수 없으며, 없을 때 기본 보이스로 안전하게 대체한다.
- Nike Run Club의 코치 음성은 사람 녹음 기반의 독점 콘텐츠이므로 포함하거나 복제하지 않는다.

## 검증

- [x] Debug iOS Simulator `PacingTests` 통과 (iPhone 16 Pro, iOS 26.0)
- [x] `km → 시간 → km당 페이스` 문구 생성과 유효하지 않은 지표 차단 테스트 통과
- [x] `git diff --check` 통과
- [ ] 실기기에서 기본/Premium 한국어 보이스의 청취성 확인
- [ ] Apple Music 재생 중 음성 안내, ducking, 안내 후 음악 복귀 확인
- [ ] 유선 이어폰·AirPods·Bluetooth 이어폰 출력 확인
- [ ] pause/resume과 다중 km 경계에서 안내 중복·누락 여부 확인

## 남은 이슈

실기기 오디오 라우팅과 설치된 보이스 품질은 Simulator로 검증할 수 없다. 특히 음악 재생, AirPods 연결, 시스템 볼륨 상태별 청취성을 실기기에서 확인해야 한다.

## 관련 이슈

Closes #156
