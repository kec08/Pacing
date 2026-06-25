import SwiftUI

extension Color {
    // MARK: - Main (Pink)
    static let main500 = Color(hex: "#FF375F")
    static let main400 = Color(hex: "#EB2954")
    static let main300 = Color(hex: "#F46882")
    static let main200 = Color(hex: "#E8D1D7")

    // MARK: - Sub (Indigo)
    static let sub500 = Color(hex: "#5E5CE6")
    static let sub400 = Color(hex: "#7E7BEF")
    static let sub300 = Color(hex: "#D3D2E6")

    // MARK: - Background
    static let backgroundPrimary = Color(hex: "#FFFFFF")
    static let backgroundSecondary = Color(hex: "#F5F5F7")

    // MARK: - Gray
    static let gray100 = Color(hex: "#ECECEF")
    static let gray200 = Color(hex: "#E3E3E6")
    static let gray300 = Color(hex: "#D2D2D5")
    static let gray400 = Color(hex: "#A8A8AA")
    static let gray500 = Color(hex: "#838386")
    static let gray600 = Color(hex: "#474749")

    // MARK: - Text
    static let textPrimary = Color(hex: "#1C1C1E")
    static let textSecondary = Color(hex: "#7A7A80")

    // MARK: - Divider
    static let dividerPrimary = Color(hex: "#C8C8CC")
    static let dividerSecondary = Color(hex: "#7A7A80")

    // MARK: - Accent
    static let accent500 = Color(hex: "#FF3740")

    // MARK: - Action
    static let success500 = Color(hex: "#39D053")
    static let warning500 = Color(hex: "#FFA006")
    static let info500 = Color(hex: "#2383E7")
}

private extension Color {
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
