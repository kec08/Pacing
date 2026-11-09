# feat #01 기반셋업-온보딩 — FE 최종 개발 보고서

> **완료일**: 2026-06-25
> **관련 이슈**: [#1](https://github.com/kec08/Pacing/issues/1)
> **브랜치**: `feat/01-foundation-onboarding`
> **상태**: 개발자 검토 대기

---

## 구현 요약

앱 실행부터 메인 탭 진입까지의 전체 진입 흐름을 구성했습니다.
Apple 로그인 UI → 위치/Music 권한 요청 → 프로필 입력 → 메인 탭의 흐름이
완성되었으며, MVVM 기반 프로젝트 구조와 디자인 시스템 컬러 토큰도 함께 적용했습니다.

---

## 구현된 파일 목록

| 파일 | 설명 |
|------|------|
| `DesignSystem/PacingColor.swift` | 디자인 시스템 컬러 토큰 전체 (Color extension) |
| `Core/AppState/AppState.swift` | 전역 로그인/프로필 상태 + UserDefaults 자동 저장 |
| `Features/Auth/View/SplashView.swift` | 앱 진입 시 로고 스플래시 + 세션 복원 후 분기 라우팅 |
| `Features/Auth/View/LoginView.swift` | Apple 로그인 버튼 UI + NavigationStack + 온보딩 연결 |
| `Features/Onboarding/View/OnboardingPermissionView.swift` | 위치 권한 요청 안내 + CLLocationManager 연동 |
| `Features/Onboarding/View/OnboardingMusicView.swift` | Apple Music 권한 요청 안내 + MusicAuthorization 연동 |
| `Features/Onboarding/View/ProfileSetupView.swift` | 닉네임/키/체중/나이/성별 입력 + 유효성 검사 |
| `Features/Main/MainTabView.swift` | 하단 탭 3개 뼈대 (홈/러닝/마이) |

---

## 커밋 이력

| 커밋 | 내용 |
|------|------|
| `718be88` | feat: 프로젝트 구조 세팅 및 디자인 시스템 컬러 토큰 적용 |
| `10dc00f` | fix: Color 커스텀 토큰 foregroundStyle 타입 추론 오류 수정 |
| `2b78812` | feat: 온보딩 권한 화면 구현 — 위치/Apple Music 권한 요청 |
| `67c5d4a` | feat: SplashView 상태 복원 로직 및 권한 설명 문구 추가 |
| `6897b24` | fix: 프로필 완료 후 LoginView 재진입 버그 수정 |

---

## 계획서 대비 변경 사항

| 항목 | 계획 | 실제 구현 | 사유 |
|------|------|-----------|------|
| Apple 로그인 | Firebase Auth 연동 | 버튼 UI만 구현 (TODO) | Firebase 설정 전 단계 |
| Firestore 저장 | 프로필 저장 | UserDefaults 임시 처리 (TODO) | Firebase 설정 전 단계 |
| 닉네임 중복 검사 | Firestore 쿼리 | 미구현 | Firebase 연동 시 추가 예정 |

---

## QA 결과

| 완료 기준 | 결과 |
|-----------|------|
| Apple 로그인 성공 후 Firestore `users/{uid}` 문서 생성 | ⏸ Firebase 연동 후 검증 예정 |
| 재실행 시 로그인 유지 → MainTabView 바로 진입 | ✅ UserDefaults로 정상 동작 |
| 신규 유저 온보딩 → 프로필 입력 → 메인 순서 정상 동작 | ✅ 정상 |
| 닉네임 비어있을 때 "시작하기" 버튼 비활성화 | ✅ 정상 |
| 하단 탭 3개 전환 정상 동작 | ✅ 정상 |

---

## 발견된 이슈

| 이슈 | 심각도 | 상태 |
|------|--------|------|
| 프로필 완료 후 LoginView 재진입 | Major 🟠 | ✅ 수정 완료 (`6897b24`) |

---

## 알려진 제한사항

- Apple 로그인은 **실기기에서만** 동작 (시뮬레이터 미지원)
- Firebase 미연동 상태로 로그인/프로필 저장은 **UserDefaults 임시 처리**
  → feat #02 BE 세팅 시 Firebase로 전환 예정
- 닉네임 중복 검사 미구현 (Firebase 연동 후 추가)

---

## 다음 단계

- Firebase 프로젝트 생성 및 iOS 앱 연결 (BE)
- Apple 로그인 Firebase Auth 실제 연동
- Firestore `users/{uid}` 문서 저장 구현

---

> **개발자 검토 의견**:
> 최종 승인: 승인 ✅ / 재작업 🔄
