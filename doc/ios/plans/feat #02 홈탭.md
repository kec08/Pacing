# feat #02 홈탭 — FE 계획서

> **상태**: 검토 대기
> **작성일**: 2026-06-25
> **담당**: FE
> **브랜치**: `feat/02-home-tab`

---

## 1. 목적

홈 탭에서 이번 주 러닝 통계, 최근 러닝 기록 리스트,
최근 같이 들은 러너 섹션을 보여준다.
Firebase 미연동 상태에서는 더미 데이터로 UI를 완성하고,
이후 Firestore 연동 시 데이터 교체한다.

---

## 2. 화면 레이아웃

```
┌─────────────────────────────┐
│  안녕하세요, [닉네임] 👋        │  ← 인사 + 오늘 날짜
├─────────────────────────────┤
│  이번 주 러닝                 │  ← WeeklyStatsCard
│  ┌──────┬──────┬──────┐    │
│  │ 거리  │ 시간  │ 페이스│    │
│  │12.4km│1:23  │5'32" │    │
│  └──────┴──────┴──────┘    │
├─────────────────────────────┤
│  최근 러닝 기록               │  ← RecentRunList (최대 5건)
│  [날짜] [거리] [시간] [썸네일]  │
│  [날짜] [거리] [시간] [썸네일]  │
├─────────────────────────────┤
│  같이 들은 러너               │  ← RecentListenSection (최대 3건)
│  [아바타] [닉네임] [곡명]      │
└─────────────────────────────┘
```

---

## 3. 컴포넌트 구성

### HomeView
- `ScrollView` + `LazyVStack`
- 당겨서 새로고침 (`.refreshable`)
- 로딩 중 `ProgressView`

### WeeklyStatsCard
- 이번 주 (월~일) 집계
- 총 거리 (km) / 총 시간 (h:mm) / 평균 페이스 (분'초")
- 러닝 기록 없으면 빈 상태 텍스트 표시

### RecentRunRow
- 날짜 | 거리 | 시간 | 경로 썸네일
- 썸네일: `MKMapSnapshotter`로 비동기 생성
- 탭 → 상세 화면 (6주차 이후)

### ListenSessionRow
- 이니셜 원형 아바타 | 닉네임 | 같이 들은 곡명

---

## 4. 데이터 모델

```swift
struct RunRecord: Identifiable {
    let id: String
    let startedAt: Date
    let duration: Int        // 초
    let distance: Double     // km
    let avgPace: Double      // 분/km
    let routeCoordinates: [CLLocationCoordinate2D]
}

struct WeeklyStats {
    var totalDistance: Double  // km
    var totalDuration: Int     // 초
    var avgPace: Double        // 분/km
}

struct ListenSession: Identifiable {
    let id: String
    let partnerNickname: String
    let songTitle: String
    let date: Date
}
```

---

## 5. ViewModel 구조

```swift
class HomeViewModel: ObservableObject {
    @Published var weeklyStats: WeeklyStats?
    @Published var recentRuns: [RunRecord] = []
    @Published var recentListenSessions: [ListenSession] = []
    @Published var isLoading: Bool = false
    @Published var nickname: String = ""

    func loadHomeData() async      // Firestore 연동 전 더미 데이터
    func formatPace(_ pace: Double) -> String   // "5'32\""
    func formatDuration(_ seconds: Int) -> String  // "1:23"
}
```

---

## 6. 작업 목록

- [ ] 데이터 모델 정의 (`RunRecord`, `WeeklyStats`, `ListenSession`)
- [ ] `HomeViewModel` — 더미 데이터 + 포맷 함수
- [ ] `HomeView` 레이아웃 구성
- [ ] `WeeklyStatsCard` 컴포넌트
- [ ] `RecentRunRow` 컴포넌트 (썸네일 제외 먼저)
- [ ] `ListenSessionRow` 컴포넌트
- [ ] 빈 상태 (EmptyState) UI
- [ ] `MainTabView`에 `HomeView` 연결

---

## 7. 완료 기준

- [ ] 홈 탭 진입 시 더미 데이터 기반 통계 카드 표시
- [ ] 최근 러닝 기록 최대 5건 표시
- [ ] 최근 같이 들은 러너 최대 3건 표시
- [ ] 러닝 기록 없을 때 빈 상태 화면 표시
- [ ] 당겨서 새로고침 동작

---

## 8. 특이 사항

- Firebase 미연동 → 더미 데이터로 UI 완성 후 Firestore 연동 시 교체
- 경로 썸네일(`MKMapSnapshotter`)은 이번 단계에서 제외, 회색 placeholder로 대체
- 페이스 포맷: `5'32"` / 시간 포맷: `1:23` (1시간 23분)
