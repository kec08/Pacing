# feat #44 브랜드 UI 및 인터랙션 개선 최종 개발 보고서

> **완료일**: 2026-07-18<br>
> **관련 이슈**: [#53](https://github.com/kec08/Pacing/issues/53)<br>
> **PR**: 작성 대기<br>
> **브랜치**: `feat/44-brand-ui-interaction-refresh`

---

## 구현 요약

기존 화면 구조를 유지하면서 Pacing의 브랜드 요소를 스플래시와 로그인에 일관되게 적용했다. 러닝 음악 시트의 글래스 UI는 유지하되 플레이리스트 선택 패널이 콘텐츠 뒤로 겹쳐 보이던 문제를 전면 레이어와 페이드 전환으로 정리했다. 마이 탭의 불필요한 상단 여백도 함께 제거했다.

## 구현된 기능 목록

- [x] Pacing 투명 P 마크와 핑크·퍼플 그라데이션 스플래시 적용
- [x] 스플래시 종료 시 로고 축소·페이드 및 배경 페이드 전환 적용
- [x] `Reduce Motion` 활성화 시 스플래시 애니메이션 생략
- [x] 마이 탭의 빈 상단 내비게이션 영역 제거
- [x] 러닝 음악 시트의 플레이리스트 패널을 전면 글래스 레이어로 표시
- [x] 플레이리스트 패널의 상단 이동 효과를 페이드 전환으로 변경
- [x] 패널 바깥 탭으로 닫기 및 배경 딤 처리 적용
- [x] 음악 시트와 플레이리스트의 투명 글래스 소재 유지
- [x] 로그인 상단에 Pacing 앱 아이콘, 브랜드명, 슬로건 배치
- [x] OAuth 버튼에 제공받은 Apple 외 Google·Kakao·Naver 로고 적용
- [x] OAuth 버튼 순서를 Apple → Google → 카카오 → 네이버로 정렬
- [x] 네이버 버튼색을 로고와 같은 `#00C73C`로 맞추고 마크 크기 확대

## 변경 파일

| 파일 | 변경 내용 |
|------|----------|
| `Pacing/Pacing/Features/Auth/View/SplashView.swift` | 브랜드 스플래시와 종료 전환 적용 |
| `Pacing/Pacing/Features/Auth/View/LoginView.swift` | 앱 아이콘·OAuth 로고·버튼 순서·간격 조정 |
| `Pacing/Pacing/Features/My/View/MyView.swift` | 상단 빈 내비게이션 영역 제거 |
| `Pacing/Pacing/Features/Running/View/RunningView.swift` | 글래스 플레이리스트 패널의 전면 표시·전환 정리 |
| `Pacing/Pacing/Assets.xcassets/PacingSplashMark.imageset` | 스플래시 P 로고 에셋 |
| `Pacing/Pacing/Assets.xcassets/PacingLoginAppIcon.imageset` | 로그인 상단 앱 아이콘 에셋 |
| `Pacing/Pacing/Assets.xcassets/*LoginMark.imageset` | Google·Kakao·Naver OAuth 로고 에셋 |

## QA 결과

| 완료 기준 | 결과 |
|-----------|------|
| 스플래시 로고·그라데이션·축소/페이드 전환 컴파일 | ✅ 통과 |
| 동작 줄이기 설정에서 즉시 전환 분기 확인 | ✅ 코드 검증 완료 |
| 음악 플레이리스트 전면 레이어·글래스 소재 반영 | ✅ 코드 검증 완료 |
| 마이 탭 상단 내비게이션 영역 제거 | ✅ 코드 검증 완료 |
| OAuth 에셋 참조 및 버튼 순서 반영 | ✅ 코드 검증 완료 |
| `git diff --check` | ✅ 통과 |
| iOS Simulator Debug 빌드 | ✅ 통과 |
| 로그인·음악 시트 실기기 시각 QA | ⚠️ 추가 확인 권장 |

## 발견된 이슈 및 해결

| 이슈 | 심각도 | 상태 |
|------|--------|------|
| 음악 플레이리스트 패널이 반투명 배경에서 뒤 콘텐츠와 겹쳐 보임 | Minor | 해결 완료 |
| 마이 탭에 빈 내비게이션 영역이 남아 프로필이 아래로 내려감 | Minor | 해결 완료 |
| OAuth 버튼이 SF Symbol로 표시되어 브랜드 로고와 다름 | Minor | 해결 완료 |

## 알려진 제한사항

- 제공된 OAuth PNG는 알파 채널이 포함된 원본을 사용했다. 각 공급사의 최신 브랜드 가이드·에셋 사용 정책은 배포 전 별도 확인이 필요하다.
- 시뮬레이터 빌드로 컴파일은 검증했지만, 로그인 제공자별 실제 OAuth 인증 흐름은 각 서비스 설정이 완료된 실기기에서 추가 확인해야 한다.
- 기존 워크트리의 `Pacing/Pacing.xcodeproj/project.pbxproj` 변경은 이번 작업과 무관한 사용자 로컬 설정으로 판단해 커밋에 포함하지 않았다.

## Git 이력

- 원격 푸시 완료: `feat/44-brand-ui-interaction-refresh`
- 주요 최종 커밋: `dd5c09a ui: 로그인 로고 간격 조정 (#53)`
- PR은 `dev` 대상 생성 대기 상태다.

---

> **개발자 검토 의견**:<br>
> 최종 승인: 승인 ✅ / 재작업 🔄
