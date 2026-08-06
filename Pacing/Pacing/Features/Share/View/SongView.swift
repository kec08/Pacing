import SwiftUI
import MusicKit
import MediaPlayer
import UIKit
import Combine
import ImageIO

struct SongView: View {
    @StateObject private var vm = SongViewModel()
    @StateObject private var nowPlayingController = SongNowPlayingController()
    @State private var mainScrollOffset: CGFloat = 0
    @State private var bottomSentinelMinY: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                NavigationStack {
                    ScrollView {
                        mainOffsetReader

                        LazyVStack(alignment: .leading, spacing: 28) {
                            headerSection
                            friendPlaylistSection
                            recentAlbumSection
                            genreAlbumSection
                            moodPlaylistSection
                            recommendationPlaylistSection
                            bottomOffsetReader
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, nowPlayingController.hasActiveTrack ? 112 : 34)
                    }
                    .coordinateSpace(name: "songMainScroll")
                    .background(background.ignoresSafeArea())
                    .scrollIndicators(.hidden)
                    .navigationBarHidden(true)
                    .task {
                        viewportHeight = proxy.size.height
                        await vm.load()
                    }
                    .onChange(of: proxy.size.height) { _, newValue in
                        viewportHeight = newValue
                        updateOverlayProgress()
                    }
                    .onPreferenceChange(SongMainScrollOffsetKey.self) { value in
                        mainScrollOffset = value
                        updateOverlayProgress()
                    }
                    .onPreferenceChange(SongBottomScrollOffsetKey.self) { value in
                        bottomSentinelMinY = value
                        updateOverlayProgress()
                    }
                    .refreshable { await vm.load() }
                    .alert("노래 탭 오류", isPresented: errorBinding) {
                        Button("확인", role: .cancel) { dismissErrorMessage() }
                    } message: {
                        Text(vm.errorMessage ?? "")
                    }
                }
                .environmentObject(nowPlayingController)

