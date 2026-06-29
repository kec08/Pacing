# issue-05 Firestore 숫자 타입 캐스팅 실패로 러닝 데이터 0 표시

## 발생 feat
feat #08 홈·마이 데이터 연동

## 현상
- 마이 탭: 러닝 횟수(17회)는 올바르게 표시되나 거리 0.0km / 페이스 --'--" / 시간 0:00 으로 나타남
- 홈 탭: 이번 주 러닝 통계가 0으로 표시됨

## 원인
`FirestoreService.fetchRunHistory` 에서 숫자 필드를 직접 타입 캐스팅:

```swift
// 기존 코드 (문제)
let duration = d["duration"] as? Int     // Int64로 저장된 경우 nil 반환
let distance = d["distance"] as? Double  // 정수로 저장된 경우 nil 반환
let avgPace  = d["avgPace"]  as? Double  // 정수로 저장된 경우 nil 반환
```

Firestore iOS SDK는 저장 시점과 값에 따라 숫자를 `Int64` 또는 `Double`로 반환하는데,
Swift의 `as? Int` / `as? Double` 직접 캐스팅은 타입이 정확히 일치하지 않으면 `nil` 반환.

예: `distance = 5.0` 이 정수 `5`로 저장된 경우 `as? Double` 실패 → guard 실패 → 레코드 nil 반환

## 수정
`NSNumber`를 경유하는 유연한 캐스팅으로 변경:

```swift
// 수정 코드
let duration = (d["duration"] as? NSNumber)?.intValue    ?? 0
let distance = (d["distance"] as? NSNumber)?.doubleValue ?? 0
let avgPace  = (d["avgPace"]  as? NSNumber)?.doubleValue ?? 0
```

`NSNumber`는 Firestore가 반환하는 모든 숫자 타입(Int, Int64, Double, Float 등)을 수용하므로
타입 불일치로 인한 파싱 실패를 방지.

## 수정 파일
- `Core/Firebase/FirestoreService.swift` — `fetchRunHistory` 숫자 파싱 로직

## 비고
- guard 실패 시 레코드 전체가 nil 처리되어 카운트는 줄어들지만, 숫자 필드가 0으로 저장된 경우(시뮬레이터 GPS 미작동 등)는 파싱 성공 후 0 표시. 이는 실제 데이터 문제로 코드 수정 범위 외.
