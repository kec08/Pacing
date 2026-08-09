import SwiftUI

extension Color {
    // MARK: - Main (Pink)
    static let main500 = dynamic(light: "#FF375F", dark: "#FF3B63")
    static let main400 = dynamic(light: "#EB2954", dark: "#E62954")
    static let main300 = dynamic(light: "#F46882", dark: "#FF6683")
    static let main200 = dynamic(light: "#E8D1D7", dark: "#4D2631")

    // MARK: - Sub (Indigo)
    static let sub500 = dynamic(light: "#5E5CE6", dark: "#5E5CE6")
    static let sub400 = dynamic(light: "#7E7BEF", dark: "#8B87F5")
    static let sub300 = dynamic(light: "#D3D2E6", dark: "#292744")

    // MARK: - Background
    static let backgroundPrimary = dynamic(light: "#FFFFFF", dark: "#111111")
    static let backgroundSecondary = dynamic(light: "#F5F5F7", dark: "#1B1B1B")

    // MARK: - Gray
    static let gray100 = dynamic(light: "#ECECEF", dark: "#292929")
    static let gray200 = dynamic(light: "#E3E3E6", dark: "#3A3A3A")
    static let gray300 = dynamic(light: "#D2D2D5", dark: "#3D3D3F")
    static let gray400 = dynamic(light: "#A8A8AA", dark: "#777777")
    static let gray500 = dynamic(light: "#838386", dark: "#A0A0A5")
    static let gray600 = dynamic(light: "#474749", dark: "#D0D0D4")

    // MARK: - Text
    static let textPrimary = dynamic(light: "#1C1C1E", dark: "#F5F5F7")
    static let textSecondary = dynamic(light: "#7A7A80", dark: "#AEAEB2")

    // MARK: - Divider
    static let dividerPrimary = dynamic(light: "#C8C8CC", dark: "#303032")
    static let dividerSecondary = dynamic(light: "#7A7A80", dark: "#8E8E93")

    // MARK: - Accent
    static let accent500 = dynamic(light: "#FF3740", dark: "#FF6670")

    // MARK: - Action
    static let success500 = dynamic(light: "#39D053", dark: "#30D158")
    static let warning500 = dynamic(light: "#FFA006", dark: "#FF9F0A")
    static let info500 = dynamic(light: "#2383E7", dark: "#0A84FF")

    // MARK: - Loading & Surface
    static let skeletonBase = dynamic(light: "#ECECEF", dark: "#29292B")
    static let skeletonHighlight = dynamic(light: "#FFFFFF", dark: "#444448")
    static let surfaceBorder = dynamic(light: "#D2D2D5", dark: "#3D3D3F")
    static let stopHoldTrack = dynamic(light: "#FFB5C4", dark: "#FFFFFF")
    static let stopHoldProgress = dynamic(light: "#FF375F", dark: "#FFFFFF")
}

private extension Color {
    static func dynamic(light: String, dark: String) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