                if nowPlayingController.hasActiveTrack {
                    SongNowPlayingOverlay(
                        controller: nowPlayingController,
                        expandedWidth: min(proxy.size.width - 36, 372)
                    )
                        .padding(.trailing, 16)
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.34, dampingFraction: 0.88), value: nowPlayingController.hasActiveTrack)
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color.main200.opacity(0.35),
                Color.backgroundSecondary,
                Color.backgroundPrimary
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("노래")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color.textPrimary)

                Text("친구 플레이리스트와 Apple Music 추천을 한 번에 둘러보세요")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }

    private var friendPlaylistSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("친구가 듣고 있는 음악")

            if (!vm.hasCompletedInitialLoad || vm.isLoadingFriends) && vm.friendSharedPlaylists.isEmpty {
                playlistSkeletonRow
            } else if vm.friendSharedPlaylists.isEmpty {
                infoCard(
                    title: "아직 친구 플레이리스트가 없어요",
                    message: "친구가 노래 탭에 들어와 플레이리스트를 동기화하면 여기에서 바로 볼 수 있어요."
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(vm.friendSharedPlaylists) { playlist in
                            NavigationLink {
                                SharedPlaylistDetailView(viewModel: SharedPlaylistDetailViewModel(sharedPlaylist: playlist))
                                    .environmentObject(nowPlayingController)
                            } label: {
                                FriendSharedPlaylistCard(playlist: playlist)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var recommendationPlaylistSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("나만을 위한 추천 플레이리스트")

            if !vm.hasCompletedInitialLoad && vm.recommendedPlaylists.isEmpty {
                recommendationSkeletonRow
            } else if vm.musicAuthorizationStatus != .authorized {
                infoCard(
                    title: "Apple Music 권한이 필요해요",
                    message: "노래 탭에서 추천 플레이리스트를 보려면 Apple Music 접근을 허용해주세요."
                )
            } else if vm.isLoadingRecommendations && vm.recommendedPlaylists.isEmpty {
                recommendationSkeletonRow
            } else if vm.recommendedPlaylists.isEmpty {
                infoCard(
                    title: "추천 플레이리스트를 불러오지 못했어요",
                    message: "계정 상태나 구독 상태에 따라 추천이 비어 있을 수 있어요."
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(vm.recommendedPlaylists, id: \.id) { playlist in
                            NavigationLink {
                                SharedPlaylistDetailView(viewModel: SharedPlaylistDetailViewModel(recommendedPlaylist: playlist))
                                    .environmentObject(nowPlayingController)
                            } label: {
                                RecommendationPlaylistCard(
                                    playlist: playlist,
                                    artworkURL: vm.recommendationArtworkURLs["\(playlist.id)"]
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var recentAlbumSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("최근에 들은 앨범")

            if !vm.hasCompletedInitialLoad && vm.recentlyPlayedAlbums.isEmpty {
                albumSkeletonRow
            } else if vm.musicAuthorizationStatus != .authorized {
                infoCard(
                    title: "Apple Music 권한이 필요해요",
                    message: "최근에 들은 앨범을 보려면 Apple Music 접근을 허용해주세요."
                )
            } else if vm.isLoadingRecentlyPlayedAlbums && vm.recentlyPlayedAlbums.isEmpty {
                albumSkeletonRow
            } else if vm.recentlyPlayedAlbums.isEmpty {
                infoCard(
                    title: "최근에 들은 앨범이 없어요",
                    message: "Apple Music에서 재생한 앨범이 생기면 여기에서 바로 확인할 수 있어요."
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(vm.recentlyPlayedAlbums, id: \.id) { album in
                            NavigationLink {
                                SharedPlaylistDetailView(viewModel: SharedPlaylistDetailViewModel(recentAlbum: album))
                                    .environmentObject(nowPlayingController)
                            } label: {
                                RecentAlbumCard(album: album)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var genreAlbumSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("장르별 추천 앨범")

            if vm.isLoadingRecommendations && vm.genreAlbumRows.isEmpty {
                albumSkeletonRow
            } else if vm.musicAuthorizationStatus != .authorized {
                infoCard(
                    title: "장르 앨범을 확인할 수 없어요",
                    message: "Apple Music 접근 권한이 없으면 장르별 추천 앨범을 표시할 수 없어요."
                )
            } else if vm.genreAlbumRows.isEmpty {
                infoCard(
                    title: "장르 앨범을 불러오지 못했어요",
                    message: "잠시 후 다시 시도하면 인디, R&B, 힙합, K-Pop 앨범을 보여드릴게요."
                )
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(vm.genreAlbumRows) { row in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(row.genreTitle)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.main500)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(row.albums) { item in
                                        NavigationLink {
                                            SharedPlaylistDetailView(viewModel: SharedPlaylistDetailViewModel(recentAlbum: item.album))
                                                .environmentObject(nowPlayingController)
                                        } label: {
                                            GenreAlbumCard(item: item)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
            }
        }
    }

    private var moodPlaylistSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("나의 무드 찾기")

            if vm.isLoadingRecommendations && vm.moodPlaylists.isEmpty {
                recommendationSkeletonRow
            } else if vm.musicAuthorizationStatus != .authorized {
                infoCard(
                    title: "무드 플레이리스트를 확인할 수 없어요",
                    message: "Apple Music 접근 권한이 없으면 무드별 플레이리스트를 표시할 수 없어요."
                )
            } else if vm.moodPlaylists.isEmpty {
                infoCard(
                    title: "무드 플레이리스트를 불러오지 못했어요",
                    message: "Chill, Workout, Focus 같은 무드 추천을 잠시 후 다시 불러와볼게요."
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(vm.moodPlaylists) { item in
                            NavigationLink {
                                SharedPlaylistDetailView(viewModel: SharedPlaylistDetailViewModel(recommendedPlaylist: item.playlist))
                                    .environmentObject(nowPlayingController)
                            } label: {
                                MoodPlaylistCard(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(Color.textPrimary)
    }

    private func infoCard(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.gray200, lineWidth: 1)
        )
    }

    private var playlistSkeletonRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(0..<2, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 10) {
                        SkeletonBlock(width: 212, height: 212, cornerRadius: 24)
                        SkeletonBlock(width: 132, height: 16, cornerRadius: 8)
                        SkeletonBlock(width: 76, height: 13, cornerRadius: 7)
                    }
                    .frame(width: 212, alignment: .leading)
                    .padding(14)
                    .background(Color.backgroundPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                }
            }
        }
    }

    private var recommendationSkeletonRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(0..<2, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 12) {
                        SkeletonBlock(width: 188, height: 188, cornerRadius: 18)
                        SkeletonBlock(width: 118, height: 16, cornerRadius: 8)
                        SkeletonBlock(width: 142, height: 13, cornerRadius: 7)
                    }
                    .frame(width: 188, alignment: .leading)
                }
            }
        }
    }

    private var albumSkeletonRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(0..<2, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 12) {
                        SkeletonBlock(width: 188, height: 188, cornerRadius: 18)
                        SkeletonBlock(width: 124, height: 16, cornerRadius: 8)
                        SkeletonBlock(width: 90, height: 13, cornerRadius: 7)
                    }
                    .frame(width: 188, alignment: .leading)
                }
            }
        }
    }


    private var errorBinding: Binding<Bool> {
        Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { dismissErrorMessage() } }
        )
    }

    private func dismissErrorMessage() {
        DispatchQueue.main.async {
            vm.errorMessage = nil
        }
    }

    private var mainOffsetReader: some View {
        GeometryReader { proxy in
            Color.clear
                .preference(
                    key: SongMainScrollOffsetKey.self,
                    value: proxy.frame(in: .named("songMainScroll")).minY
                )
        }
        .frame(height: 0)
    }

    private var bottomOffsetReader: some View {
        GeometryReader { proxy in
            Color.clear
                .preference(
                    key: SongBottomScrollOffsetKey.self,
                    value: proxy.frame(in: .named("songMainScroll")).minY
                )
        }
        .frame(height: 12)
    }

    private func updateOverlayProgress() {
        guard !nowPlayingController.isAlbumDetailVisible else { return }

        let scrollDistance = max(0, -mainScrollOffset - 2)
        let collapseProgress = min(scrollDistance / 28, 1)
        let bottomGap = bottomSentinelMinY - viewportHeight
        let isNearBottom = bottomGap < 72

        if isNearBottom || nowPlayingController.isTemporarilyExpanded {
            nowPlayingController.updateCollapseProgress(0)
        } else {
            nowPlayingController.updateCollapseProgress(collapseProgress)
        }
    }
}

@MainActor
final class SongNowPlayingController: ObservableObject {
    @Published private(set) var title: String = ""
    @Published private(set) var artist: String = ""
    @Published private(set) var artwork: UIImage?
    @Published private(set) var isPlaying: Bool = false
    @Published var collapseProgress: CGFloat = 0
    @Published private(set) var restoreRequestID: Int = 0
    @Published private(set) var isTemporarilyExpanded: Bool = false
    @Published private(set) var isAlbumDetailVisible: Bool = false
    @Published private(set) var isForceCollapsed: Bool = false

    private let player = MPMusicPlayerController.systemMusicPlayer
    private let applicationPlayer = ApplicationMusicPlayer.shared
    private var notificationObservers: [NSObjectProtocol] = []
    private var applicationQueueObserver: AnyCancellable?
    private var applicationStateObserver: AnyCancellable?
    private var applicationPlaybackPoller: AnyCancellable?

    var hasActiveTrack: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var trackIdentity: String {
        "\(title)\u{1F}|\(artist)"
    }

    var artworkIdentity: String {
        "\(trackIdentity)|\(artwork == nil ? "placeholder" : "artwork")"
    }

    init() {
        player.beginGeneratingPlaybackNotifications()
        observePlayer()
        observeApplicationPlayer()
        refresh()
    }

    deinit {
        notificationObservers.forEach(NotificationCenter.default.removeObserver)
        player.endGeneratingPlaybackNotifications()
    }

    func togglePlayPause() {
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        refresh()
    }

    func skipToNext() {
        player.skipToNextItem()
        refresh()
    }

    func updateCollapseProgress(_ progress: CGFloat) {
        if isForceCollapsed {
            collapseProgress = 1
            return
        }
        collapseProgress = min(max(progress, 0), 1)
    }

    func setAlbumDetailVisible(_ isVisible: Bool) {
        isAlbumDetailVisible = isVisible
    }

    func requestRestore() {
        isForceCollapsed = false
        isTemporarilyExpanded = true
        restoreRequestID += 1
        collapseProgress = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.isTemporarilyExpanded = false
        }
    }

    func requestCollapse() {
        isForceCollapsed = true
        collapseProgress = 1
    }

    func prime(title: String, artist: String, artworkURL: String?) {
        self.title = title
        self.artist = artist
        self.isPlaying = true
        loadArtwork(from: artworkURL)
    }

    private func loadArtwork(from artworkURL: String?) {
        // 다음 곡의 이미지를 못 받아도 이전 곡 커버가 남지 않게 즉시 초기화한다.
        self.artwork = nil

        guard let artworkURL,
              let url = URL(string: artworkURL) else {
            return
        }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = UIImage(data: data) else { return }
                await MainActor.run {
                    if self.title == title && self.artist == artist {
                        self.artwork = image
                    }
                }
            } catch {
                // 현재 곡의 이미지를 못 받으면 플레이스홀더를 표시한다.
            }
        }
    }

    private func observePlayer() {
        let stateObserver = NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: player,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }

        let itemObserver = NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: player,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }

        notificationObservers = [stateObserver, itemObserver]
    }

    private func observeApplicationPlayer() {
        applicationStateObserver = applicationPlayer.state.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.refresh()
            }

        let queueObserver = NotificationCenter.default.addObserver(
            forName: .applicationMusicPlayerQueueDidChange,
            object: applicationPlayer,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.bindApplicationQueue()
                self?.refresh()
            }
        }
        notificationObservers.append(queueObserver)
        bindApplicationQueue()

        applicationPlaybackPoller = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard self?.applicationPlayer.state.playbackStatus != .stopped else { return }
                self?.refresh()
            }
    }

    private func bindApplicationQueue() {
        applicationQueueObserver = applicationPlayer.queue.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.refresh()
            }
    }

    private func refresh() {
        if let entry = applicationPlayer.queue.currentEntry,
           applicationPlayer.state.playbackStatus != .stopped {
            let nextTitle = entry.title
            let nextArtist = entry.subtitle ?? "Apple Music"
            let didTrackChange = title != nextTitle || artist != nextArtist
            title = nextTitle
            artist = nextArtist
            isPlaying = applicationPlayer.state.playbackStatus == .playing
            if didTrackChange {
                loadArtwork(from: entry.artwork?.url(width: 220, height: 220)?.absoluteString)
            }
            return
        }

        if player.playbackState == .stopped {
            title = ""
            artist = ""
            artwork = nil
            isPlaying = false
            return
        }

        guard let item = player.nowPlayingItem else {
            title = ""
            artist = ""
            artwork = nil
            isPlaying = false
            return
        }

        title = item.title ?? ""
        artist = item.artist ?? "Apple Music"
        artwork = item.artwork?.image(at: CGSize(width: 220, height: 220))
        isPlaying = player.playbackState == .playing
    }
}

