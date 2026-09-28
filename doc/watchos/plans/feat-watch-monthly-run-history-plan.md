# Apple Watch 이번 달 러닝 기록 연동 및 활동 UI 개선 계획서

> **상태**: 검토 대기<br>
> **작성일**: 2026-09-28<br>
> **관련 이슈**: [#191](https://github.com/kec08/Pacing/issues/191)<br>
> **예정 브랜치**: `feat/191-watch-monthly-run-history`

---

## 1. 목적 및 배경

Watch 활동 탭은 현재 월간 거리·러닝 횟수가 고정값이며 최근 러닝도 빈 상태만 표시한다. iPhone의 Firestore 러닝 기록과 같은 이번 달 요약·최근 기록을 Watch에서도 확인하고, 완료된 러닝의 핵심 정보를 상세 화면에서 볼 수 있도록 개선한다.

## 2. 사용자 시나리오

1. iPhone이 로그인된 사용자의 러닝 기록을 조회하거나 새 기록을 저장한다.
2. iPhone은 이번 달 총 거리·러닝 횟수와 최근 러닝의 경량 데이터를 Watch로 전송하고 마지막 상태를 보관한다.
3. Watch 활동 탭은 이번 달 총 km와 러닝 횟수, 최근 러닝 목록을 표시한다.
4. 각 최근 러닝 행은 굵은 총 거리와 그 아래 `M월 d일 요일`을 표시한다.
5. 사용자가 행을 탭하면 날짜·거리·시간·평균 페이스·칼로리·심박수 등 종료 후 확인 가능한 세부 정보를 본다.
6. Watch 운동 세션 준비 실패 시 `운동 세션을 준비할 수 없어요.` 문구는 표시하지 않고 시작 화면을 유지한다.

## 3. 데이터 흐름

```
Firestore runHistory
  → iPhone run-history sync service
  → WatchConnectivity application context / 실시간 메시지
  → Watch run-history repository (마지막 스냅샷 보관)
  → WatchActivityViewModel
  → 월간 요약 · 최근 러닝 목록 · 상세 화면
```

- Watch에는 렌더링에 필요한 최소 데이터만 보내고, 각 최근 러닝의 경로는 최대 40개 좌표로 축약한다. 대용량 이미지 등은 포함하지 않는다.
- application context를 사용해 Watch가 나중에 열려도 마지막 동기화 결과를 복원한다.
- 이번 달 범위·유효 러닝 판정은 iPhone과 동일한 기준을 사용한다.

## 4. 작업 목록

- [ ] Task 1: iPhone/Watch 공용 Codable 러닝 기록 스냅샷과 월간 요약 모델을 정의한다.
- [ ] Task 2: iPhone에서 기록 조회·저장 후 WatchConnectivity로 스냅샷을 전송한다.
- [ ] Task 3: Watch 수신 저장소와 활동 ViewModel을 추가해 application context 및 실시간 메시지를 처리한다.
- [ ] Task 4: Watch 활동 탭에 이번 달 요약·최근 러닝 행·빈 상태를 구현한다.
- [ ] Task 5: Watch 최근 러닝 상세 화면을 구현하고 행 탭 네비게이션을 연결한다.
- [ ] Task 6: `sessionUnavailable` 오류 문구를 숨기고 다른 오류 문구는 유지한다.
- [ ] Task 7: 월간 집계·날짜 포맷·수신 스냅샷 단위 테스트와 Watch 실기기 QA를 수행한다.

## 5. 완료 기준

- [ ] Watch의 이번 달 총 거리와 러닝 횟수가 iPhone의 동일 월 기록과 일치한다.
- [ ] 최근 러닝 행에 굵은 거리와 `M월 d일 요일`이 올바르게 표시된다.
- [ ] 최근 러닝 행을 탭하면 저장된 종료 지표를 상세 화면에서 확인할 수 있다.
- [ ] Watch가 늦게 열려도 마지막 동기화된 기록이 표시된다.
- [ ] `운동 세션을 준비할 수 없어요.` 문구가 노출되지 않는다.
- [ ] 다른 Watch 러닝 실패 문구와 기존 1km 랩·종료 요약은 회귀하지 않는다.
- [ ] 관련 테스트와 Watch 실기기 QA를 수행한다.

## 6. 변경 예상 범위

- `Pacing/Pacing/Core/Health/PhoneRunSyncPublisher.swift`
- `Pacing/Pacing/Features/Running/ViewModel/RunningViewModel.swift`
- `Pacing/Pacing/Features/Home/ViewModel/HomeViewModel.swift` 또는 러닝 기록 동기화 전용 서비스
- `Pacing/Pacing Watch Watch App/Repository/PhoneRunSyncReceiver.swift`
- `Pacing/Pacing Watch Watch App/Repository/WatchRunHistoryRepository.swift` (신규)
- `Pacing/Pacing Watch Watch App/ContentView.swift`
- `Pacing/Pacing Watch Watch App/Features/Running/Domain/WatchRunDomain.swift`
- iPhone·Watch 테스트 타깃

## 7. QA 및 PR 절차

1. 계획서·GitHub 이슈 등록 후 전용 브랜치에서 구현
2. iPhone/Watch 단위 테스트 및 빌드 수행
3. 개발자가 iPhone과 Apple Watch 실기기에서 동기화·목록·상세·세션 오류 문구를 QA
4. 실기기 결과와 최종 검토가 완료된 뒤에만 PR 생성
5. 최종 머지는 개발자가 직접 진행

---

> **검토 의견** (개발자 작성):<br>
> 승인 여부: 승인 ✅ / 수정 요청 🔄
