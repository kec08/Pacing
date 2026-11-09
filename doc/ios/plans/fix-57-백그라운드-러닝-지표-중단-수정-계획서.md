# fix #57 백그라운드 러닝 거리·페이스·칼로리 중단 수정 계획서

> **상태**: 개발자 검토 대기
> **작성일**: 2026-07-20
> **관련 이슈**: 생성 예정
> **대상 브랜치**: `dev` (PR #56 개인정보 처리방침 병합 커밋 `c8104db` 기준)
> **작업 브랜치**: 개발자 승인 후 생성

## 1. 목적

러닝을 시작한 뒤 홈으로 이동하거나 화면을 잠가 앱이 백그라운드 상태가 되어도, 시간뿐 아니라 **거리(km), 페이스, 칼로리 및 경로 좌표**가 계속 기록되도록 한다.

## 2. 현상과 확인된 원인

### 현상

- 백그라운드 전환 뒤 시간은 계속 증가한다.
- 거리, 페이스, 칼로리는 전환 시점 값에서 멈춘다.
- 앱을 다시 열면 이후 위치부터 다시 기록된다.

### 원인

시간은 `RunningViewModel`이 시작 시각(`runningStartedAt`)과 현재 시각의 차이로 계산한다. 따라서 화면의 `Timer` 이벤트가 늦거나 일시 중단되어도 다음 갱신 시 경과 시간이 보정된다.

반면 거리·페이스·칼로리는 `CLLocationManager`의 위치 콜백에 의존한다. 현재 `LocationManager.configureBackgroundLocationSupport()`는 아래처럼 `UIBackgroundModes`를 `[String]`으로만 읽는다.

```swift
let backgroundModes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] ?? []
```

확인 결과 프로젝트는 `GENERATE_INFOPLIST_FILE = YES`로 자동 plist를 생성하고 있었으며, `INFOPLIST_KEY_UIBackgroundModes` 빌드 설정의 배열 표기는 최종 앱 plist에 반영되지 않았다. 따라서 앱 번들에 `UIBackgroundModes` 자체가 없었고, `LocationManager`는 `location` 모드가 없다고 판단했다. 결과적으로 러닝 중에도 `allowsBackgroundLocationUpdates`가 `false`가 되어 iOS가 백그라운드 위치 이벤트를 지속 전달하지 않는다.

```text
백그라운드 전환
→ UIBackgroundModes 배열 판별 실패
→ allowsBackgroundLocationUpdates = false
→ 위치 콜백 중단
→ 거리 정지 → 페이스/칼로리(거리 파생값) 정지
```

## 3. 범위

### 포함

1. 자동 plist 생성을 중지하고 정적 `Info.plist`에 `UIBackgroundModes` 배열(`location`, `audio`)을 명시한다.
2. `LocationManager`의 background mode 판별을 문자열과 문자열 배열 모두 안전하게 처리하도록 보강한다.
3. 러닝 기록 중이고 위치 권한이 `Always`일 때만 `allowsBackgroundLocationUpdates`와 시스템 위치 표시기를 활성화한다.
4. 러닝 시작 시 위치 권한이 `Always`가 아니면 측정을 시작하지 않고, 권한 변경 안내 얼럿을 표시한다.
5. 얼럿의 `설정으로 이동` 동작으로 iOS 앱 설정 화면을 열어 사용자가 `항상 허용`으로 변경할 수 있게 한다.
6. 구성값 해석과 백그라운드 활성 조건을 단위 테스트로 검증한다.
7. 빌드된 앱의 실제 `Info.plist`와 실기기 백그라운드 동작을 QA한다.

### 제외

- 강제 종료(앱 전환 화면에서 위로 쓸어 종료) 후 자동 기록 재개: iOS 정책상 일반 위치 앱도 보장할 수 없음.
- HealthKit 칼로리 산정, Apple Watch 연동, 칼로리 공식 자체 변경.
- 지도 UI/종료 요약 UI의 디자인 변경.

## 4. 설계

### 책임 분리

| 계층 | 책임 | 변경 |
|---|---|---|
| Configuration | 빌드된 plist의 background mode 제공 | 정적 plist에 배열을 명시하고 산출물에서 검증 |
| LocationManager | 권한·러닝 상태·background mode에 따라 위치 추적을 허용 | mode 해석을 견고하게 하고 활성 조건 유지 |
| RunningViewModel | 위치 배치에서 거리 누적, 거리 기반 페이스·칼로리 계산 및 시작 가능 여부 제공 | 권한 미충족 시 측정을 시작하지 않음 |
| RunningView | 사용자 입력과 권한 안내 표현 | `항상 허용`이 아닐 때 설정 이동 얼럿 표시 |

### 데이터 흐름

```text
CLLocationManager didUpdateLocations
→ LocationManager.recentRecordedLocations
→ RunningViewModel.updateDistance
→ distance 갱신
→ avg/current pace 및 estimatedCalories 재계산
→ RunningView 수치 갱신
```

### 권한 안내 흐름

```text
사용자가 러닝 시작 탭
→ 현재 위치 권한 확인
→ Always: 러닝 시작
→ 앱 사용 중/거부/제한: 러닝 미시작
   → “백그라운드 러닝을 위해 위치를 ‘항상 허용’으로 변경해 주세요” 얼럿
   → [설정으로 이동] / [취소]
```

## 5. 세부 작업

- [x] Task 1 — 자동 plist 생성을 중지하고 정적 `Info.plist`에 `location`, `audio` 배열과 필수 앱 메타데이터를 명시한다.
- [x] Task 2 — `LocationManager`에 타입이 다른 plist 값도 정규화하는 작은 설정 해석 로직을 추가한다.
- [x] Task 3 — 시작 버튼에서 `Always` 권한을 검사하고, 미충족 시 설정 이동 얼럿을 표시한다.
- [x] Task 4 — `allowsBackgroundLocationUpdates` 활성 조건(러닝 중 + Always 권한 + location mode)과 시작 차단을 단위 테스트한다.
- [x] Task 5 — iOS Simulator Debug 빌드 후 산출물 `Info.plist`에서 `UIBackgroundModes`가 배열이며 `location`을 포함하는지 확인한다.
- [ ] Task 6 — 실기기에서 권한 안내, 앱 전환, 화면 잠금, 앱 복귀, 일시정지/재개를 QA하고 결과를 보고한다.
- [ ] Task 7 — QA 결과 및 알려진 제한사항을 최종 보고서에 기록한다.

## 6. 완료 기준

- [ ] Debug와 Release 모두 빌드된 plist의 `UIBackgroundModes`가 `location`, `audio` 배열이다.
- [ ] 러닝 중 Always 위치 권한이면 `allowsBackgroundLocationUpdates`가 활성화된다.
- [ ] 러닝 시작 시 위치 권한이 Always가 아니면 러닝이 시작되지 않고 권한 변경 얼럿이 표시된다.
- [ ] 얼럿의 `설정으로 이동`을 누르면 Pacing 앱 설정 화면이 열린다.
- [ ] 홈 이동·화면 잠금·다른 앱 전환 중 이동한 거리가 앱 복귀 후 누적되어 있다.
- [ ] 백그라운드 구간을 포함한 평균 페이스와 칼로리가 거리 증가에 맞춰 갱신된다.
- [ ] 일시정지 시에는 백그라운드 위치 기록이 중단되고, 재개 시 다시 시작된다.
- [ ] 단위 테스트 및 Debug 빌드가 성공한다.

## 7. QA 시나리오

| 시나리오 | 기대 결과 |
|---|---|
| 러닝 시작 후 홈으로 이동, 약 2~3분 이동 | 거리·경로·페이스·칼로리 증가 |
| 화면 잠금 후 이동 | 시스템 위치 표시가 나타나며 동일하게 증가 |
| 앱 복귀 | 백그라운드 이동 구간을 포함한 최신 수치와 경로 표시 |
| 일시정지 후 화면 잠금 | 시간·거리·페이스·칼로리 모두 고정 |
| 재개 후 화면 잠금 | 위치 수신 및 수치 증가 재개 |
| 위치 권한이 ‘앱 사용 중’인 경우 | 러닝 미시작, Always 권한 필요 얼럿 및 설정 이동 제공 |
| 위치 권한이 거부/제한인 경우 | 러닝 미시작, 설정 이동 제공 |

## 8. 리스크 및 결정 필요 사항

- iOS는 배터리 절약과 GPS 환경에 따라 위치 콜백을 배치 전달할 수 있다. 이 경우 수치는 매초가 아니라 위치 배치 도착 시 갱신되지만, 누락 없이 누적되어야 한다.
- 시스템 위치 사용 표시(상태바/블루 인디케이터)는 백그라운드 추적 중 정상이며 사용자 신뢰를 위해 유지한다.
- 실기기 QA에는 **설정 > 개인정보 보호 및 보안 > 위치 서비스 > Pacing > 항상** 권한이 필요하다.

---

## 9. 개발자 검토

**검토 결과**: 승인 ✅ / 수정 요청 🔄
**의견**:
