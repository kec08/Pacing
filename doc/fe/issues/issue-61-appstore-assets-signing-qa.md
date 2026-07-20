# #61 App Store 자산 및 서명 팀 설정 QA 보고서

> **작성일**: 2026-07-20
> **브랜치**: `fix/61-appstore-assets-signing`

## 검증 결과

| 항목 | 결과 | 비고 |
|---|---|---|
| `make-screenshots.js` 문법 | 통과 | `node --check` |
| `render_screenshots.py` 문법 | 통과 | `python3 -m py_compile` |
| Git 공백 오류 검사 | 통과 | `git diff --check` |
| 서명 팀 설정 | 확인 완료 | 이전 팀 ID 1곳을 현재 팀 ID로 통일 |

## 수동 확인 항목

- [ ] App Store Connect 업로드 전 각 출력 PNG의 해상도·문구·화면 구성이 최신 앱과 일치하는지 확인
- [ ] Archive 시 선택한 배포 프로파일과 Team이 일치하는지 Xcode에서 확인

## 알려진 제한 사항

- 실제 App Store Connect 업로드 및 배포 서명 검증은 개발자 Apple 계정 환경에서 수행해야 한다.
