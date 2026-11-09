# issue-12 네이버 로그인 미지원

## 상태
✅ 해결 완료 (feat #14)

## 문제
- 로그인 화면에 Apple, Google, 카카오 외 네이버 로그인 미지원
- 네이버 계정 보유 유저의 접근 불가

## 원인
- Firebase Auth가 네이버를 네이티브 지원하지 않음
- Cloud Functions + Custom Token 방식 구현 필요
- 네이버 OAuth redirect_uri에 커스텀 URL 스킴 불가 → HTTPS 우회 필요

## 해결 방법

### Cloud Functions (Node.js)
- `naverLogin` HTTPS Callable Function 배포 (asia-northeast3)
- 인증 코드 → 네이버 토큰 교환 → `openapi.naver.com/v1/nid/me` 사용자 정보 조회
- `admin.auth().createCustomToken(naverUID)` 발급 후 반환

### Firebase Hosting (중간 리다이렉트)
- `https://pacing-a8639.web.app/naver-callback` 배포
- 네이버 OAuth redirect_uri로 HTTPS URL 등록 (네이버 콘솔 요구사항)
- JS로 `naverPacing://oauth?code=...` 딥링크 → 앱으로 코드 전달

### iOS
- NaverThirdPartyLogin SDK SPM 추가 (SDK 초기화 용도)
- `ASWebAuthenticationSession` + Firebase Hosting 리다이렉트 방식
- `callbackURLScheme = "naverPacing"` → 앱으로 인증 코드 수신
- `Info.plist`: `naverPacing` URL Scheme, `LSApplicationQueriesSchemes` 추가
- 로그인 취소/실패 시 `scenePhase` 감지로 로딩 상태 자동 해제

### 발생 이슈 및 해결
| 이슈 | 원인 | 해결 |
|------|------|------|
| 서비스 설정에 오류가 있습니다 | 네이버 콘솔 redirect_uri 미등록 + 서비스 URL 미설정 | PC 웹 환경 추가 및 Callback URL 등록 |
| 커스텀 URL 스킴 redirect_uri 거부 | 네이버 OAuth 서버가 `naverPacing://` 형식 불허 | Firebase Hosting HTTPS 중간 리다이렉트 도입 |
| Page Not Found (Firebase Hosting) | `cleanUrls: false`로 `.html` 확장자 필요 | `firebase.json`에 `cleanUrls: true` 추가 |
| 로그인 실패 후 로딩 고착 | ASWebAuthenticationSession 취소 시 `isLoading` 미해제 | `defer` + `scenePhase` 감지로 1.5초 후 자동 해제 |

## 영향 범위
- `PacingApp.swift`
- `AuthViewModel.swift`
- `LoginView.swift`
- `Info.plist`
- `functions/functions/index.js`
- `functions/public/naver-callback.html` (신규)
- `functions/firebase.json`
