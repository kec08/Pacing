import SwiftUI
import MusicKit

struct ShareView: View {
    @StateObject private var vm = ShareViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                background

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 28) {
                        headerSection
                        friendPlaylistSection
                        recommendationPlaylistSection
                        stationSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 34)
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarHidden(true)
            .task { await vm.load() }
            .refreshable { await vm.load() }
            .alert("공유 탭 오류", isPresented: errorBinding) {
                Button("확인", role: .cancel) { vm.errorMessage = nil }
            } message: {
                Text(vm.errorMessage ?? "")
            }
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color.black,
                Color(red: 0.08, green: 0.04, blue: 0.08),
                Color.black
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("공유")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)

                Text("친구 플레이리스트와 Apple Music 추천을 한 번에 둘러보세요")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.68))
            }

            Spacer(minLength: 12)

            Button {
                Task { await vm.syncMyPlaylistsIfPossible() }
            } label: {
                HStack(spacing: 6) {
                    if vm.isSyncingLibrary {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .bold))
                    }

                    Text("내 플레이리스트 동기화")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.12))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(vm.isSyncingLibrary)
        }
    }

    private var friendPlaylistSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("친구가 듣고 있는 음악")

            if vm.isLoadingFriends && vm.friendSharedPlaylists.isEmpty {
                playlistSkeletonRow
            } else if vm.friendSharedPlaylists.isEmpty {
                darkEmptyCard(
                    title: "아직 친구 플레이리스트가 없어요",
                    message: "친구가 공유 탭에 들어와 플레이리스트를 동기화하면 여기에서 바로 볼 수 있어요."
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(vm.friendSharedPlaylists) { playlist in
                            NavigationLink {
                                SharedPlaylistDetailView(viewModel: SharedPlaylistDetailViewModel(sharedPlaylist: playlist))
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

            if vm.musicAuthorizationStatus != .authorized {
                darkEmptyCard(
                    title: "Apple Music 권한이 필요해요",
                    message: "공유 탭에서 추천 플레이리스트를 보려면 Apple Music 접근을 허용해주세요."
                )
            } else if vm.isLoadingRecommendations && vm.recommendedPlaylists.isEmpty {
                recommendationSkeletonRow
            } else if vm.recommendedPlaylists.isEmpty {
                darkEmptyCard(
                    title: "추천 플레이리스트를 불러오지 못했어요",
                    message: "계정 상태나 구독 상태에 따라 추천이 비어 있을 수 있어요."
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(vm.recommendedPlaylists, id: \.id) { playlist in
                            NavigationLink {
                                SharedPlaylistDetailView(viewModel: SharedPlaylistDetailViewModel(recommendedPlaylist: playlist))
                            } label: {
                                RecommendationPlaylistCard(playlist: playlist)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var stationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("추천 스테이션")

            if vm.musicAuthorizationStatus != .authorized {
                darkEmptyCard(
                    title: "추천 스테이션을 확인할 수 없어요",
                    message: "Apple Music 접근 권한이 없으면 스테이션 추천이 표시되지 않아요."
                )
            } else if vm.recommendedStations.isEmpty {
                darkEmptyCard(
                    title: "표시할 스테이션이 없어요",
                    message: "개인화 추천에 스테이션이 없으면 이 섹션은 비어 있을 수 있어요."
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(vm.recommendedStations, id: \.id) { station in
                        StationRow(station: station) {
                            Task { await vm.play(station: station) }
                        }
                    }
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.white)
    }

    private func darkEmptyCard(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Color.white.opacity(0.68))
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var playlistSkeletonRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(0..<2, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 10) {
                        SkeletonBlock(width: 210, height: 210, cornerRadius: 22)
                        SkeletonBlock(width: 148, height: 18, cornerRadius: 8)
                        SkeletonBlock(width: 84, height: 14, cornerRadius: 7)
                    }
                }
            }
        }
    }

    private var recommendationSkeletonRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(0..<2, id: \.self) { _ in
                    SkeletonBlock(width: 280, height: 320, cornerRadius: 28)
                }
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )
    }
}

private struct FriendSharedPlaylistCard: View {
    let playlist: SharedPlaylistSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RemoteArtworkView(urlString: playlist.artworkURL)
                .frame(width: 212, height: 212)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            Text(playlist.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(playlist.ownerNickname)
                .font(.system(size: 14))
                .foregroundStyle(Color.white.opacity(0.66))
                .lineLimit(1)
        }
        .frame(width: 212, alignment: .leading)
    }
}

private struct RecommendationPlaylistCard: View {
    let playlist: Playlist

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RemoteArtworkView(urlString: playlist.artwork?.url(width: 900, height: 900)?.absoluteString)
                .frame(width: 286, height: 328)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

            LinearGradient(
                colors: [.clear, .black.opacity(0.85)],
                startPoint: .center,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(playlist.name)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(playlist.curatorName ?? playlist.shortDescription ?? "Apple Music 추천")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.82))
                    .lineLimit(3)
            }
            .padding(20)
        }
        .frame(width: 286, height: 328)
    }
}

private struct StationRow: View {
    let station: Station
    let onPlay: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            RemoteArtworkView(urlString: station.artwork?.url(width: 320, height: 320)?.absoluteString)
                .frame(width: 62, height: 62)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(station.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("Apple Music 스테이션")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.66))
            }

            Spacer()

            Button(action: onPlay) {
                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 38, height: 38)
                    .background(Color.white)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct RemoteArtworkView: View {
    let urlString: String?

    var body: some View {
        if let urlString, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    placeholder
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    placeholder
                @unknown default:
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color.main500.opacity(0.85), Color.main300.opacity(0.42)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "music.note.list")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
        }
    }
}
