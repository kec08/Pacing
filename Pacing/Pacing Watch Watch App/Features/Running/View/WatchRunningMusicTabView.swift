import Combine
import ImageIO
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
                Text(viewModel.snapshot.title).font(.system(size: 15, weight: .bold)).lineLimit(1).minimumScaleFactor(0.65)
                Text(viewModel.snapshot.artist).font(.system(size: 12)).foregroundStyle(PacingWatchTheme.textSecondary).lineLimit(1)
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
        if let artworkData = viewModel.snapshot.artworkData,
           let image = image(from: artworkData) {
            image.resizable().scaledToFill()
        } else if let url = viewModel.snapshot.artworkURL, let artworkURL = URL(string: url) {
            AsyncImage(url: artworkURL) { image in image.resizable().scaledToFill() } placeholder: { artworkPlaceholder }
        } else { artworkPlaceholder }
    }

    private var artworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(PacingWatchTheme.surface)
            .overlay { Image(systemName: "music.note").font(.system(size: 30, weight: .medium)).foregroundStyle(PacingWatchTheme.purple) }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func image(from data: Data) -> Image? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        return Image(decorative: image, scale: 1)
    }

    @ViewBuilder
    private func controlButton(_ symbol: String, label: String, emphasized: Bool = false, action: @escaping () -> Void) -> some View {
        if emphasized {
            Button(action: action) { controlIcon(symbol, emphasized: true) }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .controlSize(.small)
                .accessibilityLabel(label)
        } else {
            Button(action: action) { controlIcon(symbol, emphasized: false) }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.mini)
                .accessibilityLabel(label)
        }
    }

    private func controlIcon(_ symbol: String, emphasized: Bool) -> some View {
        Image(systemName: symbol)
            .font(.system(size: emphasized ? 16 : 12, weight: .bold))
            .frame(width: emphasized ? 34 : 26, height: emphasized ? 34 : 26)
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
