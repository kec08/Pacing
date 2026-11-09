# feat #05 Firebase 연동 — FE 계획서

> **상태**: 검토 대기
> **작성일**: 2026-06-25
> **담당**: FE
> **브랜치**: `feat/05-firebase`

---

## 1. 목적

현재 UserDefaults + 더미 데이터로 동작하는 앱을 Firebase 기반으로 전환한다.
인증(Apple 로그인), 프로필/러닝기록 저장(Firestore), 실시간 위치 공유(Realtime DB) 기반을 마련한다.

이후 feat들(주변 러너, 같이 듣기)이 이 기반 위에서 동작한다.

---

## 2. 연동 범위

| 서비스 | 용도 | 연동 여부 |
|--------|------|-----------|
| Firebase Auth | Apple 로그인 | ✅ 이번 feat |
| Firestore | 프로필, 러닝기록 저장/조회 | ✅ 이번 feat |
| Realtime Database | 위치 브로드캐스트, 같이 듣기 세션 | 🔜 feat #06 |
| Firebase Storage | 프로필 이미지 업로드 | 🔜 추후 |

---

## 3. 작업 목록

### Step 1 — SDK 설치
- [ ] Swift Package Manager로 Firebase SDK 추가
  - `FirebaseAuth`
  - `FirebaseFirestore`
  - `FirebaseDatabase`
- [ ] `GoogleService-Info.plist` 프로젝트에 추가 확인

### Step 2 — 앱 초기화
- [ ] `PacingApp.swift`에 `FirebaseApp.configure()` 추가
- [ ] `AppDelegate` 연결 (UIApplicationDelegateAdaptor)

### Step 3 — Apple 로그인 + Firebase Auth
- [ ] `AuthViewModel` 생성
  - `signInWithApple()` — ASAuthorizationAppleIDRequest
  - `signOut()`
  - `@Published var currentUser: FirebaseAuth.User?`
- [ ] `LoginView` — 기존 더미 로그인 → Apple 로그인 버튼으로 교체
- [ ] 로그인 성공 시 `AppState.isLoggedIn = true`
- [ ] 로그아웃 시 `Auth.auth().signOut()` + AppState 초기화
- [ ] 앱 재실행 시 로그인 상태 유지 (`Auth.auth().currentUser` 확인)

### Step 4 — Firestore 유저 프로필
- [ ] `FirestoreService` 생성
  - `saveUserProfile(uid:nickname:height:weight:age:)` — users 컬렉션 저장
  - `fetchUserProfile(uid:)` — 프로필 조회
- [ ] `ProfileSetupView` — 저장 시 UserDefaults → Firestore로 교체
- [ ] `MyViewModel` — 프로필 읽기 UserDefaults → Firestore로 교체

### Step 5 — Firestore 러닝기록
- [ ] `saveRunRecord(uid:record:)` — runHistory 컬렉션 저장
- [ ] `fetchRunHistory(uid:)` — 최근 기록 조회
- [ ] `RunSummaryView` 확인 버튼 탭 시 Firestore 저장
- [ ] `MyViewModel` 러닝 기록 더미 데이터 → Firestore 조회로 교체

---

## 4. 데이터 모델 (Firestore)

### users/{uid}
```
nickname: String
height: Double
weight: Double
age: Int
createdAt: Timestamp
```

### users/{uid}/runHistory/{recordID}
```
startedAt: Timestamp
duration: Int          // 초
distance: Double       // km
avgPace: Double        // 분/km
routeCoordinates: [GeoPoint]
```

---

## 5. 파일 구조

```
Core/
  Auth/
    AuthViewModel.swift       // Apple 로그인 + Firebase Auth
  Firebase/
    FirestoreService.swift    // Firestore CRUD
```

---

## 6. 완료 기준

- [ ] Apple 로그인 → Firebase Auth 연동 동작
- [ ] 앱 재실행 시 로그인 상태 유지
- [ ] 로그아웃 정상 동작
- [ ] 프로필 정보 Firestore 저장/조회
- [ ] 러닝 종료 시 runHistory Firestore 저장
- [ ] MyViewModel 실제 데이터로 통계 표시

---

## 7. 특이사항

- `GoogleService-Info.plist` 없으면 빌드 시 크래시 → 반드시 먼저 추가
- Apple 로그인은 실기기에서만 정상 동작 (시뮬레이터 제한)
- Firestore 보안 규칙은 테스트 모드(30일)로 시작, 이후 강화 필요
- Realtime DB는 feat #06(주변 러너)에서 연동
