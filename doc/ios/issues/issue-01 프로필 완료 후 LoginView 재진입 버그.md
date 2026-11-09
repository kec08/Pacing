# issue-01 프로필 완료 후 LoginView 재진입 버그

> **심각도**: Major 🟠
> **발견일**: 2026-06-25
> **발견 브랜치**: `feat/01-foundation-onboarding`
> **상태**: 수정 완료

---

## 증상 요약

프로필 입력 후 "시작하기" 버튼을 탭해도 MainTabView로 이동하지 않고 LoginView로 돌아간다.

## 재현 방법

1. 앱 최초 실행
2. "Apple로 로그인" 탭 → 온보딩 진행
3. ProfileSetupView에서 닉네임 입력 후 "시작하기" 탭
4. MainTabView 대신 LoginView가 표시됨

## 예상 동작

"시작하기" 탭 → MainTabView로 전환

## 실제 동작

"시작하기" 탭 → LoginView 재표시

## 원인 분석

`ProfileSetupView`에서 `appState.isProfileComplete = true`만 설정하고  
`appState.isLoggedIn = true`를 설정하지 않음.

`SplashView` 분기 로직:
```swift
if appState.isLoggedIn {          // false → LoginView로 떨어짐
    if appState.isProfileComplete {
        MainTabView()
    }
} else {
    LoginView()                   // ← 여기로 진입
}
```

## 수정 내용

`ProfileSetupView` 시작하기 버튼에 `appState.isLoggedIn = true` 추가.

```swift
Button {
    appState.isLoggedIn = true        // 추가
    appState.isProfileComplete = true
}
```

## 관련 파일

- `Features/Onboarding/View/ProfileSetupView.swift` : isLoggedIn 설정 누락
