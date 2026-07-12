import SwiftUI

struct SharedPlaylistDetailView: View {
    @StateObject private var viewModel: SharedPlaylistDetailViewModel

    init(viewModel: SharedPlaylistDetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            background

            ScrollView {
                VStack(spacing: 24) {
                    artworkSection
                    metadataSection
                    actionSection
                    trackSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .alert("플레이리스트 오류", isPresented: errorBinding) {
            Button("확인", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color.black,
                Color(red: 0.06, green: 0.06, blue: 0.08),
                Color.black
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var artworkSection: some View {
        RemoteArtworkView(urlString: viewModel.summary.artworkURL)
            .frame(width: 264, height: 264)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.28), radius: 18, y: 10)
            .padding(.top, 8)
    }

    private var metadataSection: some View {
        VStack(spacing: 8) {
            Text(viewModel.summary.title)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(viewModel.ownerDescription)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.82))

            Text("\(viewModel.updatedDescription)에 업데이트")
                .font(.system(size: 14))
                .foregroundStyle(Color.white.opacity(0.58))
        }
        .frame(maxWidth: .infinity)
    }

    private var actionSection: some View {
        HStack(spacing: 14) {
            Button {
                Task { await viewModel.playAll() }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isPlaying {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.black)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 16, weight: .bold))
                    }
                    Text("전체 재생")
                        .font(.system(size: 17, weight: .bold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                Task {
                    if viewModel.canSaveToAppleMusic {
                        await viewModel.saveToAppleMusic()
                    } else {
                        await viewModel.savePlaylist()
                    }
                }
            } label: {
                Text(viewModel.primarySaveTitle)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isSaveButtonDisabled)
            .opacity(viewModel.isSaveButtonDisabled ? 0.55 : 1)
        }
    }

    private var trackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("수록곡")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)

            if viewModel.isLoading && viewModel.tracks.isEmpty {
                VStack(spacing: 12) {
                    ForEach(0..<4, id: \.self) { _ in
                        SkeletonRow(avatarSize: 48, trailingWidth: 42)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
            } else if viewModel.tracks.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "music.note")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.62))
                    Text("표시할 곡이 없어요")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.68))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.tracks.enumerated()), id: \.element.id) { index, track in
                        SharedPlaylistTrackRow(index: index + 1, track: track)
                    }
                }
                .background(Color.white.opacity(0.08))
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
}

private struct SharedPlaylistTrackRow: View {
    let index: Int
    let track: SharedPlaylistTrack

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.54))
                .frame(width: 18)

            RemoteArtworkView(urlString: track.artworkURL)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(track.artistName)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.64))
                    .lineLimit(1)
            }

            Spacer()

            if !track.durationText.isEmpty {
                Text(track.durationText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.54))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
