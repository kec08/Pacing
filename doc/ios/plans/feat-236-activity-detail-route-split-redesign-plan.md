# 활동 상세 경로 지도·구간 표 개편 계획서

> **상태**: 승인 완료
> **작성일**: 2026-11-25
> **관련 이슈**: #236
> **브랜치**: `feat/236-activity-detail-redesign` (기준 `dev`)

---

## 1. 목적 및 배경

활동 상세 화면(`RunActivityDetailView`)의 경로 지도는 높이 270pt로 작고, 출발·도착을 텍스트 말풍선으로 표시한다. 구간별 페이스는 `1 km  4'50"` 카드 목록이라 구간끼리 비교하기 어렵다. 나이키 런 클럽처럼 지도를 키워 경로와 km 지점을 한눈에 보이게 하고, 구간은 막대가 깔린 표로 바꿔 빠른·느린 구간을 바로 구분하게 한다.

## 2. 현재 코드 확인 결과

| 항목 | 현재 상태 |
|------|-----------|
| 화면 | `Features/Running/View/RunActivityDetailView.swift` (`routeSection`, `splitSection`) |
| 모델 | `Models/RunRecord.swift` — `RunLapPace(kilometer, pace)`만 있다 |
| 저장·조회 | `Core/Firebase/FirestoreService.swift` `saveRunRecord` / `fetchRunHistory`, 경로 `users/{uid}/runHistory/{id}` |
| 랩 확정 | `RunningViewModel.completePendingLapsIfNeeded` — 경과 초 기준으로 페이스만 계산 |
| 심박수 | 러닝 전체 평균만 `averageHeartRate`로 저장. `HeartRateRepository.averageHeartRate(from:to:)` 재사용 가능 |
| 날씨 | **저장하지 않는다.** WeatherKit 권한(entitlement)도 없다 |
| 위치 이름 | **저장하지 않는다.** 공유 화면(`RunRecordCameraShareView`)에만 `MKReverseGeocodingRequest` 역지오코딩이 있다 |
| 최소 OS | iOS 26.0 — `MKReverseGeocodingRequest`, `MKAddressRepresentations` 바로 사용 가능 |

## 3. 화면 구성

### 3.1 러닝 경로 지도 카드
- 높이 270pt → 화면 폭 기준 세로형(폭 × 1.25, 약 440pt)으로 키운다. 모서리 20pt 카드 유지.
- 경로선 두께 4 → 6pt, 기존 분홍→인디고 그라데이션은 유지한다.
- 경로 전체 영역(bounding box)에 여백 배율 1.5를 주고, 카드 비율에 맞춰 위·아래 오버레이 카드에 가리지 않게 세로 여백을 더 준다.
- **출발 핀**: 초록 원(`success/500` `#39D053`), **도착 핀**: 빨강 원(`accent/500` `#FF3740`). 지름 16pt, 흰 테두리 3pt, 그림자. 기존 "출발/도착" 텍스트 말풍선(`RouteEndpointLabel`)은 지운다.
- **km 라벨**: 경로 위 1km마다 흰 캡슐 `2 km`(검정 13pt semibold, 그림자).
  - 좌표 사이 거리를 누적해 k km 지점을 두 좌표 사이에서 선형 보간해 찾는다.
  - GPS 경로 길이와 기록 거리(`record.distance`, Watch 거리일 수 있음)가 다를 수 있어, 경로 길이를 기록 거리에 맞춰 비율로 맞춘다. 그래서 라벨 개수가 구간 표의 행 수와 같다.
  - 마지막 km 지점이 도착 핀과 거의 겹치면(50m 이내) 라벨을 생략한다.
  - 15km를 넘는 기록은 라벨이 겹치지 않게 2km 간격으로 줄인다(나이키 참고 이미지도 2·4·6·8 km만 표시).
- **위치 카드(오른쪽 위)**: `남양주시, 대한민국`처럼 시·구 단위. 반투명 다크 표면(`background/primary` 90%) 둥근 카드.
- **날씨 카드(오른쪽 아래)**: `0°` + SF Symbol 날씨 아이콘(밤이면 달 계열).
- 두 카드는 값이 없으면 숨긴다(기존 기록 포함).

