//
//  ContentView.swift
//  Pacing Watch Watch App
//

import Combine
import HealthKit
import ImageIO
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = WatchAppViewModel()
    @StateObject private var runningMusicPresentation = WatchRunningMusicPresentation()

    var body: some View {
        ZStack {
            PacingWatchTheme.background.ignoresSafeArea()

            if viewModel.isRunSummaryPresented {
                WatchRunningTabView(viewModel: viewModel.runningViewModel)
            } else if viewModel.isRunExperiencePresented {
                TabView(selection: $viewModel.selectedRunTab) {
                    WatchRunControlsTabView(viewModel: viewModel.runningViewModel).tag(WatchRunTab.controls)
                    if !viewModel.isRunPaused {
                        WatchRunningTabView(viewModel: viewModel.runningViewModel).tag(WatchRunTab.dashboard)
                    }
                    WatchRunningMusicTabView(presentation: runningMusicPresentation).tag(WatchRunTab.music)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .disabled(viewModel.isRunTabLocked)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    WatchRunTabIndicator(
                        selectedTab: $viewModel.selectedRunTab,
                        tabs: viewModel.runTabs
                    )
                        .offset(y: 20)
                        .disabled(viewModel.isRunTabLocked)
                }
                .overlay(alignment: .topLeading) {
                    if viewModel.selectedRunTab == .music {
                        WatchRunningMusicPlaylistButton(presentation: runningMusicPresentation)
                            .offset(x: 6, y: -30)
                            .transaction { $0.animation = nil }
                    }
                }
            } else {
                TabView(selection: $viewModel.selectedTab) {
                    WatchMusicTabView().tag(WatchTab.music)
                    WatchRunningTabView(viewModel: viewModel.runningViewModel).tag(WatchTab.running)
                    WatchListenTogetherTabView().tag(WatchTab.listenTogether)
                    WatchActivityTabView().tag(WatchTab.activity)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    WatchTabIndicator(selectedTab: $viewModel.selectedTab)
                        .offset(y: 12)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

/// Watch 앱의 페이지 순서와 공통 메타데이터를 한곳에서 관리합니다.
enum WatchTab: Int, CaseIterable, Hashable, Identifiable {
    case music
    case running
    case listenTogether
    case activity

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .music: "음악"
        case .running: "러닝"
        case .listenTogether: "같이 듣기"
        case .activity: "활동"
        }
    }
}

enum WatchRunTab: Int, CaseIterable, Hashable, Identifiable {
    case controls
    case dashboard
    case music

    var id: Int { rawValue }

    var accessibilityTitle: String {
        switch self {
        case .controls: "러닝 제어"
        case .dashboard: "러닝 대시보드"
        case .music: "현재 재생 음악"
        }
    }
}

/// 실제 HealthKit 운동 세션을 연결하기 전, 화면의 공통 상태를 관리합니다.
@MainActor
final class WatchAppViewModel: ObservableObject {
    @Published var selectedTab: WatchTab = .running
    let runningViewModel = WatchRunningViewModel()
    @Published var selectedRunTab: WatchRunTab = .controls
    @Published private(set) var isRunExperiencePresented = false
    @Published private(set) var isRunPaused = false
    @Published private(set) var isRunTabLocked = false
    @Published private(set) var isRunSummaryPresented = false
    private var cancellables = Set<AnyCancellable>()

    var runTabs: [WatchRunTab] {
        isRunPaused ? [.controls, .music] : [.controls, .dashboard, .music]
    }

    init() {
        PhoneRunSyncReceiver.shared.onSnapshot = { [weak self] snapshot in
            self?.selectedTab = .running
            self?.runningViewModel.applyPhoneSnapshot(snapshot)
        }
        PhoneRunSyncReceiver.shared.onCommand = { [weak self] command in
            self?.runningViewModel.applyPhoneCommand(command)
        }

        runningViewModel.$state
            .sink { [weak self] state in
                guard let self else { return }

                isRunSummaryPresented = false
                isRunExperiencePresented = state.isActive
                isRunPaused = state == .paused
                isRunTabLocked = false

                switch state {
                case .countdown:
                    selectedRunTab = .dashboard
                    isRunTabLocked = true
                case .running:
                    selectedRunTab = .dashboard
                case .paused:
                    selectedRunTab = .controls
                case .ended:
                    // 기본 홈의 러닝 탭도 같은 ViewModel을 사용한다. 종료 상태를
                    // 남겨두면 앱을 다시 열었을 때 종료 화면이 홈에 재표시된다.
                    runningViewModel.reset()
                case .idle, .starting, .ending, .failed:
                    break
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .phoneStartedRunning)
            .compactMap { $0.object as? HKWorkoutConfiguration }
            .sink { [weak self] configuration in
                self?.selectedTab = .running
                self?.runningViewModel.startFromPhone(configuration: configuration)
            }
            .store(in: &cancellables)

        if let configuration = WatchWorkoutLaunchStore.shared.takePendingConfiguration() {
            selectedTab = .running
            runningViewModel.startFromPhone(configuration: configuration)
        }
    }
}

private struct WatchTabIndicator: View {
    @Binding var selectedTab: WatchTab

    var body: some View {
        HStack(spacing: 5) {
            ForEach(WatchTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Circle()
                        .fill(tab == selectedTab ? PacingWatchTheme.main500 : PacingWatchTheme.textSecondary.opacity(0.42))
                        .frame(width: 4, height: 4)
                        .animation(.easeInOut(duration: 0.18), value: selectedTab)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(tab.title) 탭")
                .accessibilityValue(tab == selectedTab ? "선택됨" : "선택 안 됨")
            }
        }
    }
}

private struct WatchRunTabIndicator: View {
    @Binding var selectedTab: WatchRunTab
    let tabs: [WatchRunTab]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(tabs) { tab in
                Button { selectedTab = tab } label: {
                    Circle()
                        .fill(tab == selectedTab ? PacingWatchTheme.main500 : PacingWatchTheme.textSecondary.opacity(0.42))
                        .frame(width: 4, height: 4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.accessibilityTitle)
                .accessibilityValue(tab == selectedTab ? "선택됨" : "선택 안 됨")
            }
        }
    }
}

private struct WatchMusicTabView: View {
    @StateObject private var viewModel = WatchMusicPlaybackViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 9) {
                Text("최근 재생한 음악")
                    .font(.headline)

                if viewModel.snapshot.recentlyPlayed.isEmpty {
                    ContentUnavailableView(
                        "최근 재생 음악 없음",
                        systemImage: "music.note.list",
                        description: Text("iPhone에서 음악을 재생하면 여기에 표시됩니다."))
                        .font(.caption)
                } else {
                    ForEach(viewModel.snapshot.recentlyPlayed) { track in
                        Button { viewModel.play(track) } label: {
                            HStack(spacing: 8) {
                                WatchMusicArtwork(data: track.artworkData, url: track.artworkURL, size: 38)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(track.title).font(.system(size: 11, weight: .semibold)).lineLimit(1)
                                    Text(track.artist).font(.system(size: 9)).foregroundStyle(PacingWatchTheme.textSecondary).lineLimit(1)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "play.fill")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.trailing, 14)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(7)
                            .background(PacingWatchTheme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(track.title), \(track.artist) 재생")
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 30)
        }
        .onAppear { viewModel.refresh() }
    }
}

private struct WatchMusicArtwork: View {
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
            } else { placeholder }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
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

private struct WatchListenTogetherTabView: View {
    var body: some View {
        WatchPlaceholderPage(
            title: "같이 듣기",
            systemImage: "person.2.wave.2.fill",
            accent: PacingWatchTheme.magenta,
            headline: "함께 달릴 사람 찾기",
            message: "주변 러너와 친구에게 같이 듣기 요청을 보내는 기능을 준비하고 있어요."
        )
    }
}

private struct WatchActivityTabView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                WatchActivityMetric(value: "0.0", unit: "km", label: "이번 달", labelAboveValue: true)
                WatchActivityMetric(value: "0", unit: "회", label: "러닝 횟수")

                VStack(alignment: .leading, spacing: 6) {
                    Text("최근 러닝")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PacingWatchTheme.textPrimary)
                    Text("아직 기록된 러닝이 없어요")
                        .font(.caption2)
                        .foregroundStyle(PacingWatchTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(PacingWatchTheme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 30)
        }
    }
}

