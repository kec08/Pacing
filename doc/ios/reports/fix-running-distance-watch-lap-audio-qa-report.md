# 러닝 거리·워치 1km 알림·음성 안내 오디오 수정 보고서

## 상태

거리·랩·오디오 수정 완료 · iOS/Watch 테스트 타깃 빌드 통과 · 실기기 QA 대기

## 관련 작업

- 선행 이슈: [#213 러닝 종료 화면·활동 상세 평균 페이스 정합성](https://github.com/kec08/Pacing/issues/213)
- 관련 GitHub 이슈: [#222](https://github.com/kec08/Pacing/issues/222) (MeloTTS 통합은 별도 작업)
- 로컬 이슈 초안: `doc/ios/issues/draft-running-distance-watch-lap-audio.md`
- 브랜치: `fix/running-distance-lap-audio-consistency` (`origin/dev` 기준)
- PR: dev 대상, 실기기 QA 미완료를 명시해 생성

## 조사 결과

2026-10-23 추가 사례: 사용자는 10km를 달렸으나 2026-10-13 Pacing 활동 상세에는 4.70km/54:51/5'15"로 저장됐습니다. 기록의 거리와 시간으로 계산한 값도 5'15"와 맞지 않습니다. 해당 화면은 이번 브랜치의 미커밋 수정이 실기기에 설치되기 전에 생성된 기록이며, 기존 앱 코드에서 누락이 계속 발생한다는 증거입니다.

새 첨부 화면은 Pacing 6.47km/54:02/4'40", Apple 운동 10.00km/52:02/5'12"입니다. Pacing의 거리와 시간으로 계산한 평균은 약 8'21"/km이므로 4'40"은 같은 수치를 기준으로 하지 않습니다. 원인 후보는 이전 버전이 GPS 필터 통과 구간 시간만 평균 페이스에 반영한 점, 그리고 Watch HealthKit 거리를 iPhone 실시간/저장 기록에 연결하지 않은 점입니다.

Pacing의 iPhone GPS 누적은 Core Location 샘플 간 이동거리 기준입니다. 이전 최소 이동거리 기준은 수평 정확도 20–30m일 때 최대 10–12m였고, 앱은 약 5m 단위로 위치를 받도록 설정돼 있었습니다. 이런 샘플이 거절될 때마다 기준점도 이동해 이후 거리까지 잃을 수 있었습니다. km 안내도 같은 누적거리 경계에 의존했습니다.

기존 Watch 운동 저장소는 거리 통계의 `mostRecentQuantity()`를 읽고 있었습니다. 이는 최신 샘플 하나이며 전체 누적거리가 아니므로, Watch 화면에서 전체 거리가 줄어들거나 부정확할 수 있었습니다. 누적합인 `sumQuantity()`를 우선 사용하도록 바꿨습니다.

## 변경 사항

- GPS 정확도에 따라 요구하던 최소 이동거리를 기존 최대 12m에서 1.5–3m로 낮췄습니다.
- 유효하지 않은 위치는 다음 기준 위치로 옮기지 않게 해, 후속 유효 샘플까지의 실제 거리가 누락되지 않도록 했습니다. 속도가 정지/보행 노이즈 범위인 위치는 기준점만 갱신해 정지 중 GPS 흔들림 누적을 방지합니다.
- 위치 배치가 여러 km 경계를 한 번에 넘더라도 각 경계별 안내를 호출하도록 했습니다. 랩 페이스를 계산할 이동시간이 없는 경계는 페이스 목록에는 넣지 않고 음성 안내는 전달합니다.
- Watch 실시간 거리 통계는 HealthKit 누적 합계를 사용합니다.
- 연결된 Watch 운동 중 HealthKit 누적거리/운동시간을 WatchConnectivity로 iPhone에 보내고, iPhone 거리·랩·저장값이 그 기준을 사용합니다. 종료값은 최신 application context와 전송 큐에도 보냅니다.
- Watch HealthKit 거리로 전환한 뒤에도 GPS 경로/고도는 계속 수집하지만 GPS 필터 결과로 공식 거리를 덮어쓰지 않습니다. 평균 페이스 입력은 운동 경과시간/최종 거리로 맞췄습니다.
- Watch 거리 수신이 시작된 뒤에도 iPhone GPS를 계속 누적합니다. Watch 최신 값이 15초 넘게 오지 않으면 마지막 확정 거리와 GPS 누적 중 큰 값으로 이어 기록하고, Watch가 다시 연결되면 HealthKit 누적값을 사용합니다.
- 음성 안내 전후 음악을 pause/resume하던 코드를 제거했습니다. `.voicePrompt`, `.duckOthers`, `.interruptSpokenAudioAndMixWithOthers` 오디오 세션으로 안내 중 음악을 계속 재생하며 ducking하도록 구성하고 기존 세션 설정 복구를 유지했습니다.
- 저정확도 GPS의 짧은 정상 이동과 단일 배치의 복수 km 경계를 확인하는 회귀 테스트를 추가했습니다.

## 검증 결과

| 항목 | 결과 |
| --- | --- |
| 변경 Swift 파일 구문 파싱 (`swiftc -frontend -parse`) | ✅ 통과 |
| `git diff --check` | ✅ 통과 |
| iOS/Watch `build-for-testing` | ✅ 통과 (2026-10-23, 최신 dev 기준, 테스트 타깃 컴파일 포함) |
| 단위 테스트 실행 | ⚠️ iOS 26 Simulator 51개 중 44개 통과·7개 실패. 신규 테스트 입력 오류 1개를 수정한 뒤 변경 관련 테스트 6개 모두 통과. 나머지 6개는 고도 계산 테스트이며 이번 PR 범위 밖; 별도 검토 필요 |
| 의존성 다운로드 | ✅ 고정된 Swift Package 의존성을 내려받은 후 빌드 성공 |
| 실기기 GPS/HealthKit/음악 ducking | ⏳ 개발자 실기기 QA 필요 |

Apple의 `voicePrompt` 안내는 TTS 앱이 `.duckOthers`와 `.interruptSpokenAudioAndMixWithOthers`를 함께 사용하는 패턴을 안내합니다. [Apple voicePrompt 문서](https://developer.apple.com/documentation/avfaudio/avaudiosession/mode-swift.struct/voiceprompt?language=objc), [Apple duckOthers 문서](https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/duckothers)

## 실기기 QA 체크리스트

- [ ] iPhone과 페어링한 Apple Watch에서 5km 이상 러닝을 진행한다.
- [ ] Pacing 기록 거리와 Apple 운동 거리를 비교한다. 같은 시작/종료 시각 및 일시정지 여부를 맞춰 확인한다.
- [ ] 1km, 2km, 3km 경계에서 음성 안내가 각 한 번씩 나오는지 확인한다.
- [ ] 러닝 중 화면 잠금/앱 백그라운드 복귀 뒤 거리와 안내가 계속 이어지는지 확인한다.
- [ ] Apple Music 앱 플레이어와 Pacing 앱 플레이어 경로에서 안내 중 곡이 멈추지 않는지 확인한다.
- [ ] 안내 음성이 나올 때 음악이 낮아지고 안내 종료 후 원래 음량으로 돌아오는지 이어폰/Watch 연결 경로별 확인한다.
- [ ] 일시정지·재개와 종료 직전의 거리/페이스가 활동 상세 저장값과 일치하는지 확인한다.

## 제한 및 후속 조치

- 실기기 GPS·HealthKit 거리, 1km 안내, 음악 덕킹은 개발자 QA가 필요하다. 10km 기록 누락이 실기기에서 해결됐다고 아직 단정할 수 없다.
- MeloTTS 오프라인 통합은 이 PR 범위에서 제외하고 별도 브랜치에서 진행한다. 현재 음성은 `AVSpeechSynthesizer`를 사용한다.
