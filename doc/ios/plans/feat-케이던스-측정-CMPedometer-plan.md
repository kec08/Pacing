# 케이던스 실시간 측정 및 결과 표시 개발 계획

## 1. 문서 정보

- 작성일: 2026-08-28
- 상태: 개발 전 계획 검토 완료
- 관련 이슈: [#132](https://github.com/kec08/Pacing/issues/132)
- 작업 브랜치: `feat/132-cadence-cm-pedometer`
- 기준 브랜치: `dev`

## 2. 목표

러닝 중 케이던스를 실제 걸음 센서 데이터로 측정하고, 러닝 중 화면과 러닝 종료 결과·활동 상세 화면에서 동일한 기준으로 표시한다.

이번 작업에서는 GPS 이동거리나 심박수로 케이던스를 추정하지 않는다. 측정 장치가 값을 제공하지 않거나 권한·지원 조건을 만족하지 못하면 임의의 숫자를 표시하지 않고 `--`로 표시한다.

## 3. 현재 상태 및 문제

- `RunRecord.averageCadence` 모델 필드는 존재한다.
- 결과 화면과 상세 화면의 케이던스 영역은 현재 `--` 고정이다.
- 실시간 케이던스를 수집하는 Core Motion 저장소와 일시정지 구간을 제외한 평균 계산 로직은 없다.
- 기존 고도·심박수 처리와 같은 화면 표시 흐름을 유지하되, 케이던스 수집 책임은 별도 Repository로 분리한다.

## 4. 조사 결과 및 기술 기준

Apple Core Motion의 `CMPedometer`를 기준으로 구현한다.

- [`CMPedometer.startUpdates(from:withHandler:)`](https://developer.apple.com/documentation/coremotion/cmpedometer)는 현재 러닝 구간의 보행 데이터를 비동기로 전달한다.
- [`CMPedometerData.currentCadence`](https://developer.apple.com/documentation/coremotion/cmpedometerdata/currentcadence)는 초당 걸음 수(steps/sec)이며, 값이 아직 없거나 지원되지 않는 경우 `nil`일 수 있다.
- `currentCadence * 60`으로 steps/min 단위의 현재 케이던스를 계산한다.
- `CMPedometer.isCadenceAvailable()`와 `CMPedometer.authorizationStatus()`로 기기 지원 여부와 권한 상태를 확인한다.
- `NSMotionUsageDescription`을 Info.plist에 설정하고, 권한 거부·제한·미지원 기기에서는 값 대신 `--`을 사용한다.
- `stopUpdates()` 후 재시작할 때 일시정지 구간의 시간과 걸음 수가 평균에 섞이지 않도록 새 구간의 기준값을 재설정한다.

참고 공식 문서:

- [Apple Developer - CMPedometerData.currentCadence](https://developer.apple.com/documentation/coremotion/cmpedometerdata/currentcadence)
- [Apple Developer - CMPedometer](https://developer.apple.com/documentation/coremotion/cmpedometer)
- [Apple Developer - CMPedometer.isCadenceAvailable()](https://developer.apple.com/documentation/coremotion/cmpedometer/iscadenceavailable%28%29)

## 5. 정확도와 계산 정책

### 5.1 실시간 케이던스

- Core Motion의 `currentCadence`를 steps/sec에서 steps/min으로 변환한다.
- 화면 갱신 주기는 센서 콜백에 맞추되, View에서 별도 타이머로 값을 추정하지 않는다.
- `nil`, 음수, 비유한 값, 비정상적으로 큰 값은 유효하지 않은 샘플로 취급한다.

### 5.2 평균 케이던스

평균 케이던스는 유효한 구간의 총 걸음 수와 실제 활동 시간으로 계산한다.

```text
평균 케이던스(steps/min) = 유효 구간의 걸음 수 합계 / 유효 활동 시간(초) * 60
```

- 순간 케이던스 값들의 단순 평균을 사용하지 않는다.
- 일시정지 시간, 센서가 값을 제공하지 않은 구간, 비정상적으로 역행한 누적 걸음 수는 분모와 분자에서 제외한다.
- 현재 구간의 누적 걸음 수가 이전 샘플보다 작아지면 해당 구간을 무효화하고 기준값을 재설정한다.
- 유효 활동 시간 또는 유효 샘플이 없으면 `averageCadence = nil`로 저장하고 화면에는 `--`을 표시한다.
- 기존 기록에서 값이 없는 경우도 동일하게 `--`을 유지해 마이그레이션 오류를 방지한다.

## 6. 설계 및 작업 범위

### 6.1 Domain / Data

- `PedometerRepository` 프로토콜을 정의한다.
- `CoreMotionPedometerRepository`에서 `CMPedometer` 권한, 시작·중지, 콜백 변환을 담당한다.
- 순수 계산 가능한 `CadenceCalculator` 또는 기존 `RunMetricsCalculator` 확장을 추가한다.
- 센서 콜백과 계산기를 연결하는 측정 모델에는 샘플 시각, 누적 걸음 수, 현재 케이던스, 활동 구간 정보를 명시한다.

### 6.2 ViewModel

- 러닝 시작 시 케이던스 업데이트를 시작한다.
- 일시정지 시 업데이트를 중지하고, 재개 시 새 활동 구간으로 다시 시작한다.
- 러닝 종료 시 계산된 평균 케이던스를 `RunRecord.averageCadence`에 저장한다.
- 권한 거부·미지원·데이터 없음은 오류로 가장하지 않고 표시용 nil 상태로 전달한다.

### 6.3 View

- 러닝 중 화면의 케이던스 지표를 기존 6개 지표 흐름 안에서 독립적으로 표시한다.
- 결과 요약 화면과 활동 상세 화면에서 실제 평균 케이던스를 표시한다.
- 측정 불가 시 모든 화면에서 `--`을 사용하고, 기존 레이아웃이 흔들리지 않도록 단위와 자리 배치를 유지한다.
- 다크 모드와 작은 화면에서 숫자·단위가 겹치지 않는지 확인한다.

### 6.4 권한 및 설정

- `NSMotionUsageDescription` 문구를 앱의 권한 안내 정책에 맞게 추가한다.
- 기존 HealthKit 심박수 권한과 독립적으로 요청하고, 한쪽 권한 실패가 다른 지표를 막지 않도록 한다.

## 7. 테스트 및 QA 계획

### 단위 테스트

- 180걸음 / 60초가 180 steps/min으로 계산되는지 확인한다.
- 서로 다른 길이의 유효 구간은 총 걸음 수 / 총 활동 시간으로 계산되는지 확인한다.
- 일시정지 30초가 평균 시간에 포함되지 않는지 확인한다.
- `nil`, 음수, 비유한 값, 누적 걸음 수 역행을 제외하는지 확인한다.
- 유효 데이터가 없을 때 nil을 반환하는지 확인한다.
- 기존 기록의 nil 케이던스가 정상적으로 `--`으로 표시되는지 확인한다.

### 통합 및 수동 QA

- 권한 허용, 권한 거부, 기기 미지원 상태에서 시작·일시정지·재개·종료 흐름을 확인한다.
- 실제 보행 중 러닝 화면의 현재 케이던스가 갱신되는지 확인한다.
- 결과 화면과 상세 화면의 케이던스가 동일한 기록값인지 확인한다.
- 화면 전환·백그라운드·일시정지 후 재개 시 센서 업데이트가 중복 실행되지 않는지 확인한다.
- `xcodebuild build`, `build-for-testing` 및 관련 단위 테스트를 실행한다. 테스트 러너가 결과를 반환하지 않으면 성공으로 간주하지 않고 별도 보고한다.

## 8. 커밋 및 구현 순서

작은 의미 단위로 다음 순서의 커밋을 만든다.

1. 계획서와 이슈 연결 문서 추가
2. Core Motion 권한 및 Pedometer Repository 추가
3. 케이던스 계산기와 단위 테스트 추가
4. RunningViewModel 생명주기 연결
5. 러닝 중·결과·상세 화면 표시 연결
6. QA 수정 및 최종 보고서 작성

## 9. 완료 기준

- 실제 `CMPedometer` 데이터를 사용해 러닝 중 현재 케이던스를 표시한다.
- 평균 케이던스가 일시정지 시간을 제외한 유효 활동 시간 기준으로 계산된다.
- 결과 요약과 상세 화면에서 평균 케이던스를 확인할 수 있다.
- 측정 불가 상태에서 임의의 값이 아닌 `--`이 표시된다.
- 단위 테스트와 빌드 검증 결과, 남은 제한사항이 최종 보고서에 기록된다.

## 10. 예상 제한사항

- `CMPedometer` 케이던스 지원 여부는 기기와 iOS 상태에 따라 달라질 수 있다.
- 이 범위는 iPhone Core Motion 기반 측정이다. Apple Watch 전용 센서 데이터와의 직접 병합은 별도 조사·설계가 필요하다.
- 센서가 제공하지 않는 값을 보간하거나 GPS로 대체하지 않으므로 짧은 러닝 초기 구간 또는 기기 미지원 환경에서는 `--`이 표시될 수 있다.
