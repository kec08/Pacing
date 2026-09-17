//
//  ContentView.swift
//  Pacing Watch Watch App
//

import Combine
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = WatchAppViewModel()

    var body: some View {
        ZStack {
            PacingWatchTheme.background.ignoresSafeArea()

            TabView(selection: $viewModel.selectedTab) {
                WatchMusicTabView().tag(WatchTab.music)
                WatchRunningTabView(onStartRequested: viewModel.requestRunStart).tag(WatchTab.running)
                WatchListenTogetherTabView().tag(WatchTab.listenTogether)
                WatchActivityTabView().tag(WatchTab.activity)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .safeAreaInset(edge: .bottom, spacing: 0) {
                WatchTabIndicator(selectedTab: $viewModel.selectedTab)
                    .offset(y: 12)
            }
        }
        .alert("러닝 준비 중", isPresented: $viewModel.isRunStartNoticePresented) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("실제 운동 세션과 거리·페이스 기록은 다음 단계에서 연결합니다.")
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

/// 실제 HealthKit 운동 세션을 연결하기 전, 화면의 공통 상태를 관리합니다.
@MainActor
final class WatchAppViewModel: ObservableObject {
    @Published var selectedTab: WatchTab = .running
    @Published var isRunStartNoticePresented = false

    func requestRunStart() {
        isRunStartNoticePresented = true
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

private struct WatchMusicTabView: View {
    var body: some View {
        WatchPlaceholderPage(
            title: "음악",
            systemImage: "music.note.list",
            accent: PacingWatchTheme.purple,
            headline: "최근 재생한 음악",
            message: "Apple Music을 연결하면 최근 재생 곡과 러닝 중인 곡을 여기에서 확인할 수 있어요."
        )
    }
}

private struct WatchRunningTabView: View {
    let onStartRequested: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 4)

            Button(action: onStartRequested) {
                Image("PacingWatchMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 112, height: 112)
                    .accessibilityHidden(true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("러닝 시작")
            .accessibilityHint("운동 세션 연결 전 안내를 표시합니다")

            Spacer(minLength: 2)
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 22)
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
                        .background(PacingWatchTheme.surface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
            }
            .padding(.horizontal, 14)
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
                .background(PacingWatchTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.horizontal, 15)
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
