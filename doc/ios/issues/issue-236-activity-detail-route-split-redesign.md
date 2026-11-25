# [feat] 활동 상세 경로 지도·구간 표 개편

> **상태**: 개발 완료 · 실기기 QA 대기
> **작성일**: 2026-11-25
> **GitHub 이슈**: [#236](https://github.com/kec08/Pacing/issues/236)
> **브랜치**: `feat/236-activity-detail-redesign` (`dev` 기준)
> **계획서**: `doc/ios/plans/feat-236-activity-detail-route-split-redesign-plan.md`

## 배경

활동 상세의 경로 지도가 작고(270pt) 출발·도착을 텍스트 말풍선으로 표시했으며, 구간별 페이스는 카드 목록이라 구간끼리 비교하기 어려웠다. 나이키 런 클럽처럼 지도와 구간 표를 개편한다.

## 검토 때 확정한 사항

- 기준 브랜치: `dev` (#234 PR #235가 이미 머지된 상태)
- 위치 카드: 지도 **오른쪽 위** (참고 이미지는 왼쪽 위지만 요청 문구대로)
- 날씨 출처: WeatherKit

## 구현 범위

- [x] 지도 카드를 세로형(가로:세로 = 0.8)으로 키우고, 경로 여백 배율 1.4 → 1.6
- [x] 경로선 두께 4 → 6pt
- [x] 출발 초록 원(`success500`)·도착 빨강 원(`accent500`), 흰 테두리 3pt. 텍스트 말풍선 핀 삭제
- [x] 출발·도착이 가까우면(경로 크기의 3% 또는 80m 이내) 두 원을 나란히 붙인 핀 하나로 그림
- [x] 1km마다 흰 캡슐 `N km` 라벨. 경로 길이를 기록 거리에 맞춰 보간. 15km 초과는 2km 간격. 도착 50m 안의 라벨은 생략
- [x] 오른쪽 위 위치 카드(`MKReverseGeocodingRequest` → `cityWithContext`), 오른쪽 아래 기온·날씨 아이콘 카드, 지도 아래 "날씨 정보 제공: Apple 날씨" 법적 고지 링크
- [x] 새 러닝 저장 때 출발 좌표로 위치 이름·날씨 조회(각 5초 제한, 실패해도 저장 진행). Firestore `locationName`, `weather{temperatureCelsius, symbolName}`
- [x] 구간 표 `Km | 평균 페이스 | 심박수`. 페이스 칸에 `gray100` 막대, 빠를수록 길게(35%~100%)
- [x] 랩 확정 때 벽시계 범위를 기록하고 종료 뒤 구간마다 HealthKit 평균 심박수 조회. Firestore `lapPaces[].averageHeartRate`
- [x] 값이 없는 기존 기록: 위치·날씨 카드 숨김, 심박수 `--`
- [x] `com.apple.developer.weatherkit` entitlement 추가

## 계획과 달라진 점

- 공유 화면(`RunRecordCameraShareView`)의 역지오코딩 코드는 옮기지 않았다. 공유 화면 동작에 손대지 않으려고 새 `RunPlaceNameResolver`만 추가했다.
- 출발·도착 핀 겹침 처리를 추가했다. 시뮬레이터 확인에서 왕복 코스의 도착 핀이 출발 핀에 가려 사라졌다.
- Apple 로고 문자(``)가 빈칸으로 보여 날씨 출처 문구를 "Apple 날씨"로 썼다.

## 알려진 제약

- 왕복 코스는 같은 자리를 지나는 km 라벨끼리 겹치고, MapKit이 겹친 라벨 일부를 자동으로 숨긴다(나이키도 같은 방식).
- 구간 심박수는 Apple Watch 심박 샘플이 있을 때만 채워진다. 일시정지가 낀 구간은 쉬는 동안의 심박도 평균에 들어간다.
- WeatherKit capability가 App ID에서 꺼져 있으면 날씨 조회가 실패해 날씨 카드가 숨겨진다.
