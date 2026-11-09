# feat #07 주변 러너

## 목표
Firebase Realtime DB를 이용해 러닝 중 내 위치와 현재 곡 정보를 브로드캐스트하고, 주변 러너를 지도 핀과 시트로 보여주기

---

## 현재 상태 (feat/06 기준)
- 러닝 탭 하단 "주변" 버튼 존재하지만 액션 없음
- Firebase Realtime DB SPM 패키지는 이미 추가됨 (`FirebaseDatabase`)
- 위치 수집: `LocationManager`에서 `CLLocationManager`로 실시간 GPS 수집 중

---

## 구현 목표

### 1. 내 위치 브로드캐스트
- 러닝 시작 시 `activeRunners/{uid}` 경로에 5초 간격으로 업데이트
- 러닝 종료 시 해당 노드 삭제 (오프라인 시 자동 삭제 — `onDisconnect`)
- 저장 데이터:
  ```
  activeRunners/{uid}
    latitude: Double
    longitude: Double
    currentSongTitle: String
    currentArtist: String
    updatedAt: Long (Unix ms)
    nickname: String
  ```

### 2. 주변 러너 수신
- `activeRunners` 전체 구독 → 내 위치 기준 반경 필터링 (클라이언트 사이드)
- 반경: 300m / 500m / 1km (기본값 500m)
- 나 자신 제외 (`uid` 비교)
- 실시간 업데이트: `observe(.value)` 로 변경 감지

### 3. 지도 핀 표시
- 주변 러너 위치에 커스텀 핀 표시
- 핀: 작은 원형 아바타 + 닉네임
- 핀 탭 → 해당 러너 카드 하이라이트

### 4. 주변 러너 시트 (Bottom Sheet)
- "주변" 버튼 탭 시 시트 열기
- 반경 세그먼트 피커: 300m / 500m / 1km
- 러너 카드 목록:
  - 닉네임
  - 현재 듣는 곡 제목 + 아티스트
  - 나와의 거리 (m/km)
  - "같이 듣기" 버튼 (feat #08에서 구현, 이번엔 UI만)
- 러너 없을 때: "주변에 러너가 없어요" 빈 상태

---

## 화면 구성

### 지도 위 핀
```
   ◉ [닉네임]
```
- 크기: 36×36 원형, 테두리 흰색
- 배경: main500 색상
- 텍스트: 닉네임 이니셜 1글자

### 주변 찾기 시트
```
┌─────────────────────────┐
│  주변 러너        완료   │
│  [300m] [500m] [1km]    │  ← 세그먼트 피커
├─────────────────────────┤
│  ● 김은찬                │
│    로마네스크 · 쏜애플   │
│    230m 떨어져 있어요    │
│              [같이 듣기] │
├─────────────────────────┤
│  ● 정영훈                │
│    Supernova · aespa    │
│    480m 떨어져 있어요    │
│              [같이 듣기] │
└─────────────────────────┘
```

---

## 기술 스택
- `FirebaseDatabase` — Realtime DB 읽기/쓰기
- `CLLocation.distance(from:)` — 거리 계산
- `MapKit` — 커스텀 어노테이션 추가
- `Timer` — 5초 간격 브로드캐스트

---

## 작업 순서
1. `RealtimeDBService` 싱글턴 작성 — 브로드캐스트 / 구독 / 삭제
2. `NearbyRunnerViewModel` 작성 — 주변 러너 모델, 필터링, 반경 설정
3. `RunningViewModel` 수정 — 러닝 시작/종료 시 브로드캐스트 on/off
4. `RunningMusicViewModel` 연동 — 현재 곡 정보 브로드캐스트에 포함
5. 지도 커스텀 핀 추가 (`RunningView`)
6. 주변 러너 시트 UI 작성
7. QA → 보고서 → 커밋/PR
