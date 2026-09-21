# 네이버 로그인 계정 삭제 오류 분석 및 개선 계획서

## 1. 작업 개요

| 항목 | 내용 |
| --- | --- |
| GitHub Issue | #179 |
| 작업 유형 | 버그 수정 / 외부 OAuth 연동 정합성 보완 |
| 대상 | 네이버 로그인 사용자의 회원탈퇴 |
| 기준 브랜치 | `dev` (`b324ecd`) |
| 작업 브랜치 | `fix/179-naver-account-deletion` |
| 완료 기준 | 앱 데이터·Firebase 계정 삭제와 네이버 로그인 토큰 폐기가 일관되게 완료되고, 실패 원인을 사용자와 운영 로그에서 구분할 수 있다. |

## 2. 현황 및 원인 분석

현재 `naverLogin` 함수는 네이버 access/refresh token을 발급받고 프로필을 조회한 뒤 Firebase Custom Token만 반환한다. 회원탈퇴의 `deleteAccount` 함수는 Pacing 데이터와 Firebase Authentication 사용자만 삭제한다.

따라서 네이버 토큰을 보존하지 않아 탈퇴 시 네이버 Token Revocation API를 호출할 수 없으며, 네이버 연결 서비스 목록에 Pacing 연동이 남는다. 또한 iOS는 모든 Callable Function 실패를 하나의 일반 오류로 표시한다.

네이버 공식 로그인 가이드는 서비스 탈퇴 시 `POST /oauth2.0/revoke`를 호출하도록 안내하며, refresh token을 폐기하면 연결된 access token도 함께 폐기된다.

## 3. 목표 사용자 흐름

1. 네이버 로그인 사용자가 기존 회원탈퇴 확인 절차를 완료한다.
2. 앱이 Keychain에 보관된 네이버 refresh token을 삭제 요청에 한 번만 전달한다.
3. 서버가 네이버 토큰 폐기를 수행하고 HTTP 200을 검증한다.
4. 성공 후 Pacing 데이터와 Firebase Authentication 사용자를 삭제한다.
5. 서버 성공 후에만 앱이 Keychain 토큰, Firebase 세션, 로컬 캐시를 정리하고 로그인 화면으로 전환한다.
6. 연동 해제 또는 데이터 삭제 실패 시 로그인 상태와 토큰을 유지하고 재시도 안내를 표시한다.

## 4. 기술 설계

### iOS

- 네이버 로그인 응답의 refresh token을 Keychain 전용 저장소에 보관한다.
- UserDefaults·로그·화면 상태에는 토큰을 기록하지 않는다.
- 네이버 사용자에 한해 회원탈퇴 요청에 refresh token을 조건부로 전달한다.
- 토큰 누락 시 Firebase 계정을 삭제하지 않고 재로그인 후 재시도를 안내한다.
- 성공 시에만 Keychain 항목을 삭제하며, 실패 시 재시도 가능하도록 유지한다.
- Callable Function 오류 코드에 맞춰 메시지를 분리한다.

### Cloud Functions

- `naverLogin`이 refresh token을 iOS에 반환한다.
- `deleteAccount`가 네이버 사용자라면 `/oauth2.0/revoke`에 POST form 요청을 보내고 HTTP 200만 성공으로 처리한다.
- 토큰 폐기 실패 시 Firebase·Pacing 데이터 삭제 전에 오류를 반환한다.
- 토큰/프로필을 로그에 남기지 않고 UID, 처리 단계, HTTP 상태만 기록한다.

### 호환성

- Apple·Google·Kakao·이메일 로그인 탈퇴 동작은 유지한다.
- 기존 네이버 사용자 중 Keychain 토큰이 없는 경우에는 재로그인을 요구한다.

## 5. 구현 및 QA

1. Cloud Functions 로그와 네이버 테스트 계정으로 기존 오류를 재현한다.
2. 토큰 반환 모델·Keychain 저장소·삭제 요청 연결을 구현한다.
3. Token Revocation 및 단계별 오류 처리를 구현한다.
4. 성공, 토큰 누락, 401, 503 케이스의 단위 테스트를 추가한다.
5. 실제 네이버 계정 탈퇴 후 연결 해제, Firebase 데이터 삭제, 재로그인 신규 가입을 검증한다.

## 6. 완료 기준

- 네이버 연결 서비스 목록에서 Pacing 연동이 제거된다.
- Firestore, Realtime Database, Firebase Authentication 데이터가 삭제된다.
- 외부 API 실패 시 계정과 Keychain 토큰이 보존되고 재시도할 수 있다.
- 비네이버 로그인 탈퇴 흐름에 회귀가 없다.
- iOS Debug 빌드, 관련 테스트, Cloud Functions 문법 검사, `git diff --check`를 통과한다.