> 위치 카드 자리: 참고 이미지(나이키)는 왼쪽 위지만, 검토에서 요청 문구대로 **오른쪽 위 위치 / 오른쪽 아래 날씨**로 확정했다.

### 3.2 구간 표
- 제목 "구간별 페이스" → "구간". 하나의 둥근 카드(`background/primary`) 안에 표를 넣는다.
- 헤더: `Km | 평균 페이스 | 심박수` (`text/secondary` 13pt).
- 행: 높이 44pt, km 번호 / 페이스 칸 / 심박수(`157`, 없으면 `--`) 오른쪽 정렬.
- 페이스 칸: 회색 가로 막대(다크 모드 `gray/600` 계열, 라이트 `gray/100`)를 깔고 그 위 왼쪽에 페이스 텍스트를 올린다.
- 막대 길이: 빠를수록 길다. `너비 = 최소 35% + 65% × (가장 느린 페이스 − 이 구간 페이스) / (가장 느린 − 가장 빠른)`. 모든 구간이 같으면 100%.
- 가장 빠른 구간 막대만 `main/500` 옅은 틴트로 강조할지는 디자인 시스템과 맞춰 판단한다(기본은 회색만, 나이키와 동일).
- 이전 기록(구간 페이스 없음)에 평균 페이스로 채우던 안내 문구는 그대로 둔다.

## 4. 데이터 흐름

### 4.1 구간 심박수 (새로 저장)
- `RunLapPace`에 `averageHeartRate: Double?` 추가(기본값 nil → 기존 호출부 그대로 동작).
- 랩 확정 때 구간의 시작·끝 시각(`Date`)을 함께 기록해 둔다(메모리만).
- 러닝 종료 뒤 전체 평균 심박수를 조회하는 자리(`stop` 흐름)에서 구간마다 `averageHeartRate(from:to:)`를 조회해 채운다.
  - 달리는 중에 바로 조회하지 않는 이유: Apple Watch 심박 샘플이 iPhone HealthKit에 늦게 동기화돼 구간 도중 조회는 비는 경우가 많다.
- Firestore `lapPaces[]` 원소에 `averageHeartRate` 키를 값이 있을 때만 넣는다. 조회 때 없으면 nil → 표에 `--`.

### 4.2 위치 이름·날씨 (새로 저장)
- `RunRecord`에 `locationName: String?`, `weather: RunWeatherSnapshot?`(`temperatureCelsius: Double`, `symbolName: String`) 추가.
- 러닝 종료 후 저장(`saveRecord`) 직전에 출발 좌표로 조회한다. 둘 다 실패해도 기록 저장은 막지 않는다(타임아웃 5초).
  - 위치: `MKReverseGeocodingRequest` → `mapItem.addressRepresentations?.cityWithContext`(예: `남양주시, 대한민국`), 없으면 `shortAddress`.
  - 날씨: 아래 5장 선택지 중 승인된 방식.
- Firestore 문서에 `locationName`, `weather: { temperatureCelsius, symbolName }`를 값이 있을 때만 넣는다.
- 공유 화면의 역지오코딩 코드를 새 `RunPlaceNameResolver`로 옮겨 함께 쓴다(공유 화면 동작은 그대로).

### 4.3 상태 관리
- 화면은 `RunRecord` 값만 그린다. km 라벨 좌표 계산은 순수 함수(`RunRouteKilometerMarkers`)로 분리해 단위 테스트한다.
- 막대 너비 계산도 순수 함수로 분리해 테스트한다.

## 5. 검토 결과

