# issue-03 브로드캐스트 좌표 guard로 노래 정보 미업로드

## 발생 시점
feat #07 주변 러너 — 두 기기 연동 테스트 중

## 증상
주변 러너 카드에 상대방 닉네임은 표시되나 현재 곡 정보가 비어 있음

## 원인
`upload()` 내부에서 `guard let coord = coord else { return }` 로 좌표가 없으면 함수 전체를 중단
→ GPS 수집 전이거나 위치 권한이 없는 경우 곡 정보도 함께 업로드되지 않음

## 해결
`coord`를 Optional로 유지하되 `guard` 제거, 좌표가 있을 때만 위도·경도 필드를 추가하는 방식으로 변경
```swift
var data: [String: Any] = [
    "nickname": nickname,
    "currentSongTitle": song.title,
    "currentArtist": song.artist,
    "updatedAt": ServerValue.timestamp()
]
if let coord = coord {
    data["latitude"] = coord.latitude
    data["longitude"] = coord.longitude
}
db.child("activeRunners").child(uid).updateChildValues(data)
```

## 재발 방지
브로드캐스트 데이터 중 일부 필드가 없어도 나머지 필드는 항상 업로드되도록 `updateChildValues` 사용 유지
