import SwiftUI
import Combine

final class AppState: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var isProfileComplete: Bool = false
}
