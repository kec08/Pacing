# 같이 듣기 요청 푸시 알림 최종 개발 보고

관련 이슈: [#209](https://github.com/kec08/Pacing/issues/209)

## 변경 사항

- Firebase Functions에 `incomingRequests/{recipientUID}/{sessionID}` 생성 이벤트를 처리하는 `notifyListenTogetherRequest` 트리거를 추가했다.
- 수신자의 등록된 모든 FCM 기기에 요청자 닉네임, 세션 ID, 요청자 UID를 담은 `listenTogetherRequest` 푸시를 발송한다.
- `listenSessions`가 아닌 수신함 생성 이벤트만 감지해 재생 위치 동기화에 따른 중복 알림을 방지한다.
- iOS 알림 라우터가 새 푸시 타입을 러닝 탭으로 연결한다. 러닝 화면은 기존 실시간 요청 구독 결과를 사용하므로, 이미 처리된 요청은 표시하지 않는다.
- 새 푸시 타입의 라우팅과 알 수 없는 타입 무시를 단위 테스트로 추가했다.

## 검증 결과

- `node --check functions/functions/index.js` 통과
- `xcodebuild build -project Pacing/Pacing.xcodeproj -scheme Pacing -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO` 통과
- 변경 파일 대상 `git diff --check` 통과

## QA 미완료 항목

- 현재 환경에는 사용 가능한 iOS Simulator가 없어 자동 UI 테스트를 실행하지 못했다.
- Firebase Functions 배포 전이므로 FCM 실수신 및 포그라운드·백그라운드·앱 종료 상태의 실기기 QA는 미완료다.
- 배포 후 두 계정으로 요청 생성, 푸시 수신, 알림 탭 후 수락/거절, 처리된 알림 재탭을 확인해야 한다.

## 배포 유의사항

- 이 변경은 Firebase Functions 배포가 있어야 푸시 발송이 활성화된다.
- APNs와 FCM 설정, 수신 기기의 알림 권한 및 FCM 토큰 저장 상태가 필요하다.
