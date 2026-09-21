import SwiftUI

struct WatchRunControlsTabView: View {
    @ObservedObject var viewModel: WatchRunningViewModel

    var body: some View {
        HStack(spacing: 18) {
            Button { viewModel.pauseOrResume() } label: {
                Image(systemName: viewModel.state == .paused ? "play.fill" : "pause.fill")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(viewModel.state == .paused ? .white : .black)
                    .frame(width: 66, height: 66)
                    .background(
                        viewModel.state == .paused ? PacingWatchTheme.main500 : Color.white,
                        in: Circle()
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(viewModel.state == .paused ? "러닝 재개" : "러닝 일시정지")

            WatchRunEndHoldButton(action: { viewModel.end() })
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct WatchRunEndHoldButton: View {
    let action: () -> Void
    @State private var progress = 0.0
    @State private var didComplete = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 4)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(PacingWatchTheme.main500, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: "stop.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 66, height: 66)
        .background(Color(red: 0.18, green: 0.18, blue: 0.20), in: Circle())
        .contentShape(Circle())
        .onLongPressGesture(minimumDuration: 1.2, maximumDistance: 22, pressing: updatePress) {
            guard !didComplete else { return }
            didComplete = true
            WKInterfaceDevice.current().play(.success)
            action()
        }
        .accessibilityLabel("길게 눌러 러닝 종료")
        .accessibilityHint("1.2초 동안 길게 누르면 러닝이 종료됩니다")
    }

    private func updatePress(_ isPressing: Bool) {
        guard !didComplete else { return }
        withAnimation(.linear(duration: isPressing ? 1.2 : 0.16)) {
            progress = isPressing ? 1 : 0
        }
        if isPressing {
            WKInterfaceDevice.current().play(.click)
        }
    }
}
