# fix #169 iPhone 러닝 시작 시 Watch 앱 및 시간 동기화 최종 개발 보고서

> **완료일**: 2026-09-21
> **관련 이슈**: [#169](https://github.com/kec08/Pacing/issues/169)
> **PR**: [#170](https://github.com/kec08/Pacing/pull/170)
> **브랜치**: `feat/169-watch-phone-run-start-sync`

## 구현 요약

iPhone에서 러닝을 시작해도 Apple Watch 앱이 반응하지 않던 문제를 수정했습니다. iPhone이 HealthKit 운동 시작 API로 Watch 러닝 운동을 시작하고, Watch 앱이 실행 이벤트를 놓치지 않도록 처리했습니다. 또한 iPhone의 러닝 시간·거리·페이스·일시정지 상태를 Watch 화면에 동기화합니다.

근본 원인은 Watch 앱이 iPhone 앱 번들에 포함되지 않은 프로젝트 설정이었습니다. Xcode 타깃 의존성과 Copy Files 설정을 정리해 Watch 앱이 `Pacing.app/Watch/Pacing Watch Watch App.app` 경로에 포함되도록 수정했습니다.

## 구현된 기능 목록

- [x] iPhone 러닝 시작 시 `HKHealthStore.startWatchApp(toHandle:)`로 Watch 운동 시작 요청
- [x] Watch 앱 실행 이벤트를 앱 UI 초기화 전에도 보관해 유실 방지
- [x] iPhone 러닝 상태(`running`, `paused`, `ended`)를 Watch에 동기화
- [x] iPhone의 경과 시간·거리·페이스를 Watch 러닝 화면 지표에 반영
- [x] 최신 상태 보존을 위한 `updateApplicationContext`와 연결 중 즉시 반영을 위한 메시지 전송 병행
- [x] Watch 러닝 시작 전 HealthKit 권한 요청 처리
- [x] iPhone 타깃에 Watch 타깃 의존성 및 `Embed Watch Content` Copy Files 단계 추가
- [x] Watch 앱이 iPhone 앱 번들의 `Watch/` 경로에 포함되는지 빌드 산출물로 확인

## 아키텍처 반영

| 계층 | 구현 |
|---|---|
| iPhone ViewModel | 러닝 상태 전이 시 Watch 운동 시작 요청과 상태 스냅샷 발행 |
| iPhone Core | HealthKit 기반 Watch 실행 런처, WatchConnectivity 상태 발행기 |
| Watch App Delegate | HealthKit 운동 실행 구성을 보관하고 UI 준비 후 전달 |
| Watch Repository | WatchConnectivity 수신 및 최신 iPhone 러닝 스냅샷 보관 |
| Watch ViewModel | 수신한 상태·시간·거리·페이스를 Watch 러닝 UI 상태로 반영 |

## 계획서 대비 변경 사항

| 항목 | 계획 | 실제 구현 | 사유 |
|---|---|---|---|
| Watch 앱 자동 실행 | iPhone 러닝 시작 시 Watch 실행 | HealthKit 운동 시작 API로 Watch 앱 실행 요청 | 운동 세션 기반 실행이 Apple Watch의 공식 진입 경로임 |
| 실행 이벤트 처리 | Watch 러닝 화면 전환 | 실행 구성을 임시 보관한 뒤 ViewModel에 전달 | 앱 시작 시 UI 초기화보다 이벤트가 먼저 도착하는 경쟁 상태 방지 |
| 상태 동기화 | 시간 및 러닝 상태 반영 | 시간·거리·페이스·상태 스냅샷 동기화 | Watch 화면이 iPhone 러닝 진행 상태를 즉시 표시하도록 확장 |
| Watch 앱 설치 | 기존 Watch 타깃 사용 | iPhone 번들 `Watch/` 경로에 Watch 앱 포함 | 실제 기기에서 Watch 앱이 실행되지 않던 근본 원인 해결 |

## QA 결과

| 완료 기준 | 결과 |
|---|---|
| iOS 기기 대상 Debug 빌드 | ✅ 통과 (코드 서명 제외) |
| Watch 앱 번들 경로 | ✅ `Pacing.app/Watch/Pacing Watch Watch App.app` 확인 |
| `git diff --check` | ✅ 통과 |
| iPhone 러닝 시작 후 Watch 앱 자동 실행 | ✅ 실기기 확인 완료 |
| Watch 러닝 화면 전환 | ✅ 실기기 확인 완료 |
| 시간·거리·페이스 상태 동기화 | ✅ 실기기 확인 완료 |
| 관련 자동 테스트 | ⚠️ 별도 자동 테스트 없음 |

## 발견된 이슈

| 이슈 | 심각도 | 상태 |
|---|---|---|
| Watch 앱이 iPhone 앱 번들에 포함되지 않아 자동 실행 대상이 설치되지 않음 | Critical | ✅ 해결 완료 |
| Watch 실행 이벤트가 UI 초기화 전에 도착하면 러닝 화면 전환이 유실될 수 있음 | Major | ✅ 해결 완료 |

## 알려진 제한사항 및 후속 작업

- 현재 Xcode 26.0 SDK에서 `WATCHOS_DEPLOYMENT_TARGET = 26.6` 경고가 발생합니다. 기능 동작에는 영향이 없지만 배포 타깃 정리는 별도 작업으로 관리합니다.
- iPhone과 Watch가 연결되지 않았거나 HealthKit 권한이 거부된 환경의 사용자 안내 UX는 별도 개선 대상으로 관리합니다.

> **개발자 검토 의견**: iPhone 시작을 단일 진입점으로 유지하면서 Watch는 HealthKit 운동 세션과 WatchConnectivity 상태를 수신하는 구조로 분리했습니다. 실기기에서 자동 실행과 동기화가 확인되어 이슈 #169의 목표를 충족했습니다.
> **최종 승인**: 개발자 검토 대기
