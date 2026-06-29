# issue-10 로그인 재진입 시 프로필 재입력 · 프로필 사진 미지원

## 증상
1. 로그아웃 후 다시 로그인하면 프로필(닉네임/신체정보)을 매번 재입력해야 함
2. 회원가입에 프로필 사진 입력이 없음
3. 로그인 수단이 애플/익명뿐 → 구글 로그인 미지원

## 원인
- 프로필 완료 여부를 **로컬 UserDefaults(`isProfileComplete`)** 에만 의존
- `signOut()`이 `isProfileComplete = false`로 덮어써, Firestore에 프로필이 있어도 무시됨
- 로그인 성공 시 Firestore 프로필 존재 여부를 확인하지 않음
- `ProfileSetupView`에 사진 입력 UI 없음, `FirestoreService`에 사진 필드 없음

## 해결 방향
- 로그인 성공 직후 `FirestoreService.hasUserProfile(uid:)`로 프로필 존재 확인 → `isProfileComplete` 분기
- 프로필 있으면 UserDefaults(`nickname/height/weight/age/profileImage`) 복원
- `SplashView.restoreSession`도 Firestore 검증으로 보강
- `ProfileSetupView`에 `PhotosPicker` 사진 선택(200×200 JPEG → Base64) 추가
- `FirestoreService.saveUserProfile`에 `profileImageBase64` 추가, 마이탭 표시
- 구글 로그인(`signInWithGoogle`) 추가 + `LoginView` 버튼

## 관련 feat
feat #12 회원가입 정리 — 1단계 (로그인 유지 + 프로필 사진 + 구글)
