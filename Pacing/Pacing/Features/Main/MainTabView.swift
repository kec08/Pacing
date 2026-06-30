import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("홈", systemImage: "house.fill")
                }

            FriendsView()
                .tabItem {
                    Label("친구", systemImage: "person.2.fill")
                }

            RunningView()
                .tabItem {
                    Label("러닝", systemImage: "figure.run")
                }

            SharePlaceholderView()
                .tabItem {
                    Label("공유", systemImage: "music.note.list")
                }

            MyView()
                .tabItem {
                    Label("마이", systemImage: "person.fill")
                }
        }
        .tint(Color.main500)
    }
}
