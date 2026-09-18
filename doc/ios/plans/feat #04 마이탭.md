# feat #04 마이탭 — FE 계획서

> **상태**: 검토 대기
> **작성일**: 2026-06-25
> **담당**: FE
> **브랜치**: `feat/04-my-tab`

---

## 1. 목적

마이 탭에서 내 프로필, 러닝 통계(주/월/년/전체), 최근 러닝 기록을 확인한다.
Firebase 미연동 상태에서는 UserDefaults + 더미 데이터로 UI를 완성하고,
이후 Firestore 연동 시 교체한다.

---

## 2. 화면 레이아웃

```
┌─────────────────────────────────┐
│  [이니셜 아바타]  닉네임           │  ← 프로필 헤더
│                 키 · 몸무게 · 나이│
├─────────────────────────────────┤
│  [주] [월] [년] [전체]            │  ← 기간 필터 탭
│                                 │
│  0.0                            │
│  킬로미터 (큰 숫자)               │
│                                 │
│  0회         -'--"      0:00    │
│  러닝         평균페이스    시간   │
│                                 │
│  ┌─────────────────────────┐    │
│  │   메인컬러 막대 차트       │    │  ← 요일/날짜별 거리 bar chart
│  │   (월 화 수 목 금 토 일)   │    │
│  └─────────────────────────┘    │
├─────────────────────────────────┤
│  최근 활동                       │
│  ┌─────────────────────────┐    │
│  │ [지도썸네일] 2026. 6. 28  │    │
│  │             토요일 러닝   │    │
│  │  4.21km  5'55"  24:58   │    │
│  └─────────────────────────┘    │
│  ┌─────────────────────────┐    │
│  │ ...                     │    │
│  └─────────────────────────┘    │
├─────────────────────────────────┤
│  설정                            │
│  > 프로필 수정                    │
│  > 로그아웃                       │
└─────────────────────────────────┘
```

---

## 3. 컴포넌트 구성

### MyView (메인)
- `ScrollView` + `VStack`
- 당겨서 새로고침

### ProfileHeaderView
- 이니셜 원형 아바타
- 닉네임 / 키·몸무게·나이

### StatsFilterTab
- `주 / 월 / 년 / 전체` 세그먼트 탭 (선택된 탭 = main500 배경)
- 탭 전환 시 아래 통계 업데이트

### StatsSummaryView
- 총 거리 (큰 폰트, bold)
- 러닝 횟수 / 평균 페이스 / 총 시간 (3컬럼)
- 선택된 기간 레이블 ("이번 주" / "이번 달" 등)

### ActivityBarChart
- 기간에 따라 X축 변경:
  - 주: 월~일 (7개 막대)
  - 월: 1일~말일 (주 단위 집계 or 일 단위)
  - 년: 1~12월
  - 전체: 월별
- 막대 색: `main500` (핑크)
- 값 없는 날: 회색 빈 막대
- Swift Charts 사용 (`import Charts`)

### RunHistoryCard
- 카드뷰 (`.background(.white).cornerRadius(12).shadow`)
- 지도 썸네일 (더미 이미지 or MapKit snapshot)
- 날짜: "2026. 6. 28."
- 부제: 시작 시각 (예: "오후 1시 0분")
- 3컬럼: 거리(km) / 평균 페이스 / 시간

### SettingsSection
- 프로필 수정 → ProfileSetupView
- 로그아웃 → AppState 초기화 → LoginView

---

## 4. 데이터 모델

```swift
enum StatsPeriod { case week, month, year, all }

struct MyStats {
    var totalDistance: Double   // km
    var totalRuns: Int
    var avgPace: Double         // 분/km
    var totalTime: Int          // seconds
}

struct RunRecord: Identifiable {
    var id: UUID
    var date: Date
    var distance: Double        // km
    var avgPace: Double         // 분/km
    var duration: Int           // seconds
    var routeCoordinates: [CLLocationCoordinate2D]
}

struct BarChartEntry: Identifiable {
    var id: String              // "월", "화", ... or "1월" ...
    var label: String
    var value: Double           // km
}
```

---

## 5. ViewModel

```swift
final class MyViewModel: ObservableObject {
    @Published var nickname: String = ""
    @Published var height: Int = 0
    @Published var weight: Int = 0
    @Published var age: Int = 0
    @Published var selectedPeriod: StatsPeriod = .week
    @Published var stats: MyStats = .empty
    @Published var chartEntries: [BarChartEntry] = []
    @Published var runHistory: [RunRecord] = []

    func loadData()
    func changePeriod(_ period: StatsPeriod)
    func logout()
}
```

---

## 6. 작업 목록

- [ ] `MyViewModel` — 더미 데이터 + UserDefaults 읽기
- [ ] `MyView` 전체 레이아웃
- [ ] `ProfileHeaderView`
- [ ] `StatsFilterTab` (주/월/년/전체)
- [ ] `StatsSummaryView`
- [ ] `ActivityBarChart` (Swift Charts, main500 색상)
- [ ] `RunHistoryCard` (카드뷰 + 더미 데이터)
- [ ] `SettingsSection`
- [ ] `MainTabView`에 `MyView` 연결

---

## 7. 완료 기준

- [ ] 마이 탭 진입 시 프로필 정보 표시
- [ ] 기간 탭 전환 시 통계 + 차트 업데이트
- [ ] 막대 차트 main500 핑크 색상으로 표시
- [ ] 최근 러닝 카드뷰 리스트 표시 (날짜 / km / 페이스 / 시간)
- [ ] 로그아웃 → LoginView 이동
- [ ] 프로필 수정 → ProfileSetupView 이동

---

## 8. 특이사항

- Firebase 미연동 → 더미 RunRecord 3~5개로 UI 확인
- 지도 썸네일: MapKit Snapshot 대신 회색 placeholder 이미지 사용 (초안)
- Swift Charts: iOS 16+ 지원, 현재 타겟 iOS 26 → 사용 가능
- 프로필 정보는 UserDefaults 키 `nickname`, `height`, `weight`, `age`에서 읽음
