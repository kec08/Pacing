# feat: Watch 음악 탭 및 러닝 중 재생 제어 계획서

> **작성일**: 2026-09-21  
> **기준 브랜치**: `dev`  
> **관련 이슈**: [#173](https://github.com/kec08/Pacing/issues/173)

## 목표

Apple Watch 첫 번째 음악 탭에서 iPhone의 최근 재생 음악을 확인하고 선택해 재생합니다. 러닝 중 세 번째 탭에서는 iPhone에서 재생 중인 곡의 앨범 아트·제목·아티스트와 이전/재생·일시정지/다음 제어를 제공합니다.

## 범위

- 최근 재생 음악 목록과 곡 선택 재생
- iPhone의 현재 재생 상태를 Watch에 전달하고 Watch 제어 요청을 iPhone에 전달
- 러닝 중 화면: 시간, 앨범 아트, 곡 정보, 이전/재생·일시정지/다음 버튼
- 앨범 아트 탭 시 하단 제어를 부드럽게 숨기고 아트를 확장하는 전환
- 빈 상태·권한/연결 오류 상태·접근성 레이블·Reduce Motion 대응

## 아키텍처

- `MusicPlaybackRepository` 프로토콜로 조회·상태 관찰·제어 요청을 추상화합니다.
- iPhone은 MusicKit 재생 상태와 최근 재생 목록을 제공하는 Repository 구현을 둡니다.
- Watch는 WatchConnectivity로 iPhone 스냅샷과 제어 명령을 교환하는 Repository 구현을 둡니다.
- ViewModel은 Repository 상태를 화면 상태로 변환하고, View는 표시와 사용자 입력 전달만 담당합니다.
- Watch 자체 MusicKit 제어는 프로토콜의 별도 구현으로 확장 가능하게 유지하며 이번 범위에는 포함하지 않습니다.

## 작업 순서

1. 공통 음악 모델·명령·Repository 인터페이스 정의
2. iPhone MusicKit Repository 및 WatchConnectivity 송수신 연결
3. Watch 음악 탭의 최근 재생 목록 및 재생 동작 구현
4. 러닝 중 현재 재생 화면과 앨범 아트 확장 인터랙션 구현
5. 단위 테스트·빌드·실기기 QA 및 문서화

## 검토 결과

- 초기 단계는 iPhone을 단일 재생 원본으로 두는 방식이 음악 권한·큐·Apple Music 계정 상태를 일관되게 유지할 수 있어 현실적입니다.
- Watch 화면의 삭제 요청(X)과 연결 버튼은 요구사항에 따라 포함하지 않습니다.
- 실제 최근 재생 이력은 MusicKit 접근 제약을 확인하고, 제공 불가 시 Apple Music의 최근 항목 또는 앱 내 재생 이력으로 명확히 대체합니다.

## 완료 기준

- [ ] 첫 번째 탭에 최근 재생 음악 목록이 표시되고 곡 선택 시 iPhone 재생을 요청함
- [ ] 러닝 중 음악 탭이 현재 곡·앨범 아트·제어를 표시함
- [ ] 앨범 아트 탭 시 제어가 애니메이션과 함께 숨겨지고 아트가 확장됨
- [ ] WatchConnectivity 지연/미연결과 빈 재생 상태가 사용자에게 안내됨
- [ ] 관련 자동 테스트·빌드·`git diff --check`가 통과함
- [ ] 실기기 iPhone·Watch QA 결과와 제한사항을 최종 보고서에 기록함
