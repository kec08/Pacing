import Combine
import ImageIO
import SwiftUI

@MainActor
final class WatchRunningMusicPresentation: ObservableObject {
    @Published var isArtworkExpanded = false
    @Published var isTrackListPresented = false
}

struct WatchRunningMusicTabView: View {
    @StateObject private var viewModel = WatchMusicPlaybackViewModel()
    @ObservedObject var presentation: WatchRunningMusicPresentation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if presentation.isTrackListPresented {
                trackList
                    .padding(.top, 2)
                    // 탭 인디케이터가 안전 영역을 확보하므로 추가 하단 여백은 두지 않는다.
                    .padding(.bottom, 0)
                    .transition(reduceMotion ? .identity : .opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
            } else {
                nowPlaying
                    .padding(.top, 12)
                    .padding(.bottom, presentation.isArtworkExpanded ? 8 : 27)
                    .transition(reduceMotion ? .identity : .opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 10)
        .onAppear { viewModel.refresh() }
        .onChange(of: viewModel.snapshot.id) { _, _ in
            guard presentation.isArtworkExpanded else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { presentation.isArtworkExpanded = false }
        }
    }

    private var nowPlaying: some View {
        VStack(spacing: presentation.isArtworkExpanded ? 8 : 6) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.28)) { presentation.isArtworkExpanded.toggle() }
            } label: {
                artwork
                    // AsyncImage의 실제 레이아웃 크기를 고정하고 scale만 전환한다.
                    // 확대 중 이미지 뷰가 다시 생성되며 placeholder로 깜빡이는 것을 막는다.
                    .frame(width: 126, height: 126)
                    .clipShape(RoundedRectangle(cornerRadius: presentation.isArtworkExpanded ? 16 : 14, style: .continuous))
                    .scaleEffect(presentation.isArtworkExpanded ? 1 : 86 / 126)
                    .frame(
                        width: presentation.isArtworkExpanded ? 126 : 86,
                        height: presentation.isArtworkExpanded ? 126 : 86
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(presentation.isArtworkExpanded ? "앨범 아트 축소" : "앨범 아트 확대")

            VStack(spacing: 1) {
                Text(viewModel.snapshot.title).font(.system(size: 17, weight: .bold)).lineLimit(1).minimumScaleFactor(0.6)
                Text(viewModel.snapshot.artist).font(.system(size: 11, weight: .medium)).foregroundStyle(PacingWatchTheme.textSecondary).lineLimit(1)
            }
            .frame(maxWidth: .infinity)

            if !presentation.isArtworkExpanded {
                HStack(spacing: 15) {
                    controlButton("backward.fill", label: "이전 곡") { viewModel.previous() }
                    controlButton(viewModel.snapshot.isPlaying ? "pause.fill" : "play.fill", label: viewModel.snapshot.isPlaying ? "일시정지" : "재생", emphasized: true) { viewModel.togglePlayback() }
                    controlButton("forward.fill", label: "다음 곡") { viewModel.next() }
                }
                .transition(reduceMotion ? .identity : .opacity.combined(with: .move(edge: .bottom)))
            }
        }
    }

    private var trackList: some View {
        ScrollView {
            LazyVStack(spacing: 5) {
                ForEach(viewModel.snapshot.playlistTracks) { track in
                    Button {
                        viewModel.play(track)
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { presentation.isTrackListPresented = false }
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
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(PacingWatchTheme.main500)
                            }
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 6)
                        .background(PacingWatchTheme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(track.title), \(track.artist) 재생")
                    .onAppear { viewModel.requestArtworkIfNeeded(for: track) }
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

struct WatchRunningMusicPlaylistButton: View {
    @ObservedObject var presentation: WatchRunningMusicPresentation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.28)) {
                presentation.isTrackListPresented.toggle()
            }
        } label: {
            Image(systemName: presentation.isTrackListPresented ? "xmark" : "list.bullet")
                .font(.system(size: 12, weight: .bold))
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel(presentation.isTrackListPresented ? "곡 목록 닫기" : "곡 목록 보기")
        .frame(width: 34, height: 34)
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
    private var cancellables = Set<AnyCancellable>()
    private var awaitingPlaybackState: Bool?
    private var awaitingTrack: WatchMusicTrack?
    private var pendingArtworkTrackIDs = Set<String>()
    private var requestedArtworkTrackIDs = Set<String>()
    private var artworkRequestTask: Task<Void, Never>?

    init(repository: (any WatchMusicPlaybackRepository)? = nil) {
        let repository = repository ?? PhoneMusicPlaybackRepository.shared
        self.repository = repository
        repository.snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.applyPhoneSnapshot(snapshot)
            }
            .store(in: &cancellables)
    }

    func refresh() { repository.refresh() }

    func requestArtworkIfNeeded(for track: WatchMusicTrack) {
        guard track.artworkData == nil,
              !hasRemoteArtworkURL(track.artworkURL),
              requestedArtworkTrackIDs.insert(track.id).inserted
        else { return }

        pendingArtworkTrackIDs.insert(track.id)
        guard artworkRequestTask == nil else { return }
        artworkRequestTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard let self, !Task.isCancelled else { return }
            let songIDs = Array(self.pendingArtworkTrackIDs.prefix(12))
            self.pendingArtworkTrackIDs.subtract(songIDs)
            self.artworkRequestTask = nil
            self.repository.requestArtwork(for: songIDs)
        }
    }
    func togglePlayback() {
        // iPhone의 실제 재생 상태는 뒤이어 수신되는 스냅샷으로 확정한다.
        // 다만 Watch 조작에는 즉시 반응해 버튼이 늦게 바뀌지 않게 한다.
        let expectedPlaybackState = !snapshot.isPlaying
        awaitingPlaybackState = expectedPlaybackState
        snapshot = snapshot.updatingPlaybackState(to: expectedPlaybackState)
        repository.send(.setPlaybackState, songID: nil, isPlaying: expectedPlaybackState, title: nil, artist: nil)
    }
    func previous() {
        awaitingTrack = moveCurrentTrack(by: -1)
        repository.send(.previous, songID: nil, isPlaying: nil, title: nil, artist: nil)
    }

    func next() {
        awaitingTrack = moveCurrentTrack(by: 1)
        repository.send(.next, songID: nil, isPlaying: nil, title: nil, artist: nil)
    }

    func play(_ track: WatchMusicTrack) {
        awaitingTrack = track
        repository.send(.play, songID: track.id, isPlaying: nil, title: track.title, artist: track.artist)
    }

    @discardableResult
    private func moveCurrentTrack(by offset: Int) -> WatchMusicTrack? {
        guard let currentIndex = snapshot.playlistTracks.firstIndex(where: {
            $0.title == snapshot.title && $0.artist == snapshot.artist
        }) else { return nil }
        let targetIndex = currentIndex + offset
        guard snapshot.playlistTracks.indices.contains(targetIndex) else { return nil }
        let targetTrack = snapshot.playlistTracks[targetIndex]
        snapshot = snapshot.updatingCurrentTrack(to: targetTrack)
        return targetTrack
    }

    private func applyPhoneSnapshot(_ incoming: WatchMusicPlaybackSnapshot) {
        // Watch 터치 직후 iPhone의 이전 상태 스냅샷이 먼저 도착할 수 있다.
        // 반대 상태는 실제 명령 결과가 도착할 때까지 무시해 아이콘이
        // 재생 ↔ 일시정지로 깜빡이지 않게 한다.
        if let awaitingPlaybackState {
            guard incoming.isPlaying == awaitingPlaybackState else { return }
            self.awaitingPlaybackState = nil
        }
        if let awaitingTrack {
            guard incoming.title == awaitingTrack.title, incoming.artist == awaitingTrack.artist else { return }
            self.awaitingTrack = nil
        }
        snapshot = incoming
    }

    private func hasRemoteArtworkURL(_ value: String?) -> Bool {
        guard let value,
              let url = URL(string: value)
        else { return false }
        return ["http", "https"].contains(url.scheme?.lowercased() ?? "")
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
