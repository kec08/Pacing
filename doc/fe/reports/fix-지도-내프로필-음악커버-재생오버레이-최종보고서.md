# #80 지도 내 프로필·음악 커버·재생 오버레이 최종 보고서

> **상태**: 완료
> **작성일**: 2026-07-31
> **이슈**: #80
> **브랜치**: `fix/80-map-profile-artwork-overlay`

## 결과

- 지도는 시스템 `userLocation` 초기 표시를 제거하고, 현재 위치에 프로필·현재 재생 곡을 담은 커스텀 핀만 표시한다.
- 내 프로필 이미지는 Firestore에서 갱신해 핀에 반영하고, 프로필 정보가 준비되지 않은 동안에도 빨간 일반 위치 점 대신 중립 색상 폴백을 사용한다.
- 홈의 친구 최근 음악은 저장된 Base64, 원격 URL, Apple Music 카탈로그 재조회, 기본 커버 순서로 표시한다.
- 재생 중인 홈 음악 카드는 고정된 112×112 커버 영역에서만 딤 레이어와 5개 음파를 표시한다. 그림자와 크기 확대 전환은 제거했다.

## 원인과 조치

| 항목 | 원인 | 조치 |
| --- | --- | --- |
| 지도 빨간 위치 점 | 초기 카메라의 `.userLocation` 설정이 시스템 위치 표시를 동반할 수 있음 | `.automatic`으로 시작하고 위치 수신 후 커스텀 카메라 이동 |
| 추천·친구 음악 커버 누락 | 오래된 Firestore 이력 또는 MusicKit 응답에 대표 이미지 정보가 없음 | 카탈로그 보조 조회 및 이미지 캐시 적용 |
| 홈 재생 카드 확대 | 재생 오버레이의 그림자·스케일 전환이 카드 밖으로 확장됨 | 고정 프레임 안에서 딤/음파만 표시 |

## 검증

- `git diff --check` 통과
- `xcodebuild -project Pacing/Pacing.xcodeproj -scheme Pacing -sdk iphonesimulator -configuration Debug build` 통과

## 커밋

- `b972baf fix: 지도 프로필과 음악 커버 표시 복구 (#80)`
- `4f26573 fix: 지도 위치 점과 홈 음악 카드 보완 (#80)`

## 제외된 사용자 변경

- `Pacing/Pacing.xcodeproj/project.pbxproj`
- `Pacing/Pacing/Pacing.entitlements`
