import SwiftUI

struct SharedPlaylistDetailView: View {
    @StateObject private var viewModel: SharedPlaylistDetailViewModel
    @EnvironmentObject private var nowPlayingController: SongNowPlayingController
    @State private var scrollOffset: CGFloat = 0
    @State private var isRestoringFromMiniPlayer = false

    init(viewModel: SharedPlaylistDetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                offsetReader

                VStack(spacing: 24) {
                    artworkSection
                        .id("album-detail-top")
                    metadataSection
                    actionSection
                    trackSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, nowPlayingController.hasActiveTrack ? 126 : 32)
            }
            .coordinateSpace(name: "albumDetailScroll")
            .background(background.ignoresSafeArea())
            .scrollIndicators(.hidden)
            .onPreferenceChange(SharedPlaylistScrollOffsetKey.self) { value in
                guard !isRestoringFromMiniPlayer else { return }
                scrollOffset = value
                nowPlayingController.updateCollapseProgress(collapseProgress)
            }
            .onChange(of: nowPlayingController.restoreRequestID) { _, _ in
                guard nowPlayingController.isAlbumDetailVisible else { return }
                withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                    isRestoringFromMiniPlayer = true
                    scrollOffset = 0
                    proxy.scrollTo("album-detail-top", anchor: .top)
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    isRestoringFromMiniPlayer = false
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .task { await viewModel.load() }
            .onAppear {
                nowPlayingController.setAlbumDetailVisible(viewModel.isAlbumSource)
            }
            .onDisappear {
                nowPlayingController.setAlbumDetailVisible(false)
            }
            .alert("플레이리스트 오류", isPresented: errorBinding) {
                Button("확인", role: .cancel) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var background: some View {
        Color.backgroundPrimary
    }

    private var artworkSection: some View {
        RemoteArtworkView(urlString: viewModel.summary.effectiveArtworkURL, contentMode: .fill)
            .frame(width: 264, height: 264)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 14, y: 8)
            .padding(.top, 8)
    }

    private var offsetReader: some View {
        GeometryReader { proxy in
            Color.clear
                .preference(
                    key: SharedPlaylistScrollOffsetKey.self,
                    value: proxy.frame(in: .named("albumDetailScroll")).minY
                )
        }
        .frame(height: 0)
    }

    private var metadataSection: some View {
        VStack(spacing: 8) {
            Text(viewModel.summary.title)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)

            Text(viewModel.ownerDescription)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.textSecondary)

            Text("\(viewModel.updatedDescription)에 업데이트")
                .font(.system(size: 14))
                .foregroundStyle(Color.gray500)
        }
        .frame(maxWidth: .infinity)
    }

    private var actionSection: some View {
        Group {
            if viewModel.isStationSource {
                Button {
                    Task { await viewModel.playAll() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 16, weight: .bold))

                        Text("스테이션 재생")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.main500)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(PressableScaleButtonStyle())
            } else {
                HStack(spacing: 14) {
                    Button {
                        if let firstTrack = viewModel.tracks.first {
                            nowPlayingController.prime(
                                title: firstTrack.title,
                                artist: firstTrack.artistName,
                                artworkURL: firstTrack.effectiveArtworkURL ?? viewModel.summary.effectiveArtworkURL
                            )
                        } else {
                            nowPlayingController.prime(
                                title: viewModel.summary.title,
                                artist: viewModel.ownerDescription,
                                artworkURL: viewModel.summary.effectiveArtworkURL
                            )
                        }
                        Task { await viewModel.playAll() }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 16, weight: .bold))

                            Text("전체 재생")
                                .font(.system(size: 17, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.main500)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(PressableScaleButtonStyle())

                    Button {
                        Task { await viewModel.savePrimaryPlaylist() }
                    } label: {
                        HStack(spacing: 8) {
                            if viewModel.isSaving {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(Color.main500)
                            }

                            Text(viewModel.primarySaveTitle)
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundStyle(Color.main500)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.main500.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.main500.opacity(0.18), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isSaveButtonDisabled)
                    .opacity(viewModel.isSaveButtonDisabled ? 0.55 : 1)
                }
            }
        }
    }

    private var trackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.isStationSource ? "스테이션 안내" : "수록곡")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.textPrimary)

            if viewModel.isStationSource {
                VStack(alignment: .leading, spacing: 10) {
                    Text("이 스테이션은 Apple Music이 관련된 곡을 실시간으로 이어서 재생해줘요.")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)

                    Text("고정된 수록곡 목록은 제공되지 않아서 목록 대신 실제 재생 중인 곡이 아래 노래 UI와 시스템 플레이어에 바로 반영돼요.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                        .lineSpacing(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(Color.backgroundPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.gray200, lineWidth: 1)
                )
            } else if viewModel.isLoading && viewModel.tracks.isEmpty {
                VStack(spacing: 12) {
                    ForEach(0..<4, id: \.self) { _ in
                        SkeletonRow(avatarSize: 48, trailingWidth: 42)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.backgroundPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
            } else if viewModel.tracks.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "music.note")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.gray500)
                    Text("표시할 곡이 없어요")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(Color.backgroundPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.gray200, lineWidth: 1)
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.tracks.enumerated()), id: \.element.id) { index, track in
                        Button {
                            nowPlayingController.prime(
                                title: track.title,
                                artist: track.artistName,
                                artworkURL: track.effectiveArtworkURL ?? viewModel.summary.effectiveArtworkURL
                            )
                            Task { await viewModel.play(track: track) }
                        } label: {
                            if viewModel.isAlbumSource {
                                SharedAlbumTrackRow(
                                    trackNumber: index + 1,
                                    track: track,
                                    isPlaying: viewModel.playingTrackID == track.id
                                )
                            } else {
                                SharedPlaylistTrackRow(
                                    track: track,
                                    isPlaying: viewModel.playingTrackID == track.id
                                )
                            }
                        }
                        .buttonStyle(.plain)

                        if index < viewModel.tracks.count - 1 {
                            Divider()
                                .padding(.leading, viewModel.isAlbumSource ? 0 : 60)
                                .overlay(Color.gray200)
                        }
                    }
                }
                .background(Color.backgroundPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private var collapseProgress: CGFloat {
        let distance = max(0, -scrollOffset - 6)
        return min(distance / 36, 1)
    }
}

