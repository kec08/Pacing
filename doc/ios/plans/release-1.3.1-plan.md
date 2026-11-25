# Pacing 1.3.1 릴리스 계획

> GitHub 이슈: [#238](https://github.com/kec08/Pacing/issues/238) · 브랜치: `feat/238-release-1.3.1` (`dev` 기준)

## 기준과 범위
- 기준: `origin/main`(1.3.0)과 `origin/dev`(1344fe4)를 비교한다. 이 구간에 병합된 PR은 #235(#234), #237(#236)이다.
- 변경 범위
  - iPhone·Watch 앱의 마케팅 버전을 1.3.1로 올린다.
  - README에 1.3.1 소개를 추가한다.
  - App Store 업데이트 문구와 심사 메모를 작성한다.

## 순서
1. `origin/dev`에서 릴리스 브랜치를 분기한다.
2. 버전 설정과 문서를 작은 단위로 커밋한다.
3. 시뮬레이터 빌드로 확인한다.
4. 릴리스 브랜치 → `dev` PR을 연다. 병합 뒤 `dev` → `main` PR을 연다. 최종 병합은 개발자가 한다.
5. 개발자가 릴리스 브랜치에서 Xcode로 1.3.1을 Archive하고 업로드한다.

## 확인할 위험
- WeatherKit entitlement가 새로 들어갔다. App ID `com.eunchan.Pacing`에 WeatherKit capability가 켜져 있어야 Archive 서명과 날씨 조회가 된다.
- iPhone과 Watch 앱 버전이 일치해야 한다.
- 심사 계정 비밀번호를 저장소나 PR에 기록하지 않는다.
