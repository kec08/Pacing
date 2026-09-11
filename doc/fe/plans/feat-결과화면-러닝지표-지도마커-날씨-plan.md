# 결과 화면 러닝 지표·지도 마커·날씨 개선 계획서

> **상태**: 검토 대기
> **작성일**: 2026-08-26
> **관련 이슈**: [#127](https://github.com/kec08/Pacing/issues/127)
> **브랜치**: `feat/127-run-result-metrics`
> **참고 이미지**: 제공된 결과 화면 1·2 및 Nike Run Club 스타일 지도 3

## 1. 목적 및 배경

현재 러닝 결과 화면은 거리·시간·평균 페이스·칼로리와 경로만 표시한다. 결과 화면을 다음 방향으로 개선한다.

- 결과 상단에 고도 상승, 평균 심박수, 평균 케이던스를 Nike Run Club과 유사한 정보 위계로 추가한다.
- 경로 지도에 실제 누적 거리 기준 1km 지점을 표시한다.
- 지도 오른쪽 아래에 오늘 날씨와 날씨 상태 아이콘·온도를 표시한다.
- 숫자 표시를 먼저 추가하지 않고, 거리·시간·일시정지·GPS 이상값·권한 부재를 포함한 측정 파이프라인을 정리해 결과값이 서로 모순되지 않도록 한다.

현재 코드 확인 결과 `RunRecord`에는 거리, 시간, 평균 페이스, 경로 좌표, km 랩 페이스만 있고, `LocationManager`는 위치의 수평 정확도와 최소 이동 거리만 검증한다. 심박수·고도·케이던스·날씨 저장 및 조회 계층은 아직 없다.

## 2. 조사 결과 및 기술 결정

### 2.1 거리·페이스

- 거리의 기준은 현재처럼 GPS 좌표 간 거리가 아니라, 검증을 통과한 위치 샘플의 누적 거리로 단일화한다.
- 위치 샘플은 `horizontalAccuracy`, timestamp, 이동 속도, 비정상적으로 큰 점프를 검증한 뒤 누적한다.
- `pause` 구간은 거리·시간·랩·케이던스·심박수 집계에서 제외한다. 재개 직후 첫 위치는 기준점으로만 사용해 재개 점프를 방지한다.
- 평균 페이스는 `유효 활동 시간(초) / 유효 거리(km)`로 계산하고, 표시용 랩 페이스와 혼용하지 않는다.
- 1km 마커는 저장된 원본 좌표의 인덱스가 아니라 누적 유효 거리의 1,000m 경계를 선분 내 보간해 생성한다. 한 위치 업데이트가 여러 km 경계를 넘는 경우 모든 경계를 생성한다.

### 2.2 고도 상승

- `CLLocation.altitude`는 평균 해수면 기준 고도이며 `verticalAccuracy`가 양수일 때만 유효하다. 따라서 수직 정확도 미확인 값은 계산에서 제외한다.
- 연속 샘플의 고도 차이를 그대로 더하지 않는다. GPS 고도 노이즈로 인한 하강·상승 반복을 줄이기 위해 정확도 한계, 최소 상승 임계값, 비정상 점프 제거 및 짧은 이동 평균/완화 규칙을 적용한다.
- 표시값은 누적 상승 고도(`elevation gain`)이며, 순고도 차이(`마지막 고도 - 시작 고도`)와 다르다는 점을 모델·테스트에 명시한다.
- 유효한 고도 샘플이 부족하면 `--`를 표시하고 0m로 위장하지 않는다.

### 2.3 케이던스

- `CMPedometer`의 `currentCadence`를 우선 사용한다. Apple 문서상 값의 단위는 steps/sec이며 표시값은 steps/min으로 변환한다.
- 평균 케이던스는 순간값의 단순 평균이 아니라 유효 cadence 구간을 시간 가중해 계산한다. cadence가 nil이거나 기기에서 지원되지 않으면 해당 구간을 제외한다.
- `CMPedometer` 권한과 기기 지원 여부를 확인하고, 거부·미지원 시 `--`와 짧은 안내를 표시한다.
- 케이던스를 거리로 역산하거나 임의의 고정값으로 채우지 않는다.

### 2.4 심박수

- 평균 심박수는 Apple Watch가 HealthKit에 기록한 `heartRate` 샘플을 우선 사용한다. iPhone에는 자체 심박수 센서가 없으므로, Apple 공식 문서 기준으로 iPhone 단독 측정은 지원 범위로 간주하지 않는다.
- 현재 프로젝트에는 HealthKit 연동·entitlement·사용 목적 문구가 없으므로, HealthKit capability 추가와 `NSHealthShareUsageDescription` 설정이 필수다. 이번 기능은 앱이 직접 Apple Watch workout session을 새로 시작하는 구조가 아니라, 사용자가 Apple Watch/운동 장치로 생성한 HealthKit 데이터를 읽는 방향으로 우선 설계한다.
- 조회 범위는 러닝의 실제 시작 시각부터 종료 시각까지로 제한하고, pause 구간의 샘플은 제외한다. 샘플의 source/device가 확인 가능하면 Apple Watch 등 운동 센서 source를 우선하고 중복 샘플을 제거한다.
- 평균값은 HealthKit의 discrete average 통계 또는 동일한 시간 범위의 유효 샘플 평균을 사용한다. 값은 count/minute 단위로 변환하고, 비정상 범위 값은 제외한다.
- HealthKit 미지원 기기, 권한 거부, Apple Watch 미연결, 샘플 없음, 조회 오류는 모두 정상적인 `unavailable` 상태로 통합하고 결과 화면에는 `--`를 표시한다. 페이스·나이·칼로리로 심박수를 추정하지 않는다.
- 실시간 결과 화면에서 심박수를 보여주는 것은 후속 범위로 둔다. 이번 범위의 필수 결과는 러닝 종료 후 HealthKit에 저장된 샘플을 조회해 표시하는 평균 심박수다.

### 2.5 날씨

- Apple WeatherKit의 `CurrentWeather`를 사용해 날씨 상태, `symbolName`, 기온을 표시한다.
- WeatherKit 연동에는 앱 capability/서비스 설정, 위치 권한, WeatherKit attribution 등 배포 조건 확인이 필요하다.
- 네트워크·권한·쿼터·서비스 오류 시 결과 화면을 깨뜨리지 않고 날씨 카드만 숨기거나 `날씨 정보를 불러올 수 없음` 상태로 표시한다.
- 역사적 러닝 당시 날씨와 현재 오늘 날씨는 다른 의미다. 1차 구현은 요청 문구에 맞춰 결과 진입 시점의 현재 위치 기준 `오늘 날씨`를 표시하되, 러닝 기록의 정확한 환경을 보존해야 하는 요구가 확정되면 시작 시각·시작 위치의 날씨를 별도 저장하는 후속 범위로 분리한다.

## 3. 사용자 시나리오

```
사용자가 러닝을 종료한다
→ 결과 화면에서 거리·시간·평균 페이스를 확인한다
→ 고도 상승·평균 심박수·평균 케이던스를 한눈에 확인한다
→ 지도에서 이동 경로와 1km, 2km ... 지점 및 시작/종료 지점을 확인한다
→ 지도 오른쪽 아래 작은 날씨 카드에서 오늘의 기온과 상태 아이콘을 확인한다
→ 측정 권한·센서·네트워크가 없으면 해당 값만 명확한 대체 상태로 확인한다
```

## 4. 화면 구성

### 결과 화면

- 상단: 총 거리 대형 표시
- 핵심 요약: 평균 페이스, 시간, 칼로리
- 추가 지표 3열: 고도 상승, 평균 심박수, 평균 케이던스
- 지도: 경로, 시작/종료 마커, 1km 단위 거리 라벨
- 지도 우측 하단 오버레이: 기온 + WeatherKit 상태 아이콘
- 데이터 없음 상태: `--`와 접근성 가능한 설명을 표시

### 활동 상세 화면

- 저장된 `RunRecord`에 추가 지표와 1km 마커 데이터를 연결한다.
- 결과 화면과 동일한 계산 규칙을 사용한다. 화면별로 값을 다시 계산해 불일치가 생기지 않도록 한다.
- 기존 기록에 새 필드가 없으면 안전하게 fallback한다.

## 5. 데이터 흐름 및 책임

### 모델

- `RunRecord`: `elevationGainMeters`, `averageHeartRate`, `averageCadence`, 필요 시 `kilometerMarkers`를 nullable/optional 호환 필드로 추가한다.
- `RunMeasurementSample` 또는 동등한 내부 모델: timestamp, 위치, 수평·수직 정확도, 누적 거리, 고도, cadence, 심박수, 활동 구간을 표현한다.
- 저장 모델과 화면 표시 모델을 분리해 센서 원본과 표시용 반올림 값을 혼동하지 않는다.

### 계층별 책임

- `LocationManager`: 위치 권한, 수평/수직 정확도 검증, 유효 위치 샘플 전달
- `PedometerRepository`: `CMPedometer` live update 시작·종료, cadence 권한/지원 상태 처리
- `HealthKitRepository`: 심박수 읽기/운동 통계 권한과 샘플 조회. 권한 거부를 오류가 아닌 상태로 반환
- `RunMetricsCalculator` 또는 UseCase: 거리·활동 시간·고도 상승·평균 심박수·평균 케이던스·km 경계 계산
- `WeatherRepository`: WeatherKit 조회, 상태 아이콘·기온 단위 변환, 실패 상태 처리
- `RunningViewModel`: 러닝 생명주기와 UseCase 결과를 연결하고 저장 시 확정된 스냅샷 전달
- `RunSummaryView` / `RunActivityDetailView`: 표시와 사용자 입력만 담당
- `FirestoreService`: 새 필드 저장·조회 및 구기록 호환

## 6. 작업 목록 (Tasks)

- [ ] Task 1: 현재 결과 화면·러닝 종료·Firestore 저장 경로의 중복 계산 지점과 pause/resume 흐름 점검
- [ ] Task 2: 유효 위치 샘플, 활동 시간, GPS 점프 제거, 거리 및 평균 페이스를 단일 계산 규칙으로 정리
- [ ] Task 3: 고도 샘플 검증·노이즈 완화·누적 상승 고도 계산기와 단위 테스트 구현
- [ ] Task 4: 1km 경계 선분 보간 및 마커 모델 구현, 지도 annotation 표시
- [ ] Task 5: `CMPedometer` repository 및 cadence 권한/미지원/일시정지 처리 구현
- [ ] Task 6: HealthKit capability/Info.plist 설정, Apple Watch 심박수 권한·샘플 조회·평균 계산 및 `--` 상태 UI 구현
- [ ] Task 7: WeatherKit repository, 날씨 상태 아이콘·기온 카드·오류/로딩/권한 상태 구현
- [ ] Task 8: `RunRecord`/Firestore schema 확장 및 기존 기록 fallback 처리
- [ ] Task 9: 결과 화면을 제공 이미지의 정보 위계로 재구성하고 Dynamic Type·다크모드·VoiceOver·최소 44pt 터치 영역 검증
- [ ] Task 10: 활동 상세 화면에도 동일 지표·마커·날씨 정책 적용
- [ ] Task 11: 단위 테스트, GPS 로그 기반 계산 테스트, 권한/센서 부재 테스트, 실기기 러닝 QA 및 최종 보고서 작성

## 7. 완료 기준 (Acceptance Criteria)

- [ ] 평균 페이스와 거리의 기준이 하나로 통일되고, pause/resume 후 거리·시간·페이스가 튀지 않는다.
- [ ] 비정상 정확도·timestamp·속도·GPS 점프가 거리·고도·km 마커에 포함되지 않는다.
- [ ] 고도 상승은 유효 수직 정확도 샘플만 사용하며, 순고도 차이와 혼동되지 않는다.
- [ ] 케이던스는 `CMPedometer` 값만 사용하고, 평균 계산에서 유효 구간을 시간 가중한다.
- [ ] 심박수는 러닝 시간 범위의 Apple Watch/HealthKit 유효 샘플이 있을 때만 표시되며, 없거나 조회할 수 없을 때 반드시 `--`를 표시한다.
- [ ] 심박수 계산에서 pause 구간과 중복/비정상 샘플이 제외되고, bpm 단위로 표시된다.
- [ ] 1km 이상 이동 시 경계마다 정확히 한 개의 마커가 생성되고 1회 업데이트에서 여러 경계를 넘는 경우도 누락되지 않는다.
- [ ] 지도에 경로·시작/종료·1km 마커가 함께 표시되고, 경로가 없거나 마커가 없어도 화면이 깨지지 않는다.
- [ ] 날씨 카드에 오늘 기온과 상태 아이콘이 표시되며 WeatherKit 실패 시 graceful fallback이 동작한다.
- [ ] 기존 Firestore 기록은 새 필드가 없어도 기존 정보로 정상 표시된다.
- [ ] iPhone 실기기에서 위치 권한, 모션 권한, HealthKit 권한 거부/허용, Apple Watch 샘플 있음/없음, WeatherKit 네트워크 실패를 각각 확인한다.
- [ ] Debug 빌드와 단위 테스트가 통과한다.

## 8. 예상 소요 시간

| 작업 | 예상 시간 |
|------|-----------|
| 현행 측정 흐름 점검 및 계산 규칙 정리 | 1시간 |
| 거리·고도·km 마커 계산기 및 테스트 | 2시간 |
| 케이던스 연동 | 1.5시간 |
| HealthKit/Apple Watch 심박수 연동 | 2.5~4시간 |
| WeatherKit 연동 및 카드 UI | 1.5~2시간 |
| 모델·Firestore·결과/상세 화면 | 2~3시간 |
| 실기기 QA·오류 수정·문서화 | 2시간 |
| **합계** | **11~14.5시간** |

## 9. 범위·리스크 및 확인 필요 사항

- 심박수는 시뮬레이터에서 실제 센서 측정값을 검증할 수 없다. Apple Watch가 페어링된 iPhone 실기기에서 Health 앱에 운동 시간대 심박수 샘플이 생성된 경우와 생성되지 않은 경우를 모두 테스트해야 한다.
- HealthKit 권한 요청의 성공 callback은 사용자가 실제 read 권한을 허용했다는 뜻과 동일하지 않으므로, 권한 상태와 조회 결과를 별도로 처리해야 한다.
- Apple Watch에서 별도 운동 세션이 실행 중이면 앱이 직접 `HKWorkoutSession`을 시작하는 방식과 충돌할 수 있다. 따라서 1차 구현은 기존 Apple Watch 운동 기록을 읽는 방식으로 제한하고, 향후 실시간 연동이 필요할 때 watchOS companion 및 운동 세션 정책을 별도 설계한다.
- `CMPedometer.currentCadence`는 기기·OS 지원 여부에 따라 nil일 수 있으므로 항상 숫자가 표시된다고 가정하지 않는다.
- WeatherKit은 앱 설정과 attribution 검토가 필요하며, 네트워크가 없는 환경에서는 표시할 수 없다.
- 현재 브랜치에 사용자 변경 사항(`Info.plist` 수정 및 추적되지 않은 산출물)이 있으므로 승인 후 브랜치 분기 시 해당 변경을 보존하고 작업 범위를 섞지 않는다.
- Nike Run Club의 시각적 경험은 참고하되 로고·상표·전용 그래픽을 복제하지 않고 Pacing 디자인 시스템으로 재해석한다.
- 날씨 카드의 의미를 `결과를 보는 시점의 오늘 날씨`로 할지 `러닝 당시 날씨`로 할지 승인 시 최종 확정한다. 정확한 기록 보존이 우선이면 후자를 권장하며, 이 경우 러닝 종료 시 날씨 스냅샷 저장 범위가 추가된다.

## 10. 조사 참고 자료

- [Apple Developer — CLLocation altitude](https://developer.apple.com/documentation/corelocation/cllocation/altitude): 수직 정확도 유효성 및 고도 기준
- [Apple Developer — CMPedometer](https://developer.apple.com/documentation/coremotion/cmpedometer): cadence 지원 여부와 live update
- [Apple Developer — CMPedometerData.currentCadence](https://developer.apple.com/documentation/coremotion/cmpedometerdata/currentcadence): cadence 단위 및 nil 조건
- [Apple Developer — HealthKit quantity types](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier): 심박수 등 quantity type
- [Apple Developer — HKWorkout.statistics(for:)](https://developer.apple.com/documentation/healthkit/hkworkout/statistics(for:)): 운동 범위 통계 계산
- [Apple Developer — Authorizing access to health data](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data): HealthKit read 권한과 사용 목적 문구
- [Apple Developer — HKWorkoutSession](https://developer.apple.com/documentation/healthkit/hkworkoutsession): iPhone 단독 심박수 측정 한계 및 Apple Watch workout session 동작
- [Apple Developer — Heart rate](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/heartrate): 심박수 샘플의 discrete count/time 특성
- [Apple Developer — WeatherKit CurrentWeather](https://developer.apple.com/documentation/weatherkit/currentweather): 기온·상태·SF Symbol 제공

---

> **검토 의견** (개발자 작성):
> 승인 여부: 승인 ✅ / 수정 요청 🔄
> 날씨 의미: 결과 조회 시점의 오늘 날씨 / 러닝 당시 날씨
