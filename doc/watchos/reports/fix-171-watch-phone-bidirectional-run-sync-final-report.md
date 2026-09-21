# fix #171 iPhone·Watch 양방향 러닝 제어 및 종료 동기화 최종 개발 보고서

> **완료일**: 2026-09-21
> **관련 이슈**: [#171](https://github.com/kec08/Pacing/issues/171)
> **브랜치**: `feat/171-watch-phone-bidirectional-run-sync`
> **PR**: [#172](https://github.com/kec08/Pacing/pull/172)

## 구현 요약

iPhone과 Apple Watch가 하나의 러닝 세션을 공유하도록 양방향 제어를 구현했습니다. 어느 기기에서든 러닝 시작·일시정지·재개·종료를 수행하면 상대 기기의 러닝 상태와 화면이 함께 변경됩니다.

추가로 원격 종료 시 iPhone 종료 요약 화면이 표시되지 않던 문제와 iPhone·Watch의 시작 기준 시각이 달라 시간이 어긋나던 문제를 수정했습니다. iPhone 종료 컨트롤은 Apple Watch와 동일한 시각 언어로 정리했습니다.

## 구현된 기능 목록

- [x] Watch 시작 → iPhone 러닝 시작
- [x] iPhone 시작 → Watch 앱 실행 및 러닝 시작
- [x] Watch 일시정지·재개 → iPhone 상태 반영
- [x] iPhone 일시정지·재개 → Watch 상태 반영
- [x] Watch 정리·종료 → iPhone 운동 세션 및 화면 종료
- [x] iPhone 종료 → Watch 운동 세션 및 화면 종료
- [x] `WCSession` 단일 delegate 구조로 양방향 명령 수신 안정화
- [x] `sendMessage`와 `transferUserInfo`를 사용한 즉시·지연 명령 전달
- [x] 명령 ID 중복 처리 방지
- [x] 공통 `startAt` 기반 `3·2·1` 이후 `0초` 시작 기준 통일
- [x] 원격 종료 시 iPhone `RunSummaryView` 표시
- [x] iPhone 종료 버튼 위치·색상·진행선·크기 조정
- [x] iPhone 종료 버튼 꾹 누르기 진행률을 실제 경과 시간 기반으로 부드럽게 표시

## 아키텍처 반영

| 계층 | 구현 |
|---|---|
| iPhone ViewModel | 로컬·Watch 명령의 러닝 시작, 일시정지, 재개, 종료 상태 전이 처리 |
| iPhone Core | Watch 명령 수신, iPhone 상태 스냅샷 발행, 명령 중복 제거 |
| Watch ViewModel | 로컬·iPhone 명령에 따른 HealthKit 세션 및 Watch UI 상태 전이 |
| Watch Repository | WatchConnectivity 명령 송신 및 iPhone 스냅샷 수신 |
| View | 양쪽 러닝 컨트롤과 종료 요약 화면 표시 |

## 계획서 대비 변경 사항

| 항목 | 계획 | 실제 구현 | 상태 |
|---|---|---|---|
| 공통 명령 모델 | 시작·일시정지·재개·종료 명령과 세션 ID 정의 | `PhoneRunCommand`에 명령 ID·송신 기기·세션 ID·시작 시각 포함 | ✅ |
| 양방향 전송 | WatchConnectivity 명령 송수신 | 즉시 연결은 `sendMessage`, 연결 지연은 `transferUserInfo` 사용 | ✅ |
| 시작 시각 통일 | 카운트다운 후 공통 시각으로 시작 | `startAt` 기준으로 iPhone·Watch 타이머 시작 | ✅ |
| 종료 정리 | 양쪽 운동 세션·화면 종료 | 원격 종료 시 ViewModel 상태와 iPhone 요약 화면까지 처리 | ✅ |
| UI 통일 | Watch 컨트롤과 동일한 종료 UX | iPhone 종료 버튼 위치·색상·진행 애니메이션을 Watch 기준으로 조정 | ✅ |

## QA 결과

| 완료 기준 | 결과 |
|---|---|
| iPhone·Watch 타깃 빌드 | ✅ 통과 (코드 서명 제외) |
| `git diff --check` | ✅ 통과 |
| 양방향 명령 모델 컴파일 | ✅ 통과 |
| iPhone 종료 요약 화면 경로 | ✅ 원격 `finished` 상태에서 표시하도록 확인 |
| 공통 시작 시각 로직 | ✅ `startAt` 기반으로 확인 |
| iPhone 종료 버튼 UI | ✅ 80pt 재개 버튼, 76pt 종료 버튼으로 테두리 보정 |
| 꾹 누르기 진행 애니메이션 | ✅ 60fps 경과 시간 기반으로 구현 |
| 실기기 iPhone·Apple Watch 양방향 QA | ⏳ PR 생성 후 최신 빌드로 최종 확인 필요 |
| 자동 테스트 | ⚠️ 별도 자동 테스트 없음 |

## 발견된 이슈

| 이슈 | 심각도 | 상태 |
|---|---|---|
| `WCSession` delegate가 송신기와 수신기 사이에서 교체됨 | Critical | ✅ 해결 완료 |
| iPhone 원격 종료 시 종료 요약 화면 미표시 | Major | ✅ 해결 완료 |
| iPhone·Watch 시작 시각 불일치 | Major | ✅ 해결 완료 |
| iPhone 종료 버튼 진행률이 끊겨 보임 | Minor | ✅ 해결 완료 |

## 알려진 제한사항 및 후속 작업

- 실기기에서 iPhone 시작·Watch 시작·양방향 일시정지·재개·종료를 최신 빌드로 최종 확인해야 합니다.
- Xcode 26.0 SDK에서 `WATCHOS_DEPLOYMENT_TARGET = 26.6` 경고가 발생합니다. 기능 동작에는 영향이 없으나 배포 타깃 정리는 별도 작업으로 관리합니다.
- 연결 해제·HealthKit 권한 거부 상태의 사용자 안내 UX는 후속 개선 대상으로 관리합니다.

> **개발자 검토 의견**: iPhone과 Watch의 운동 제어를 명령과 상태 스냅샷으로 분리하고, 각 플랫폼의 단일 `WCSession` delegate를 통해 양방향 동기화를 구성했습니다.
> **최종 승인**: 개발자 검토 대기