private struct SongNowPlayingOverlay: View {
    @ObservedObject var controller: SongNowPlayingController
    let expandedWidth: CGFloat

    var body: some View {
        morphingOverlay
    }

    private var progress: CGFloat {
        controller.collapseProgress
    }

    private var currentWidth: CGFloat {
        lerp(from: expandedWidth, to: 58, progress: progress)
    }

    private var currentHeight: CGFloat {
        lerp(from: 60, to: 58, progress: progress)
    }

    private var collapsedScale: CGFloat {
        1 - (progress * 0.04)
    }

    private var barOpacity: CGFloat {
        1 - progress
    }

    private var circleShadowOpacity: CGFloat {
        lerp(from: 0.06, to: 0.18, progress: progress)
    }

    private var artworkCenteringOffset: CGFloat {
        let expandedArtworkCenter = (-expandedWidth / 2) + 37
        return lerp(from: 0, to: -expandedArtworkCenter, progress: progress)
    }

    private var morphingOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.07 * barOpacity),
                                    Color.white.opacity(0.012 * barOpacity)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.30 * barOpacity), lineWidth: 1)
                )
                .opacity(barOpacity)

            HStack(spacing: 12) {
                artworkView(size: 46)
                    .frame(width: 46, height: 46)
                    .scaleEffect(lerp(from: 1, to: 1.26, progress: progress))
                    .offset(x: lerp(from: 0, to: 2, progress: progress))

                ZStack(alignment: .leading) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(controller.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(1)

                        Text(controller.artist)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(1)
                    }
                    .id(controller.trackIdentity)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                }
                .clipped()
                .opacity(barOpacity)
                .blur(radius: progress * 1.2)

                Spacer(minLength: 8)

                HStack(spacing: 12) {
                    Button {
                        controller.togglePlayPause()
                    } label: {
                        Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.black.opacity(0.82))
                    }
                    .buttonStyle(.plain)

                    Button {
                        controller.skipToNext()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.black.opacity(0.82))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.trailing, 6)
                .opacity(Double(max(CGFloat(0), 1 - (progress * 1.15))))
                .blur(radius: progress * 1.4)
            }
            .padding(.horizontal, 14)
            .frame(width: expandedWidth, height: 60)
            .offset(x: artworkCenteringOffset)
        }
        .frame(width: currentWidth, height: currentHeight)
        .scaleEffect(collapsedScale)
        .clipShape(
            RoundedRectangle(
                cornerRadius: lerp(from: 28, to: 29, progress: progress),
                style: .continuous
            )
        )
        .shadow(color: .black.opacity(circleShadowOpacity), radius: lerp(from: 18, to: 8, progress: progress), y: lerp(from: 10, to: 3, progress: progress))
        .contentShape(Capsule())
        .onTapGesture {
            if progress > 0.72 {
                controller.requestRestore()
            } else {
                controller.requestCollapse()
            }
        }
        .onLongPressGesture(minimumDuration: 0.24) {
            controller.requestRestore()
        }
        .animation(.easeInOut(duration: 0.30), value: controller.trackIdentity)
        .animation(.spring(response: 0.38, dampingFraction: 0.88), value: progress)
    }

    private func artworkView(size: CGFloat) -> some View {
        ZStack {
            Group {
                if let artwork = controller.artwork {
                    Image(uiImage: artwork)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(
                        colors: [Color.main500.opacity(0.85), Color.main300.opacity(0.45)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .id(controller.artworkIdentity)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
        }
        .frame(width: size, height: size)
        .clipped()
        .clipShape(Circle())
    }

    private func lerp(from start: CGFloat, to end: CGFloat, progress: CGFloat) -> CGFloat {
        start + ((end - start) * min(max(progress, 0), 1))
    }
}

private struct SongMainScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct SongBottomScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct FriendSharedPlaylistCard: View {
    let playlist: SharedPlaylistSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            artwork
                .frame(width: 188, height: 188)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )

            Text(playlist.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)

            Text(playlist.ownerNickname)
                .font(.system(size: 14))
                .foregroundStyle(Color.textSecondary)
                .lineLimit(1)
        }
        .frame(width: 188, alignment: .leading)
    }

    @ViewBuilder
    private var artwork: some View {
        RemoteArtworkView(urlString: playlist.effectiveArtworkURL)
    }
}

