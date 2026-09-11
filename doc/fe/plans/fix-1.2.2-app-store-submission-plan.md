# 1.2.2 App Store 심사 대응 계획서

## 목적

App Store Connect에서 1.2.2 빌드가 거절된 원인을 제거하고, `dev` 브랜치에 안전하게 반영할 수 있는 심사 제출용 빌드를 준비한다.

## 심사 오류 범위

- 지원되지 않는 SDK 또는 Xcode 버전으로 빌드됨
- `NSHealthUpdateUsageDescription` 목적 문자열 누락
- FirebaseFirestoreInternal, absl, grpc, grpcpp, openssl_grpc framework의 dSYM 업로드 실패

## 사용자·배포 시나리오

- 사용자는 1.2.2 앱을 설치하고 기존 러닝·HealthKit 심박수 기능을 사용할 수 있다.
- HealthKit 권한 요청 화면에는 심박수 데이터를 읽고 필요한 경우 기록하는 목적이 명확하게 표시된다.
- App Store Connect에는 앱 바이너리와 Firebase 포함 framework의 대응 dSYM이 함께 업로드된다.
- 앱 동작 변경 없이 심사 메타데이터와 배포 빌드 설정만 보완한다.

## 구현 계획

### Task 1. 기준 브랜치 및 빌드 환경 확인

- `origin/dev`의 최신 커밋과 현재 작업 트리 변경을 확인한다.
- 설치된 Xcode와 SDK 버전을 확인하고 프로젝트의 `LastUpgradeCheck`, deployment target, build settings를 점검한다.
- 심사 제출에 사용할 Release archive의 SDK/Xcode가 Apple 지원 범위인지 개발자 확인 항목으로 분리한다.

### Task 2. HealthKit 목적 문자열 보완

- 앱의 HealthKit 사용 방식에 맞는 `NSHealthUpdateUsageDescription`을 `Info.plist`에 추가한다.
- 기존 `NSHealthShareUsageDescription`과 문구가 충돌하지 않도록 읽기·기록 목적을 구분한다.
- HealthKit capability와 entitlements가 실제 사용 코드와 일치하는지 확인한다.

### Task 3. Firebase dSYM 생성·업로드 경로 보완

- Swift Package Manager로 연결된 Firebase SDK 및 transitive binary framework의 버전을 확인한다.
- Release archive에서 각 framework의 UUID와 dSYM 대응 여부를 검사한다.
- `DWARF with dSYM File`, strip/embedding 설정 및 symbol upload 단계에서 dSYM이 누락되지 않도록 필요한 최소 설정을 적용한다.
- SDK 자체에서 dSYM을 제공하지 않는 경우에는 Firebase SDK 업데이트 또는 배포 환경에서 제공되는 공식 symbols 처리 방법을 우선 검토한다.

### Task 4. 버전 및 심사 빌드 검증

- 앱 target의 marketing version이 `1.2.2`인지 확인하고 build number 정책을 점검한다.
- Debug Simulator 빌드 및 가능한 범위의 Release archive를 실행한다.
- archive의 `Info.plist`, entitlements, embedded frameworks, dSYM UUID를 정적 검사한다.
- `git diff --check`와 관련 자동 테스트를 실행한다.

### Task 5. 문서화 및 PR

- QA 결과와 실기기/App Store Connect 재업로드 필요 항목을 최종 보고서에 기록한다.
- Conventional Commit 형식으로 의미 단위 커밋을 생성하고 원격 브랜치에 push한다.
- `dev`를 base로 하는 PR을 생성한다. PR에는 SDK/Xcode 확인 결과와 dSYM 검증 결과를 명시한다.
- PR 생성 후 머지는 개발자가 직접 진행한다.

## 영향 범위 및 비범위

- 영향 범위: `Info.plist`, Xcode 프로젝트 빌드 설정, Firebase 패키지/archive symbol 처리, 배포 문서.
- 비범위: 러닝·음악·같이 듣기 기능의 동작 변경, Firebase 데이터 구조 변경, App Store Connect에서의 실제 제출·심사 요청.
- Xcode/SDK 지원 버전 자체는 프로젝트 코드만으로 보장할 수 없으므로, 최종 archive는 개발자 Mac의 최신 Release Candidate 환경에서 생성한다.

## 완료 기준

- [x] `NSHealthUpdateUsageDescription`이 앱의 `Info.plist`에 추가된다.
- [x] `NSHealthShareUsageDescription`과 HealthKit capability 설정을 코드 기준으로 확인한다.
- [x] 프로젝트의 1.2.2 버전과 build number가 확인된다.
- [ ] 사용 중인 Xcode/SDK가 App Store 제출 지원 범위인지 확인된다.
- [ ] Firebase 관련 framework의 dSYM UUID 대응을 최종 archive에서 확인한다.
- [x] `git diff --check`와 Debug Simulator 테스트가 통과한다.
- [x] QA 결과와 잔여 실기기/App Store Connect 검증 항목이 문서화된다.
- [ ] `dev` 대상 PR이 생성된다.

## 예상 소요

- 환경·의존성 점검: 30분
- Info.plist 및 빌드 설정 보완: 30분~1시간
- archive/dSYM 검증: 1~2시간
- QA·문서화·PR: 30분~1시간
