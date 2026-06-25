import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("홈", systemImage: "house.fill")
                }

            Text("러닝")
                .tabItem {
                    Label("러닝", systemImage: "figure.run")
                }

            Text("마이")
                .tabItem {
                    Label("마이", systemImage: "person.fill")
                }
        }
        .tint(Color.main500)
    }
}
