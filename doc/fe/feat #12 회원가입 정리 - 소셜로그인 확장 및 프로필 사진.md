# feat #12 회원가입 정리 — 소셜 로그인 확장 · 프로필 사진 · 로그인 정보 유지 기획서

## 목표
1. 소셜 로그인 확장: **카카오 · 네이버 · 구글** 추가 (애플 유지)
2. 회원가입(프로필 설정)에 **프로필 사진** 추가 (Base64 → Firestore)
3. 로그인을 다시 해도 **프로필 정보 유지** (재입력 제거)

> 자체 로그인(이메일/비밀번호)은 이번 범위에서 제외.

---

## ⚠️ 사전 작업 (개발자 직접 — 콘솔 설정)
코드는 모두 붙이지만, 아래 키/등록은 직접 발급·등록해야 동작합니다.

| 플랫폼 | 필요 항목 |
|--------|----------|
| 카카오 | [Kakao Developers] 앱 생성 → **네이티브 앱 키**, iOS 번들 ID 등록, URL 스킴 `kakao{앱키}` |
| 네이버 | [Naver Developers] 앱 생성 → **Client ID / Client Secret**, URL 스킴 등록 |
| 구글 | Firebase Console에서 Google 로그인 활성화 → `GoogleService-Info.plist`의 `REVERSED_CLIENT_ID` URL 스킴 등록 |
| 애플 | (이미 완료) |

- Firebase Console → Authentication → 로그인 제공업체에서 **Google** 활성화
- 카카오/네이버는 Firebase 기본 제공업체가 아니므로 **Custom Token** 또는 OAuth 연동 방식 사용 (아래 참조)

---

## 해결 방향

### 1. 소셜 로그인 확장

#### 구조
- `LoginView`에 카카오(노랑) · 네이버(초록) · 구글(흰/테두리) · 애플(검정) 버튼 4종 배치
- 각 SDK 연동 후 Firebase Auth 세션으로 통합

#### 플랫폼별 연동 방식
| 플랫폼 | SDK | Firebase 연동 |
|--------|-----|--------------|
| 구글 | GoogleSignIn-iOS | Firebase 기본 지원 → `GoogleAuthProvider.credential` |
| 애플 | (구현됨) | `OAuthProvider.appleCredential` |
| 카카오 | kakao-ios-sdk (KakaoSDKUser) | Firebase 미지원 → 카카오 토큰으로 로그인 후 **이메일/UID 기반 커스텀 처리** |
| 네이버 | naveridlogin-sdk-ios | Firebase 미지원 → 동일 |

> **카카오/네이버 방식 확정**: Firebase Auth가 기본 제공업체로 지원하지 않으므로
> **Firebase Cloud Functions + Custom Token** 방식으로 연동한다.
> 앱에서 카카오/네이버 SDK 로그인 → 토큰을 Cloud Function에 전달 →
> Function이 토큰 검증 후 Firebase Admin SDK로 Custom Token 발급 →
> 앱이 `Auth.auth().signIn(withCustomToken:)`로 로그인 → 정식 Firebase UID 생성.
> (별도 백엔드 불필요, Blaze 종량제 필요하나 로그인 용도 비용 사실상 0원)

#### 모듈
- `Core/Auth/AuthViewModel.swift`에 메서드 추가
  - `signInWithGoogle(appState:)`
  - `signInWithKakao(appState:)`
  - `signInWithNaver(appState:)`
- SPM 의존성 추가 (Xcode): GoogleSignIn, KakaoOpenSDK, naveridlogin-sdk
- `Info.plist`에 URL 스킴 / LSApplicationQueriesSchemes 추가
- `PacingApp`에 `onOpenURL` 핸들러 (카카오/네이버 콜백)

### 2. 로그인 정보 유지 (핵심)
로그인 성공 직후 **Firestore에서 프로필 존재 여부 확인** 후 분기:

```
소셜 로그인 성공
   ↓
Firestore users/{uid} 조회
   ├─ 프로필 존재 → UserDefaults 복원 → isProfileComplete = true → MainTabView
   └─ 프로필 없음 → isProfileComplete = false → ProfileSetupView
```

- `FirestoreService`에 `hasUserProfile(uid:) -> Bool` 추가 (또는 `fetchUserProfile` 재사용)
- 각 로그인 메서드 끝에서 프로필 확인 → `isProfileComplete` 설정 + UserDefaults 복원
- `SplashView.restoreSession`도 Firestore 검증으로 보강

### 3. 프로필 사진 (Base64 → Firestore)
- `ProfileSetupView` Step 1에 원형 사진 선택 버튼 추가
  - `PhotosPicker`(PhotosUI)로 갤러리 선택
  - 선택 이미지 → 200×200 리사이즈 → JPEG 압축(품질 0.7) → Base64
- `FirestoreService.saveUserProfile`에 `profileImageBase64` 파라미터 추가
- 마이탭 프로필 영역에 사진 표시 (없으면 이니셜 아바타 fallback)
- UserDefaults에도 캐시(즉시 표시)

---

## 변경 / 추가 파일
| 파일 | 변경 내용 |
|------|----------|
| `Core/Auth/AuthViewModel.swift` | 구글/카카오/네이버 로그인 + 프로필 확인 분기 |
| `Features/Auth/View/LoginView.swift` | 소셜 버튼 4종 배치 |
| `Features/Auth/View/SplashView.swift` | 세션 복원 시 Firestore 검증 |
| `Core/Firebase/FirestoreService.swift` | `hasUserProfile`, `profileImageBase64` 저장/조회 |
| `Features/Onboarding/View/ProfileSetupView.swift` | 프로필 사진 선택 UI |
| `Features/My/...` | 프로필 사진 표시 |
| `PacingApp.swift` / `Info.plist` | URL 스킴, onOpenURL 콜백 |
| `Pacing.xcodeproj` | GoogleSignIn / Kakao / Naver SPM 추가 |

---

## 완료 기준
- [ ] 구글 로그인 동작 + 세션 유지
- [ ] 카카오 로그인 동작 (MVP 방식)
- [ ] 네이버 로그인 동작 (MVP 방식)
- [ ] 애플 로그인 정상 유지
- [ ] 재로그인 시 프로필 재입력 없이 메인 진입 (Firestore 검증)
- [ ] 신규 유저는 프로필 설정 진입
- [ ] 프로필 사진 선택 + 마이탭 표시 + 재로그인 후 유지

---

## 구현 순서 (확정)
**1단계 (feat #12)** — 로그인 정보 유지 + 프로필 사진 + **구글 로그인**
- 로그인 유지/사진: 콘솔 의존 없음, 즉시 구현
- 구글: Firebase 기본 지원 (GoogleSignIn SPM + Console Google 활성화 + URL 스킴)

**2단계 (feat #13)** — 카카오 로그인 (Cloud Functions + Custom Token)
**3단계 (feat #14)** — 네이버 로그인 (Cloud Functions + Custom Token)

---

## 1단계 개발자 선행 작업 (구글)
| 작업 | 위치 |
|------|------|
| Google 로그인 제공업체 활성화 | Firebase Console → Authentication |
| `GoogleService-Info.plist` 최신화 (Google 활성화 후 재다운로드) | 프로젝트 |
| URL 스킴에 `REVERSED_CLIENT_ID` 추가 | Xcode → Info → URL Types |
| GoogleSignIn-iOS 패키지 추가 | Xcode → Add Packages (`https://github.com/google/GoogleSignIn-iOS`) |

> 위 4개는 직접 처리 필요. 코드(AuthViewModel, LoginView 버튼, onOpenURL)는 작업해 둠.