private struct RecommendationPlaylistCard: View {
    let playlist: Playlist
    let artworkURL: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RemoteArtworkView(
                urlString: artworkURL ?? playlist.artwork?.url(width: 900, height: 900)?.absoluteString,
                contentMode: .fill
            )
            .frame(width: 188, height: 188)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(playlist.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                Text(playlist.curatorName ?? playlist.shortDescription ?? "Apple Music 추천")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(2)
            }
        }
        .frame(width: 188, alignment: .leading)
    }
}

private struct RecentAlbumCard: View {
    let album: Album

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RemoteArtworkView(
                urlString: album.artwork?.url(width: 900, height: 900)?.absoluteString,
                contentMode: .fill
            )
            .frame(width: 188, height: 188)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(album.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                Text(album.artistName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 188, alignment: .leading)
    }
}

private struct GenreAlbumCard: View {
    let item: GenreAlbumShelfItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RemoteArtworkView(
                urlString: item.album.artwork?.url(width: 900, height: 900)?.absoluteString,
                contentMode: .fill
            )
            .frame(width: 188, height: 188)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(item.album.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                Text(item.album.artistName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 188, alignment: .leading)
    }
}

private struct MoodPlaylistCard: View {
    let item: MoodPlaylistShelfItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RemoteArtworkView(
                urlString: item.playlist.artwork?.url(width: 900, height: 900)?.absoluteString,
                contentMode: .fill
            )
            .frame(width: 188, height: 188)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(item.moodTitle)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.main500)

                Text(item.playlist.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                Text(item.playlist.curatorName ?? item.playlist.shortDescription ?? "Apple Music 추천")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(2)
            }
        }
        .frame(width: 188, alignment: .leading)
    }
}