1. **기준 브랜치**: `dev`에서 분기 — 확정. #234(PR #235)는 이미 `dev`에 머지돼 그 위에서 시작한다.
2. **위치 카드 자리**: 오른쪽 위 — 확정.
3. **날씨 데이터 출처**: WeatherKit — 확정
   - **WeatherKit (권장)**: Apple 공식, 무료 한도(월 50만 호출) 충분, SF Symbol 이름을 바로 준다. 단 Apple Developer 사이트에서 App ID에 WeatherKit capability를 **사용자가 직접 켜야** 하고, 앱 entitlement 추가와 화면에 Apple 날씨 출처 표기(attribution)가 필요하다.
   - Open-Meteo: 키 없이 바로 쓰지만 무료 플랜은 비상업 용도 조건이 있어 App Store 앱에는 맞지 않을 수 있다.

## 6. 작업 목록 (Tasks)

- [ ] Task 1: `RunLapPace.averageHeartRate`, `RunRecord.locationName`·`weather` 모델과 Firestore 저장·조회 매핑 (+ 테스트)
- [ ] Task 2: 랩 시작·끝 시각 기록, 종료 시 구간 심박수 조회 (+ 테스트, 가짜 `HeartRateRepository`)
- [ ] Task 3: `RunPlaceNameResolver`(역지오코딩)·`RunWeatherRepository`(날씨) 추가, 종료 저장 경로에 연결
- [ ] Task 4: km 라벨 좌표 계산 순수 함수 (+ 테스트)
- [ ] Task 5: 지도 카드 개편 — 크기·영역·원 핀·km 캡슐·위치/날씨 카드
- [ ] Task 6: 구간 표 개편 — 헤더·막대·심박수 열 (+ 막대 너비 테스트)
- [ ] Task 7: 시뮬레이터 빌드, 샘플 기록으로 지도·표 스크린샷 확인 (라이트/다크)

## 7. 완료 기준 (Acceptance Criteria)

- [ ] 지도 카드가 세로로 커지고 경로 전체가 여백을 두고 들어온다.
- [ ] 출발 초록 원·도착 빨강 원(흰 테두리)이 보이고 텍스트 말풍선 핀은 없다.
- [ ] 1km마다(15km 초과 시 2km마다) 흰 `N km` 캡슐이 경로 위에 놓인다.
- [ ] 새 러닝에는 위치 이름·날씨가 저장되고 지도 오른쪽 위·오른쪽 아래 카드로 보인다. 값이 없는 기존 기록은 카드가 없다.
- [ ] 구간 표가 `Km | 평균 페이스 | 심박수` 열로 보이고, 빠른 구간 막대가 더 길다. 심박수가 없으면 `--`.
- [ ] 위치·날씨·심박수 조회가 실패해도 러닝 기록 저장과 화면 표시는 정상이다.
- [ ] 단위 테스트와 시뮬레이터 빌드가 통과한다.

## 8. 예상 소요 시간

| 작업 | 예상 시간 |
|------|-----------|
| Task 1~2 (모델·저장·구간 심박수) | 1.5시간 |
| Task 3 (위치·날씨) | 1.5시간 |
| Task 4~5 (지도) | 2시간 |
| Task 6 (구간 표) | 1시간 |
| Task 7 (QA) | 1시간 |
| **합계** | 7시간 |

## 9. 특이 사항 / 기술 검토

- WeatherKit capability가 꺼져 있으면 날씨 조회가 실패한다. 실패는 조용히 넘기고 카드만 숨긴다.
- 구간 심박수는 Apple Watch를 차고 달렸을 때만 의미가 있다. Watch가 없으면 모두 `--`.
- 일시정지 구간이 낀 랩은 벽시계 시각 범위로 조회하므로 쉬는 동안의 심박도 평균에 들어간다(영향 작음, 문서에 남긴다).
- 돌아오는 경로(왕복)는 km 라벨이 가깝게 겹칠 수 있다(나이키도 동일). 1차는 겹침 처리 없이 둔다.
- 친구 기록 화면(`owner != nil`)도 같은 뷰를 쓰므로 함께 바뀐다.

---

> **검토 의견** (개발자 작성):
> 승인 여부:  승인 ✅ (2026-11-25, 기준 `dev`, 위치 카드 오른쪽 위, 날씨 WeatherKit)
