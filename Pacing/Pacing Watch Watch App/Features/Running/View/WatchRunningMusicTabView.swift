import Combine
import ImageIO
import SwiftUI

struct WatchRunningMusicTabView: View {
    @StateObject private var viewModel = WatchMusicPlaybackViewModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isArtworkExpanded = false
    @State private var isTrackListPresented = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Group {
                    if isTrackListPresented {
                        trackList
                            .padding(.top, 2)
                            .padding(.bottom, 27)
                            .transition(reduceMotion ? .identity : .opacity)
                    } else {
                        nowPlaying
                            .padding(.top, 12)
                            .padding(.bottom, isArtworkExpanded ? 8 : 27)
                            .transition(reduceMotion ? .identity : .opacity)
                    }
                }
                .frame(
                    width: max(0, proxy.size.width - 20),
                    height: proxy.size.height,
                    alignment: .topLeading
                )
                .padding(.horizontal, 10)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)

                // 버튼은 콘텐츠와 완전히 분리된 Watch 탭 고정 좌표를 사용한다.
                playlistButton
                    .position(x: 23, y: 1)
                    .transaction { $0.animation = nil }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .onAppear { viewModel.refresh() }
        .onChange(of: viewModel.snapshot.id) { _, _ in
            guard isArtworkExpanded else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { isArtworkExpanded = false }
        }
    }

    private var nowPlaying: some View {
        VStack(spacing: isArtworkExpanded ? 8 : 6) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.28)) { isArtworkExpanded.toggle() }
            } label: {
                artwork
                    .frame(width: isArtworkExpanded ? 118 : 86, height: isArtworkExpanded ? 118 : 86)
                    .clipShape(RoundedRectangle(cornerRadius: isArtworkExpanded ? 16 : 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isArtworkExpanded ? "앨범 아트 축소" : "앨범 아트 확대")

            VStack(spacing: 1) {
                Text(viewModel.snapshot.title).font(.system(size: 17, weight: .bold)).lineLimit(1).minimumScaleFactor(0.6)
                Text(viewModel.snapshot.artist).font(.system(size: 11, weight: .medium)).foregroundStyle(PacingWatchTheme.textSecondary).lineLimit(1)
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
    }

    private var playlistButton: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.28)) {
                isTrackListPresented.toggle()
            }
        } label: {
            Image(systemName: isTrackListPresented ? "xmark" : "list.bullet")
                .font(.system(size: 12, weight: .bold))
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel(isTrackListPresented ? "곡 목록 닫기" : "곡 목록 보기")
        .frame(width: 34, height: 34, alignment: .topLeading)
    }

    private var trackList: some View {
        ScrollView {
            LazyVStack(spacing: 5) {
                ForEach(viewModel.snapshot.playlistTracks) { track in
                    Button {
                        viewModel.play(track)
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { isTrackListPresented = false }
                    } label: {
                        HStack(spacing: 8) {
                            WatchRunningMusicArtwork(data: track.artworkData, url: track.artworkURL, size: 38)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(track.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .lineLimit(1)
                                Text(track.artist)
                                    .font(.system(size: 10))
                                    .foregroundStyle(PacingWatchTheme.textSecondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            if isCurrentTrack(track) {
                                Image(systemName: viewModel.snapshot.isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(PacingWatchTheme.purple)
                            }
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 6)
                        .background(PacingWatchTheme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(track.title), \(track.artist) 재생")
                }
            }
            .padding(.vertical, 0)
        }
        .overlay {
            if viewModel.snapshot.playlistTracks.isEmpty {
                ContentUnavailableView("플레이리스트 없음", systemImage: "music.note.list")
                    .font(.caption2)
            }
        }
    }

    private func isCurrentTrack(_ track: WatchMusicTrack) -> Bool {
        track.title == viewModel.snapshot.title && track.artist == viewModel.snapshot.artist
    }

    @ViewBuilder private var artwork: some View {
        if let artworkData = viewModel.snapshot.artworkData,
           let image = image(from: artworkData) {
            image.resizable().scaledToFill()
        } else if let url = viewModel.snapshot.artworkURL,
                  let artworkURL = URL(string: url),
                  ["http", "https"].contains(artworkURL.scheme?.lowercased() ?? "") {
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
                .frame(width: 34, height: 34)
                .accessibilityLabel(label)
        }
    }

    private func controlIcon(_ symbol: String, emphasized: Bool) -> some View {
        Image(systemName: symbol)
            .font(.system(size: emphasized ? 16 : 12, weight: .bold))
            .frame(width: emphasized ? 34 : 26, height: emphasized ? 34 : 26)
    }
}

private struct WatchRunningMusicArtwork: View {
    let data: Data?
    let url: String?
    let size: CGFloat

    var body: some View {
        Group {
            if let data, let image = image(from: data) {
                image.resizable().scaledToFill()
            } else if let url,
                      let artworkURL = URL(string: url),
                      ["http", "https"].contains(artworkURL.scheme?.lowercased() ?? "") {
                AsyncImage(url: artworkURL) { image in image.resizable().scaledToFill() } placeholder: { placeholder }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(PacingWatchTheme.surface)
            .overlay { Image(systemName: "music.note").font(.caption).foregroundStyle(PacingWatchTheme.purple) }
    }

    private func image(from data: Data) -> Image? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        return Image(decorative: image, scale: 1)
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
    func togglePlayback() {
        // iPhone의 실제 재생 상태는 뒤이어 수신되는 스냅샷으로 확정한다.
        // 다만 Watch 조작에는 즉시 반응해 버튼이 늦게 바뀌지 않게 한다.
        snapshot = snapshot.updatingPlaybackState(to: !snapshot.isPlaying)
        repository.send(.togglePlayback, songID: nil)
    }
    func previous() {
        moveCurrentTrack(by: -1)
        repository.send(.previous, songID: nil)
    }

    func next() {
        moveCurrentTrack(by: 1)
        repository.send(.next, songID: nil)
    }

    func play(_ track: WatchMusicTrack) {
        snapshot = snapshot.updatingCurrentTrack(to: track)
        repository.send(.play, songID: track.id)
    }

    private func moveCurrentTrack(by offset: Int) {
        guard let currentIndex = snapshot.playlistTracks.firstIndex(where: {
            $0.title == snapshot.title && $0.artist == snapshot.artist
        }) else { return }
        let targetIndex = currentIndex + offset
        guard snapshot.playlistTracks.indices.contains(targetIndex) else { return }
        snapshot = snapshot.updatingCurrentTrack(to: snapshot.playlistTracks[targetIndex])
    }
}

private extension WatchMusicPlaybackSnapshot {
    var id: String { [title, artist, artworkURL ?? ""].joined(separator: "|") }

    func updatingPlaybackState(to isPlaying: Bool) -> Self {
        Self(
            updatedAt: updatedAt,
            title: title,
            artist: artist,
            artworkURL: artworkURL,
            artworkData: artworkData,
            isPlaying: isPlaying,
            recentlyPlayed: recentlyPlayed,
            playlistTracks: playlistTracks
        )
    }

    func updatingCurrentTrack(to track: WatchMusicTrack) -> Self {
        Self(
            updatedAt: updatedAt,
            title: track.title,
            artist: track.artist,
            artworkURL: track.artworkURL,
            artworkData: track.artworkData,
            isPlaying: isPlaying,
            recentlyPlayed: recentlyPlayed,
            playlistTracks: playlistTracks
        )
    }
}