struct RemoteArtworkView: View {
    enum ContentMode {
        case fill
        case fit
    }

    let urlString: String?
    var contentMode: ContentMode = .fill
    @StateObject private var loader = RemoteArtworkLoader()

    var body: some View {
        Group {
            if let image = loader.image {
                artwork(image: Image(uiImage: image))
            } else {
                placeholder
            }
        }
        .task(id: urlString) {
            await loader.load(urlString: urlString)
        }
    }

    @ViewBuilder
    private func artwork(image: Image) -> some View {
        switch contentMode {
        case .fill:
            image
                .resizable()
                .scaledToFill()
        case .fit:
            ZStack {
                Color.backgroundSecondary
                image
                    .resizable()
                    .scaledToFit()
                    .padding(14)
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color.main500.opacity(0.85), Color.main300.opacity(0.42)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "music.note")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
        }
    }
}

@MainActor
final class ArtworkImageStore {
    static let shared = ArtworkImageStore()

    private let cache = NSCache<NSURL, UIImage>()
    private let session: URLSession
    private var inFlightTasks: [URL: Task<UIImage?, Never>] = [:]

    private init() {
        cache.countLimit = 180
        cache.totalCostLimit = 80 * 1024 * 1024

        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = URLCache(
            memoryCapacity: 20 * 1024 * 1024,
            diskCapacity: 120 * 1024 * 1024,
            diskPath: "PacingArtworkCache"
        )
        session = URLSession(configuration: configuration)
    }

