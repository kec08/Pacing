# fix: Watch 음악 앨범아트 미표시 (#180) 계획서

> **브랜치**: `fix/180-watch-music-artwork`
> **기준 브랜치**: `origin/dev` (`616126c`)

## 문제와 원인

Watch 음악 화면은 곡 제목·아티스트·재생 제어를 정상 수신하지만 앨범 아트는 기본 아이콘으로 남는다.

1. 최근 재생 목록 모델은 `artworkURL`만 전달한다. MusicKit 라이브러리의 `musicKit://` artwork URL은 watchOS `AsyncImage`/`URLSession`이 처리할 수 없다.
2. 현재 재생 곡은 원본 JPEG를 그대로 WatchConnectivity JSON payload에 넣는다. `Data`는 JSON 직렬화 중 Base64로 팽창하며, 전송 한도 초과 시 `updateApplicationContext` 실패가 무시된다.
3. 따라서 이미지 없이 먼저 전송된 메타데이터만 Watch에 남고, URL fallback도 실패해 placeholder가 표시된다.

## 목표

- 현재 재생 곡과 최근 재생 목록 모두에서 iPhone이 생성한 축소 JPEG를 우선 렌더링한다.
- `musicKit://` URL에 의존하지 않는다.
- 전체 WatchConnectivity payload가 안전 예산을 넘지 않도록 곡별 썸네일 예산을 분리한다.
- 이미지 생성·전송 실패 시에도 곡 정보·제어 기능은 유지하고 HTTP(S) URL만 보조 fallback으로 사용한다.

## 구현 단계

1. 공유 음악 스냅샷의 최근 재생 트랙에 artwork data 필드를 추가한다.
2. iPhone 측에 크기별 JPEG 인코더를 둔다.
   - 현재 곡: 확장 화면에 맞는 썸네일과 보수적인 최대 바이트 수
   - 최근 목록: 작은 행 아이콘용 썸네일과 더 작은 최대 바이트 수
3. 이미지 캐시와 HTTP(S) 원격 artwork 보강 경로에서 위 인코더를 재사용하고, 다운로드 완료 시 스냅샷을 다시 발행한다.
4. 발행 전 직렬화된 payload 크기를 확인해 전송 예산을 보장한다. 실패를 묵살하지 않고, 이미지 제거 fallback payload를 발행한다.
5. Watch 목록과 러닝 음악 탭이 data → HTTP(S) URL → placeholder 순서로 렌더링하도록 통일한다.
6. 이미지 인코딩·모델 디코딩·fallback 동작 테스트 및 Watch 빌드를 수행한다.

## 검토 결과

- URL만 전달하는 방식은 라이브러리 곡에서 재현되는 `musicKit://` 스킴 문제를 해결하지 못해 채택하지 않는다.
- 원본 이미지를 전송하는 방식은 WatchConnectivity payload 한도를 침해할 수 있어 채택하지 않는다.
- iPhone을 이미지 생성의 단일 원본으로 유지하므로 Watch의 MusicKit 권한·네트워크 상태와 독립적으로 동작한다.

## QA 기준

- Apple Music 라이브러리 곡(`musicKit://` 가능), 카탈로그 HTTP(S) artwork, artwork 없음의 세 경우
- 현재 곡 전환 및 최근 재생 12곡 누적 시 아트워크/메타데이터 일치
- Watch 연결 지연 후 application context 복구
- 전송 예산 초과 상황에서도 크래시 없이 기본 이미지로 안전하게 fallback
