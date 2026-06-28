# issue-04 같은 Apple ID 두 기기 테스트 불가

## 발생 시점
feat #07 주변 러너 — 두 기기 동시 테스트 시도

## 증상
두 기기가 동일한 Apple ID로 Sign In with Apple 로그인 시 Firebase UID가 동일하게 발급됨
→ `activeRunners/{uid}` 경로가 겹쳐 한 기기의 데이터가 다른 기기 데이터를 덮어씀
→ 주변 러너로 자기 자신이 보이거나 상대방이 안 보이는 문제 발생

## 해결
로그인 화면에 익명 로그인 옵션 추가 (`게스트로 시작` 버튼)
```swift
func signInAnonymously(appState: AppState) async {
    try await Auth.auth().signInAnonymously()
    appState.isLoggedIn = true
}
```
두 기기 중 하나를 익명 로그인으로 접속해 서로 다른 UID 확보

## 영향 범위
- `AuthViewModel.swift` — `signInAnonymously()` 추가
- `LoginView.swift` — 게스트 버튼 UI 추가

## 비고
익명 계정은 닉네임이 없으므로 UserDefaults fallback "러너"로 표시됨
추후 소셜/이메일 계정 연동 기능 추가 시 익명 계정 병합(merge) 처리 필요
