# feat #165 Watch 러닝 실시간 대시보드 최종 개발 보고서

> **완료일**: 2026-09-18
> **관련 이슈**: [#165](https://github.com/kec08/Pacing/issues/165)
> **PR**: [#166](https://github.com/kec08/Pacing/pull/166)
> **브랜치**: `feat/165-watch-running-live-dashboard`

## 구현 요약

Apple Watch에서 iPhone 없이 러닝을 시작하고, 카운트다운·실시간 지표·일시정지·길게 눌러 종료·종료 요약까지 처리하는 러닝 경험을 구현했습니다. 러닝 중에는 페이스를 가장 크게 표시하고, 하단 지표는 탭으로 전환할 수 있습니다. 종료 후에는 경로·주요 기록·구간 기록을 세로 스크롤로 확인합니다.

## 구현된 기능 목록

- [x] `idle`, `countdown`, `starting`, `running`, `paused`, `ending`, `ended`, `failed` 러닝 상태 모델
- [x] 3초 핑크 카운트다운 및 카운트다운 중 러닝 탭 고정
- [x] HealthKit `HKWorkoutSession`·`HKLiveWorkoutBuilder` 기반 Watch 단독 운동 세션
- [x] 시간·킬로미터·평균 페이스·BPM·칼로리·고도 상승 지표 모델 및 포맷 통일
- [x] 페이스 중심 대시보드와 하단 두 지표의 독립 탭 전환
- [x] 실행 중 3개 탭(제어·대시보드·음악), 일시정지 중 2개 탭(제어·음악) 전환
- [x] 멈춤/재개에 Watch 시작·정지 햅틱 적용
- [x] 종료 확인 얼럿 제거 및 1.2초 길게 누르는 원형 게이지 종료 버튼
- [x] 종료 요약 화면: 최종 거리 강조, 닫기/완료, 6개 지표, 구간 목록, 경로 없음 상태
- [x] `CoreLocation` 기반 Watch 경로 수집 및 보라→핑크 그라데이션 경로 렌더링
- [x] HealthKit·위치 권한 문구 및 Xcode Preview 안전 실행 경로

## 아키텍처 반영

| 계층 | 구현 |
|---|---|
| View | 상태별 탭, 대시보드, 제어, 음악, 종료 요약 UI |
| ViewModel | 러닝 상태 전이, 카운트다운, 타이머, 지표 선택, 햅틱 호출 |
| Domain | `WatchRunState`, `WatchRunMetrics`, 표시 지표·경로·구간 모델 |
| Repository | HealthKit 라이브 운동 세션 및 CoreLocation 경로 수집 |

## QA 결과

| 완료 기준 | 결과 |
|---|---|
| Watch Simulator Swift 정적 타입 검사 | ✅ 통과 |
| `git diff --check` | ✅ 통과 |
| 카운트다운·러닝·정지·종료 상태 전환 코드 경로 | ✅ 확인 |
| 빈 경로 표시 | ✅ `러닝 경로가 없어요` 처리 구현 |
| 다크 모드·작은 Watch 화면 고려 | ✅ 다크 테마·스크롤 기반 레이아웃 적용 |
| HealthKit·GPS·햅틱 실기기 QA | ⏳ 필요 |
| Debug iOS Simulator 전체 빌드 | ⚠️ CoreSimulator 환경 제약으로 미실행 |

## 알려진 제한사항 및 후속 작업

- 실기기에서 HealthKit/위치 권한 승인, GPS 정확도, 화면 잠금·백그라운드 중 경로 수집, 시작·정지 햅틱을 확인해야 합니다.
- 현재 Watch에서 수집한 경로와 구간 정보의 iPhone 동기화·영구 저장은 후속 `WatchConnectivity`/기록 Repository 작업 범위입니다.
- iPhone에서 러닝을 시작할 때 Watch 앱을 자동 진입시키고 같은 상태를 표시하는 기능도 `WatchConnectivity` 기반 후속 작업이 필요합니다.
- 작업 트리에 남은 음악 탭 `Combine` import, Xcode 설정, `xcshareddata/`, `output/`, `tmp/` 변경은 이번 PR 범위에서 제외했습니다.

> **개발자 검토 의견**: Watch 단독 러닝의 핵심 화면·상태 흐름은 구현됐습니다. 실제 운동 데이터의 정확도와 iPhone 동기화는 실기기 QA 후 별도 이슈로 분리하는 것이 적절합니다.
> **최종 승인**: 개발자 검토 대기
