import SwiftUI
import Combine

final class AppState: ObservableObject {
    @Published var isLoggedIn: Bool = false {
        didSet { UserDefaults.standard.set(isLoggedIn, forKey: "isLoggedIn") }
    }
    @Published var isProfileComplete: Bool = false {
        didSet { UserDefaults.standard.set(isProfileComplete, forKey: "isProfileComplete") }
    }
}
