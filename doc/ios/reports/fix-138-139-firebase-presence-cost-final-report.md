# activeRunners Firebase 위치 공유 비용 최적화 최종 개발 보고서

> **관련 이슈**: [#138](https://github.com/kec08/Pacing/issues/138), [#139](https://github.com/kec08/Pacing/issues/139)  
> **작성일**: 2026-09-10  
> **브랜치**: `fix/138-139-firebase-presence-cost`  
> **상태**: `dev` 대상 PR 생성

## 1. 구현 요약

`activeRunners` 위치 공유에서 발생하던 불필요한 Firebase Realtime Database 읽기·쓰기 요청을 줄였다. 위치 전송 정책을 상태별로 분리하고, 전체 snapshot observer를 child 이벤트 observer로 변경해 기본 위치 공유 기능은 유지하면서 Firebase 과금 및 네트워크 사용량을 낮췄다.

## 2. 변경 사항

- 포그라운드, 백그라운드, 러닝 상태별 위치 전송 정책 적용
  - 포그라운드: 최소 15초 또는 30m 이동
  - 백그라운드: 최소 60초 또는 50m 이동
  - 러닝: 최소 5초 또는 10m 이동
- 동일 위치·동일 곡에 대한 반복 `activeRunners` write 차단
- 곡이 변경되면 위치가 같아도 최신 곡 정보를 반영
- `activeRunners`의 전체 `.value` observer를 `childAdded`, `childChanged`, `childRemoved` observer로 변경
- observer 재등록 전 기존 observer 및 stale 정리 타이머 해제
- 30초 주기로 로컬 stale 러너 캐시 정리
- stale 러너의 단건 조회 결과를 반환하지 않도록 필터링
- 기존 `onDisconnectRemoveValue`, 브로드캐스트 중지 시 데이터 삭제 동작 유지
- MainTab 및 Running 화면의 위치·곡 갱신 경로에 러닝 상태 전달

## 3. 과금 방지 효과

- 기존에는 한 명의 위치가 변경될 때마다 `activeRunners` 전체 snapshot을 다시 처리했다.
- 변경 후에는 변경된 child 데이터만 전달받아 전체 목록 재다운로드를 방지한다.
- 5초 타이머는 유지하지만 실제 Firebase write 전에 시간·거리·곡 변경 정책을 검사한다.
- 다른 사용자의 stale 데이터를 클라이언트가 임의 삭제하지 않는다. 현재 Realtime Database 규칙상 타 사용자 데이터 삭제 권한을 추가하지 않고, `onDisconnect`와 로컬 stale 필터로 안전하게 처리했다.

## 4. QA 결과

| 항목 | 결과 | 비고 |
| --- | --- | --- |
| `git diff --check` | ✅ 통과 | 변경 파일 기준 |
| Debug iOS Simulator 빌드 | ✅ 통과 | `xcodebuild -quiet -project Pacing/Pacing.xcodeproj -scheme Pacing -sdk iphonesimulator -configuration Debug -derivedDataPath /private/tmp/pacing-derived-data CODE_SIGNING_ALLOWED=NO build` |
| 기존 위치 공유 API 호환성 | ✅ 코드 검증 | 기존 메서드 시그니처 기본 동작 유지 |
| 위치 주기·이동 거리 제한 | ✅ 코드 검증 | 상태별 정책 적용 확인 |
| child observer 등록·해제 | ✅ 코드 검증 | 중복 등록 및 화면 이탈 해제 확인 |
| stale 러너 필터링 | ✅ 코드 검증 | 캐시·단건 조회 모두 적용 |
| 자동 테스트 | ⏳ 실행 보류 | CoreSimulatorService 장애 및 구체적인 Simulator 대상 확인 실패 |
| 실기기 Firebase 과금·네트워크 확인 | ⏳ 추가 확인 필요 | 개발자 실기기 QA 필요 |

## 5. 알려진 제한사항 및 후속 작업

- 서버에 이미 남아 있는 타 사용자의 stale 데이터를 클라이언트가 직접 삭제하지 않는다. 운영 정리까지 필요하면 Cloud Functions 기반 TTL 정리 작업을 별도 검토해야 한다.
- Firebase 콘솔의 실제 다운로드량·쓰기량은 실기기 2대 이상으로 위치 이동 및 러닝 상태를 재현해 최종 확인해야 한다.
- 기존 코드에서 발생하는 iOS 26 `UIScreen.main` deprecation warning은 이번 변경 범위에 포함하지 않았다.

## 6. 주요 커밋

- `8e6ed54 fix: active runner Firebase 전송 및 구독 비용 최적화 (#138, #139)`

> PR은 자동 병합하지 않으며, 최종 검토와 병합은 개발자가 직접 진행한다.
