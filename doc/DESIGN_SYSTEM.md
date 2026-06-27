# Pacing Design System

> Apple Music inspired, Clean & Modern, Light Mode, Rounded Cards, Minimal

---

## Color Tokens

### Main (Pink)

| 토큰 | HEX | 용도 |
|------|-----|------|
| `main/500` | `#FF375F` | Primary 버튼, 주요 강조 |
| `main/400` | `#EB2954` | 호버/프레스 상태 |
| `main/300` | `#F46882` | 보조 강조, 아이콘 |
| `main/200` | `#E8D1D7` | 배경 틴트, 태그 |

### Sub (Indigo)

| 토큰 | HEX | 용도 |
|------|-----|------|
| `sub/500` | `#5E5CE6` | 보조 버튼, 링크 |
| `sub/400` | `#7E7BEF` | 호버/프레스 상태 |
| `sub/300` | `#D3D2E6` | 배경 틴트 |

### Background

| 토큰 | HEX | 용도 |
|------|-----|------|
| `background/primary` | `#FFFFFF` | 메인 배경, 카드 |
| `background/secondary` | `#F5F5F7` | 화면 배경, 섹션 구분 |

### Gray

| 토큰 | HEX | 용도 |
|------|-----|------|
| `gray/100` | `#ECECEF` | 입력 필드 배경 |
| `gray/200` | `#E3E3E6` | 비활성 배경 |
| `gray/300` | `#D2D2D5` | 보더, 구분선 |
| `gray/400` | `#A8A8AA` | placeholder 텍스트 |
| `gray/500` | `#838386` | 보조 아이콘 |
| `gray/600` | `#474749` | 비활성 텍스트 |

### Text

| 토큰 | HEX | 용도 |
|------|-----|------|
| `text/primary` | `#1C1C1E` | 본문, 제목 |
| `text/secondary` | `#7A7A80` | 부제목, 설명 텍스트 |

### Divider

| 토큰 | HEX | 용도 |
|------|-----|------|
| `divider/primary` | `#C8C8CC` | 섹션 구분선 |
| `divider/secondary` | `#7A7A80` | 강조 구분선 |

### Accent

| 토큰 | HEX | 용도 |
|------|-----|------|
| `accent/500` | `#FF3740` | 알림 배지, 경고 강조 |

### Action

| 토큰 | HEX | 용도 |
|------|-----|------|
| `success/500` | `#39D053` | 완료, 연결 성공 |
| `warning/500` | `#FFA006` | 주의, 배터리 낮음 |
| `info/500` | `#2383E7` | 안내, 정보 |

---

## Swift 코드 (Color Extension)

```swift
extension Color {
    // Main
    static let main500 = Color(hex: "#FF375F")
    static let main400 = Color(hex: "#EB2954")
    static let main300 = Color(hex: "#F46882")
    static let main200 = Color(hex: "#E8D1D7")

    // Sub
    static let sub500 = Color(hex: "#5E5CE6")
    static let sub400 = Color(hex: "#7E7BEF")
    static let sub300 = Color(hex: "#D3D2E6")

    // Background
    static let backgroundPrimary = Color(hex: "#FFFFFF")
    static let backgroundSecondary = Color(hex: "#F5F5F7")

    // Gray
    static let gray100 = Color(hex: "#ECECEF")
    static let gray200 = Color(hex: "#E3E3E6")
    static let gray300 = Color(hex: "#D2D2D5")
    static let gray400 = Color(hex: "#A8A8AA")
    static let gray500 = Color(hex: "#838386")
    static let gray600 = Color(hex: "#474749")

    // Text
    static let textPrimary = Color(hex: "#1C1C1E")
    static let textSecondary = Color(hex: "#7A7A80")

    // Divider
    static let dividerPrimary = Color(hex: "#C8C8CC")
    static let dividerSecondary = Color(hex: "#7A7A80")

    // Accent
    static let accent500 = Color(hex: "#FF3740")

    // Action
    static let success500 = Color(hex: "#39D053")
    static let warning500 = Color(hex: "#FFA006")
    static let info500 = Color(hex: "#2383E7")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
```

---

## Claude 프롬프트 (디자인 요청 시 사용)

```
Create a modern iOS running app design system.

Primary Color: #FF375F
Secondary Color: #5E5CE6

Style:
- Apple Music inspired
- Clean and modern
- Supports Light Mode
- Rounded cards
- Minimal design
- Soft gray backgrounds
- High contrast typography

Color Tokens:
main/500 #FF375F / main/400 #EB2954 / main/300 #F46882 / main/200 #E8D1D7
sub/500 #5E5CE6 / sub/400 #7E7BEF / sub/300 #D3D2E6
background/primary #FFFFFF / background/secondary #F5F5F7
text/primary #1C1C1E / text/secondary #7A7A80
success/500 #39D053 / warning/500 #FFA006 / info/500 #2383E7
```
