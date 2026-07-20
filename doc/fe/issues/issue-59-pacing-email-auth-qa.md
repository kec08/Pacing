# #59 Pacing 이메일 로그인·회원가입 QA 보고서

> **작성일**: 2026-07-20
> **브랜치**: `feat/59-pacing-email-auth`

## 자동 검증 결과

| 항목 | 결과 | 비고 |
|---|---|---|
| iOS Simulator Debug 빌드 | 통과 | Xcode, iOS 26.0 SDK, 코드 서명 비활성화 |
| `PacingTests` | 통과 | iPhone 17 Pro Max, iOS 26.0 Simulator |
| 이메일 형식 검증 | 통과 | 잘못된 이메일 입력 거부 테스트 |
| 회원가입 비밀번호 확인 | 통과 | 불일치 입력 거부 및 정상 입력 테스트 |
| Apple nonce 매칭 | 통과 | ID 토큰 nonce 해시로 원본 nonce를 조회 |
| 로그인 버튼 레이아웃 | 통과 | Pacing 로그인 최상단 유지, 전체 버튼 묶음 24pt 하향 |

## 수동 QA 체크리스트

- [x] Firebase Console에서 Email/Password 제공업체 활성화
- [ ] 신규 계정 생성 후 권한·음악 안내 및 4단계 프로필 입력 완료
- [ ] 프로필 저장 후 로그아웃·재로그인 시 메인 화면 진입 확인
- [ ] 잘못된 이메일·비밀번호·네트워크 오류 문구 확인
- [ ] Apple 로그인 성공/취소/오류 흐름 실기기 확인
- [ ] App Store Connect App Review Information에 심사 계정과 절차 등록

## 알려진 제한 사항

- Firebase Console 설정 및 App Store Connect 심사 계정 등록은 앱 코드 외부 작업이므로 배포 전 개발자가 직접 완료해야 한다.
- 실제 Firebase 인증 호출과 Apple 로그인 오류 재현은 연결된 실기기·운영/심사 환경에서 추가 검증이 필요하다.
