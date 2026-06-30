# feat #03 러닝탭 — FE 계획서

> **상태**: 검토 대기
> **작성일**: 2026-06-25
> **담당**: FE
> **브랜치**: `feat/03-running-tab`

---

## 1. 목적

러닝 탭의 핵심 기능을 구현한다.
전체화면 MapKit 지도 위에서 러닝을 시작/일시정지/종료하고,
CoreLocation으로 실시간 GPS를 수집하여 지도에 Polyline을 그린다.
러닝 중 거리/시간을 실시간으로 표시하고, 종료 시 요약 화면을 보여준다.

---

## 2. 화면 구성

### RunningView (기본 화면)
```
┌─────────────────────────────┐
│                             │
│     전체화면 MapKit 지도      │  ← 내 위치 중심
│     (초록 펄스 링)            │
│                             │
│  ┌─────────────────────┐   │
│  │  러닝 중: 2.3km  12:34│   │  ← 러닝 중일 때만 표시
│  └─────────────────────┘   │
│                             │
│  [음악]   [ 시작 ]  [주변]   │  ← 하단 컨트롤
└─────────────────────────────┘
```

### 러닝 중 상태
- 시작 버튼 → 일시정지 버튼으로 전환
- 상단 오버레이: 거리 / 경과 시간 실시간 표시
- 지도에 이동 경로 Polyline 실시간 드로잉

### RunSummaryView (종료 후 요약)
```
┌─────────────────────────────┐
│  러닝 완료!                   │
│  [경로 지도 썸네일]            │
│  총 거리: 5.2 km              │
│  시간: 35분                   │
│  평균 페이스: 6'44"/km         │
│  [ 저장하기 ]                 │
└─────────────────────────────┘
```

---

## 3. 상태 관리

```swift
enum RunningState {
    case idle       // 대기 중
    case running    // 러닝 중
    case paused     // 일시정지
    case finished   // 종료 (요약 화면)
}
```

---

## 4. ViewModel 구조

```swift
class RunningViewModel: ObservableObject {
    @Published var runningState: RunningState = .idle
    @Published var elapsedTime: Int = 0        // 초
    @Published var distance: Double = 0.0      // km
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var routeCoordinates: [CLLocationCoordinate2D] = []
    @Published var avgPace: Double = 0.0

    func startRunning()
    func pauseRunning()
    func stopRunning()
    func saveSummary()   // TODO: Firestore 저장
}
```

---

## 5. 주요 구현 포인트

### 위치 수집
- `CLLocationManager` — `desiredAccuracy: kCLLocationAccuracyBest`
- 러닝 시작 시 `startUpdatingLocation()`
- 5m 이상 이동 시에만 좌표 추가 (노이즈 제거)

### 타이머
- `Timer.publish(every: 1, on: .main, in: .common)` 사용
- 러닝 중에만 카운트, 일시정지 시 중단

### Polyline
- `MapPolyline(coordinates: routeCoordinates)` — iOS 17+ SwiftUI Map API
- 컬러: `main500`

### 내 위치 표시
- `MapUserLocationButton` + 초록 펄스 링 커스텀 어노테이션

---

## 6. 작업 목록

- [ ] `LocationManager` — CoreLocation 래퍼 (싱글톤)
- [ ] `RunningViewModel` — 상태/타이머/거리 계산
- [ ] `RunningView` — 전체화면 Map + 하단 컨트롤
- [ ] 러닝 중 오버레이 (거리/시간 실시간 표시)
- [ ] Polyline 실시간 드로잉
- [ ] 시작/일시정지/종료 버튼 전환 로직
- [ ] `RunSummaryView` — 종료 후 요약 화면
- [ ] `MainTabView`에 `RunningView` 연결

---

## 7. 완료 기준

- [ ] 지도 전체화면 표시 및 내 위치 중심 이동
- [ ] 시작 버튼 탭 → 위치 수집 시작 + 타이머 시작
- [ ] 러닝 중 거리/시간 실시간 업데이트
- [ ] 이동 경로 Polyline 지도에 표시
- [ ] 일시정지 → 재개 정상 동작
- [ ] 종료 → 요약 화면 표시 (거리/시간/페이스)

---

## 8. 특이 사항

- 시뮬레이터에서 위치 시뮬레이션: Xcode → Features → Location → City Run
- `NSLocationAlwaysAndWhenInUseUsageDescription` 이미 설정됨 (feat #01)
- Firestore 저장은 TODO 처리, Firebase 연동 후 구현
- 음악 버튼 / 주변 찾기 버튼은 이번 단계에서 UI placeholder만
