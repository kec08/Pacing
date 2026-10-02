# #215 푸시 알림 전달 복구 최종 보고서

## 상태

개발 완료 · PR 검토 대기

## 관련 이슈

- https://github.com/kec08/Pacing/issues/215
- PR: https://github.com/kec08/Pacing/pull/216
- 브랜치: `fix/215-push-notification-delivery`

## 구현 내용

- APNs 등록 성공 뒤 FCM 토큰을 즉시 다시 동기화하고, APNs 등록·FCM 토큰 발급·Firestore 저장의 성공 또는 실패를 iOS 로그로 남겼다.
- Cloud Functions가 토큰 부재, 전송 성공·실패 수, FCM 오류 코드를 알림 유형별로 기록하도록 보강했다.
- 친구 요청·친구 러닝·같이 듣기 알림의 발신자 이름을 Firestore 프로필 닉네임 우선으로 통일했다.
- 프로필 조회가 실패해도 기존 이벤트의 이름을 보조값으로 사용해 푸시 전송 자체는 계속되도록 했다.
- Firebase Console에 APNs 개발·프로덕션 인증 키를 등록하고, 관련 Functions를 배포했다.

## 운영 검증 결과

| 항목 | 결과 |
| --- | --- |
| APNs 인증 키 등록 전 같이 듣기 푸시 | `messaging/third-party-auth-error`로 실패 |
| APNs 인증 키 등록 후 테스트 푸시 | `successCount: 1`, `failureCount: 0` |
| 실제 같이 듣기 요청 | 등록 기기 2대에 `successCount: 2`, `failureCount: 0` |
| 친구 러닝 시작 | 등록 토큰이 있는 기기에 전송 성공 로그 확인 |
| 친구 요청 트리거 | Firestore 생성 이벤트 Function `ACTIVE` 확인 |
| 20:00 KST 리마인더 | 스케줄 Function `ACTIVE`, 매일 실행 로그 확인 |

## 코드 검증

| 항목 | 결과 |
| --- | --- |
| `node --check functions/functions/index.js` | ✅ 통과 |
| `git diff --check` | ✅ 통과 |
| iPhone Debug 빌드 | ⚠️ 기존 Watch 앱 자산 컴파일 단계 실패; 이번 Cloud Functions 변경과 무관 |

## 발견 및 조치

| 이슈 | 상태 |
| --- | --- |
| Firebase APNs 인증 키 미등록으로 인한 FCM third-party auth 오류 | ✅ 개발·프로덕션 키 등록으로 해결 |
| 오래되었거나 삭제된 설치의 토큰이 남을 수 있음 | ✅ 전송 실패 시 무효 토큰 자동 삭제, 앱 실행 시 최신 토큰 재저장 |
| 등록된 토큰이 없는 친구는 러닝 시작 푸시를 받을 수 없음 | ⚠️ 해당 기기에서 앱 실행·로그인 후 토큰 등록 필요 |

## 남은 QA

- 친구 요청을 서로 다른 실기기 계정으로 한 번 발송해 수신을 확인한다.
- 오늘 20:00 KST 실행 뒤 `sendEveningRunReminders`의 실제 전송 결과를 확인한다.
- 수신 기기에서 iOS 알림 허용, 배너·알림 센터 표시 및 집중 모드 상태를 확인한다.

## 커밋

- `0e469d6 fix: 푸시 알림 전달 진단 로그 보강 (#215)`
- `c09a6b1 fix: 푸시 발신자 닉네임을 프로필 기준으로 통일 (#215)`

---

> **개발자 검토 의견**:  
> 최종 승인: 승인 ✅ / 재작업 🔄
