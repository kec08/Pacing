# 활동 상세 경로 지도·구간 표 개편 최종 보고서

## 상태

개발 완료 · 시뮬레이터 빌드와 새 단위 테스트 통과 · 실기기 QA 대기

## 관련 작업

- GitHub 이슈: [#236](https://github.com/kec08/Pacing/issues/236)
- 계획서: `doc/ios/plans/feat-236-activity-detail-route-split-redesign-plan.md`
- 이슈 문서: `doc/ios/issues/issue-236-activity-detail-route-split-redesign.md`
- 브랜치: `feat/236-activity-detail-redesign` (`dev` 기준)

## 변경 사항

| 파일 | 내용 |
|------|------|
| `Models/RunRecord.swift` | `RunLapPace.averageHeartRate`, `RunWeatherSnapshot`, `RunRecord.locationName`·`weather` 추가 |
| `Core/Firebase/FirestoreService.swift` | 구간 심박수·위치·날씨 저장·조회. 값이 없으면 키를 쓰지 않아 기존 기록과 호환 |
| `Features/Running/ViewModel/RunningViewModel.swift` | 랩 벽시계 범위 기록, 종료 뒤 `RunLapHeartRateResolver`로 구간 심박수 조회, 저장 때 위치·날씨 조회(각 5초 제한) |
| `Core/Location/RunPlaceNameResolver.swift` | 출발 좌표 → `남양주시, 대한민국` 형식 이름 |
| `Core/Weather/RunWeatherRepository.swift` | WeatherKit 현재 날씨, `AsyncTimeout` |
| `Core/Location/RunRouteKilometerMarkers.swift` | 누적 거리 보간으로 km 라벨 좌표 계산 |
| `Features/Running/View/RunActivityDetailView.swift` | 세로형 지도, 원형 핀, km 캡슐, 위치·날씨 카드, 구간 표 |
| `Pacing.entitlements` | WeatherKit entitlement |
| `PacingTests/RunActivityDetailRedesignTests.swift` | km 라벨 위치·비율·간격, 막대 너비, 구간 심박수 조회 테스트 5개 |

## 검증

- `xcodebuild build-for-testing` (iPhone 17 Pro 시뮬레이터, iOS 27.0): 성공
- `RunActivityDetailRedesignTests` 5개: 모두 통과
- 시뮬레이터 화면 확인: 10.05km 왕복 샘플 기록(구간 심박수·남양주·0° 포함)을 임시 진입점으로 띄워 다크 모드에서 확인했다. 임시 코드는 커밋하지 않았다.
  - 세로형 지도에 경로 전체가 들어오고, 출발·도착 원 핀이 나란히 보인다.
  - km 캡슐이 경로 위에 놓이고, 왕복 구간에서 겹친 라벨은 MapKit이 일부를 숨긴다.
  - 오른쪽 위 위치 카드, 오른쪽 아래 `0°`·달 아이콘 카드, 지도 아래 날씨 출처 링크가 보인다.
  - 구간 표에서 가장 빠른 1km(4'58") 막대가 가장 길고 심박수 열이 보인다.
- 실행하지 않은 것: 전체 테스트 스위트, 라이트 모드 확인, 실제 러닝으로 저장 경로 확인

## 실기기 QA 체크리스트

- [ ] Apple Developer에서 App ID(`com.eunchan.Pacing`)에 WeatherKit capability가 켜져 있는지 확인(자동 서명이 켜 주지 않으면 직접 켠다)
- [ ] Apple Watch를 차고 2km 이상 달린 뒤 저장 → 활동 상세에 구간 심박수가 표시
- [ ] 새 기록에 위치 카드(시·구, 대한민국)와 날씨 카드가 표시
- [ ] 기존 기록에서 위치·날씨 카드가 숨겨지고 심박수가 `--`
- [ ] 편도 코스에서 출발·도착 핀이 따로, 왕복 코스에서 나란히 표시
- [ ] 라이트 모드에서 막대·카드 대비 확인
- [ ] 친구 기록 상세에서도 같은 화면이 깨지지 않는지 확인
