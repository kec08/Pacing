# feat #16 친구 프로필 상세 최종 개발 보고서

> **완료일**: 2026-06-30  
> **관련 이슈**: #26  
> **브랜치**: `feat/26-friend-profile-detail`

---

## 구현 요약

친구 탭의 친구 카드를 탭하면 친구 프로필 상세 화면으로 이동하도록 구현했다. 상세 화면은 중앙 프로필, 러닝 요약 지표, 최근 들은 노래 리스트로 구성된다. 러닝 통계는 기존 `users/{uid}/runHistory`에서 산출하고, 최근 들은 노래는 러닝 기록 저장 시 현재곡을 `users/{uid}/recentSongs`에 저장하는 구조를 추가했다.

## 구현된 기능 목록

- [x] 친구 카드 탭 시 친구 프로필 상세 화면 이동
- [x] 추천/검색 사용자 프로필 영역 탭 시 상세 화면 이동
- [x] 친구 프로필 상세 View 추가
- [x] `FriendProfileViewModel` 추가
- [x] `FriendProfileStats`, `FriendRecentSong` 모델 추가
- [x] 친구 상세 관계 상태 버튼 추가
  - 친구 추가
  - 요청 대기중
  - 친구
- [x] 친구 `runHistory` 기반 평균 페이스, 운동 총 시간, 누적 km 산출
- [x] `users/{uid}/recentSongs` 저장/조회 API 추가
- [x] 러닝 기록 저장 시 현재 재생곡을 최근 노래로 저장
- [x] 최근 노래 리스트 및 빈 상태 UI 구현

## 계획서 대비 변경 사항

| 항목 | 계획 | 실제 구현 | 사유 |
|------|------|-----------|------|
| 최근 노래 저장 | 러닝 중 또는 같이 듣기 세션에서 저장 | 러닝 기록 저장 시 현재곡 저장 | 기존 저장 지점이 명확하고 기능 범위를 과하게 넓히지 않기 위함 |
| 앨범 아트 | 1차 구현 기본 음악 아이콘 | 기본 음악 아이콘 | 현재 저장 데이터에 artwork URL이 없음 |
| 추천 사용자 상세 | 친구 카드만 상세 이동 | 추천/검색 사용자도 상세 이동 | 친구 추가 전 사용자 정보를 확인할 수 있어야 함 |

## QA 결과

| 항목 | 결과 |
|------|------|
| 친구 카드 탭 상세 이동 | ✅ 구현 |
| 중앙 프로필 표시 | ✅ 구현 |
| 평균 페이스 / 운동 시간 / 누적 거리 표시 | ✅ 구현 |
| 최근 노래 리스트 표시 | ✅ 구현 |
| 최근 노래 빈 상태 | ✅ 구현 |
| 친구 요청 후 추천 목록 제외 | ✅ 구현 |
| 상세 화면 요청 대기중 유지 | ✅ 구현 |
| Debug 빌드 | ✅ 통과 |
| `git diff --check` | ✅ 통과 |

## 발견된 이슈

| 이슈 | 심각도 | 상태 |
|------|--------|------|
| `FriendProfileViewModel` Combine import 누락 | Minor | QA 중 발견 후 수정 완료 |

## 알려진 제한사항

- 최근 노래는 이번 구현 이후 저장되는 러닝 기록부터 쌓인다.
- 기존 과거 러닝 기록에는 노래 데이터가 없으므로 최근 노래 리스트가 비어 있을 수 있다.
- 앨범 아트는 아직 표시하지 않고 기본 음악 아이콘을 사용한다.
- 같이 듣기 세션만으로 들은 곡을 별도 최근 노래로 저장하는 처리는 후속 개선으로 분리한다.

## 테스트 명령

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Pacing/Pacing.xcodeproj -scheme Pacing -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/PacingDerivedData build
```

## 다음 단계 / 후속 작업

- 실제 Firestore 데이터로 친구 상세 화면 기기 테스트
- 최근 노래 artwork 저장 또는 MusicKit catalog 조회 연동
- 같이 듣기 세션 기반 최근 노래 저장 정책 검토

---

> **개발자 검토 의견**:  
> 최종 승인: 승인 ✅ / 재작업 🔄
