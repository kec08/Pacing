# feat #130 결과 화면 고도·HealthKit 심박수 최종 개발 보고서

> **완료일**: 2026-08-28
> **관련 이슈**: [#130](https://github.com/kec08/Pacing/issues/130)
> **PR**: [#131](https://github.com/kec08/Pacing/pull/131)
> **기준 브랜치**: `dev`
> **작업 브랜치**: `feat/130-healthkit-heart-rate`

## 구현 요약

러닝 종료 결과 화면과 활동 상세 화면에서 고도 상승과 평균 BPM을 확인할 수 있도록 데이터 흐름을 확장했습니다. 위치 센서의 유효 고도 샘플을 보존해 누적 상승 고도를 계산하고, HealthKit에서 러닝 시간 범위의 심박수 샘플을 조회해 평균 BPM을 표시합니다.

## 구현된 기능

- [x] 러닝 중 고도 상승값을 `0m`에서 시작
- [x] 유효 위치 샘플 수신 시 고도 상승값 실시간 갱신
- [x] 고도 정확도·GPS 노이즈 기준을 적용한 누적 상승 고도 계산
- [x] 결과 화면에 고도 상승·BPM·케이던스 영역 추가
- [x] 활동 상세 화면에 동일한 6개 지표 구조 추가
- [x] HealthKit 읽기 권한 요청
- [x] Apple Watch 심박수 샘플 우선 조회
- [x] 러닝 시작·종료 시간 범위의 평균 BPM 계산
- [x] 심박수 권한·샘플·기기 데이터가 없을 때 `--` 표시
- [x] `RunRecord` 및 Firestore optional 필드 저장·조회
- [x] 기존 Firestore 기록과의 호환성 유지
- [ ] 케이던스 실제 측정·평균 계산 — 다음 브랜치에서 `CMPedometer`로 진행
- [ ] WeatherKit 날씨 연동 — 별도 후속 범위

## 측정 및 계산 정책

### 고도

- `CLLocation.altitude`를 사용합니다.
- `verticalAccuracy`가 0 이하이거나 30m를 초과하는 샘플은 제외합니다.
- 2m 미만의 상승 변화는 GPS 고도 노이즈로 보고 제외합니다.
- 유효한 양의 고도 변화만 누적합니다.
- 종료 결과에서 유효 샘플이 부족하면 `--`를 표시합니다.

### 심박수

- HealthKit `heartRate` 샘플을 사용합니다.
- 러닝 전체 시간 범위의 유효 샘플을 조회합니다.
- Apple Watch로 식별 가능한 샘플을 우선합니다.
- 30~240 BPM 범위 밖의 샘플은 제외합니다.
- 유효 샘플의 평균을 BPM으로 표시합니다.
- 권한 거부·Apple Watch 미연결·샘플 없음·조회 오류는 `--`로 표시합니다.

## 커밋 단위

- `9db9370` 계획서·HealthKit 권한 설정
- `8980638` 고도 데이터·RunRecord·Firestore 확장
- `1ebc0d2` HealthKit 심박수 조회·러닝 종료 취합
- `71b2f4e` 결과·활동 상세 화면 지표 표시
- `6c8c76d` 러닝 시작 시 고도 0m 표시
- `dc96ea5` 러닝 중 고도 상승값 실시간 갱신

## QA 결과

| 항목 | 결과 |
|------|------|
| iOS Debug 빌드 | ✅ `BUILD SUCCEEDED` |
| 테스트 타깃 컴파일 | ✅ `TEST BUILD SUCCEEDED` |
| 고도 계산 단위 테스트 대상 | ✅ 기존 계산기 테스트 포함 |
| 시뮬레이터 단위 테스트 실행 | ⚠️ 테스트 러너가 결과 없이 종료되어 성공 확정 불가 |
| Apple Watch 심박수 실기기 검증 | ⏳ iPhone·Apple Watch 연결 환경 필요 |
| 다크 모드·실제 HealthKit 권한 흐름 | ⏳ 실기기 QA 필요 |

## 알려진 제한사항 및 후속 작업

- 현재 케이던스는 실제 계산하지 않으며 화면에 `--`를 표시합니다. 다음 브랜치에서 `CMPedometer.currentCadence`와 활동 시간 기반 평균식을 구현합니다.
- 현재 심박수는 앱이 직접 Apple Watch 운동 세션을 생성하지 않고 HealthKit에 저장된 샘플을 읽습니다.
- HealthKit 심박수와 고도는 시뮬레이터에서 실제 센서 검증이 불가능합니다.
- WeatherKit 날씨 카드와 1km 지도 annotation 연결은 후속 범위입니다.
- Xcode 26의 `UIScreen.main` deprecated 경고는 기존 레이아웃 후속 정리 대상입니다.

## 참고 자료

- [Apple HealthKit quantity types](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier)
- [Apple HKSample](https://developer.apple.com/documentation/healthkit/hksample)
- [Apple CMPedometerData.currentCadence](https://developer.apple.com/documentation/coremotion/cmpedometerdata/currentcadence)
- [Apple CLLocation altitude](https://developer.apple.com/documentation/corelocation/cllocation/altitude)

> **개발자 검토 의견**: 고도와 HealthKit 심박수의 데이터 계층·결과 표시를 구현했습니다. 케이던스는 정확한 `CMPedometer` 연동을 위해 다음 브랜치로 분리합니다.
