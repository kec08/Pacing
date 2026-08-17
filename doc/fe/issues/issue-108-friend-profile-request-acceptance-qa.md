# #108 친구 프로필 권한 오류 및 친구 요청 수락 실패 QA 보고서

> **심각도**: Major 🟠
> **발견일**: 2026-08-17
> **발견 브랜치**: `fix/108-friend-profile-request-acceptance`
> **상태**: 해결 완료

---

## 증상 요약

비친구 프로필 진입 시 친구 전용 데이터 조회가 Firestore 권한에 거부되어 프로필 오류 경고가 노출됐다. 친구 요청 수락은 연속 호출 시 선행 요청이 성공했어도 후속 호출이 실패로 처리되어 수락 실패 경고가 표시될 수 있었다.

## 재현 방법 (Steps to Reproduce)

1. 로그인한 사용자 A가 친구가 아닌 사용자 B의 추천 또는 검색 프로필에 진입한다.
2. 기존 앱은 B의 `runHistory`와 `recentSongs`를 함께 조회한다.
3. Firestore의 상호 친구 규칙에 의해 조회가 거부되면 `친구 프로필 오류` 경고가 표시된다.
4. 사용자 A가 받은 친구 요청의 수락 버튼을 연속으로 누른다.
5. 첫 Cloud Function 호출이 친구 관계를 만들고 요청을 `accepted`로 바꾼 뒤, 후속 호출은 기존 `pending` 조건에서 실패한다.

## 예상 동작

- 비친구 프로필은 공개 정보와 친구 추가 UI를 오류 없이 표시한다.
- 친구가 된 뒤에만 러닝·음악 활동을 조회한다.
- 동일 수락 요청의 중복 호출은 실패 경고 없이 성공으로 수렴하며, UI는 처리 중 중복 입력을 막는다.

## 실제 동작

- 비친구 프로필에서도 친구 전용 데이터를 읽으려 해 프로필 오류 경고가 노출됐다.
- 수락 호출이 중복되면 이미 수락된 요청을 `수락할 수 없는 친구 요청`으로 처리할 수 있었다.

## 스크린샷 / 로그

- 제공된 스크린샷: 비친구 프로필에서 `친구 프로필 오류` 경고가 노출됨.
- Firebase Cloud Functions 로그: 2026-08-17 동일 `acceptFriendRequest` Callable 요청이 짧은 간격으로 반복 수신됨.

## 원인 분석

- `FriendProfileViewModel.load()`가 친구 관계 확인 전 프로필·통계·러닝·음악 데이터를 병렬 요청했다.
- Cloud Function은 요청 상태가 정확히 `pending`일 때만 성공하도록 구현되어, 이미 `accepted`가 된 동일 요청의 재호출을 실패로 반환했다.
- 수락 행 UI는 처리 중 상태를 보관하지 않아 같은 요청의 중복 탭을 방지하지 못했다.

## 수정 내용

- 공개 프로필과 친구 관계를 먼저 로드하고, 친구 관계일 때만 러닝 통계·최근 러닝·최근 음악을 요청하도록 분리했다.
- 비친구 활동 영역은 잠금 안내로 표시한다.
- 수락 버튼에 처리 상태를 추가해 중복 탭을 차단했다.
- Cloud Function이 `accepted` 상태의 동일 요청을 멱등 성공으로 반환하고, 트랜잭션 읽기를 `getAll`로 명시했다.
- iOS 클라이언트가 Callable 응답의 `accepted: true`를 검증하도록 했다.
- 변경된 `acceptFriendRequest` v2 Callable 함수를 `asia-northeast3`에 배포했다.
- 취소된 요청은 기존 문서의 상태만 `pending`으로 되돌리도록 수정하고, Firestore 규칙에서 발신자의 `rejected → pending` 전환을 허용했다.
- 검색 결과는 요청 대기 중인 러너를 유지하고, 추천 목록에서만 제거하도록 필터를 분리했다.
- 검색 빈 상태는 테두리·그림자 없이 아이콘과 문구만 표시하도록 정리했다.

## 관련 파일

- `Pacing/Pacing/Features/Friends/ViewModel/FriendProfileViewModel.swift`: 친구 관계 기반의 활동 데이터 조건부 로드
- `Pacing/Pacing/Features/Friends/View/FriendProfileView.swift`: 비친구 활동 잠금 상태 UI
- `Pacing/Pacing/Features/Friends/ViewModel/FriendsViewModel.swift`: 수락 요청 처리 상태 관리
- `Pacing/Pacing/Features/Friends/View/FriendsView.swift`: 수락·거절 입력 비활성화와 진행 표시
- `Pacing/Pacing/Core/Firebase/FirestoreService.swift`: Callable 성공 응답 검증
- `functions/functions/index.js`: 수락 요청 멱등 처리
