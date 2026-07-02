import SwiftUI
import CoreLocation
import FirebaseAuth
import MediaPlayer

private enum MainTab: Hashable {
    case home
    case friends
    case running
    case share
    case my
}

struct MainTabView: View {
    @StateObject private var locationManager = LocationManager.shared
    @State private var selection: MainTab = .home

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tag(MainTab.home)
                .tabItem {
                    Label("홈", systemImage: "house.fill")
                }

            FriendsView()
                .tag(MainTab.friends)
                .tabItem {
                    Label("친구", systemImage: "person.2.fill")
                }

            RunningView()
                .tag(MainTab.running)
                .tabItem {
                    Label("러닝", systemImage: "figure.run")
                }

            SharePlaceholderView()
                .tag(MainTab.share)
                .tabItem {
                    Label("공유", systemImage: "music.note.list")
                }

            MyView()
                .tag(MainTab.my)
                .tabItem {
                    Label("마이", systemImage: "person.fill")
                }
        }
        .tint(Color.main500)
        .onAppear {
            startPresenceBroadcast()
        }
        .onChange(of: selection) { _, newSelection in
            guard newSelection == .running else { return }
            locationManager.requestPermission()
            locationManager.startMonitoringCurrentLocation()
        }
        .onDisappear {
            stopPresenceBroadcast()
        }
    }

    private func startPresenceBroadcast() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let nickname = UserDefaults.standard.string(forKey: "nickname") ?? "러너"

        RealtimeDBService.shared.startBroadcast(uid: uid, nickname: nickname) {
            locationManager.currentLocation?.coordinate
        } songProvider: {
            let item = MPMusicPlayerController.systemMusicPlayer.nowPlayingItem
            return (item?.title ?? "", item?.artist ?? "")
        } profileImageProvider: {
            UserDefaults.standard.string(forKey: "profileImageBase64")
        }
    }

    private func stopPresenceBroadcast() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        RealtimeDBService.shared.stopBroadcast(uid: uid)
    }
}
