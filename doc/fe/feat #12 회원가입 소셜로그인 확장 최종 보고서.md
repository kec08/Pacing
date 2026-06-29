# feat #12 회원가입 소셜로그인 확장 최종 보고서

## 개요
- **브랜치**: feat/12-auth-social-login
- **목표**: Google 로그인 추가, 프로필 사진 등록, 로그인 유지(재입력 방지), 회원가입 흐름 개선

---

## 구현 내용

### 1. Google 로그인
- GoogleSignIn SPM 추가
- `signInWithGoogle()`: keyWindow rootVC를 presenter로 사용
- `GoogleService-Info.plist` CLIENT_ID / REVERSED_CLIENT_ID 설정
- URL Scheme 등록 (`com.googleusercontent.apps.1059516488378-...`)
- 로그인 취소/에러 한글 메시지 처리

### 2. 프로필 사진
- `PhotosPicker` → 200×200 JPEG 리사이즈 → Base64 → Firestore 저장
- `MyView` 프로필 아바타: Base64 디코딩 후 실제 사진 표시
- `ProfileSetupView` Step 4에 원형 사진 선택 UI

### 3. 로그인 유지 (재입력 방지)
- `restoreProfile(appState:)`: 로그인 성공 시 Firestore 프로필 조회 → UserDefaults 복원
- `SplashView.restoreSession()`: Firestore 확인 후 isLoading 해제 → 깜빡임 방지
- 프로필 없는 유저: 자동 로그아웃 → 로그인 화면으로

### 4. 계정 전환 시 프로필 분리
- `logout()`: UserDefaults 캐시 클리어
- `restoreProfile()`: 항상 캐시 비우고 새 계정 데이터로 채움

### 5. 회원가입 흐름 개선 (4단계)
- Step 1: 이름(닉네임)
- Step 2: 성별, 나이
- Step 3: 신체정보 (키, 체중)
- Step 4: 프로필 사진 (선택)

### 6. UI 개선
- `preferredColorScheme(.light)` 앱 전체 적용 → 로그인 시 검은 배경 제거
- TextField 텍스트 색상 `Color(uiColor: .label)` 적용
- 로그아웃 확인 얼럿 추가
- 에러 메시지 한글화 (취소 시 미표시)
- `AppState.isAuthLoading` 추가 → 소셜 로그인 후 ProfileSetupView 깜빡임 방지

---

## 해결된 이슈
- issue-10: 로그인 재진입 시 프로필 재입력 및 사진 미지원 → 해결
- issue-11: 카카오 로그인 미지원 → feat #13으로 분리 해결

---

## 변경 파일
| 파일 | 변경 내용 |
|------|-----------|
| `AppState.swift` | `isAuthLoading` 추가 |
| `AuthViewModel.swift` | Google/Kakao 로그인, restoreProfile, 에러 한글화 |
| `SplashView.swift` | Firestore 확인 후 화면 전환, 프로필 없으면 로그아웃 |
| `LoginView.swift` | Google/카카오 버튼 추가 |
| `ProfileSetupView.swift` | 4단계 흐름, 사진 선택 |
| `MyView.swift` | 프로필 사진 표시, 로그아웃 얼럿 |
| `MyViewModel.swift` | 프로필 사진 디코딩, 로그아웃 캐시 클리어 |
| `PacingApp.swift` | GoogleSignIn/KakaoSDK 초기화, preferredColorScheme |
| `Info.plist` | Google/카카오 URL Scheme |
| `GoogleService-Info.plist` | CLIENT_ID 업데이트 |
| `functions/functions/index.js` | kakaoLogin Cloud Function |
