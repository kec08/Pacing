# #82 프로필 활동 매핑·음악 커버 보강 최종 보고서

> **상태**: PR 준비 완료
> **작성일**: 2026-07-31
> **관련 이슈**: #82
> **브랜치**: `feat/82-profile-activity-artwork`

## 구현 결과

- 마이 화면의 그래프 막대를 탭하면 차트 바로 아래에 선택 날짜 전용 러닝 카드 영역이 열린다.
- 동일 날짜를 다시 탭하면 영역이 닫히고, 다른 날짜를 선택하면 해당 날짜의 기록으로 교체된다.
- 날짜 제목은 숫자(`2026`, `7`, `21`)만 메인 핑크로 강조하고, `년·월·일·수요일 러닝`은 기본 텍스트 색을 유지한다.
- 선택 영역은 그래프 안이 아닌 차트 아래에서만 짧은 투명도·오프셋 전환으로 표시한다.
- 내 프로필에 최근 러닝을 추가하고, 내·친구 프로필의 최근 음악을 최대 5개로 제한했다.
- 음악 커버는 저장 Base64 → Apple Music 카탈로그 보조 URL → 기존 URL → 기본 커버 순서로 표시한다.

## QA

- `xcodebuild -project Pacing/Pacing.xcodeproj -scheme Pacing -sdk iphonesimulator -configuration Debug build` 성공
- `git diff --check` 통과

## 앱스토어 1.1.2 준비 메모

- 이번 PR 머지 후 버전 `1.1.2`와 빌드 번호를 확정한다.
- Release Archive, 실제 기기 QA, 개인정보·심사 정보·스크린샷 점검은 별도 배포 체크리스트에서 진행한다.

## 제외된 사용자 변경

- `Pacing/Pacing.xcodeproj/project.pbxproj`
- `Pacing/Pacing/Pacing.entitlements`
