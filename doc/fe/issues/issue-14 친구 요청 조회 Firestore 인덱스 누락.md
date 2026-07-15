# issue-14 친구 요청 조회 Firestore 인덱스 누락

> **심각도**: Major 🟠  
> **발견일**: 2026-06-30  
> **발견 브랜치**: `feat/15-friends-tab`  
> **상태**: 해결 완료

---

## 증상 요약

친구 탭 진입 시 받은 친구 요청 조회 쿼리에서 Firestore 복합 인덱스 누락 에러가 발생했다.

## 재현 방법

1. 앱 실행
2. 네이버 로그인 완료
3. 친구 탭 진입
4. Xcode 콘솔에서 Firestore index required 로그 확인

## 예상 동작

별도 콘솔 설정 없이 친구 탭이 받은 요청 목록을 조회해야 한다.

## 실제 동작

Firestore가 `friendRequests` 컬렉션의 `toUID`, `status`, `createdAt desc` 조합에 대한 복합 인덱스를 요구했다.

## 스크린샷 / 로그

```
Listen for query at friendRequests|f:toUID==...status==pending|ob:createdAtdesc__name__desc failed:
The query requires an index.
```

## 원인 분석

`fetchIncomingFriendRequests`에서 `toUID`, `status` 조건과 `createdAt` 정렬을 같은 Firestore 쿼리에 사용했다. Firestore는 이 조합에 복합 인덱스를 요구한다.

## 수정 내용

MVP 단계에서는 콘솔 인덱스 선행 작업을 줄이기 위해 Firestore 쿼리의 `order(by: "createdAt")`를 제거하고, 조회 후 앱에서 `createdAt` 기준 내림차순 정렬하도록 변경했다.

## 관련 파일

- `FirestoreService.swift` : 친구 요청 조회 쿼리의 서버 정렬 제거 및 클라이언트 정렬 추가
