# feat #04 마이탭 — FE 최종 보고서

> **작성일**: 2026-06-25
> **브랜치**: `feat/04-my-tab`
> **이슈**: #7
> **상태**: QA 완료

---

## 1. 구현 요약

마이 탭에서 프로필, 러닝 통계(주/월/년/전체), 최근 러닝 기록, 설정을 확인할 수 있는 화면을 구현했다.
Firebase 미연동 상태에서 UserDefaults + 더미 데이터로 UI를 완성했으며, 이후 Firestore 연동 시 교체 예정이다.

---

## 2. 구현 내용

### 파일 목록
| 파일 | 구분 | 설명 |
|------|------|------|
| `Features/My/View/MyView.swift` | 신규 | 마이탭 메인 화면 |
| `Features/My/View/RunHistoryCard.swift` | 신규 | 러닝 기록 카드 컴포넌트 |
| `Features/My/ViewModel/MyViewModel.swift` | 신규 | 통계/피커/포맷 로직 |
| `Models/RunRecord.swift` | 수정 | 더미 데이터 5개 추가 |
| `Features/Onboarding/View/ProfileSetupView.swift` | 수정 | UserDefaults 저장 로직 추가 |
| `Features/Main/MainTabView.swift` | 수정 | `MyView()` 연결 |

### 주요 컴포넌트

#### ProfileHeaderView
- 이니셜 원형 아바타 (main500 핑크)
- 닉네임 / 키·몸무게·나이 (UserDefaults에서 읽어옴)
- 값이 0이면 해당 항목 숨김

#### StatsFilterTab (드래그 지원)
- 주/월/년/전체 탭
- 선택 탭: main500 배경 + 흰색 텍스트 + 스프링 애니메이션
- `DragGesture`로 좌우 드래그 시 기간 전환

#### 기간 레이블 피커 (wheel 스타일)
- 탭 시 `.sheet` 표시
- **주**: "이번 주 ~ 4주 전" wheel 1개
- **월**: 연도 고정(현재 연도) + 1월~이번 달 wheel 2개 나란히
- **년**: 2023년~이번 해 wheel 1개
- **전체**: 피커 없음
- ProfileSetupView와 동일한 `.pickerStyle(.wheel)` + 회색 둥근 배경

#### StatsSummaryView
- 총 거리: 68pt heavy + 핑크 "km" 단위
- 서브텍스트 ("이번 주의 총 거리") 숫자 아래
- 러닝/평균 페이스/총 시간: main500 아이콘 + 22pt 값 + 12pt 레이블

#### ActivityBarChart (Swift Charts)
- 막대: main500 → main300 그라데이션
- 빈 날짜: gray200
- 기간별 X축 자동 변경
  - 주 → 월·화·수·목·금·토·일
  - 월 → 1~5주
  - 년 → 1~12월
  - 전체 → 최근 6개월
- 차트 높이 160pt, "거리 추이" 타이틀

#### RunHistoryCard
- 날짜: "2026. 6. 28."
- 시작 시각: "오후 1시 0분"
- 거리 / 평균 페이스 / 총 시간 3컬럼

---

## 3. 기술 결정

| 결정 | 이유 |
|------|------|
| Swift Charts 사용 | iOS 16+ 지원, 현재 타겟 iOS 26에서 안정적 |
| DragGesture 탭 전환 | 터치 영역 내 드래그로 자연스러운 기간 전환 UX |
| wheel 피커 스타일 | ProfileSetupView와 일관된 입력 UX |
| 배경색 흰색 단일 통일 | 섹션 구분 없이 깔끔한 단일 흐름 유지 |

---

## 4. 특이사항 및 한계

- **더미 데이터**: Firebase 미연동으로 `RunRecord.dummies` 5개 사용. Firestore 연동 시 교체 필요
- **지도 썸네일**: RunHistoryCard에서 map.fill 아이콘 placeholder 사용. 추후 MapKit Snapshot으로 교체 예정
- **프로필 수정**: 버튼 UI만 구현, 실제 수정 화면 연결은 추후 구현
- **SourceKit 오류**: 빌드는 통과하나 Xcode 인덱서가 파일을 일부 못 찾는 현상 — 실제 컴파일 에러 없음
- **러닝 기록 저장**: feat #03에서 저장 로직 미구현으로 실제 기록 누적 불가 → 추후 연동 필요

---

## 5. QA 결과

| 항목 | 결과 |
|------|------|
| 빌드 성공 | ✅ |
| 프로필 정보 표시 | ✅ |
| 기간 탭 전환 + 드래그 | ✅ |
| 기간 피커 (주/월/년) | ✅ |
| 통계 업데이트 | ✅ |
| 차트 기간별 X축 | ✅ |
| 최근 활동 카드뷰 | ✅ |
| 로그아웃 동작 | ✅ (코드 리뷰 기준) |

---

## 6. 커밋 이력

| 커밋 | 내용 |
|------|------|
| `4df0227` | feat: 마이탭 구현 — 프로필/통계/차트/러닝기록/설정 |
| `540def2` | feat: 프로필 네비바 이동, 통계 사이즈 축소 |
| `18e4c09` | feat: 통계 레이아웃 개편 — 좌측정렬/기간레이블/필터 축소 |
| `b26d23a` | feat: 프로필 고정헤더/필터 크기 확대/드래그 탭/간격 조정 |
| `cf682f4` | feat: 좌측 마진 확대/통계 카드 UI/차트 그라데이션 |
| `525111c` | feat: 통계 박스 제거, 아이콘/텍스트 크기 확대 |
| `daf146f` | feat: 배경색 흰색으로 통일 |
| `501a45a` | feat: 총 거리 영역 확대 — 숫자 68pt/km 26pt |
| `a63449b` | feat: 총 거리 서브텍스트 숫자 아래로 이동 |
| `e37f6c6` | feat: 기간 피커 시트 — 주/월/년 선택 |
| `f9cf177` | feat: 기간 피커 wheel 스타일로 변경 |
