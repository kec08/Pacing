import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "appAppearance"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "시스템 설정 모드"
        case .light: "라이트 모드"
        case .dark: "다크 모드"
        }
    }

    var description: String? {
        switch self {
        case .system: "시스템 디스플레이 설정에 따라 앱도 라이트/다크 모드로 자동 전환됩니다."
        case .light, .dark: nil
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
