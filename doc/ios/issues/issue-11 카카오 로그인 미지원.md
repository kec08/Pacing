# issue-11 카카오 로그인 미지원

## 상태
✅ 해결 완료 (feat #13)

## 문제
- 로그인 화면에 Apple, Google 외 카카오 로그인 미지원
- 카카오 계정 보유 유저의 접근 불가

## 원인
- Firebase Auth가 카카오를 네이티브 지원하지 않음
- Cloud Functions + Custom Token 방식 구현 필요

## 해결 방법

### Cloud Functions (Node.js)
- `kakaoLogin` HTTPS Callable Function 배포 (asia-northeast3)
- 카카오 액세스 토큰 → `kapi.kakao.com/v2/user/me` 사용자 정보 조회
- `admin.auth().createCustomToken(kakaoUID)` 발급 후 반환

### iOS
- KakaoSDK SPM 추가 (`KakaoSDKCommon`, `KakaoSDKAuth`, `KakaoSDKUser`)
- `KakaoSDK.initSDK(appKey:)` 앱 초기화
- URL Scheme `kakao73e4e7c46ea882a0d78a306b29553c17` 등록
- `signInWithKakao()`: 카카오 웹 로그인 → 액세스 토큰 → Cloud Functions → Custom Token → Firebase 로그인

### 발생 이슈 및 해결
| 이슈 | 원인 | 해결 |
|------|------|------|
| IOS bundleId validation failed (KOE009) | 카카오 Developers iOS 플랫폼 미등록 | `com.eunchan.Pacing` 번들 ID 등록 |
| Permission 'iam.serviceAccounts.signBlob' denied | Cloud Functions 서비스 계정 권한 부족 | `roles/iam.serviceAccountTokenCreator` 부여 |
| GTMSessionFetcher was already running | 권한 적용 전 인스턴스 캐시 | 함수 재배포로 새 인스턴스 생성 |

## 영향 범위
- `PacingApp.swift`
- `AuthViewModel.swift`
- `LoginView.swift`
- `Info.plist`
- `functions/functions/index.js` (신규)
