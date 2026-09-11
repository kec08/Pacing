# 1.2.2 App Store 심사 대응 최종 보고서

## 구현 요약

App Store Connect 심사 오류 중 앱 번들에서 수정 가능한 HealthKit 목적 문자열을 보완하고, Firebase Swift Package Manager 의존성을 공식 지원 환경에 맞춰 갱신했다. 기존 기능 동작은 변경하지 않았다.

## 변경 사항

| 항목 | 변경 내용 |
| --- | --- |
| HealthKit | `NSHealthUpdateUsageDescription` 추가 |
| Firebase | 최소 버전 `12.15.0` → `12.17.0`으로 상향. 실제 resolve 버전은 `12.18.0` |
| 앱 버전 | Debug/Release marketing version `1.2.2` 확인 |
| 심볼 | Release `DEBUG_INFORMATION_FORMAT = dwarf-with-dsym` 기존 설정 확인 |
| 테스트 호환성 | 현재 `ActiveRunner` initializer와 맞지 않던 테스트 인자 제거 |

## 검증 결과

- [x] `plutil -lint Pacing/Pacing/Info.plist`
- [x] Release build settings에서 `MARKETING_VERSION = 1.2.2` 확인
- [x] Release build settings에서 `CURRENT_PROJECT_VERSION = 1` 확인
- [x] Release build settings에서 `DEBUG_INFORMATION_FORMAT = dwarf-with-dsym` 확인
- [x] 깨끗한 임시 경로에서 SwiftPM 의존성 resolve 성공
- [x] Debug iOS Simulator 자동 테스트 통과
- [x] `git diff --check` 통과
- [ ] Release archive 및 Firebase framework dSYM UUID 대응 확인
- [ ] 최신 Release Candidate Xcode/SDK에서 실제 App Store Connect 업로드 확인
- [ ] Apple Developer 계정이 연결된 실기기 QA 완료

## 남은 이슈 및 제출 전 필수 작업

1. 현재 Mac은 `Xcode 26.0 (17A324)`이므로 제출 archive 생성에 사용하지 않는다. Apple 공식 릴리스 페이지 기준 최신 Release Candidate 환경에서 archive한다.
2. Firebase Firestore SPM 기본 precompiled binary와 absl/gRPC binary는 로컬 임시 checkout에서 자체 dSYM을 포함하지 않는 것으로 확인됐다. Firebase 12.18.0으로 갱신했지만, 최종 archive에서 심사 오류 UUID가 사라졌는지 반드시 확인한다.
3. 최종 archive에서 `Pacing.app/Info.plist`의 `NSHealthUpdateUsageDescription`, 앱 버전·build number, entitlements를 확인한 뒤 업로드한다.

## 관련 파일

- `doc/fe/plans/fix-1.2.2-app-store-submission-plan.md`
- `Pacing/Pacing/Info.plist`
- `Pacing/Pacing.xcodeproj/project.pbxproj`
- `Pacing/PacingTests/PacingTests.swift`

## 관련 이슈

Closes #151
