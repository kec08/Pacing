import SwiftUI
import CoreLocation
import FirebaseAuth
import MediaPlayer
import Combine

private enum MainTab: Hashable {
    case home
    case friends
    case running
    case song
    case my
}

struct MainTabView: View {
    @StateObject private var locationManager = LocationManager.shared
    @State private var selection: MainTab = .home
    @State private var didStartBroadcast = false
    @State private var presenceErrorMessage: String?
    @State private var lastPresenceErrorDate: Date?

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tag(MainTab.home)
                .tabItem {
                    Image(systemName: "house.fill")
                }

            FriendsView()
                .tag(MainTab.friends)
                .tabItem {
                    Image(systemName: "person.2.fill")
                }

            RunningView()
                .tag(MainTab.running)
                .tabItem {
                    Image(systemName: "figure.run")
                }

            SongView()
                .tag(MainTab.song)
                .tabItem {
                    Image(systemName: "music.note")
                }

            MyView()
                .tag(MainTab.my)
                .tabItem {
                    Image(systemName: "person.fill")
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
        .alert("위치 공유 오류", isPresented: Binding(
            get: { presenceErrorMessage != nil },
            set: { if !$0 { presenceErrorMessage = nil } }
        )) {
            Button("확인", role: .cancel) { presenceErrorMessage = nil }
        } message: {
            Text(presenceErrorMessage ?? "현재 위치를 공유하지 못했어요.")
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
        } onError: { error in
            DispatchQueue.main.async {
                guard lastPresenceErrorDate?.addingTimeInterval(30) ?? .distantPast < .now else { return }
                lastPresenceErrorDate = .now
                presenceErrorMessage = "현재 위치를 공유하지 못했어요. \(error.localizedDescription)"
            }
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
