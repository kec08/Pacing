# Collection Capacity Pre-allocation·Sub-sequence Sharing 계획서

> 상태: 구현 완료 / 컴파일 QA 진행 중
> 작성일: 2026-08-22
> 관련 이슈: [#121 Collection Capacity Pre-allocation·Sub-sequence Sharing 최적화](https://github.com/kec08/Pacing/issues/121)
> 브랜치: `refactor/121`

## 목적

컬렉션 결과 개수를 예측할 수 있는 데이터 조회 경로의 배열 재할당을 줄이고, 배치 처리 중 생성되는 불필요한 배열 복사를 `ArraySlice` 공유로 제거한다.

## 대상

| 주제 | 대상 코드 | 현재 병목 | 변경 방향 |
| --- | --- | --- | --- |
| Capacity Pre-allocation | Firestore 친구 활동·친구 목록, RealtimeDB 활성 러너/세션 매핑 | 빈 배열에 반복 append | 입력 문서·스냅샷 개수 기준 `reserveCapacity` |
| Sub-sequence Sharing | Apple Music fallback 곡 매칭 | 모든 배치 슬라이스를 `Array`로 복사 | 필요한 시점에 `ArraySlice`를 직접 순회 |

## 완료 기준

- [x] 각 대상의 Before/After 측정 문서 생성
- [x] 고정 입력 벤치마크로 checksum과 개선율 기록
- [ ] 결과 순서와 값이 기존 구현과 동일함을 테스트
- [ ] Xcode 컴파일 QA 및 가능한 범위의 XCTest 실행

## 검토 결과

동작 변경 없이 메모리 할당과 컬렉션 복사만 줄이는 범위로 진행한다. API·Firestore·MusicKit 응답 시간은 순수 계산 측정에서 제외한다.