    func image(for url: URL) async -> UIImage? {
        guard ["https", "http"].contains(url.scheme?.lowercased() ?? "") else {
            return nil
        }

        if let cachedImage = cache.object(forKey: url as NSURL) {
            return cachedImage
        }

        let task: Task<UIImage?, Never>
        if let inFlightTask = inFlightTasks[url] {
            task = inFlightTask
        } else {
            task = Task { [session] in
                await Self.downloadImage(from: url, session: session)
            }
            inFlightTasks[url] = task
        }

        let image = await task.value
        inFlightTasks[url] = nil

        if let image {
            cache.setObject(image, forKey: url as NSURL, cost: image.memoryCost)
        }

        return image
    }

    func prefetch(urlStrings: [String]) async {
        let uniqueURLs = Array(
            Set(
                urlStrings
                    .compactMap(URL.init(string:))
                .filter { ["https", "http"].contains($0.scheme?.lowercased() ?? "") }
            )
        )

        for batchStartIndex in stride(from: 0, to: uniqueURLs.count, by: 4) {
            let batch = uniqueURLs[batchStartIndex..<min(batchStartIndex + 4, uniqueURLs.count)]
            await withTaskGroup(of: Void.self) { group in
                for url in batch {
                    group.addTask { [weak self] in
                        _ = await self?.image(for: url)
                    }
                }
            }
        }
    }

    private static func downloadImage(from url: URL, session: URLSession) async -> UIImage? {
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 15

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  200..<300 ~= httpResponse.statusCode
            else {
                return nil
            }

            return downsampledImage(from: data)
        } catch {
            return nil
        }
    }

    private static func downsampledImage(from data: Data, maximumPixelSize: CGFloat = 720) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize
        ]

        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary)
        else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}

private extension UIImage {
    var memoryCost: Int {
        guard let cgImage else { return 1 }
        return cgImage.bytesPerRow * cgImage.height
    }
}

@MainActor
final class RemoteArtworkLoader: ObservableObject {
    @Published private(set) var image: UIImage?

    func load(urlString: String?) async {
        image = nil

        guard let urlString,
              let url = URL(string: urlString),
              ["https", "http"].contains(url.scheme?.lowercased() ?? "") else {
            return
        }

        let loadedImage = await ArtworkImageStore.shared.image(for: url)
        guard !Task.isCancelled else { return }
        image = loadedImage
    }
}

struct ArtworkCardView: View {
    let urlString: String?
    var artworkPadding: CGFloat = 14
    var imageCornerRadius: CGFloat = 24
    var borderLineWidth: CGFloat = 1

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.16))
            RemoteArtworkView(urlString: urlString, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: imageCornerRadius, style: .continuous))
                .padding(artworkPadding)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: borderLineWidth)
        )
    }
}
