# issue-13 친구 탭 ViewModel Combine import 누락

> **심각도**: Minor 🟡  
> **발견일**: 2026-06-30  
> **발견 브랜치**: `feat/15-friends-tab`  
> **상태**: 해결 완료

---

## 증상 요약

`FriendsViewModel` 빌드 시 `ObservableObject` 및 `@Published` 관련 컴파일 에러가 발생했다.

## 재현 방법

1. `feat/15-friends-tab` 브랜치 체크아웃
2. 아래 명령으로 Debug 빌드 실행
3. `FriendsViewModel` 컴파일 에러 확인

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Pacing/Pacing.xcodeproj -scheme Pacing -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/PacingDerivedData build
```

## 예상 동작

친구 탭 ViewModel이 정상 컴파일되어야 한다.

## 실제 동작

`FriendsViewModel`이 `ObservableObject`를 준수하지 않는다는 에러와 `@Published` 초기화 에러가 발생했다.

## 스크린샷 / 로그

```
FriendsViewModel.swift:5:13: error: type 'FriendsViewModel' does not conform to protocol 'ObservableObject'
FriendsViewModel.swift:6:6: error: initializer 'init(wrappedValue:)' is not available due to missing import of defining module 'Combine'
```

## 원인 분석

`ObservableObject`와 `@Published`는 Combine 모듈에 정의되어 있는데 `FriendsViewModel.swift`에서 `Combine` import가 누락되어 있었다.

## 수정 내용

`FriendsViewModel.swift`에 `import Combine`을 추가했다.

## 관련 파일

- `FriendsViewModel.swift` : Combine import 추가
