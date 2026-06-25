import SwiftUI
import Combine
import MusicKit

@MainActor
final class RunningMusicViewModel: ObservableObject {
    @Published var recentSongs: [Song] = []
    @Published var authStatus: MusicAuthorization.Status = .notDetermined
    @Published var isLoading = false

    func requestAuthorization() async {
        authStatus = await MusicAuthorization.request()
        if authStatus == .authorized {
            await fetchRecentSongs()
        }
    }

    func fetchRecentSongs() async {
        guard authStatus == .authorized else { return }
        isLoading = true
        do {
            var request = MusicRecentlyPlayedRequest<Song>()
            request.limit = 10
            let response = try await request.response()
            recentSongs = Array(response.items)
        } catch {
            recentSongs = []
        }
        isLoading = false
    }
}
