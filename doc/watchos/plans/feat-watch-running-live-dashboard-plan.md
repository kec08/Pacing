# Watch 러닝 시작 및 실시간 대시보드 계획서

> **상태**: 구현 진행 중  
> **작성일**: 2026-09-17  
> **관련 이슈**: [#165](https://github.com/kec08/Pacing/issues/165)  
> **브랜치**: `feat/165-watch-running-live-dashboard`

## 1. 목적

Apple Watch에서 iPhone 없이 러닝을 시작·일시정지·재개·종료하고, 진행 중 시간·거리·현재 페이스·심박수·칼로리를 빠르게 확인할 수 있는 러닝 탭을 구현한다. 또한 iPhone에서 러닝을 시작하면 페어링된 Watch 앱을 운동 세션에 연결·활성화하고, Watch도 같은 러닝 상태와 대시보드를 표시한다.

watchOS의 `HKWorkoutSession`과 `HKLiveWorkoutBuilder`를 운동 세션의 기준 데이터로 사용하고, 위치 기반 거리·페이스는 별도 위치 Repository에서 계산한다. 권한 거절, HealthKit 미사용 가능 상태, 위치 수신 전 상태도 사용자에게 명확히 안내한다.

## 2. 범위

### 포함

- 러닝 전 `idle` 상태의 큰 원형 `러닝 시작` 조작과 준비 상태 안내
- `running`, `paused`, `ended`를 포함한 명시적 러닝 상태 모델
- HealthKit 권한 요청 및 워치 단독 `HKWorkoutSession` 시작·일시정지·재개·종료
- `HKLiveWorkoutBuilder` 기반 심박수·활동 칼로리 수집
- `CLLocationManager` 기반 거리 누적 및 현재 페이스 계산
- iPhone에서 시작한 운동 세션의 Watch 미러링 및 Watch 앱 활성화 요청
- 세션 시작 기기(iPhone 또는 Watch)를 식별하는 공통 세션 식별자와 상태 메시지
- iPhone·Watch 양방향 일시정지·재개·종료 제어와 지표 동기화
- 러닝 중 대형 지표(시간/거리/현재 페이스)의 탭 전환
- 보조 지표(거리, 페이스, 심박수 또는 칼로리)와 일시정지·종료 제어
- 운동 중·종료 중 로딩/오류/권한 거절 상태 UI, VoiceOver 및 동작 줄이기 대응
- 단위 테스트 가능한 UseCase·Repository 프로토콜 경계

### 제외

- 거리·시간 목표 설정과 자동 랩, 음성 안내
- Firebase로의 별도 실시간 브로드캐스트 및 활동 탭 기록 반영
- 음악·같이 듣기·활동 탭의 실제 데이터 연동
- 복잡한 경로 지도 및 고도 데이터

## 3. 사용자 흐름

### Watch에서 시작

1. 앱은 기존처럼 러닝 탭을 기본으로 연다.
2. 사용자가 `러닝 시작`을 누르면 HealthKit 및 위치 권한 상태를 확인하고, 필요한 권한을 요청한다.
3. 권한과 세션 준비가 완료되면 `running` 대시보드로 전환한다. 시간은 즉시 진행하고, 위치·심박수 등 수신 전 지표는 `--`로 표시한다.

### iPhone에서 시작

1. iPhone 러닝 화면의 기존 시작 흐름이 권한 확인 및 카운트다운을 마친다.
2. iPhone이 HealthKit 운동 세션을 만들고 Watch 동반 세션 미러링을 요청한다.
3. Watch는 미러링 세션 수신 시 앱 활성화를 요청받고 러닝 탭의 동일 대시보드로 이동한다.
4. 두 기기는 같은 세션 식별자와 상태를 사용한다. 한쪽에서 일시정지·재개·종료하면 다른 쪽도 해당 상태와 지표를 갱신한다.

### 공통 조작

1. 상단 대형 지표를 탭하면 시간 → 거리 → 현재 페이스 순서로 변경한다.
2. 사용자는 일시정지 후 재개하거나, 종료를 선택한다. 종료는 확인 화면을 거쳐 세션을 끝내고 `ended` 요약을 잠시 표시한 뒤 시작 화면으로 돌아갈 수 있다.
3. 권한이 거절되거나 세션 시작·미러링에 실패하면 원인을 설명하고 재시도 또는 설정 이동 방법을 제공한다.

## 4. 아키텍처 및 데이터 흐름

```
WatchRunningView / iPhone RunningView
        ↓ 사용자 입력 / 화면 상태
iPhoneRunningSessionCoordinator / WatchRunningViewModel
        ↓
StartRunUseCase · PauseRunUseCase · EndRunUseCase
        ↓
WorkoutSessionRepository (HealthKit mirroring) + RunLocationRepository (Core Location)
        ↓
HKWorkoutSession / HKLiveWorkoutBuilder / WCSession / CLLocationManager
```

| 계층 | 책임 |
| --- | --- |
| View | 상태별 화면 렌더링, 탭·버튼 입력, 접근성 문구 |
| ViewModel | 상태 전이, 표시 지표 선택, 스트림 구독, 오류/로딩 상태 |
| UseCase | 시작·일시정지·재개·종료 규칙과 의존성 조합 |
| Repository | HealthKit 세션·라이브 수치, 위치 권한·거리·페이스 접근 추상화 |
| Model | `WatchRunState`, `WatchRunMetrics`, `WatchRunDisplayMetric` |

### 세션 소유 및 동기화 원칙

- **Watch 시작**: Watch가 HealthKit 세션의 소유자이며 iPhone은 후속 동기화 소비자다.
- **iPhone 시작**: iPhone이 HealthKit 세션의 소유자이며 Watch는 HealthKit 미러 세션을 수신해 동일한 대시보드를 표시한다.
- 두 기기가 각각 독립 운동을 동시에 시작하지 않는다. 이미 활성 세션이 있으면 해당 세션 화면으로 합류시키고, 새 세션 생성을 막는다.
- `HKWorkoutSession`의 미러링은 운동 상태·HealthKit 라이브 수치의 기준으로, `WatchConnectivity`는 화면 진입 보조·표시 설정·미러링 실패 안내 같은 비운동 제어 메시지에 한정한다.

### 상태 전이

| 현재 상태 | 사용자 동작 | 다음 상태 | 비고 |
| --- | --- | --- | --- |
| `idle` | 시작 | `running` | 권한 및 세션 준비 성공 시 |
| `running` | 일시정지 | `paused` | HealthKit 세션과 위치 갱신을 함께 정지 |
| `paused` | 재개 | `running` | 누적 거리·경과 시간은 유지 |
| `running` / `paused` | 종료 확인 | `ended` | builder 종료·운동 저장 완료 후 |
| `ended` | 완료 | `idle` | 다음 러닝을 위한 초기화 |

## 5. 화면 설계

### 러닝 전

- 중앙: 기존 Pacing 로고 스타일을 유지한 최소 112pt 원형 시작 조작
- 하단: 준비 상태 또는 권한 필요 안내
- 시작 처리 중에는 중복 입력을 막고 `ProgressView`를 표시

### 러닝 중 / 일시정지

- 상단: 탭 가능한 대형 수치 하나와 단위·라벨
- 중단: 거리, 페이스, 심박수/칼로리를 짧은 행으로 표시
- 하단: `일시정지`/`재개`, `종료` 조작. 종료는 확인을 요구
- 일시정지 시 화면에 명확한 `일시정지됨` 상태를 노출

### 접근성 및 적응형 동작

- 모든 수치에 VoiceOver용 결합 레이블(예: “거리, 1.24킬로미터”) 제공
- Dynamic Type에서 보조 지표는 세로 배열로 자연스럽게 전환
- `accessibilityReduceMotion`이 켜지면 숫자·상태 전환 애니메이션을 제거 또는 축소
- 위치·심박수 미도착 값은 색상만으로 구분하지 않고 텍스트로 설명

## 6. 작업 분리 및 커밋 단위

1. **도메인 기반** — 상태·메트릭 모델, Repository 프로토콜, UseCase, 단위 테스트
2. **공통 세션 모델** — 세션 식별자, 소유 기기, 미러 세션 이벤트와 단위 테스트
3. **HealthKit·위치 구현** — 양 기기 권한, 운동 세션·미러링, 라이브 수치, 거리·페이스 스트림
4. **러닝 전·진행 UI** — iPhone/Watch ViewModel과 시작/대시보드/제어 화면 연결
5. **상태·접근성 강화** — 미러링 실패·권한 거절·종료 확인, VoiceOver·동작 줄이기, UI 테스트
6. **QA 및 문서** — 시뮬레이터 빌드, 페어링 실기기 체크리스트, 이슈·최종 보고서

각 단위는 독립적으로 빌드·테스트한 뒤 Conventional Commit 형식의 작은 커밋으로 남긴다.

## 7. 완료 기준

- [ ] 러닝 시작부터 일시정지·재개·종료까지 상태가 일관되게 전이된다.
- [ ] 워치 단독 HealthKit 운동 세션이 생성되고 종료 시 정상적으로 마무리된다.
- [ ] iPhone에서 러닝 시작 시 페어링된 Watch가 같은 운동 세션의 러닝 대시보드로 전환된다.
- [ ] iPhone 또는 Watch에서 일시정지·재개·종료하면 상대 기기의 대시보드 상태도 일관되게 갱신된다.
- [ ] 시간은 즉시, 거리·페이스·심박수·칼로리는 데이터 수신 시 안전하게 갱신된다.
- [ ] 상단 대형 지표를 탭해 시간·거리·현재 페이스를 전환할 수 있다.
- [ ] 권한 거절, 위치 수신 전, 세션 실패, 종료 처리 중 상태가 사용자에게 명확하다.
- [ ] VoiceOver, Dynamic Type, 동작 줄이기 설정에서 핵심 조작과 수치를 사용할 수 있다.
- [ ] Watch Simulator 빌드 및 관련 단위 테스트를 통과한다.
- [ ] 페어링된 실기기에서 HealthKit·위치 권한 허용/거절 및 실제 짧은 러닝을 QA한다.
- [ ] `git diff --check`를 통과한다.

## 8. 기술적 고려 사항 및 위험

- `HKWorkoutSession`은 시작 기기에 따라 소유 세션 또는 동반 기기 미러 세션으로 동작하며, 양 타깃의 HealthKit capability·실기기 권한이 필요하다.
- 현재 iPhone 러닝 측정은 자체 타이머·위치 기반이므로, iPhone 시작 시 Watch와 같은 HealthKit 운동 세션을 제공하려면 iPhone 러닝 측정도 `HKWorkoutSession`/builder 기반 Coordinator로 연결해야 한다. 이는 Watch 전용 변경보다 범위가 넓지만, 두 기기에서 같은 세션을 보장하기 위한 필수 작업이다.
- GPS는 실외·실기기에서만 거리·페이스 정확도를 검증할 수 있다. 시뮬레이터에서는 주입 가능한 Repository 목업으로 UI와 상태 전이만 검증한다.
- 운동 종료 시 HealthKit 저장 실패 여부와 화면 상태를 분리해, 저장 실패가 다음 러닝 시작을 막지 않도록 한다.
- iPhone 동기화는 이번 범위에 포함하지 않는다. 후속 WatchConnectivity Repository가 동일 `WatchRunMetrics` 모델을 소비할 수 있도록 모델을 iPhone 의존성 없이 유지한다.

## 9. 예상 소요

| 작업 | 예상 |
| --- | ---: |
| 도메인·테스트 기반 | 0.5일 |
| iPhone·Watch 세션 미러링과 위치 Repository | 1.5일 |
| 양 기기 대시보드·제어 UI | 1일 |
| 예외 상태·접근성·페어링 QA | 1일 |
| **합계** | **약 4일** |

## 10. 검토 요청

- 워치 단독 측정(HealthKit + 위치)과 iPhone 시작 시 Watch 미러 대시보드를 **같은 이슈 범위**로 승인하는지 확인이 필요하다.
- iPhone의 기존 자체 타이머·위치 측정은 세션 미러링을 위해 HealthKit 기반 Coordinator와 연결한다. 기존 iPhone 러닝 화면의 지도·랩·음성 안내 동작을 보존하는 것을 완료 기준에 포함한다.
- 종료 뒤 `ended` 요약을 짧게 노출한 뒤 사용자가 직접 시작 화면으로 돌아가도록 제안한다. 별도 상세 결과 화면은 다음 단계로 분리한다.
