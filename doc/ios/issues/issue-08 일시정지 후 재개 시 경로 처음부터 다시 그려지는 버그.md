# issue-08 일시정지 후 재개 시 경로 처음부터 다시 그려지는 버그

## 발생 feat
feat #09 러닝 측정 개선

## 현상
- 러닝 중 일시정지 후 재개하면 이전에 그려진 경로가 사라지고 현재 위치부터 다시 그려짐

## 원인
`LocationManager.startTracking()`에서 `routeCoordinates = []` 초기화 → resume() 시 호출되어 기존 경로 소실

## 수정
`startTracking()`에서 초기화 제거, `resetRoute()`에서만 초기화 → 새 러닝 시작(`reset()`) 시에만 경로 리셋

## 수정 파일
- `Core/Location/LocationManager.swift` — `startTracking()`
