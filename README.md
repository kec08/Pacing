# Pacing

> 같은 음악, 같은 페이스. 음악으로 연결되는 러닝 경험

[![Platform](https://img.shields.io/badge/platform-iOS-000000?logo=apple)](https://apps.apple.com/kr/app/pacing/id6784299290)
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-F05138?logo=swift)](https://developer.apple.com/xcode/swiftui/)
[![Firebase](https://img.shields.io/badge/backend-Firebase-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com/)

Pacing은 러닝을 기록하고, Apple Music과 함께 나만의 페이스를 만들며, 친구·주변 러너와 음악을 공유할 수 있는 iOS 러닝 앱입니다.

<p align="center">
  <a href="https://apps.apple.com/kr/app/pacing/id6784299290"><strong>App Store에서 Pacing 만나기</strong></a>
</p>

## 핵심 기능

| 영역 | 기능 |
| --- | --- |
| 러닝 기록 | 위치 기반 경로와 거리, 시간, 페이스를 기록하고 활동 상세 화면에서 경로와 구간 페이스를 확인합니다. |
| 러닝 분석 | 주·월·연·전체 단위 통계와 거리 차트로 기록의 변화를 살펴봅니다. 차트의 날짜를 선택하면 해당 날짜의 러닝 카드를 바로 확인할 수 있습니다. |
| 음악 경험 | Apple Music 보관함 플레이리스트, 개인화 추천, 최근 재생 앨범을 탐색하고 앱 안에서 재생합니다. |
| 함께 듣기 | 친구의 플레이리스트와 최근 재생 음악을 발견하고, 주변 러너와 실시간으로 같은 음악을 듣습니다. |
| 소셜 | 친구 검색·추천·요청 관리, 친구 프로필, 친구의 최근 러닝 및 음악 활동을 제공합니다. |
| 인증과 프로필 | 이메일, Apple, Google, Kakao, Naver 로그인과 프로필 편집을 지원합니다. |

## 미리보기

<p align="center">
  <img src="docs/images/readme/pacing-preview-01.jpg" alt="Pacing 시작 화면" width="30%" />
  <img src="docs/images/readme/pacing-preview-02.jpg" alt="최근 러닝 기록" width="30%" />
  <img src="docs/images/readme/pacing-preview-03.jpg" alt="러닝 활동 상세" width="30%" />
</p>
<p align="center">
  <img src="docs/images/readme/pacing-preview-04.jpg" alt="친구 목록" width="30%" />
  <img src="docs/images/readme/pacing-preview-05.jpg" alt="지도 위 러닝 시작" width="30%" />
  <img src="docs/images/readme/pacing-preview-06.jpg" alt="Apple Music 재생 화면" width="30%" />
</p>
<p align="center">
  <img src="docs/images/readme/pacing-preview-07.jpg" alt="주변 러너 함께 듣기" width="30%" />
  <img src="docs/images/readme/pacing-preview-08.jpg" alt="음악 추천 화면" width="30%" />
  <img src="docs/images/readme/pacing-preview-09.jpg" alt="러닝 통계 차트" width="30%" />
</p>

## 기술 스택

| 구분 | 사용 기술 |
| --- | --- |
| UI | SwiftUI, Swift Charts |
| 비동기 처리 | Swift Concurrency (`async`/`await`) |
| 지도·위치 | MapKit, Core Location, 백그라운드 위치 업데이트 |
| 음악 | MusicKit, Apple Music API |
| 백엔드 | Firebase Authentication, Cloud Firestore, Realtime Database, Cloud Functions |
| 로그인 | Sign in with Apple, Google Sign-In, Kakao SDK, Naver Third-Party Login |
| 의존성 관리 | Swift Package Manager (Xcode 프로젝트) |

## 아키텍처

프로젝트는 기능 중심으로 화면을 나누고, 각 기능 안에서 **View와 ViewModel**을 분리합니다. 공통 플랫폼·데이터 접근 코드는 `Core`에 두어 화면이 Firebase, 위치, MusicKit 구현에 직접 의존하지 않도록 구성했습니다. 현재 규모에 맞춘 실용적인 Feature-first MVVM 구조입니다.

```text
SwiftUI View
    ↓ 사용자 입력 / 상태 표현
ViewModel
    ↓ 화면 상태 · 비즈니스 흐름 조합
Core Service
    ↓ 데이터·플랫폼 접근 캡슐화
Firebase / Apple Music / Core Location / MapKit
```

| 계층 | 책임 |
| --- | --- |
| `Features/*/View` | 화면 렌더링, 접근성·터치 이벤트 등 UI 표현 |
| `Features/*/ViewModel` | 화면 상태, 비동기 로딩, 사용자 액션 처리 |
| `Core/AppState` | 앱 전역 상태와 탭·세션 흐름 관리 |
| `Core/Firebase` | 사용자, 러닝, 친구, 최근 음악, 공유 플레이리스트의 영속·실시간 데이터 처리 |
| `Core/Location` | 권한 처리, 위치 추적, 경로 좌표 수집, 백그라운드 위치 동작 관리 |
| `Core/Music` | Apple Music 권한, 추천·보관함·아트워크 조회와 재생 처리 |
| `Models` | 러닝, 친구, 공유 플레이리스트 등 도메인 데이터 모델 |
| `DesignSystem` | 색상과 공통 로딩 UI 등 재사용 가능한 표현 요소 |

### 프로젝트 구조

```text
Pacing/
├── Core/
│   ├── AppState/             # 앱 전역 상태
│   ├── Auth/                 # 인증 상태와 소셜 로그인
│   ├── Date/                 # 날짜·기간 계산
│   ├── Firebase/             # Firestore / Realtime Database 서비스
│   ├── Location/             # 위치·경로 추적
│   └── Music/                # Apple Music 추천·재생·아트워크
├── DesignSystem/             # 공통 컬러와 UI 컴포넌트
├── Features/
│   ├── Auth/                 # 로그인·회원가입
│   ├── Onboarding/           # 프로필·권한 설정
│   ├── Home/                 # 러닝·친구 활동 홈
│   ├── Running/              # 러닝, 경로, 요약, 주변 러너
│   ├── Friends/              # 친구와 친구 프로필
│   ├── Share/                # 음악 추천·공유 플레이리스트
│   ├── My/                   # 내 프로필·통계·히스토리
│   └── Main/                 # 탭 내비게이션
└── Models/                   # 도메인 모델
```

## 시작하기

### 요구 사항

- iOS 26.0 이상을 지원하는 Xcode 환경
- Apple Music 기능 사용을 위한 Apple Music 권한 및 구독 환경
- Firebase 프로젝트와 인증 공급자(Apple, Google, Kakao, Naver) 설정

### 실행

1. 저장소를 클론합니다.
2. `Pacing/Pacing.xcodeproj`를 Xcode에서 엽니다.
3. Swift Package 의존성을 해석한 뒤, 개인 Firebase·소셜 로그인 설정을 프로젝트 환경에 맞게 구성합니다.
4. 실행할 시뮬레이터 또는 기기를 선택하고 `Pacing` 스킴을 빌드합니다.

명령행 빌드는 다음과 같이 실행할 수 있습니다.

```bash
xcodebuild \
  -project Pacing/Pacing.xcodeproj \
  -scheme Pacing \
  -configuration Debug \
  build
```

## 문서

- [프로젝트 문서 안내](doc/README.md)
- [Pacing App Store](https://apps.apple.com/kr/app/pacing/id6784299290)

---

Made with pace and music.
