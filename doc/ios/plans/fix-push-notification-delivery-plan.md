# #215 전체 푸시 알림 수신 실패 진단·복구 계획서

> **상태**: 구현 완료 · 실기기 QA 대기<br>
> **작성일**: 2026-10-02<br>
> **관련 이슈**: [#215](https://github.com/kec08/Pacing/issues/215)<br>
> **브랜치**: `fix/215-push-notification-delivery`

## 목적

친구 러닝·친구 요청·같이 듣기·20:00 리마인더의 공통 푸시 전달 경로를 진단하고, APNs·FCM·Firestore 토큰·Cloud Functions 실패 지점을 실기기에서 식별 가능하게 한다. 발신자 이름은 실시간 데이터가 아닌 Firestore 프로필 닉네임을 우선 사용해 모든 푸시에서 일관되게 표시한다.

## 구현 항목

- [x] APNs 등록 성공 후 FCM 토큰을 즉시 재동기화한다.
- [x] APNs 등록 실패, FCM 토큰 발급 실패, Firestore 토큰 저장 실패를 iOS 로그로 기록한다.
- [x] Functions가 토큰 부재, 전송 성공·실패 수, FCM 오류 코드를 유형별로 기록한다.
- [x] 친구 요청·친구 러닝·같이 듣기 푸시의 발신자 이름을 Firestore 프로필 닉네임 우선으로 통일한다.
- [x] 프로필 조회가 실패해도 보조 이름으로 푸시 전송을 계속한다.
- [x] Functions 문법 검사와 변경 파일의 공백 오류를 검증한다.
- [ ] 두 실기기 계정으로 친구 요청·러닝·같이 듣기 수신을 확인한다.
- [x] Firebase Console에 APNs 개발·프로덕션 키를 등록하고, 테스트 푸시 전송 성공을 확인한다.
- [ ] 20:00 KST 스케줄 알림을 Functions 로그로 확인한다.

## 실기기 QA 체크리스트

1. 수신 기기에서 알림 권한을 허용하고 앱을 다시 실행한다.
2. Xcode 콘솔에서 `APNs token registered`, `FCM token synchronized to Firestore` 로그를 확인한다.
3. Firebase Console Firestore에서 `users/{uid}/notificationDevices/{installationID}` 문서가 생성·갱신됐는지 확인한다.
4. 발신·수신 계정을 달리해 친구 요청, 친구 러닝 시작, 같이 듣기 요청을 각각 발생시킨다.
5. Cloud Functions 로그에서 `Push notification delivery result`의 성공 수와 오류 코드를 확인한다.
6. 실패 시 Firebase Console의 APNs 키 Team ID·Key ID·Bundle ID와 설치 빌드의 `aps-environment`를 대조한다.

## 검증 결과

- APNs 키 등록 전에는 `messaging/third-party-auth-error`로 전송이 실패했다.
- APNs 개발·프로덕션 키 등록 후 같이 듣기 테스트 푸시는 `successCount: 1`, `failureCount: 0`으로 전달됐다.
- 테스트용 Realtime Database 요청 데이터는 검증 뒤 제거했다.
- 전체 iPhone Debug 빌드는 기존 Watch 앱 자산 컴파일 단계에서 실패했다. 이번 변경은 iOS 앱 코드가 아닌 Cloud Functions 코드만 수정한다.

## 현재 제한

- 친구 요청·친구 러닝·20:00 스케줄은 서로 다른 실기기 계정으로 추가 QA가 필요하다.
