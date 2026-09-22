# #179 네이버 계정 삭제 및 연동 해제 최종 보고서

## 작업 정보

| 항목 | 내용 |
| --- | --- |
| GitHub Issue | [#179](https://github.com/kec08/Pacing/issues/179) |
| 작업 브랜치 | `fix/179-naver-account-deletion` |
| 대상 브랜치 | `dev` |
| PR | [#183](https://github.com/kec08/Pacing/pull/183) |
| 배포 대상 | Firebase Cloud Functions (`asia-northeast3`) |

## 문제 분석

네이버 로그인 계정의 회원탈퇴는 Pacing 데이터와 Firebase Authentication 계정만 삭제하고, 네이버 OAuth 연동은 해제하지 않았다. 또한 운영 로그에서 네이버 토큰 폐기 성공 후 Firestore·Realtime Database 정리 과정이 기본 256MiB 메모리 한도를 초과해 함수가 강제 종료되는 것을 확인했다.

이 때문에 앱에서는 일반적인 계정 삭제 실패 메시지가 표시됐고, 네이버 연결 서비스에 Pacing 연동이 남거나 Pacing 계정 삭제가 중단될 수 있었다.

## 구현 내용

### iOS

- `NaverCredentialStore`를 추가해 네이버 refresh token을 Keychain에만 저장한다.
- 네이버 로그인 함수 응답에서 refresh token을 받아 Firebase 로그인 전에 저장한다.
- 네이버 사용자의 탈퇴 요청에만 refresh token을 Cloud Function으로 전달한다.
- 로그아웃·탈퇴 성공 시 Keychain의 네이버 refresh token을 제거한다.
- Callable Function 오류 코드를 인증 정보 누락·네트워크/연동 해제 실패·일반 오류로 구분해 안내한다.

### Cloud Functions

- `naverLogin`이 네이버 refresh token을 iOS에 반환하도록 변경했다.
- `deleteAccount`가 네이버 사용자라면 Pacing 데이터 삭제 전에 네이버 Token Revocation API를 호출한다.
- 네이버 토큰 폐기 HTTP 200 확인 후에만 Firestore, Realtime Database, Firebase Authentication 삭제를 진행한다.
- 토큰 폐기 실패 시 앱 데이터를 삭제하지 않고 오류를 반환한다.
- `deleteAccount` 함수 메모리를 256MiB에서 512MiB로 상향했다.

## 운영 반영

- `naverLogin`, `deleteAccount` 함수를 Firebase 운영 환경에 배포했다.
- `deleteAccount` Cloud Function의 상태가 `ACTIVE`이고 할당 메모리가 512MiB인 것을 확인했다.
- 운영 로그에서 네이버 토큰 폐기 성공(HTTP 200)과 기존 메모리 초과 원인을 확인했다.

## 검증 결과

- [x] Cloud Functions JavaScript 문법 검사: `node --check functions/functions/index.js`
- [x] `git diff --check` 통과
- [x] 운영 `deleteAccount` 함수 512MiB 및 `ACTIVE` 상태 확인
- [ ] Debug iOS Simulator 전체 스킴 빌드: Watch 앱 타깃의 `WatchKit` 모듈 해석 문제로 미통과
- [ ] 실기기 QA: 네이버 로그인 → 탈퇴 → 네이버 연동 해제 → 재로그인 흐름 확인 필요
- [ ] Firestore·Realtime Database·Firebase Authentication 사용자 삭제 실계정 확인 필요

## 영향 및 고려 사항

- Apple, Google, Kakao, 이메일 로그인 사용자의 기존 탈퇴 흐름은 변경하지 않는다.
- 이전 버전에서 네이버 refresh token이 Keychain에 없는 사용자는 다시 로그인한 후 탈퇴해야 한다.
- refresh token은 서버 로그, Firestore, Realtime Database에 저장하지 않는다.
- 메모리 상향은 `deleteAccount` 단일 함수에만 적용돼 다른 함수의 실행 비용에는 영향을 주지 않는다.

## 남은 작업

1. PR #183 검토 후 개발자가 직접 `dev`에 병합한다.
2. 병합된 앱을 실기기에 설치해 네이버 계정 탈퇴 전 과정을 검증한다.
3. 탈퇴 직후 네이버 연결 서비스에서 Pacing 연동이 제거됐는지 확인한다.
