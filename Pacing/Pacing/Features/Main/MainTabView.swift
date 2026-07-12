import SwiftUI
import CoreLocation
import FirebaseAuth
import MediaPlayer
import Combine

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
    @State private var didStartBroadcast = false

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

            ShareView()
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
        .onReceive(locationManager.$currentLocation.compactMap { $0 }) { location in
            refreshPresenceBroadcast(with: location.coordinate)
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
        guard !didStartBroadcast else { return }
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
        didStartBroadcast = true
    }

    private func refreshPresenceBroadcast(with coordinate: CLLocationCoordinate2D) {
        guard didStartBroadcast else { return }
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let nickname = UserDefaults.standard.string(forKey: "nickname") ?? "러너"
        let item = MPMusicPlayerController.systemMusicPlayer.nowPlayingItem

        RealtimeDBService.shared.refreshBroadcast(
            uid: uid,
            nickname: nickname,
            coord: coordinate,
            song: (item?.title ?? "", item?.artist ?? ""),
            profileImageBase64: UserDefaults.standard.string(forKey: "profileImageBase64")
        )
    }

    private func stopPresenceBroadcast() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        RealtimeDBService.shared.stopBroadcast(uid: uid)
        didStartBroadcast = false
    }
}
