# feat #03 러닝탭 — FE 최종 개발 보고서

> **완료일**: 2026-06-25
> **관련 이슈**: [#5](https://github.com/kec08/Pacing/issues/5)
> **브랜치**: `feat/03-running-tab`
> **상태**: 개발자 검토 대기

---

## 구현 요약

풀스크린 MapKit 지도 기반의 러닝 탭을 구현했습니다.
CoreLocation GPS 추적 → 실시간 Polyline 경로 → 종료 시 나이키 런 클럽 스타일 요약 화면으로 이어지는 전체 러닝 플로우가 완성됐습니다.
Apple Music MusicKit 연동으로 최근 재생곡 카드 스크롤, 카운트다운 풀스크린 오버레이, 꾹 눌러 종료하는 햅틱 피드백까지 구현했습니다.

---

## 구현된 파일 목록

| 파일 | 설명 |
|------|------|
| `Core/Location/LocationManager.swift` | CLLocationManager 래퍼, GPS 추적, Polyline 좌표 수집 |
| `Running/ViewModel/RunningViewModel.swift` | RunningState enum, 타이머, 거리/페이스/시간 계산 |
| `Running/ViewModel/RunningMusicViewModel.swift` | MusicKit 권한 요청, 최근 재생 10곡 fetch |
| `Running/View/RunningView.swift` | 풀스크린 지도, 상태별 UI, 카운트다운, 햅틱 |
| `Running/View/RunSummaryView.swift` | 종료 후 요약 — 전체 지도 + 경로 + 스탯 카드 |
| `Running/View/MusicCardView.swift` | (보조 컴포넌트) |
| `Main/MainTabView.swift` | 러닝 탭에 RunningView 연결 |

---

## 상태별 화면 구성

### idle (대기)
```
[뮤직 카드 가로 스크롤 — Apple Music 최근 재생 / 더미 5개]
                  (풀스크린 지도)
         [음악]   [시작 96pt]   [주변]
```

### 카운트다운
```
     검정 반투명 풀스크린 오버레이
              3 → 2 → 1
           (main500 핑크, 160pt)
```

### running (러닝 중)
```
 [스탯 카드 — 시간(56pt) / km·페이스(28pt)]  ← 상단 고정
                  (지도 + 핑크 Polyline 경로)
         [음악]   [정지 100pt]   [주변]
```

### 정지 후 선택
```
                  (지도 + 경로)
       [■ stop.fill]   [▶ play.fill]
         검정·꾹 1초      핑크·즉시
```

### RunSummaryView (종료 후)
```
 [러닝 완료 / 거리(64pt) / 시간·페이스]  ← ultraThinMaterial 카드
        (풀스크린 지도 + 핑크 경로)
              [ 확인 (핑크) ]
```

---

## 커밋 이력

| 커밋 | 내용 |
|------|------|
| `c77132b` | feat: 러닝탭 초안 구현 — GPS 경로 Polyline + 나이키 스타일 요약 화면 |
| `c5aaed7` | feat: 러닝뷰 UI 개선 — 그라데이션, 카운트다운, 뮤직카드, 사이드 버튼 |
| `06b022e` | feat: 뮤직 카드 수평 스크롤 + 그라데이션 확장 |
| `dbb760a` | fix: 뮤직 카드 가로 레이아웃 변경 + 탭바 그라데이션 끊김 수정 |
| `66e5413` | refactor: 러닝뷰 전체 화면 지도로 변경, 흰 배경 제거 |
| `b2ef8bf` | feat: 카운트다운 풀스크린 오버레이 |
| `d86e982` | feat: 카운트다운 메인 핑크색 + 뮤직 카드 더미 5개 |
| `dd8d4f5` | feat: 러닝 스탯 오버레이 레이아웃 개편 |
| `31d0709` | feat: 운동 중 컨트롤 개편 + 정산 화면 전체 지도로 변경 |
| `1c9d8d5` | feat: 러닝 중 뮤직카드 숨김 + 스탯 상단 이동 + 사이드 버튼 추가 |
| `2668c5c` | fix: 종료/재시작 버튼 아이콘화 + 재시작 핑크색 |
| `d633005` | fix: pausedControls 종료 버튼 텍스트→stop.fill 아이콘 |

---

## QA 결과

| 완료 기준 | 결과 |
|-----------|------|
| 풀스크린 지도, 줌/스크롤 비활성 | ✅ |
| Apple Music 카드 가로 스크롤 | ✅ (미연결 시 더미 5개) |
| 시작 버튼 탭 → 카운트다운 3→2→1 풀스크린 | ✅ |
| GPS 추적 시작 + 실시간 Polyline | ✅ |
| 스탯 오버레이 (시간 크게 / km·페이스) 상단 고정 | ✅ |
| 정지 탭 → 종료(■)/재시작(▶) 선택지 | ✅ |
| 종료 꾹 1초 → 원형 프로그레스 + 충전 진동 | ✅ |
| 버튼 탭 햅틱 | ✅ |
| RunSummaryView 전체 지도 + 경로 | ✅ |
| 요약 화면 스탯 (거리/시간/페이스) | ✅ |
| "확인" 버튼 탭 → 초기화 및 idle 복귀 | ✅ |

발견된 이슈: **없음**

---

## 알려진 제한사항

- Apple Music 카드: 실기기 Apple ID + Music 구독 필요 (시뮬레이터 미지원) → 미연결 시 더미 카드 표시
- 백그라운드 GPS 추적 미지원 — `UIBackgroundModes location` + `allowsBackgroundLocationUpdates` 추후 추가 예정
- 주변 사용자 버튼: 탭 가능한 placeholder — feat #04 이후 구현 예정
- 러닝 기록 저장: UserDefaults/Firestore 미연동 — Firebase 연동 단계에서 추가 예정

---

## 다음 단계

- feat #04 마이탭
- Firebase Firestore 연동 → 러닝 기록 저장
- 백그라운드 GPS 추적 활성화

---

> **개발자 검토 의견**:
> 최종 승인: 승인 ✅ / 재작업 🔄
