# #94 앱 화면 모드 설정 QA 보고서

> **심각도**: Minor 🟡
> **발견일**: 2026-08-09
> **발견 브랜치**: `feat/94-app-appearance-mode`
> **상태**: 환경 제약 확인

## QA 결과

| 항목 | 결과 | 확인 방법 |
|---|---|---|
| 라이트 기본값 | ✅ | `AppAppearance`의 저장값 부재 시 `.light` 반환 정적 검증 |
| 선택값 영속 | ✅ | `setAppearance`의 `UserDefaults` 저장 및 초기화 복원 경로 확인 |
| 시스템/라이트/다크 단일 선택 | ✅ | `AppAppearance.allCases`와 선택 상태 비교 구현 확인 |
| 전역 색상 전환 | ✅ | 루트 `preferredColorScheme` 및 동적 `PacingColor` 토큰 확인 |
| 지도 야간 전환 | ✅ | 전역 색상 환경을 상속하는 SwiftUI `Map` 4개 화면 확인 |
| 접근성 | ✅ | 설정 행의 레이블, 선택값, 힌트 및 104pt 이상 터치 높이 확인 |
| iOS 빌드·실기기 UI QA | ⚠️ 미실행 | 환경의 `xcode-select`가 Command Line Tools(`/Library/Developer/CommandLineTools`)를 가리켜 `xcodebuild`를 실행할 수 없음 |

## 재현 방법

1. Xcode가 설치된 macOS에서 `Pacing.xcodeproj`를 연다.
2. 마이 탭 → `화면 모드 변경`으로 이동한다.
3. 시스템 설정 모드, 라이트 모드, 다크 모드를 각각 선택한다.
4. 각 탭과 러닝 지도·러닝 요약·활동 상세·경로 썸네일을 확인한다.
5. 앱을 종료한 뒤 재실행하여 선택값이 유지되는지 확인한다.

## 실제 동작

이 개발 환경에서는 iOS 빌드 도구가 없어 런타임 UI 검증을 완료할 수 없었다. 소스 정적 검증과 공백 오류 검증은 통과했다.

## 후속 조치

Xcode가 활성화된 환경에서 위 재현 절차로 실제 지도 타일과 다크 모드 대비를 최종 확인한다.