private struct WatchActivityMetric: View {
    let value: String
    let unit: String
    let label: String
    var labelAboveValue = false

    var body: some View {
        VStack(spacing: 1) {
            if labelAboveValue {
                labelView
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text(unit)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PacingWatchTheme.textSecondary)
            }

            if !labelAboveValue {
                labelView
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var labelView: some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(PacingWatchTheme.textSecondary)
    }
}

private struct WatchPlaceholderPage: View {
    let title: String
    let systemImage: String
    let accent: Color
    let headline: String
    let message: String

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(accent)
                    .accessibilityHidden(true)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(PacingWatchTheme.textPrimary)

                VStack(spacing: 5) {
                    Text(headline)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PacingWatchTheme.textPrimary)
                    Text(message)
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(PacingWatchTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(PacingWatchTheme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 30)
        }
    }
}

/// iPhone 앱의 PacingColor를 Watch의 작은 화면과 기본 다크 모드에 맞춰 축약한 색상 토큰입니다.
enum PacingWatchTheme {
    static let main500 = Color(red: 1.0, green: 0.216, blue: 0.373) // #FF375F
    static let magenta = Color(red: 0.85, green: 0.12, blue: 0.55)
    static let purple = Color(red: 0.42, green: 0.19, blue: 0.90)

    static let background = Color(red: 0.067, green: 0.067, blue: 0.067) // #111111
    static let surface = Color(red: 0.106, green: 0.106, blue: 0.106) // #1B1B1B
    static let textPrimary = Color(red: 0.961, green: 0.961, blue: 0.969) // #F5F5F7
    static let textSecondary = Color(red: 0.682, green: 0.682, blue: 0.698) // #AEAEB2

}
