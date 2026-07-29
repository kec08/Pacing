# #74 홈·친구 러닝 및 주간 통계 정합성 QA 보고서

> **심각도**: Minor 🟡
> **발견일**: 2026-07-30
> **발견 브랜치**: `feat/74-home-friend-running-polish`
> **상태**: 해결 완료

---

## 증상 요약

친구 최근 러닝 활동 모델이 `Equatable`을 선언했지만 내부의 `RunRecord`가 `Equatable`을 준수하지 않아 iOS 시뮬레이터 빌드가 실패했다.

## 재현 방법 (Steps to Reproduce)

1. `PacingTests` 대상의 iOS 시뮬레이터 테스트를 실행한다.
2. `FriendRecentRunActivity` 컴파일 단계에서 오류를 확인한다.

## 예상 동작

친구 최근 러닝 활동 모델이 정상 컴파일되고 홈·친구 프로필에서 목록으로 렌더링된다.

## 실제 동작

`FriendRecentRunActivity`의 자동 `Equatable` 합성이 실패해 빌드가 중단됐다.

## 원인 분석

`RunRecord`는 좌표 배열을 포함하며 `Equatable`을 준수하지 않는다. 이를 저장 속성으로 가진 활동 모델도 자동 `Equatable` 합성을 할 수 없다.

## 수정 내용

- `FriendRecentRunActivity`에서 사용하지 않는 `Equatable` 선언을 제거했다.
- 동일 시뮬레이터 대상에서 재빌드를 수행했다.

## 관련 파일

- `Pacing/Pacing/Models/FriendModels.swift`: 활동 모델의 불필요한 프로토콜 선언 제거

## 검증 참고

- `xcodebuild`는 `/Applications/Xcode.app` 개발자 도구를 지정해 실행했다.
- 현재 자동화 환경에서는 `.xcresult` 메타데이터를 읽지 못해 테스트 결과의 구조화된 최종 요약을 가져오지 못했다. 앱 수동 QA는 Xcode에서 추가 확인이 필요하다.
