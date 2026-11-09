# issue-02 Realtime DB URL 누락으로 연결 강제 종료

## 발생 시점
feat #07 주변 러너 — Firebase Realtime Database 첫 연결 시도

## 증상
```
[FirebaseDatabase][I-RDB034005] Firebase Database connection was forcefully killed by the server.
Will not attempt reconnect. Reason: Firebase error. Please ensure that you have the URL of your
Firebase Realtime Database instance configured correctly.
```
activeRunners 노드에 데이터가 전혀 쌓이지 않음

## 원인
`GoogleService-Info.plist`에 `DATABASE_URL` 필드가 없어 FirebaseDatabase가 기본 URL을 추론하지 못함

## 해결
`RealtimeDBService.swift`에서 URL 명시적으로 지정
```swift
private let db = Database.database(url: "https://pacing-a8639-default-rtdb.firebaseio.com").reference()
```

## 재발 방지
신규 Firebase 프로젝트 연동 시 `GoogleService-Info.plist`에 `DATABASE_URL` 필드 포함 여부 확인
