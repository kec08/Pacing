import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("홈", systemImage: "house.fill")
                }

            RunningView()
                .tabItem {
                    Label("러닝", systemImage: "figure.run")
                }

            MyView()
                .tabItem {
                    Label("마이", systemImage: "person.fill")
                }
        }
        .tint(Color.main500)
    }
}
