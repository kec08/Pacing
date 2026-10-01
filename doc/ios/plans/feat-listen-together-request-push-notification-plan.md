# 같이 듣기 요청 푸시 알림 계획서

관련 이슈: [#209](https://github.com/kec08/Pacing/issues/209)

## 목표

친구가 러닝 중인 사용자에게 같이 듣기 요청을 보내면, 수신자가 앱을 백그라운드에 두었거나 화면을 보지 않는 상황에서도 iOS 푸시 알림으로 즉시 인지하고 요청 확인 화면으로 이동할 수 있게 한다.

## 현황 및 문제

- 요청 생성 시 Realtime Database의 `listenSessions`와 수신자별 `incomingRequests/{hostUID}/{sessionID}`가 함께 생성된다.
- iOS 앱은 `incomingRequests`를 실시간 구독하여 앱이 활성 상태일 때 요청 시트와 햅틱을 표시한다.
- Firebase Cloud Functions는 친구 요청과 친구 러닝 시작에 대한 FCM 발송만 제공하며, 같이 듣기 요청에 대한 RTDB 트리거는 없다.
- 따라서 앱이 백그라운드이거나 러닝 화면을 보지 않을 때 요청을 놓칠 수 있다.

## 구현 범위

1. **서버 푸시 발송**
   - `incomingRequests/{recipientUID}/{sessionID}` 생성 이벤트를 수신하는 Firebase Functions v2 RTDB 트리거를 추가한다.
   - 생성 데이터의 요청자 닉네임·세션 ID·요청자 UID를 이용해 수신자의 등록 FCM 토큰 전체에 알림을 발송한다.
   - 데이터 페이로드는 `type: listenTogetherRequest`, `sessionID`, `senderUID`를 포함하고, 제목/본문은 러닝 중에도 짧고 명확하게 구성한다.
   - 기존 `sendNotification` 공통 함수와 유효하지 않은 토큰 정리 정책을 재사용한다.

2. **iOS 알림 라우팅 및 화면 복귀**
   - `NotificationRouter`에 `listenTogetherRequest` 목적지를 추가한다.
   - 앱이 포그라운드일 때는 배너·사운드를 표시하고, 백그라운드/종료 상태에서 알림을 탭하면 러닝 탭으로 이동하도록 `AppState`와 메인 탭의 라우팅을 보강한다.
   - 러닝 화면이 표시된 뒤 기존 `ListenTogetherViewModel`의 `incomingRequests` 구독 결과를 사용해 요청 수락/거절 시트를 표시한다. 푸시 페이로드만으로 세션을 복원하지 않아, 취소·거절된 오래된 알림으로 잘못된 요청을 표시하지 않는다.

3. **중복 및 수명 주기 처리**
   - 푸시는 `incomingRequests`의 새 요청 생성에만 발송한다. 세션 재생 상태 업데이트·앱 재연결·단순 RTDB 읽기에는 추가 발송하지 않는다.
   - 기존 ViewModel의 `lastIncomingRequestID` 중복 방지와 요청 수락/거절 시 `incomingRequests` 삭제 흐름을 유지한다.
   - 알림을 탭했을 때 이미 처리된 세션이면 러닝 화면만 유지하고 요청 시트를 띄우지 않는다.

## 아키텍처 및 변경 예상 지점

| 계층 | 변경 내용 |
| --- | --- |
| Firebase Functions | RTDB 생성 트리거와 FCM 페이로드 추가 |
| Notification | 알림 타입/목적지 추가, 기존 토큰 저장·발송 공통화 재사용 |
| AppState / Main | 푸시 탭 이벤트를 러닝 탭 전환으로 전달 |
| Running ViewModel | 기존 요청 구독 결과로 시트 상태를 복원하고 중복 표시 방지 |
| UI | 기존 같이 듣기 요청 UI를 재사용하며, 별도 비즈니스 로직을 View에 추가하지 않음 |

## UX·접근성 기준

- 알림 문구는 요청자와 행동을 한 문장으로 알린다. 예: “민지님이 같이 듣기를 요청했어요.”
- 러닝 중 화면을 보지 않아도 기본 알림 사운드와 배너로 인지할 수 있어야 한다.
- 알림 탭 후에는 추가 탐색 없이 러닝 화면의 기존 요청 시트에서 수락/거절을 선택할 수 있어야 한다.
- 요청이 이미 종료된 경우에는 오류 안내나 빈 시트를 띄우지 않는다.

## 검증 계획

- Functions 단위/로컬 검증: `incomingRequests` 생성 시 대상 사용자의 토큰으로 한 번만 `listenTogetherRequest` 페이로드가 발송되는지 확인
- iOS 단위 테스트: `NotificationRouter`가 새 타입을 러닝 목적지로 변환하는지 확인
- 실기기 QA: 포그라운드, 백그라운드, 앱 종료 상태에서 알림 수신·탭·요청 시트 표시를 확인
- 회귀 QA: 친구 요청/친구 러닝 시작/일일 알림 라우팅과 기존 같이 듣기 요청의 수락·거절·종료가 유지되는지 확인
- 배포 전: Firebase Functions 배포 대상·APNs/FCM 설정과 `git diff --check` 확인

## 완료 기준

- 친구의 같이 듣기 요청마다 수신자의 등록 iPhone 기기에 FCM 푸시가 한 번 발송된다.
- 러닝 중이거나 앱이 백그라운드여도 알림으로 요청을 인지할 수 있다.
- 알림 탭 시 유효한 요청은 기존 수락/거절 흐름으로 이어지고, 무효 요청은 표시되지 않는다.
- 기존 알림 및 같이 듣기 기능에 회귀가 없다.

## 제외 범위

- Apple Watch 전용 알림 전달 및 watchOS 요청 수락 UI
- 사용자별 같이 듣기 푸시 수신 설정 화면
- 요청 수락/거절 결과를 요청자에게 별도 푸시로 알리는 기능
