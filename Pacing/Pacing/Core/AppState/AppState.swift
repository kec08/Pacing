import SwiftUI
import Combine

final class AppState: ObservableObject {
    @Published private(set) var appearance: AppAppearance
    @Published var isLoggedIn: Bool = false {
        didSet { UserDefaults.standard.set(isLoggedIn, forKey: "isLoggedIn") }
    }
    @Published var isProfileComplete: Bool = false {
        didSet { UserDefaults.standard.set(isProfileComplete, forKey: "isProfileComplete") }
    }
    // 로그인 직후 프로필 복원 중 → 스플래쉬 유지 (ProfileSetupView 깜빡임 방지)
    @Published var isAuthLoading: Bool = false

    init() {
        appearance = AppAppearance(rawValue: UserDefaults.standard.string(forKey: AppAppearance.storageKey) ?? "") ?? .light
    }

    func setAppearance(_ appearance: AppAppearance) {
        self.appearance = appearance
        UserDefaults.standard.set(appearance.rawValue, forKey: AppAppearance.storageKey)
    }
}
