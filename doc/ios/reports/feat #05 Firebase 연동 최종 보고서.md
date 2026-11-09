# feat #05 Firebase 연동 최종 보고서

## 개요

| 항목 | 내용 |
|------|------|
| 브랜치 | `feat/05-firebase` |
| 작업 기간 | 2026-06-25 ~ 2026-06-26 |
| 담당 | kimeunchan |

---

## 구현 내용

### 1. Firebase 초기 설정
- Firebase SDK (FirebaseAuth, FirebaseFirestore) SPM으로 추가
- `GoogleService-Info.plist` 프로젝트에 추가
- `AppDelegate` + `UIApplicationDelegateAdaptor`로 `FirebaseApp.configure()` 초기화

### 2. Apple 로그인 (Sign in with Apple)
- `AuthViewModel` 구현 — nonce 생성(SHA256), `OAuthProvider.appleCredential` Firebase 인증
- Apple Developer Portal: `com.eunchan.Pacing` → Sign in with Apple 활성화
- Firebase Console: Authentication → Apple 공급자 활성화
- Xcode Signing & Capabilities: Sign in with Apple capability 추가
- `LoginView` 커스텀 버튼 "Apple로 계속하기" 한글 텍스트 적용

### 3. Firestore 데이터 연동
- `FirestoreService` 싱글턴 구현
  - `saveUserProfile(uid:nickname:height:weight:age:)` — `users/{uid}` 저장
  - `fetchUserProfile(uid:)` — 프로필 불러오기
  - `saveRunRecord(uid:record:)` — `users/{uid}/runHistory/{id}` 저장
  - `fetchRunHistory(uid:limit:)` — 러닝 기록 목록 불러오기
- Firestore 리전: `asia-northeast3 (Seoul)` 선택

### 4. 세션 복원
- `SplashView`에서 앱 시작 시 `Auth.auth().currentUser` 확인
- 로그인 상태 유지 — 재로그인 불필요

### 5. 프로필 설정 3단계 플로우
- 1단계: 닉네임 입력
- 2단계: 성별 / 나이 선택
- 3단계: 키 / 체중 선택
- 상단 진행 바로 현재 단계 시각화
- 저장 시 UserDefaults + Firestore 동시 저장

### 6. 러닝 기록 저장
- `RunningViewModel.saveRecord()` — 러닝 완료 후 확인 버튼 탭 시 Firestore 저장
- `MyViewModel.loadData()` — Firestore에서 실제 기록 불러오기 (로그인 미완 시 더미 데이터 fallback)

### 7. 마이탭 로그아웃
- `MyViewModel.logout()` — `Auth.auth().signOut()` 호출 후 AppState 초기화

### 8. 기타 UI 개선 (이번 브랜치 병행)
- 러닝 중 위치 표시: `UserAnnotation` 큰 원 → 커스텀 작은 점 핀으로 교체
- 종료 버튼 홀드 차징 선: 흰색 → 어두운 회색 `Color(white: 0.2)`
- 지도 카메라 이동 애니메이션: `.linear(duration: 2)` 부드럽게 개선

---

## 미완 항목

| 항목 | 사유 |
|------|------|
| MusicKit 연동 | Developer Portal MusicKit 활성화 후 프로비저닝 프로파일 갱신 필요 — 별도 브랜치에서 처리 예정 |
| Google 로그인 | MVP 범위 외 — 필요 시 추가 |
| Firestore 보안 규칙 | 현재 테스트 모드 (2026-07-25 만료) — 배포 전 uid 기반 규칙으로 교체 필요 |

---

## 주요 파일 변경 목록

| 파일 | 변경 내용 |
|------|-----------|
| `PacingApp.swift` | AppDelegate + FirebaseApp.configure() 추가 |
| `Core/Auth/AuthViewModel.swift` | Apple Sign In + Firebase Auth 신규 |
| `Core/Firebase/FirestoreService.swift` | Firestore CRUD 신규 |
| `Features/Auth/View/LoginView.swift` | Apple 로그인 버튼 커스텀화 |
| `Features/Auth/View/AppleSignInButton.swift` | "Apple로 계속하기" 커스텀 버튼 신규 |
| `Features/Auth/View/SplashView.swift` | Firebase 세션 복원 추가 |
| `Features/Onboarding/View/ProfileSetupView.swift` | 3단계 플로우로 재설계 |
| `Features/My/ViewModel/MyViewModel.swift` | Firestore 프로필/기록 fetch 연동 |
| `Features/Running/ViewModel/RunningViewModel.swift` | saveRecord() Firestore 저장 추가 |
| `Features/Running/View/RunningView.swift` | 위치 핀 개선, 차징 선 색상 수정 |
| `Pacing/Pacing.entitlements` | Sign in with Apple entitlement 추가 |

---

## QA 결과

| 항목 | 결과 |
|------|------|
| Apple 로그인 | ✅ 실기기 정상 동작 |
| 프로필 설정 3단계 | ✅ 정상 동작 |
| Firestore 프로필 저장 | ✅ Firebase Console에서 데이터 확인 |
| 세션 복원 (앱 재시작) | ✅ 로그인 유지 |
| 러닝 기록 저장 | ✅ runHistory 컬렉션에 저장 확인 |
| 마이탭 기록 표시 | ✅ Firestore 데이터 반영 |
| 로그아웃 | ✅ 로그인 화면으로 이동 |
| MusicKit | ⏳ 보류 |
