import SwiftUI

struct WatchRunningMusicTabView: View {
    @StateObject private var viewModel = WatchRunningMusicViewModel()

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(PacingWatchTheme.purple)
                .frame(width: 58, height: 58)
                .background(PacingWatchTheme.surface, in: Circle())

            VStack(spacing: 2) {
                Text(viewModel.title)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(viewModel.artist)
                    .font(.caption)
                    .foregroundStyle(PacingWatchTheme.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 13) {
                musicButton("backward.fill", label: "이전 곡", action: viewModel.previous)
                musicButton(viewModel.isPlaying ? "pause.fill" : "play.fill", label: viewModel.isPlaying ? "일시정지" : "재생", action: viewModel.togglePlayback, emphasized: true)
                musicButton("forward.fill", label: "다음 곡", action: viewModel.next)
            }
            .padding(.top, 3)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 27)
        .onAppear { viewModel.refresh() }
    }

    private func musicButton(
        _ systemName: String,
        label: String,
        action: @escaping () -> Void,
        emphasized: Bool = false
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: emphasized ? 19 : 15, weight: .bold))
                .foregroundStyle(emphasized ? PacingWatchTheme.main500 : PacingWatchTheme.textPrimary)
                .frame(width: emphasized ? 42 : 34, height: emphasized ? 42 : 34)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

@MainActor
private final class WatchRunningMusicViewModel: ObservableObject {
    @Published private(set) var title = "재생 중인 음악 없음"
    @Published private(set) var artist = "iPhone 또는 Apple Watch에서 음악을 재생해 주세요"
    @Published private(set) var isPlaying = false

    func refresh() {}

    func togglePlayback() {
        if isPlaying {
            isPlaying = false
        } else {
            isPlaying = true
        }
    }

    func previous() {
        // WatchConnectivity 상태 동기화 구현 후 iPhone의 이전 곡 요청을 전달합니다.
    }

    func next() {
        // WatchConnectivity 상태 동기화 구현 후 iPhone의 다음 곡 요청을 전달합니다.
    }
}
