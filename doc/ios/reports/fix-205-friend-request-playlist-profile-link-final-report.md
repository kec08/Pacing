# 친구 요청 복구 및 플레이리스트 프로필 링크 최종 보고서

> 작성일: 2026-09-30  
> 관련 이슈: [#205](https://github.com/kec08/Pacing/issues/205)  
> 브랜치: `fix/205-friend-request-playlist-profile-link`

## 개요

친구 요청 생성 경로를 인증된 Firebase Callable Function으로 이전해 클라이언트의
Firestore 직접 쓰기 실패 영향을 제거했다. 음악 탭의 친구 플레이리스트 상세에서는
소유자 이름을 Pacing 메인 컬러의 프로필 링크로 제공한다.

## 변경 사항

- `sendFriendRequest` Callable Function 추가
  - 인증된 요청의 발신자 UID를 서버에서 확정한다.
  - 대상 사용자를 확인하고, 대기 중인 동일 요청은 중복 생성하지 않는다.
  - 취소·거절된 요청은 `pending` 상태로 다시 열 수 있다.
- iOS 친구 요청 생성 경로를 Callable Function 호출로 변경했다.
- 친구 공유 플레이리스트의 소유자 이름만 메인 컬러 링크로 표시했다.
  - 탭하면 `FriendProfileView`로 이동한다.
  - 추천 플레이리스트·앨범 등 Apple Music 콘텐츠는 기존 일반 텍스트를 유지한다.
- 링크에 접근성 레이블을 추가했다.

## 검증

- `node --check functions/functions/index.js` 통과
- Firebase Functions lint 통과
- `git diff --check` 통과
- 격리된 DerivedData 기준 `Pacing` iOS Simulator 스킴 빌드 통과
- 실기기에서 친구 요청 생성 동작 확인됨
- `sendFriendRequest` Function을 Firebase 프로젝트 `pacing-a8639`에 배포함

## 남은 확인

- 실기기에서 친구 플레이리스트 상세의 소유자 이름 탭 후 프로필 이동을 확인한다.
- 이 항목은 코드 경로와 빌드로 검증했고, PR 생성은 요청에 따라 선행한다.
