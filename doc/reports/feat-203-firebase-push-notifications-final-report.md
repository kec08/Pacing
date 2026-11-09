# Firebase 푸시 알림 기능 최종 개발 보고서

> **완료일**: 2026-09-30
> **관련 이슈**: [#203](https://github.com/kec08/Pacing/issues/203)
> **PR**: [#204](https://github.com/kec08/Pacing/pull/204)
> **브랜치**: `feat/203-firebase-push-notifications`

---

## 구현 요약

Firebase Cloud Messaging과 Cloud Functions v2를 이용해 친구 요청, 친구 러닝 시작, 저녁 리마인더, 휴식 기간 재시작 알림을 구현했습니다.

## 구현된 기능 목록

- [x] iOS APNs 권한·FCM 토큰 등록 및 토큰 갱신
- [x] 알림 탭 시 친구 또는 러닝 탭으로 라우팅
- [x] 친구 요청 Firestore 생성 알림
- [x] 친구 러닝 시작 Realtime Database 생성 알림
- [x] 매일 20:00 KST 리마인더
- [x] 3일·7일·14일 및 이후 주 1회 휴식 기간 리마인더
- [x] 만료 FCM 토큰 자동 삭제 및 새 러닝 후 휴식 단계 초기화

## 배포 및 QA 결과

| 항목 | 결과 |
|---|---|
| Firestore Rules 컴파일 | ✅ 통과 |
| Functions 문법·트리거 export | ✅ 통과 |
| Functions 4개 배포 | ✅ 완료 |
| Scheduler | ✅ `0 20 * * *`, `Asia/Seoul`, Enabled |
| 20시 예약 함수 실행 | ✅ 실행 로그 확인 |
| 실기기 FCM 수신 | ⏳ 신규 빌드 실행·권한 허용·토큰 등록 후 확인 필요 |
| 전체 스킴 빌드 | ⚠️ 기존 WatchKit/Watch Asset Catalog 구성 오류로 실패 |

## 발견 및 수정된 이슈

| 이슈 | 상태 |
|---|---|
| Realtime Database가 `us-central1`인데 Functions 기본 리전은 `asia-northeast3`인 문제 | ✅ 트리거 전용 리전을 `us-central1`으로 수정 |
| 기존 가입자가 온보딩을 거치지 않아 알림 권한과 FCM 토큰 등록을 하지 않는 문제 | ✅ 메인 화면 진입 시 권한 요청·토큰 동기화 추가 |

## 알려진 제한사항

- Firebase Console의 APNs 인증 키 등록과 실기기 권한 허용이 완료돼야 실제 수신을 검증할 수 있습니다.
- Watch는 iPhone 알림 미러링으로 수신하며, Watch 단독 APNs 푸시는 이번 범위에 포함하지 않았습니다.
- Scheduler 실행은 확인됐으나 토큰 미등록 기기에는 알림이 발송되지 않습니다.

---

> **개발자 검토 의견**:
> 최종 승인: 승인 ✅ / 재작업 🔄
