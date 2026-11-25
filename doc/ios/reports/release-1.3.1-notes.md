# Pacing 1.3.1 업데이트·심사 문구

기준: `main` (1.3.0) → `dev` 1344fe4. 아래 내용은 이 구간에 병합된 PR #235(#234), #237(#236)과 코드에서 확인했다.

## App Store 업데이트 내용

Pacing 1.3.1 업데이트

활동 상세 화면이 새로워졌어요!

달린 경로를 더 큰 지도로 확인해 보세요.

출발·도착 지점과 km 표시로 어디서 얼마나 달렸는지 한눈에 볼 수 있어요.

구간 기록을 표로 비교해 보세요.

구간마다 페이스와 심박수를 나란히 보고, 가장 빨랐던 구간을 바로 찾을 수 있어요.

새 러닝부터 달린 곳의 위치와 날씨도 함께 남겨요.

러닝 종료 음성 안내가 더 빨라졌어요.

러닝을 마치면 결산 안내가 바로 나오고, 안내가 끝나면 음악 볼륨이 원래대로 돌아와요.

10km처럼 딱 맞춰 끝낸 러닝의 마지막 구간 기록도 바로잡았어요.

새로운 Pacing 1.3.1과 함께 달려보세요!

## App Review 메모

Hello App Review Team,

Thank you for reviewing Pacing 1.3.1.

This update includes:

- A redesigned activity detail screen with a larger route map, start and finish markers, and kilometer labels along the route.
- A split table that compares the average pace and heart rate of each kilometer.
- The city name and current weather (provided by Apple Weather via WeatherKit) for new runs.
- Faster Korean voice guidance for the run summary, and restored music volume after voice guidance.

Test account:

Email: [REVIEWER_ACCOUNT_EMAIL]
Password: [REVIEWER_ACCOUNT_PASSWORD]

Testing instructions:

1. Sign in with the review account.
2. Start and finish a run of at least 1 km. Location permission is needed for route recording.
3. Open the run from the activity history to see the route map, kilometer labels, location and weather cards, and the split table. The Apple Weather attribution link appears below the map.
4. Heart rate per split requires available HealthKit heart rate data, for example from a paired Apple Watch. Without it, the heart rate column shows "--".

Thank you for reviewing Pacing 1.3.1.

## 제출 전 확인

- [ ] Apple Developer에서 App ID `com.eunchan.Pacing`에 WeatherKit capability를 켰다.
- [ ] Xcode에서 `feat/238-release-1.3.1` 브랜치로 iPhone 1.3.1, Watch 1.3.1인지 확인하고 Archive했다.
- [ ] 심사 계정 정보는 App Store Connect에만 입력했다.
