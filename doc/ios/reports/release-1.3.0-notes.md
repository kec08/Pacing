# Pacing 1.3.0 업데이트·심사 문구

기준: `main` 8119427 (1.2.2) → `dev` c06f0fb. 아래 기능은 모두 이 구간에 병합된 PR과 코드에서 확인했습니다.

## App Store 업데이트 내용

Pacing 1.3.0 업데이트

Apple Watch와 함께 달리는 경험이 새로워졌어요!

Apple Watch에서 러닝을 시작하고 제어할 수 있어요.
거리, 현재·평균 페이스, 심박수와 최근 러닝 기록을 손목에서 확인해 보세요.

러닝을 음성으로 안내해 드려요.
시작, 일시정지, 재개와 1km 구간 기록, 운동 종료 요약을 한국어로 들을 수 있어요. 오프라인에서도 안내가 이어져요.

러닝 기록을 사진으로 공유해 보세요.
거리, 기록, 경로 중 원하는 양식을 골라 촬영하고 공유할 수 있어요.

친구와 함께 달리는 순간을 놓치지 마세요.
친구 요청, 친구의 러닝 시작과 같이 듣기 요청을 푸시 알림으로 받아볼 수 있어요.

러닝 거리와 페이스, Apple Watch 동기화도 더 안정적으로 다듬었어요.
새로운 Pacing 1.3.0과 함께 달려보세요!

## App Review 메모

Hello App Review Team,

Thank you for reviewing Pacing 1.3.0.

This update adds:

- An Apple Watch app for starting and controlling runs, viewing live distance, pace and heart rate, and checking recent run history.
- Korean offline voice guidance for run state changes, kilometer splits and the final run summary.
- Camera-based sharing of run results with distance, time or route overlays.
- Push notifications for friend requests, friends starting runs and listen-together requests.

Test account:

Email: [REVIEWER_ACCOUNT_EMAIL]
Password: [REVIEWER_ACCOUNT_PASSWORD]

Testing instructions:

1. Sign in with the review account.
2. Start a run on iPhone or Apple Watch to check the synchronized run controls and metrics. A paired Apple Watch with HealthKit permissions is needed to test the Watch features.
3. Pause, resume and finish the run to hear the Korean guidance. The guidance also works without a network connection after installation.
4. Open a completed run in the activity detail screen, tap Share, choose a result format and capture a photo to review the share preview.
5. With two connected accounts, send a friend or listen-together request to check the corresponding notifications. Notification permission is required.

Apple Music permission and an active subscription are needed to test music playback and listen-together controls on Apple Watch. Location permission is needed for route recording. Heart rate requires available HealthKit data.

Thank you for reviewing Pacing 1.3.0.

## 근거 PR

- Apple Watch 러닝·기록·음악: #161, #166, #172, #174, #186, #192, #212, #226, #229
- 한국어 러닝 음성: #157, #190, #202, #224, #229
- 러닝 기록 사진 공유: #219, #221
- 푸시 알림: #204, #210, #216
- 러닝 지표·거리 보정: #214, #223, #226, #229

## 아카이브 업로드 QA

- Watch AppIcon 원본은 1024×1024 RGBA였고 모서리가 투명했습니다. 검정 배경에 합성해 RGB PNG로 저장했습니다. `sips`에서 `hasAlpha: no`, 빌드된 Watch `Assets.car`의 AppIcon에서 `Opaque: true`를 확인했습니다.
- iOS/Watch 통합 Debug 빌드(`generic/platform=iOS`, 코드 서명 제외)가 통과했습니다.
- 2026-11-09 아카이브의 누락 dSYM UUID 6개는 `FirebaseFirestoreInternal`, `absl`, `grpc`, `grpcpp`, `onnxruntime`, `openssl_grpc` 바이너리와 모두 일치합니다. 아카이브와 현재 SwiftPM artifact에는 해당 dSYM이 없고, 바이너리의 DWARF compile unit도 0개입니다. 앱 타깃의 Release 설정은 이미 `dwarf-with-dsym`입니다. 이 패키지들의 정확한 dSYM은 배포처가 제공하거나 같은 소스로 다시 빌드해야 하므로 이번 릴리스 코드에서 생성할 수 없습니다.
- 실제 App Store Connect 재업로드와 실기기 러닝·음성·알림 QA는 아직 진행하지 않았습니다.
