import Combine
import SwiftUI

struct WatchRunningMusicTabView: View {
    @StateObject private var viewModel = WatchMusicPlaybackViewModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isArtworkExpanded = false

    var body: some View {
        VStack(spacing: isArtworkExpanded ? 8 : 6) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.28)) { isArtworkExpanded.toggle() }
            } label: {
                artwork.frame(width: isArtworkExpanded ? 142 : 102, height: isArtworkExpanded ? 142 : 102)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isArtworkExpanded ? "앨범 아트 축소" : "앨범 아트 확대")

            VStack(spacing: 1) {
                Text(viewModel.snapshot.title).font(.headline.weight(.bold)).lineLimit(1).minimumScaleFactor(0.65)
                Text(viewModel.snapshot.artist).font(.caption).foregroundStyle(PacingWatchTheme.textSecondary).lineLimit(1)
            }
            .frame(maxWidth: .infinity)

            if !isArtworkExpanded {
                HStack(spacing: 15) {
                    controlButton("backward.fill", label: "이전 곡") { viewModel.previous() }
                    controlButton(viewModel.snapshot.isPlaying ? "pause.fill" : "play.fill", label: viewModel.snapshot.isPlaying ? "일시정지" : "재생", emphasized: true) { viewModel.togglePlayback() }
                    controlButton("forward.fill", label: "다음 곡") { viewModel.next() }
                }
                .transition(reduceMotion ? .identity : .opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, isArtworkExpanded ? 8 : 27)
        .onAppear { viewModel.refresh() }
        .onChange(of: viewModel.snapshot.id) { _, _ in
            guard isArtworkExpanded else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { isArtworkExpanded = false }
        }
    }

    @ViewBuilder private var artwork: some View {
        if let url = viewModel.snapshot.artworkURL, let artworkURL = URL(string: url) {
            AsyncImage(url: artworkURL) { image in image.resizable().scaledToFill() } placeholder: { artworkPlaceholder }
        } else { artworkPlaceholder }
    }

    private var artworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(PacingWatchTheme.surface)
            .overlay { Image(systemName: "music.note").font(.system(size: 30, weight: .medium)).foregroundStyle(PacingWatchTheme.purple) }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func controlButton(_ symbol: String, label: String, emphasized: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: emphasized ? 18 : 14, weight: .bold))
                .frame(width: emphasized ? 40 : 32, height: emphasized ? 40 : 32)
                .background(PacingWatchTheme.surface.opacity(emphasized ? 0.92 : 0.64), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

@MainActor
final class WatchMusicPlaybackViewModel: ObservableObject {
    @Published private(set) var snapshot = WatchMusicPlaybackSnapshot.empty
    private let repository: any WatchMusicPlaybackRepository

    init(repository: (any WatchMusicPlaybackRepository)? = nil) {
        let repository = repository ?? PhoneMusicPlaybackRepository.shared
        self.repository = repository
        repository.snapshot.receive(on: DispatchQueue.main).assign(to: &$snapshot)
    }

    func refresh() { repository.refresh() }
    func togglePlayback() { repository.send(.togglePlayback, songID: nil) }
    func previous() { repository.send(.previous, songID: nil) }
    func next() { repository.send(.next, songID: nil) }
    func play(_ track: WatchMusicTrack) { repository.send(.play, songID: track.id) }
}

private extension WatchMusicPlaybackSnapshot {
    var id: String { [title, artist, artworkURL ?? ""].joined(separator: "|") }
}
