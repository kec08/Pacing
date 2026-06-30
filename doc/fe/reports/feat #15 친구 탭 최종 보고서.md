# feat #15 친구 탭 최종 개발 보고서

> **완료일**: 2026-06-30  
> **관련 이슈**: #23  
> **PR**: TBD  
> **브랜치**: `feat/15-friends-tab`

---

## 구현 요약

Pacing v1.2의 5탭 구조에 맞춰 친구 탭 MVP를 구현했다. 친구 탭에서는 받은 요청, 내 친구 목록, 추천 친구, 닉네임 검색 결과를 확인할 수 있고, Firestore 기반 친구 요청 생성/수락/거절 흐름을 연결했다.

## 구현된 기능 목록

- [x] `doc/fe/plans` 기반 계획서 구조 정리
- [x] 친구 도메인 모델 추가 (`FriendUser`, `FriendRequest`)
- [x] Firestore 친구 API 추가
- [x] `FriendsViewModel` 상태 관리 구현
- [x] 친구 탭 UI 구현
- [x] 하단 탭 5개 구조 반영
- [x] 공유 탭 placeholder 추가
- [ ] 연락처 기반 추천 (사유: 개인정보/권한/해시 정책 필요, 후속 범위)
- [ ] 공유 탭 실제 플레이리스트 기능 (사유: 별도 기능 범위)

## 계획서 대비 변경 사항

| 항목 | 계획 | 실제 구현 | 사유 |
|------|------|-----------|------|
| 공유 탭 | placeholder만 추가 | placeholder 추가 | feat #15 범위를 친구 탭 MVP로 유지 |
| 연락처 추천 | 후속 분리 | 미구현 | 연락처 권한 및 phoneHash 정책 별도 검토 필요 |
| QA 이슈 | 없음 예상 | Combine import 누락 발견 후 수정 | 빌드 검증 중 컴파일 에러 확인 |

## QA 결과

| 완료 기준 | 결과 |
|-----------|------|
| 하단 탭이 v1.2 기준 5개 구조로 표시된다 | ✅ 빌드 반영 |
| 친구 탭 진입 시 받은 요청, 내 친구, 추천 친구 섹션이 표시된다 | ✅ 구현 |
| 닉네임 검색으로 Firestore `users` 후보를 조회할 수 있다 | ✅ 구현 |
| 이미 친구이거나 본인인 사용자는 친구 추가 후보에서 제외된다 | ✅ 구현 |
| 친구 추가 버튼 탭 시 `friendRequests` 문서가 생성된다 | ✅ 구현 |
| 받은 요청 수락 시 양쪽 친구 문서가 생성된다 | ✅ 구현 |
| 받은 요청 거절 시 요청 문서가 `rejected` 상태로 처리된다 | ✅ 구현 |
| 데이터가 없거나 로딩 중일 때 UI가 깨지지 않는다 | ✅ 구현 |
| Debug 빌드 | ✅ 통과 |

## 발견된 이슈

| 이슈 | 심각도 | 상태 |
|------|--------|------|
| issue-13 친구 탭 ViewModel Combine import 누락 | Minor | 해결 완료 |

## 알려진 제한사항

- 연락처 기반 추천은 이번 MVP에서 제외했다.
- 추천 친구는 최근 생성된 `users` 문서를 기준으로 표시한다.
- Firestore 닉네임 검색은 prefix 검색 방식이므로 완전한 전문 검색은 지원하지 않는다.
- 공유 탭은 placeholder이며 실제 Apple Music 플레이리스트 공유 기능은 후속 작업이다.

## 테스트 명령

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Pacing/Pacing.xcodeproj -scheme Pacing -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/PacingDerivedData build
```

## 다음 단계 / 후속 작업

- 연락처 권한 및 `phoneHash` 기반 친구 추천 설계
- 공유 탭 플레이리스트 탐색/내 공유 기능 구현
- 실제 Firestore 데이터로 친구 요청 수락/거절 기기 테스트

---

> **개발자 검토 의견**:  
> 최종 승인: 승인 ✅ / 재작업 🔄
