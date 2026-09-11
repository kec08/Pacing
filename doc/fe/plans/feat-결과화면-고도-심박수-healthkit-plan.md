# 결과 화면 고도·심박수 표시 및 HealthKit 연동 계획서

> **상태**: 검토 대기
> **작성일**: 2026-08-28
> **기준 브랜치**: `dev`
> **GitHub 이슈**: [#130](https://github.com/kec08/Pacing/issues/130)
> **작업 브랜치**: `feat/130-healthkit-heart-rate`
> **관련 이전 PR**: [#129](https://github.com/kec08/Pacing/pull/129) — 머지 완료

## 1. 목적

현재 러닝 종료 결과 화면에는 거리·시간·평균 페이스·칼로리만 표시되고 고도 상승과 BPM이 표시되지 않는다. 이번 작업에서는 고도와 심박수를 실제 측정 데이터에 연결해 결과 화면과 활동 상세 화면에서 6개 지표를 모두 확인할 수 있도록 한다.

측정할 수 없는 값을 추정하거나 0으로 대체하지 않는다. 유효한 센서 데이터가 없으면 해당 지표를 `--`로 표시한다.

## 2. 조사 결과 및 기술 결정

### 2.1 고도 상승

- 위치 샘플의 `CLLocation.altitude`와 `verticalAccuracy`를 사용한다.
- `verticalAccuracy <= 0`, 허용 정확도 초과, 유한하지 않은 고도는 계산에서 제외한다.
- 연속 유효 샘플의 양의 변화만 누적하되 작은 변화는 GPS 고도 노이즈로 간주해 제외한다.
- 표시값은 마지막 고도와 시작 고도의 차이가 아닌 누적 상승 고도(`elevation gain`)다.
- 유효 샘플이 부족하면 `--`를 표시한다.
- 고도 원본 샘플은 러닝 시작부터 종료까지 보존하고, pause 구간에서 새 샘플을 거리 계산에 반영하지 않는다.

### 2.2 Apple Watch 심박수

- HealthKit의 `HKQuantityTypeIdentifier.heartRate` 읽기 권한을 요청한다.
- 러닝 시작·종료 시간 범위의 `HKQuantitySample`만 조회한다.
- BPM 단위로 변환하고, 30~240 BPM 범위의 유효 샘플만 평균한다.
- Apple Watch로 식별 가능한 샘플을 우선 사용한다. Watch 샘플이 식별되지 않는 테스트 환경에서는 HealthKit의 유효 심박수 샘플을 fallback으로 사용한다.
- 권한 거부, HealthKit 미지원 기기, Apple Watch 미연결, 샘플 없음, 조회 오류는 모두 `nil` 상태로 처리하고 화면에 `--`를 표시한다.
- 심박수를 페이스·칼로리·나이로 추정하지 않는다.
- 결과 화면 조회 시점이 아니라 해당 러닝 시간대의 샘플만 사용해 기록과 측정 시점을 일치시킨다.

### 2.3 저장 호환성

- `RunRecord`에 `elevationGainMeters`, `averageHeartRate`, `averageCadence` optional 필드를 추가한다.
- Firestore 저장 시 값이 있을 때만 필드를 기록한다.
- 기존 Firestore 기록에 새 필드가 없어도 조회가 실패하지 않도록 `nil` fallback을 사용한다.
- 이번 범위에서 케이던스의 실제 센서 연동은 포함하지 않으며, 기존 `--` 정책을 유지한다.

## 3. 아키텍처 및 책임

```text
LocationManager
  └─ 유효 CLLocation 샘플·고도 보존

HealthKitHeartRateRepository
  └─ 권한 요청·러닝 시간 범위 심박수 조회

RunMetricsCalculator
  └─ 누적 상승 고도·표시용 지표 계산

RunningViewModel
  └─ 종료 시 센서 데이터 취합·RunRecord 생성

RunSummaryView / RunActivityDetailView
  └─ 6개 지표 표시, nil은 --

FirestoreService
  └─ 신규 optional 필드 저장·기존 기록 호환 조회
```

View에는 센서 조회나 계산 로직을 넣지 않고 ViewModel과 Repository를 통해 전달한다.

## 4. 작업 순서

1. 결과 화면·활동 상세·`RunRecord`·Firestore 현재 흐름 재점검
2. 계획 승인 후 GitHub 이슈 생성
3. `dev` 최신 기준으로 `feat<이슈번호>` 브랜치 분기
4. HealthKit capability 및 `NSHealthShareUsageDescription` 설정
5. `HealthKitHeartRateRepository` 구현 및 권한/샘플 없음 상태 처리
6. 위치 고도 샘플 보존 및 고도 상승 계산 연결
7. `RunningViewModel` 종료 흐름에 고도·심박수 취합 연결
8. `RunRecord`·Firestore 저장/조회 확장
9. 결과 화면·활동 상세 화면에 6개 지표 표시
10. 단위 테스트·빌드·시뮬레이터 QA·실기기 Apple Watch QA
11. 최종 보고서 작성 후 PR 생성

## 5. 화면 요구사항

### 결과 화면

- 기존 거리 대형 표시와 시간·평균 페이스·칼로리 구조를 유지한다.
- 추가 지표 영역에 고도 상승과 평균 BPM을 포함해 총 6개 지표를 표시한다.
- 고도 예: `18 m`, 심박수 예: `179 BPM`.
- 측정 불가 시 `--`를 표시한다.
- 다크 모드에서는 기존 디자인 시스템 색상을 사용한다.

### 활동 상세 화면

- 결과 화면과 동일한 계산·표시 정책을 사용한다.
- 기존 기록에 신규 필드가 없으면 고도와 BPM을 `--`로 표시한다.
- 기존 경로·구간별 페이스·출발/도착 표시는 유지한다.

## 6. 테스트 계획

### 단위 테스트

- 유효 수직 정확도 샘플만 고도 계산에 포함되는지 확인
- 작은 고도 노이즈가 상승 고도에 포함되지 않는지 확인
- 유효 샘플 부족 시 `nil`인지 확인
- 심박수 유효 범위 밖 샘플 제외
- 심박수 샘플 없음·권한 거부 시 `nil`인지 확인
- 기존 `RunRecord` 생성 호출이 신규 optional 필드 없이도 컴파일되는지 확인

### 실기기 QA

- iPhone 위치 권한 허용·거부
- HealthKit 읽기 권한 허용·거부
- Apple Watch 운동 기록이 있는 경우 시간 범위 평균 BPM 표시
- Apple Watch 미연결 또는 해당 시간대 심박수 없음 시 `--` 표시
- 고도 정확도 불량 환경에서 값이 과장되지 않는지 확인
- pause/resume 후 러닝 종료 결과가 정상 표시되는지 확인
- 라이트/다크 모드 및 작은 화면에서 6개 지표가 겹치지 않는지 확인

## 7. 완료 기준

- [ ] 결과 화면에서 거리·시간·평균 페이스·칼로리·고도 상승·BPM을 모두 확인할 수 있다.
- [ ] 고도는 유효한 `verticalAccuracy` 샘플만 사용한다.
- [ ] 심박수는 HealthKit Apple Watch 샘플을 러닝 시간 범위에서 조회한다.
- [ ] 센서·권한·샘플이 없을 때 해당 값만 `--`로 표시한다.
- [ ] 임의 추정값으로 고도·심박수를 채우지 않는다.
- [ ] `RunRecord`와 Firestore 신규 필드가 기존 기록을 깨뜨리지 않는다.
- [ ] 활동 상세 화면도 결과 화면과 동일한 지표 정책을 사용한다.
- [ ] 단위 테스트와 Debug 빌드가 통과한다.
- [ ] Apple Watch가 연결된 iPhone 실기기에서 심박수 표시를 확인한다.

## 8. 리스크 및 제한사항

- 시뮬레이터에서는 Apple Watch 심박수 측정을 검증할 수 없다.
- HealthKit 읽기 권한 상태는 앱에서 직접 값이 없다고 단정할 수 없으므로, 실제 조회 결과를 함께 확인한다.
- Apple Watch의 운동 기록이 아직 HealthKit에 저장되지 않은 러닝 직후에는 해당 결과 화면에서 BPM이 `--`일 수 있다.
- 고도는 GPS 및 기압 센서 품질에 영향을 받으므로 수직 정확도 검증과 노이즈 제거를 적용해도 물리적 측정 오차를 완전히 제거할 수는 없다.
- 케이던스 실제 연동과 WeatherKit은 이번 작업에서 제외한다.

## 9. 참고 자료

- [Apple Developer — HKQuantityTypeIdentifier](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier)
- [Apple Developer — HKQuantitySample](https://developer.apple.com/documentation/healthkit/hkquantitysample)
- [Apple Developer — HKSample](https://developer.apple.com/documentation/healthkit/hksample)
- [Apple Developer — Authorizing access to health data](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data)
- [Apple Developer — Executing statistics collection queries](https://developer.apple.com/documentation/healthkit/executing-statistics-collection-queries)
- [Apple Developer — CLLocation altitude](https://developer.apple.com/documentation/corelocation/cllocation/altitude)

> **검토 요청**: 계획 승인 후 이슈 생성과 `feat<이슈번호>` 브랜치 분기를 진행한다.
