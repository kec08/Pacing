# feat #01 기반셋업-온보딩 — FE 계획서

> **상태**: 검토 대기
> **작성일**: 2026-06-25
> **담당**: FE
> **브랜치**: `feat/01-foundation-onboarding`

---

## 1. 목적

앱 실행부터 메인 탭 진입까지의 전체 진입 흐름을 구성한다.
Apple 로그인 → 권한 요청 → 프로필 입력 → 메인 탭의 흐름과
전체 앱 아키텍처(MVVM + Combine), 네비게이션 구조를 확립한다.

---

## 2. 구현 화면 목록

| 화면 | 설명 |
|------|------|
| `SplashView` | 앱 실행 시 로고 표시, 로그인 상태 분기 |
| `LoginView` | Apple 로그인 버튼, 앱 소개 문구 |
| `OnboardingPermissionView` | 위치 권한 요청 안내 |
| `OnboardingMusicView` | Apple Music 권한 요청 안내 |
| `ProfileSetupView` | 닉네임 + 신체정보 입력 |
| `MainTabView` | 하단 탭 3개 뼈대 (홈 / 러닝 / 마이) |

---

## 3. 화면별 상세

### SplashView
- Firebase Auth 로그인 상태 확인
- 로그인 + 프로필 완료 → `MainTabView`
- 로그인 + 프로필 미완료 → `ProfileSetupView`
- 비로그인 → `LoginView`

### LoginView
- Pacing 로고 + 앱 소개 문구
- `SignInWithAppleButton` (AuthenticationServices)
- 로그인 성공 → 신규 유저: `OnboardingPermissionView` / 기존 유저: `MainTabView`

### OnboardingPermissionView
- 위치 권한 필요 이유 안내 텍스트 + 아이콘
- "허용하기" 버튼 → `CLLocationManager.requestAlwaysAuthorization()`
- 권한 결과 무관하게 다음 화면(`OnboardingMusicView`) 이동

### OnboardingMusicView
- Apple Music 권한 필요 이유 안내 텍스트 + 아이콘
- "허용하기" 버튼 → `MusicAuthorization.request()`
- 다음 화면 → `ProfileSetupView`

### ProfileSetupView
- 닉네임 TextField (최대 12자)
- 키 Picker (100~250 cm)
- 체중 Picker (20~200 kg)
- 나이 Stepper (1~100)
- 성별 Segment (남 / 여 / 선택 안 함)
- "시작하기" 버튼 → Firestore 저장 후 `MainTabView`
- 닉네임 비어있으면 버튼 비활성화

### MainTabView
- 탭 1: `HomeView` (placeholder)
- 탭 2: `RunningView` (placeholder)
- 탭 3: `MyPageView` (placeholder)
- 탭 아이콘: SF Symbols

---

## 4. 네비게이션 구조

```
PacingApp
└── AppState (전역 로그인/온보딩 상태)
    ├── 비로그인       → LoginView
    │                     └── OnboardingPermissionView
    │                           └── OnboardingMusicView
    │                                 └── ProfileSetupView
    │                                       └── MainTabView
    └── 로그인 완료    → MainTabView
```

---

## 5. ViewModel 구조

```swift
// 전역 앱 상태
class AppState: ObservableObject {
    @Published var isLoggedIn: Bool
    @Published var isProfileComplete: Bool
}

// 로그인
class AuthViewModel: ObservableObject {
    @Published var isLoading: Bool
    func signInWithApple()
}

// 프로필 설정
class ProfileSetupViewModel: ObservableObject {
    @Published var nickname: String
    @Published var height: Double
    @Published var weight: Double
    @Published var age: Int
    @Published var gender: String
    var isValid: Bool  // 닉네임 비어있으면 false
    func saveProfile() async
}
```

---

## 6. 작업 목록

- [ ] 프로젝트 폴더 구조 세팅 (MVVM 기준)
- [ ] `Color` extension — 디자인 시스템 컬러 토큰 적용
- [ ] `AppState` 전역 상태 객체 생성
- [ ] `SplashView` + 분기 로직
- [ ] `LoginView` UI
- [ ] `AuthViewModel` Apple 로그인 연동
- [ ] `OnboardingPermissionView` UI + 위치 권한 요청
- [ ] `OnboardingMusicView` UI + Music 권한 요청
- [ ] `ProfileSetupView` UI
- [ ] `ProfileSetupViewModel` 유효성 검사 + Firestore 저장
- [ ] `MainTabView` 뼈대 + placeholder 3개

---

## 7. 완료 기준

- [ ] Apple 로그인 성공 후 Firestore `users/{uid}` 문서 생성
- [ ] 재실행 시 로그인 유지 → `MainTabView` 바로 진입
- [ ] 신규 유저 온보딩 → 프로필 입력 → 메인 순서 정상 동작
- [ ] 닉네임 비어있을 때 "시작하기" 버튼 비활성화
- [ ] 하단 탭 3개 전환 정상 동작

---

## 8. 특이 사항

- `GoogleService-Info.plist` Git 커밋 금지 (`.gitignore` 처리됨)
- Apple 로그인은 실기기에서 테스트 필요 (시뮬레이터 미지원)
- `Info.plist`에 위치 권한 사용 설명 문구 추가 필수
  - `NSLocationAlwaysAndWhenInUseUsageDescription`
  - `NSLocationWhenInUseUsageDescription`
- `NSAppleMusicUsageDescription` 추가 필수
