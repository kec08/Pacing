# feat #14 네이버 로그인 최종 보고서

## 개요
- **브랜치**: feat/14-auth-naver-login
- **목표**: 네이버 아이디로 로그인 기능 추가 (Firebase Custom Token 방식)

---

## 구현 내용

### 1. 네이버 Developers 설정
- 애플리케이션 등록: iOS 번들 ID `com.eunchan.Pacing`, URL Scheme `naverPacing`
- PC 웹 환경 추가: 서비스 URL `https://pacing-a8639.web.app`, Callback URL `https://pacing-a8639.web.app/naver-callback`

### 2. Firebase Hosting 중간 리다이렉트
- `public/naver-callback.html` 배포
- 네이버가 HTTPS redirect_uri만 허용하므로 Firebase Hosting URL을 Callback으로 등록
- HTML 페이지가 JS로 `naverPacing://oauth?code=...` 딥링크 생성 → 앱으로 코드 전달

### 3. Cloud Functions `naverLogin`
- 인증 코드 + state 수신 → 네이버 토큰 API로 access_token 교환
- `openapi.naver.com/v1/nid/me`로 사용자 정보 조회
- `admin.auth().createCustomToken(naver:{userId})` 발급 후 반환

### 4. iOS 구현
- **NaverThirdPartyLogin** SPM 추가 (SDK 초기화)
- `ASWebAuthenticationSession` OAuth 플로우:
  - redirect_uri = `https://pacing-a8639.web.app/naver-callback`
  - callbackURLScheme = `naverPacing`
  - Firebase Hosting → `naverPacing://oauth?code=...` → ASWebAuthenticationSession 인터셉트
- Cloud Functions `naverLogin` 호출 → Firebase Custom Token → `signIn(withCustomToken:)`
- `restoreProfile` → `MainTabView` 진입

### 5. 안정성
- 로그인 취소/실패 시 `defer`로 `isLoading` 항상 해제
- `scenePhase` 감지: 앱 포그라운드 복귀 시 1.5초 후 로딩 자동 해제

---

## 해결된 이슈
- issue-12: 네이버 로그인 미지원 → 해결

---

## 변경 파일
| 파일 | 변경 내용 |
|------|-----------|
| `AuthViewModel.swift` | `signInWithNaver()` 추가, NaverPresentationContext, NaverLoginDelegate |
| `LoginView.swift` | 네이버 버튼 추가 (초록), 게스트 버튼 제거, scenePhase 로딩 해제 |
| `PacingApp.swift` | NaverThirdPartyLogin SDK 초기화, onOpenURL 처리 |
| `Info.plist` | `naverPacing` URL Scheme, `LSApplicationQueriesSchemes` 추가 |
| `functions/functions/index.js` | `naverLogin` Cloud Function 추가 |
| `functions/public/naver-callback.html` | Firebase Hosting 리다이렉트 페이지 (신규) |
| `functions/firebase.json` | hosting 설정 추가, `cleanUrls: true` |
