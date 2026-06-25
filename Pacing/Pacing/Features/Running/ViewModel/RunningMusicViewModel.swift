import SwiftUI
import Combine
import MusicKit

@MainActor
final class RunningMusicViewModel: ObservableObject {
    @Published var recommendedTrack: Track?
    @Published var authStatus: MusicAuthorization.Status = .notDetermined
    @Published var isLoading = false

    func requestAuthorization() async {
        authStatus = await MusicAuthorization.request()
        if authStatus == .authorized {
            await fetchRecommendedTrack()
        }
    }

    func fetchRecommendedTrack() async {
        guard authStatus == .authorized else { return }
        isLoading = true
        do {
            var request = MusicRecentlyPlayedRequest<Track>()
            request.limit = 1
            let response = try await request.response()
            recommendedTrack = response.items.first
        } catch {
            // 최근 재생 없으면 추천 시도
            do {
                var recentRequest = MusicRecentlyPlayedRequest<Song>()
                recentRequest.limit = 1
                let recentResponse = try await recentRequest.response()
                if let song = recentResponse.items.first {
                    recommendedTrack = Track.song(song)
                }
            } catch {}
        }
        isLoading = false
    }
}