private struct SharedPlaylistScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct SharedAlbumTrackRow: View {
    let trackNumber: Int
    let track: SharedPlaylistTrack
    let isPlaying: Bool

    private let indicatorWidth: CGFloat = 26

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if isPlaying {
                    TrackWaveformOverlay(
                        barColor: .main500,
                        minimumHeight: 5,
                        maximumHeight: 11,
                        barWidth: 2.6,
                        spacing: 3.2,
                        speed: 1.0
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.82)))
                } else {
                    Text("\(trackNumber)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.gray500)
                }
            }
            .frame(width: indicatorWidth, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.system(size: 18, weight: isPlaying ? .semibold : .medium))
                    .foregroundStyle(isPlaying ? Color.main500 : Color.textPrimary)
                    .lineLimit(1)

                Text(track.artistName)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            if !track.durationText.isEmpty {
                Text(track.durationText)
                    .font(.system(size: 14, weight: isPlaying ? .semibold : .medium))
                    .foregroundStyle(isPlaying ? Color.main500 : Color.gray500)
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.26), value: isPlaying)
    }
}

private struct SharedPlaylistTrackRow: View {
    let track: SharedPlaylistTrack
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if isPlaying {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.main500.opacity(0.16),
                                    Color.main300.opacity(0.08),
                                    .white.opacity(0.01)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 58, height: 58)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.main500.opacity(0.20), lineWidth: 1)
                        )
                }

                RemoteArtworkView(urlString: track.artworkURL)
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        if isPlaying {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.black.opacity(0.42))
                                .transition(.opacity)
                        }
                    }
                    .overlay {
                        if isPlaying {
                            TrackWaveformOverlay(
                                barColor: .white,
                                minimumHeight: 8,
                                maximumHeight: 17,
                                barWidth: 3,
                                spacing: 3,
                                speed: 1.1
                            )
                            .transition(.opacity.combined(with: .scale(scale: 0.84)))
                        }
                    }
            }
            .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 15, weight: isPlaying ? .semibold : .medium))
                    .foregroundStyle(trackTitleColor)
                    .lineLimit(1)
                Text(track.artistName)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            if !track.durationText.isEmpty {
                Text(track.durationText)
                    .font(.system(size: 12, weight: isPlaying ? .bold : .medium))
                    .foregroundStyle(isPlaying ? Color.main500 : Color.gray500)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.26), value: isPlaying)
    }

    private var trackTitleColor: Color {
        isPlaying ? .main500 : .textPrimary
    }
}

private struct TrackWaveformOverlay: View {
    let barColor: Color
    let minimumHeight: CGFloat
    let maximumHeight: CGFloat
    let barWidth: CGFloat
    let spacing: CGFloat
    let speed: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate

            HStack(spacing: spacing) {
                ForEach(0..<5, id: \.self) { index in
                    let value = abs(sin(phase * speed + Double(index) * 0.42))
                    Capsule()
                        .fill(barColor)
                        .frame(
                            width: barWidth,
                            height: minimumHeight + value * (maximumHeight - minimumHeight)
                        )
                }
            }
            .shadow(color: Color.black.opacity(0.10), radius: 3, y: 1)
            .drawingGroup()
        }
    }
}

private struct PressableScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
