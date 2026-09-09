# [enhancement] Firebase 프로필 이미지 Base64 데이터 분리

## 1. 목적

Realtime Database의 `activeRunners` 위치·음악 브로드캐스트에서 프로필 이미지 Base64 데이터를 분리한다. 러닝 중 반복 전송되는 payload 크기를 줄이면서, 친구·주변 러너·내 프로필 화면의 이미지 표시 기능은 유지한다.

## 2. 현재 문제

- `activeRunners/{uid}`에 위치와 현재 곡을 전송할 때 `profileImageBase64`가 함께 포함된다.
- 프로필 이미지는 변경 빈도가 낮지만 위치/곡 갱신마다 반복 전송된다.
- 주변 러너를 구독하는 모든 기기가 큰 Base64 문자열을 매번 수신할 수 있다.
- 이미지 데이터 분리 과정에서 기존 프로필/친구 화면의 표시가 깨지지 않아야 한다.

## 3. 변경 원칙

- `activeRunners`에는 위치, 닉네임, 현재 곡, 갱신 시각만 유지한다.
- 프로필 이미지의 영속 저장·조회는 기존 Firestore `users/{uid}.profileImageBase64`를 사용한다.
- 측정값, 위치 좌표, 거리, 페이스, 러닝 시간 계산 로직은 수정하지 않는다.
- 기존 데이터에 남아 있는 `activeRunners.profileImageBase64`는 조회 시 선택적으로 무시하며, 강제 삭제/마이그레이션은 별도 작업으로 분리한다.
- 이미지 조회 실패 시 기존 placeholder/fallback UX를 유지한다.

## 4. 작업 계획

### Task 1. Realtime Database payload 분리

- `RealtimeDBService.startBroadcast`, `refreshBroadcast`, `upload`에서 프로필 이미지 provider와 payload 전달을 제거한다.
- `activeRunners` write payload에서 `profileImageBase64`를 제외한다.
- 위치·곡·갱신 시각의 기존 키와 갱신 주기는 유지한다.

### Task 2. 주변 러너 이미지 조회 경로 보완

- `ActiveRunner`에서 이미지 데이터 의존을 제거하거나, 기존 호환 fallback이 필요한 범위를 확인한다.
- 주변 러너/지도 UI가 `activeRunners` 이미지에 의존하지 않도록 Firestore 프로필 조회 또는 기존 캐시 경로를 사용한다.
- Firestore 프로필 조회 대상은 1km 이내 러너와 친구 러너로 제한한다. 친구 러너는 기존 지도 정책에 따라 거리와 무관하게 포함한다.
- 조회 전·조회 실패·이미지 없음 상태에서 placeholder를 표시한다.
- 이미지 조회가 위치 갱신을 지연시키거나 측정 상태를 변경하지 않도록 비동기 책임을 분리한다.

### Task 3. 프로필 저장/조회 호환성 확인

- 온보딩, 프로필 편집, 친구 프로필, 마이 프로필이 Firestore의 프로필 이미지를 계속 사용하는지 확인한다.
- UserDefaults 로컬 캐시와 Firestore 데이터의 기존 동작을 유지한다.
- 이미지 변경/삭제 시 이전 이미지가 남는 stale 상태가 없는지 확인한다.

### Task 4. 검증

- Realtime Database `activeRunners` payload에 Base64 이미지가 포함되지 않는지 정적 확인한다.
- 위치, 현재 곡, 갱신 시각이 기존과 동일하게 전송되는지 확인한다.
- 주변 러너·지도·친구·내 프로필 이미지 표시 회귀를 확인한다.
- 러닝 측정값(거리·페이스·시간·좌표)이 변경되지 않는지 기존 테스트와 빌드로 검증한다.
- `xcodebuild`, 관련 테스트, `git diff --check`를 실행한다.

## 5. 예상 변경 파일

- `Pacing/Pacing/Core/Firebase/RealtimeDBService.swift`
- `Pacing/Pacing/Features/Running/ViewModel/NearbyRunnerViewModel.swift`
- 필요 시 주변 러너/지도 표시 View 및 프로필 조회 Repository
- 본 계획서 및 QA 보고서

## 6. 완료 기준

- `activeRunners` 신규 write에 `profileImageBase64`가 포함되지 않는다.
- 위치·곡·갱신 시각 전송 및 주변 러너 구독이 기존처럼 동작한다.
- 프로필 이미지 저장·조회 및 화면 표시가 기존과 동일하게 동작한다.
- 거리·페이스·러닝 시간·GPS 좌표 등 측정 관련 동작에 변경이 없다.
- 빌드와 테스트를 통과한다.

## 7. 브랜치

`feat/137-firebase-profile-image-separation`
