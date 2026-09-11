# [feat] 러닝 결과 지표·1km 지도 마커·날씨 카드 개선

> **상태**: 개발 진행 중
> **작성일**: 2026-08-26
> **GitHub 이슈**: [#127](https://github.com/kec08/Pacing/issues/127)
> **브랜치**: `feat/127-run-result-metrics`

## 배경

러닝 결과 화면에 고도 상승·평균 심박수·평균 케이던스, 1km 단위 지도 마커, 날씨 카드를 추가한다. 숫자만 추가하지 않고 유효 샘플·pause/resume·GPS 이상값·센서 권한을 포함한 계산 파이프라인을 정리한다.

## 구현 범위

- 거리·평균 페이스 단일 계산 기준 및 GPS 이상값 필터링
- `CLLocation.altitude` 기반 누적 상승 고도
- `CMPedometer` 기반 평균 케이던스
- Apple Watch가 HealthKit에 저장한 심박수 샘플 조회
- 심박수 샘플 없음/권한 거부/Apple Watch 미연결 시 `--` 표시
- 1km 경계 선분 보간 지도 마커
- WeatherKit 오늘 날씨 카드
- `RunRecord`/Firestore 확장 및 기존 기록 호환
- 결과 화면·활동 상세 화면 UX/접근성/실기기 QA

## 완료 기준

- [ ] 거리·시간·평균 페이스가 pause/resume 후 일관된다.
- [ ] 비정상 GPS 위치·고도 샘플이 계산에서 제외된다.
- [ ] 고도 상승·케이던스는 유효 데이터만 표시되고 없으면 `--`다.
- [ ] Apple Watch/HealthKit 심박수 샘플이 있을 때만 평균 bpm을 표시한다.
- [ ] 1km마다 정확히 한 개의 마커가 표시된다.
- [ ] 날씨 카드 오류가 결과 화면을 깨뜨리지 않는다.
- [ ] 기존 Firestore 기록이 정상 표시된다.
- [ ] 단위 테스트 및 iPhone/Apple Watch 실기기 QA를 완료한다.

## 계획서

`doc/fe/plans/feat-결과화면-러닝지표-지도마커-날씨-plan.md`
