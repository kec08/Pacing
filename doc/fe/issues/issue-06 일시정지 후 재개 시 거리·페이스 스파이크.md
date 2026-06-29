# issue-06 일시정지 후 재개 시 거리·페이스 스파이크

## 발생 feat
feat #09 러닝 측정 개선

## 현상
- 일시정지 후 재개하면 거리가 순간적으로 크게 증가
- 페이스가 비정상적으로 빠르거나 느리게 튀는 현상

## 원인
1. `pause()` 시 `lastLocation`을 초기화하지 않아 재개 후 첫 GPS 업데이트에서 일시정지 전 위치와의 거리를 그대로 누적
2. GPS 드리프트: 정지 중 좌표가 수십 미터 이동하고, 재개 시 해당 오차가 한 번에 반영됨

## 수정
`pause()` 및 `resume()` 시 `lastLocation = nil` 처리 → 재개 후 첫 위치를 새 기준점으로 설정

## 수정 파일
- `Features/Running/ViewModel/RunningViewModel.swift`
