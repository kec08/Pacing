# fix #57 백그라운드 러닝 지표 중단 최종 개발 보고서

> **완료일**: 2026-07-20
> **관련 이슈**: [#57](https://github.com/kec08/Pacing/issues/57)
> **브랜치**: `codex/fix-57-background-run-metrics`
> **PR**: 생성 예정

## 개발 결과

러닝 앱이 백그라운드로 전환되면 시간만 증가하고 거리·페이스·칼로리·경로가 멈추던 문제를 수정했다.

실제 원인은 Xcode의 자동 plist 생성이었다. 프로젝트는 `GENERATE_INFOPLIST_FILE = YES` 상태에서 `UIBackgroundModes`를 빌드 설정으로 지정하고 있었지만, 최종 앱 번들에는 해당 키가 생성되지 않았다. iOS는 `location` background mode가 없는 앱에 백그라운드 위치 이벤트를 지속 전달하지 않으므로, 거리 기반 지표와 경로 좌표가 모두 중단됐다.

## 반영 사항

- 자동 plist 생성을 중지하고 정적 `Info.plist`를 앱의 단일 설정 원본으로 전환
- `UIBackgroundModes`에 `location`, `audio`를 배열로 명시
- `LocationManager`의 background mode 해석을 문자열 배열/단일 문자열 모두 지원하도록 보강
- 러닝 시작 전 `Always` 위치 권한 확인
  - 미충족 시 러닝 시작 차단
  - `설정으로 이동`이 포함된 안내 얼럿 제공
- background mode 및 권한 활성 조건 단위 테스트 추가

## 기대 동작

`항상 허용` 권한으로 러닝을 시작하면 홈 이동, 화면 잠금, 다른 앱 전환 상태에서도 위치 배치가 계속 수신된다.
수신된 좌표는 기존 `LocationManager → RunningViewModel → RunningView` 흐름으로 전달되므로 거리, 경로 선, 페이스, 칼로리가 함께 갱신된다.

## 검증 결과

| 검증 항목 | 결과 |
|---|---|
| `Info.plist` 형식 검사 | 통과 |
| 빌드된 Simulator 앱의 `UIBackgroundModes` | `location`, `audio` 배열 포함 확인 |
| iPhone 17 Pro Simulator 테스트 | 5개 성공, 실패 0개 |
| 위치 모드/권한 조건 단위 테스트 | 통과 |
| 실기기 화면 잠금·앱 전환 GPS QA | 대기 |

## 검토 결과

- 코드 책임은 Configuration(`Info.plist`), 위치 추적(`LocationManager`), 시작 UX(`RunningView`), 측정 상태(`RunningViewModel`)로 분리되어 있다.
- 경로 렌더링과 거리·페이스·칼로리 계산식은 변경하지 않아 기존 측정 로직의 영향 범위를 최소화했다.
- 실기기 QA는 GPS·권한·화면 잠금 상태가 필요한 운영체제 동작이므로 PR 병합 전 반드시 확인해야 한다.

## 실기기 QA 체크리스트

- [ ] 위치 권한 `항상 허용` 상태에서 2~3분 백그라운드 이동 후 거리·경로·페이스·칼로리 증가 확인
- [ ] 앱 복귀 후 백그라운드 이동 구간의 경로 선 연속 표시 확인
- [ ] `앱 사용 중` 권한에서 시작 버튼을 누르면 설정 이동 얼럿 표시 확인
- [ ] 일시정지 시 측정 중단, 재개 후 측정 재시작 확인

## 알려진 제한

- 앱을 강제 종료하면 iOS 정책상 백그라운드 위치 기록을 보장할 수 없다.
- GPS 신호 및 iOS 전력 정책에 따라 위치 업데이트가 묶여 도착할 수 있으며, 이 경우 UI 갱신은 약간 늦을 수 있다.
