# feat #195 Watch 카운트다운 및 음악 UI 최종 개발 보고서

> **완료일**: 2026-09-29  
> **관련 이슈**: [#195](https://github.com/kec08/Pacing/issues/195)  
> **브랜치**: `feat/195-watch-countdown-recent-music-ui`

## 구현 요약

Watch 러닝 시작 카운트다운을 iPhone과 같은 축소→확대 전환으로 통일하고, 최근 재생·러닝 중 플레이리스트의 재생 제어와 앨범 커버 동기화를 개선했습니다. 곡 전환 중 WatchConnectivity와 앨범 커버 처리로 iPhone UI가 밀리던 경로도 분리·최적화했습니다.

## 변경 사항

- Watch 3·2·1 카운트다운의 숫자별 확대 전환과 Reduce Motion 대응
- 러닝 시작 시 기본 화면이 잠깐 보이지 않도록 대시보드 탭 전환 순서 보정
- 최근 재생·러닝 플레이리스트에서 곡 탭 시 iPhone의 실제 재생 곡 변경
- 실제 현재 재생 곡에만 볼륨 아이콘 표시, 불필요한 핑크 상태 아이콘 제거
- `musicKit://` 대신 iPhone이 해석한 HTTPS artwork URL 우선 사용
- 최근 재생 및 현재 곡 주변의 축소 JPEG artwork data 전달
- Watch 목록에서 화면에 나타나는 곡을 최대 12개 단위로 지연 요청해, 스크롤로 보는 전체 플레이리스트의 커버를 순차 보강
- 동일 음악 상태의 중복 Watch 전송·JSON 직렬화 차단
- Watch 스냅샷 조립을 150ms로 합치고 보정 폴링을 1초로 완화
- 앨범 커버 인코딩 캐시·실패 재시도 간격 적용

## 성능 고려 사항

- iPhone 재생 UI 상태 갱신과 Watch 스냅샷 생성 경로를 분리했습니다.
- 앨범 커버는 곡·URL·표시 용도별로 캐시하며, 목록용 JPEG는 64px·2.2KB로 제한합니다.
- 전체 플레이리스트 이미지 바이너리를 전송하지 않고, 화면에 노출된 행의 HTTPS URL만 점진적으로 보강합니다.

## 검증

- [x] `git diff --check` 통과
- [x] Watch Simulator `xcodebuild test` 통과
- [x] Watch Simulator 빌드 통과
- [x] 연결된 Apple Watch 실기기 대상 빌드·서명 통과
- [x] 기존 사용자 작업 트리 변경을 커밋 범위에서 제외
- [ ] Apple Music 구독 계정·iPhone/Watch 페어링 환경에서 전체 목록 스크롤 및 재생 전환 수동 QA

## 알려진 제한사항

- Apple Music 카탈로그에서 커버 URL을 해석할 수 없거나 네트워크가 없는 곡은 기본 음악 아이콘으로 표시됩니다.
- Watch가 iPhone에 연결되지 않은 상태에서는 화면에 새로 노출된 행의 커버 보강 요청이 다음 연결 시점까지 지연될 수 있습니다.

## 관련 커밋

- `4f57306` Watch 카운트다운 및 최근 재생 음악 UI 개선
- `0a250f2` Watch 음악 동기화 전송 부하 완화
- `e0dfab0` 곡 전환 시 Watch 동기화 작업 합치기
- `103bf12` Watch 플레이리스트 커버 URL 우선순위 보정
- `37d8f9c` Watch 플레이리스트 전체 커버 지연 로드

---

> **개발자 검토 의견**:  
> 최종 승인: 승인 ✅ / 재작업 🔄
