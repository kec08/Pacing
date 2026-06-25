# feat #02 홈탭 — FE 최종 개발 보고서

> **완료일**: 2026-06-25
> **관련 이슈**: [#3](https://github.com/kec08/Pacing/issues/3)
> **브랜치**: `feat/02-home-tab`
> **상태**: 개발자 검토 대기

---

## 구현 요약

홈 탭 UI 초안을 구현했습니다.
더미 데이터 기반으로 이번 주 통계 카드, 최근 러닝 기록, 같이 들은 러너
3개 섹션이 정상 렌더링됩니다. Firebase 연동 시 더미 데이터를 교체할 예정입니다.

---

## 구현된 파일 목록

| 파일 | 설명 |
|------|------|
| `Models/RunRecord.swift` | RunRecord / WeeklyStats / ListenSession 데이터 모델 |
| `Home/ViewModel/HomeViewModel.swift` | 더미 데이터, 거리/시간/페이스 포맷 함수 |
| `Home/View/HomeView.swift` | 메인 레이아웃 (ScrollView + 섹션 3개) |
| `Home/View/WeeklyStatsCard.swift` | 이번 주 통계 카드 컴포넌트 |
| `Home/View/RecentRunRow.swift` | 최근 러닝 기록 행 컴포넌트 |
| `Home/View/ListenSessionRow.swift` | 같이 들은 러너 행 컴포넌트 |
| `Main/MainTabView.swift` | 홈 탭에 HomeView 연결 |

---

## 커밋 이력

| 커밋 | 내용 |
|------|------|
| `6b0d9a2` | feat: 홈탭 UI 초안 구현 (#3) |

---

## 계획서 대비 변경 사항

| 항목 | 계획 | 실제 구현 | 사유 |
|------|------|-----------|------|
| 경로 썸네일 | MKMapSnapshotter | 회색 placeholder | 계획대로 제외 |
| Firestore 연동 | 실제 데이터 | 더미 데이터 | Firebase 미연동 단계 |
| 당겨서 새로고침 | 구현 | 구현 (더미 재로드) | 정상 구현 |

---

## QA 결과

| 완료 기준 | 결과 |
|-----------|------|
| 통계 카드 표시 (거리/시간/페이스) | ✅ 포맷 정확 |
| 최근 러닝 기록 최대 5건 표시 | ✅ 정상 |
| 최근 같이 들은 러너 최대 3건 표시 | ✅ 정상 |
| 빈 상태 화면 분기 | ✅ 로직 정상 |
| 당겨서 새로고침 | ✅ 정상 |

발견된 이슈: **없음**

---

## 알려진 제한사항

- 더미 데이터 사용 중 → Firebase 연동 시 `HomeViewModel.loadHomeData()` 교체 예정
- 경로 썸네일 미구현 (회색 placeholder) → 추후 `MKMapSnapshotter` 적용 예정
- 닉네임은 UserDefaults에서 읽음 → Firebase 연동 후 Firestore에서 읽도록 변경 예정

---

## 다음 단계

- feat #03 러닝탭 기본 (MapKit, CoreLocation, Polyline)

---

> **개발자 검토 의견**:
> 최종 승인: 승인 ✅ / 재작업 🔄
