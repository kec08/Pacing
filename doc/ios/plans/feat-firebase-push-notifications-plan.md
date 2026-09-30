# Firebase 푸시 알림 기능 계획서

> **상태**: 검토 대기
> **작성일**: 2026-09-30
> **관련 이슈**: [#203](https://github.com/kec08/Pacing/issues/203)
> **예정 브랜치**: `feat/203-firebase-push-notifications`

---

## 1. 목적 및 배경

친구의 러닝 시작과 친구 요청을 즉시 알려 사회적 러닝 참여를 높이고, 매일 저녁 8시(KST)에 페이싱의 음악 중심 운동 리마인더를 제공한다. 또한 최근 러닝이 없는 사용자는 휴식 기간에 맞춘 재시작 리마인더로 부담 없이 운동 습관을 회복하도록 돕는다. 전송 권한과 대상 판별은 iOS 클라이언트가 아닌 Firebase Cloud Functions에서 수행한다.

## 2. 사용자 시나리오

```
친구가 러닝을 시작해 activeRunners에 최초 등록된다
→ 서버가 상호 친구의 등록된 기기로 FCM 알림을 전송한다
→ 수신자가 알림을 탭하면 앱이 해당 러너의 러닝 화면으로 이동한다

사용자가 친구 요청을 보낸다
→ friendRequests에 pending 요청이 생성된다
→ 서버가 요청 수신자에게 알림을 전송한다
→ 수신자가 알림을 탭하면 친구 요청 목록으로 이동한다

매일 20:00 (Asia/Seoul)
→ 서버 스케줄러가 최근 러닝 이력과 마지막 리마인더 전송일을 확인한다
→ 장기 미러닝 대상에게는 개인화된 재시작 리마인더를, 나머지에게는 일반 리마인더를 전송한다
→ 알림을 탭하면 러닝 탭으로 이동한다
```

## 3. 알림 UX 및 문구

| 유형 | 제목 | 본문 | 탭 동작 |
|---|---|---|---|
| 친구 러닝 시작 | `친구가 러닝을 시작했어요` | `{닉네임}님과 같이 달려볼까요?` | 러닝 탭 및 해당 친구 러너 표시 |
| 친구 요청 | `새로운 친구 요청` | `{닉네임}님이 친구 요청을 보냈어요.` | 친구 요청 목록 |
| 저녁 리마인더 | `오늘도 페이싱과 달려볼까요?` | `좋아하는 노래와 함께 오늘 하루를 기분 좋게 마무리해요.` | 러닝 탭 |
| 휴식 기간 재시작 | `잠시 쉬었다면, 오늘은 가볍게 다시 달려볼까요?` | `가벼운 러닝으로 다시 페이스를 찾아봐요.` | 러닝 탭 |

알림 권한은 온보딩 완료 후 사용 맥락을 설명한 뒤 1회 요청한다. 거부·토큰 미등록 사용자는 조용히 제외하며, 권한 변경은 iOS 설정 화면에서 안내한다.

## 4. 아키텍처 및 데이터 흐름

### iOS

- `FirebaseMessaging` SPM 의존성과 Push Notifications / Background Modes(Remote notifications) capability를 추가한다.
- `AppDelegate`가 APNs 토큰을 FCM에 연결하고, FCM 등록 토큰 갱신을 `NotificationDeviceRepository`를 통해 Firestore에 저장한다.
- `NotificationPermissionUseCase`가 권한 상태 조회·요청을 담당한다. View는 권한 안내와 결과 표현만 담당한다.
- `NotificationRouter`가 `userInfo.type`과 식별자를 해석해 `AppState`의 탭/딥링크 상태를 갱신한다. 포그라운드에서는 배너·사운드를 표시한다.

### Firestore

```
users/{uid}/notificationDevices/{installationID}
  token: String
  platform: "ios"
  updatedAt: serverTimestamp

users/{uid}/notificationPreferences/default
  lastInactivityReminderAt: Timestamp
  lastInactivityMilestoneDays: Number
```

- 클라이언트는 자기 기기 문서만 생성·갱신·삭제할 수 있고 읽기는 허용하지 않는다.
- Functions Admin SDK만 친구 관계와 기기 토큰을 읽는다.
- 휴식 기간 알림 상태 문서는 Functions만 기록한다. 사용자의 마지막 완료 러닝은 `users/{uid}/runHistory`의 최신 기록으로 계산한다.
- 계정 탈퇴 시 해당 하위 컬렉션도 기존 `recursiveDelete` 흐름으로 함께 정리된다.

### Cloud Functions

- Firestore `friendRequests/{requestID}` 생성 트리거: `pending` 요청만 전송하며 발신자 프로필 닉네임을 사용한다.
- Realtime Database `activeRunners/{uid}` 생성 트리거: 해당 UID의 친구 목록만 조회해 전송한다. 동일 러닝 중 위치·곡 갱신은 `childChanged`이므로 재전송하지 않는다.
- Scheduled Function: `0 20 * * *`, timezone `Asia/Seoul`로 매일 실행한다. 일반 저녁 리마인더와 휴식 기간 재시작 리마인더 중 하나만 사용자별로 발송한다.
- 휴식 기간 재시작 리마인더는 마지막 완료 러닝 이후 3일, 7일, 14일째에 한 번씩 발송한다. 14일 이후에는 과도한 재촉을 피하기 위해 7일 간격으로만 발송한다. 새 러닝 완료 시 해당 발송 이력은 초기화한다.
- 공통 `sendMulticastNotification`은 최대 500개 단위 전송, 성공·실패를 기록하고 `registration-token-not-registered` / `invalid-registration-token`은 Firestore에서 정리한다.
- payload는 `type`, `senderUID` 또는 `requestID`를 포함하며 알림 본문에는 위치·민감 정보·FCM 토큰을 넣지 않는다.

## 5. 작업 목록

- [ ] Task 1: Firebase Messaging SPM, APNs capability, Info.plist 및 앱 델리게이트 등록 흐름 구성
- [ ] Task 2: 알림 권한 UseCase·Device Repository·Firestore 규칙·토큰 수명주기 구현
- [ ] Task 3: 앱 실행/포그라운드/백그라운드 알림 라우팅 및 친구 요청·러닝 딥링크 연결
- [ ] Task 4: 친구 요청 Firestore 트리거와 친구 러닝 시작 Realtime Database 트리거 구현
- [ ] Task 5: KST 20:00 리마인더 Scheduled Function 및 무효 토큰 정리 구현
- [ ] Task 6: 마지막 러닝 기준 휴식 기간(3일·7일·14일·매주) 재시작 리마인더 및 중복 발송 방지 상태 구현
- [ ] Task 7: Functions 단위 테스트, iOS 테스트, 실기기 APNs/FCM QA 및 배포 점검

## 6. 완료 기준

- [ ] 로그인 후 알림 권한을 허용한 iPhone에서 FCM 토큰이 사용자별 기기 문서에 등록·갱신된다.
- [ ] 친구 요청 수신자만 친구 요청 알림을 받고, 알림 탭 시 친구 요청 목록이 열린다.
- [ ] 러닝 시작자의 친구만 러닝 시작당 한 번 알림을 받고, 위치·음악 갱신으로 중복 알림이 발송되지 않는다.
- [ ] 매일 한국 시간 20:00에 유효 토큰을 가진 사용자에게 지정 문구의 리마인더가 발송된다.
- [ ] 마지막 러닝 후 3일·7일·14일 및 이후 7일 간격에만 재시작 리마인더가 발송되며, 같은 날 일반 저녁 리마인더와 중복되지 않는다.
- [ ] 새 러닝을 완료하면 휴식 기간 알림 단계가 초기화된다.
- [ ] 무효·폐기 FCM 토큰이 자동 삭제되고, Functions 오류가 수신자 경험을 중단시키지 않는다.
- [ ] 다크 모드·백그라운드·종료 상태에서 알림 탭 동작을 확인한다.

## 7. 예상 소요 시간

| 작업 | 예상 시간 |
|---|---:|
| iOS Messaging·권한·라우팅 | 5시간 |
| 토큰 저장·규칙 | 2시간 |
| Functions 트리거·스케줄러·휴식 기간 정책 | 7시간 |
| 테스트·실기기 QA | 5시간 |
| **합계** | **19시간** |

## 8. 기술 검토 및 결정 사항

- Cloud Scheduler 기반 예약 함수는 Firebase Blaze 요금제가 필요하다. 개발 전 프로젝트 요금제와 Apple Developer APNs 키/Firebase 콘솔 업로드 상태를 확인한다.
- `activeRunners`는 위치가 유효할 때 최초 기록된다. 따라서 "러닝 시작" 알림의 정확한 정의는 해당 경로의 최초 생성 시점이다.
- 다기기 사용자를 지원해 FCM 토큰을 사용자 문서 단일 필드가 아닌 기기 하위 컬렉션으로 관리한다.
- 친구 러닝 알림은 수신자별 수신 설정, 야간 방해 금지, 빈도 제한을 이번 범위에 포함하지 않는다. 실제 사용량 확인 후 알림 설정 화면을 별도 이슈로 분리한다.
- 휴식 기간 기준은 습관 형성을 돕되 알림 피로를 막기 위해 3일·7일·14일·매주로 제한한다. 향후 사용자별 목표와 알림 수신 설정이 도입되면 기준을 개인화한다.
- Functions 배포와 APNs 콘솔 설정은 코드 검토 승인 후에만 수행한다.

---

> **검토 의견** (개발자 작성):
> 승인 여부: 승인 ✅ / 수정 요청 🔄
