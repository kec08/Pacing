# Refactor 117 — Static Dispatch·Lazy Evaluation·In-Place Mutation

> 상태: 구현 완료 / QA 제한 사항 확인
> 작성일: 2026-08-22
> 관련 이슈: GitHub API 권한 부족으로 미생성
> 브랜치: `refactor/117`

## 1. 목적 및 배경

러닝 기록과 경로를 화면에 표시하는 순수 계산 경로를 대상으로 불필요한 동적 디스패치, 중간 컬렉션 생성, 반복적인 배열 할당을 줄인다. 기능 동작과 화면 결과는 유지하면서 동일한 입력을 기준으로 before/after 실행 시간을 측정해 포트폴리오에 사용할 수 있는 재현 가능한 수치를 남긴다.

## 2. 대상 및 가설

| 항목 | 현재 후보 | 변경 방향 | 검증 지표 |
| --- | --- | --- | --- |
| Static Dispatch | 상속이 필요 없는 `AppDelegate`가 일반 `class`로 선언됨 | `final class`로 제한 | 컴파일러의 디스패치 선택, 빌드/테스트 회귀 |
| Lazy Evaluation | 주간 통계 계산에서 `filter` 결과 배열을 먼저 생성 | `lazy.filter` 기반 단일 순회 | 할당량, 실행 시간 |
| In-Place Mutation | 경로 세그먼트 계산의 `compactMap`과 반복적인 `Array` 결과 생성 | 예약 용량을 가진 결과 배열에 직접 `append` | 실행 시간, 결과 동일성 |

## 3. 작업 목록

- [x] 현재 브랜치 기준 테스트/빌드 가능 여부 확인
- [x] 고정 입력 데이터로 before 벤치마크 실행 및 로그 저장
- [x] `AppDelegate` static dispatch 후보 수정
- [x] 주간 통계의 lazy 평가 적용
- [x] 경로 세그먼트 생성의 in-place mutation 적용
- [x] 단위 테스트로 결과 동일성 검증 코드 추가
- [x] 동일 조건으로 after 벤치마크 실행
- [x] `before.md`, `after.md`, 최종 비교 문서 작성

## 4. 완료 기준

- [ ] Static Dispatch, Lazy Evaluation, In-Place Mutation 변경이 각각 코드와 근거로 식별된다.
- [ ] before/after 측정 조건, 반복 횟수, 평균·표준편차, 개선율을 기록한다.
- [ ] 최적화 전후 결과가 동일하다.
- [ ] 앱 테스트 또는 가능한 범위의 정적 검증 결과와 제한사항을 기록한다.
- [ ] 네트워크·Firebase 응답 시간은 순수 계산 성능 수치에 포함하지 않는다.

## 5. 계획 검토

- 범위: 사용자 기능 변경 없이 계산 경로와 디스패치 최적화만 수행한다.
- 리스크: `lazy`는 모든 경우에 빠른 것이 아니므로 할당 감소와 실행 시간을 함께 측정한다.
- 측정 제한: 현재 환경에서 Xcode 개발 디렉터리가 Command Line Tools로 설정되어 있어 `xcodebuild` 실행이 제한될 수 있다. 이 경우 순수 Swift 벤치마크와 정적 검증을 분리해 보고한다.

> 검토 결과: 구현 진행 가능. 실기기 및 Xcode Instruments 수치는 개발자 환경에서 추가 확인한다.
