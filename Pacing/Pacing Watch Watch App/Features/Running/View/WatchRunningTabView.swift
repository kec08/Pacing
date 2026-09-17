import SwiftUI

struct WatchRunningTabView: View {
    @ObservedObject var viewModel: WatchRunningViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .starting, .failed:
                startView
            case .running, .paused, .ending:
                dashboard
            case .ended:
                endedView
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: viewModel.state)
        .alert("러닝을 종료할까요?", isPresented: $viewModel.isEndConfirmationPresented) {
            Button("계속 러닝", role: .cancel) {}
            Button("종료", role: .destructive) { viewModel.end() }
        } message: {
            Text("현재 러닝을 종료하고 기록을 저장합니다.")
        }
    }

    private var startView: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 0)

            Button { viewModel.start() } label: {
                Image("PacingWatchMark")
                    .resizable()
                    .scaledToFit()
                    .accessibilityHidden(true)
                .frame(width: 112, height: 112)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("러닝 시작")
            .accessibilityHint("Watch에서 운동을 시작합니다")
            .disabled(viewModel.state == .starting)

            if viewModel.state == .starting {
                ProgressView("러닝 준비 중")
                    .font(.caption2)
            } else if case let .failed(error) = viewModel.state {
                Text(error.userMessage)
                    .font(.caption2)
                    .foregroundStyle(PacingWatchTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("운동과 위치 권한을 확인해요")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(PacingWatchTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer(minLength: 12)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 26)
    }

    private var dashboard: some View {
        VStack(spacing: 8) {
            Button { viewModel.selectNextDisplayMetric() } label: {
                WatchPrimaryMetric(
                    metric: viewModel.displayMetric,
                    metrics: viewModel.metrics
                )
            }
            .buttonStyle(.plain)
            .accessibilityHint("탭하면 시간, 거리, 현재 페이스 표시를 바꿉니다")

            if viewModel.state == .paused {
                Text("일시정지됨")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PacingWatchTheme.main500)
            }

            WatchSecondaryMetrics(metrics: viewModel.metrics)

            HStack(spacing: 8) {
                Button { viewModel.pauseOrResume() } label: {
                    Label(
                        viewModel.state == .paused ? "재개" : "일시정지",
                        systemImage: viewModel.state == .paused ? "play.fill" : "pause.fill"
                    )
                }
                .tint(PacingWatchTheme.main500)

                Button(role: .destructive) { viewModel.requestEnd() } label: {
                    Label("종료", systemImage: "stop.fill")
                }
            }
            .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 28)
    }

    private var endedView: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(PacingWatchTheme.main500)
            Text("러닝 완료")
                .font(.headline)
            Text("\(viewModel.metrics.formattedElapsed) · \(viewModel.metrics.formattedDistance) km")
                .font(.caption)
                .foregroundStyle(PacingWatchTheme.textSecondary)
            Button("다시 시작") { viewModel.reset() }
                .tint(PacingWatchTheme.main500)
        }
        .padding(.bottom, 28)
    }
}

private struct WatchPrimaryMetric: View {
    let metric: WatchRunDisplayMetric
    let metrics: WatchRunMetrics

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.65)
                .lineLimit(1)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(PacingWatchTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(accessibilityValue)")
    }

    private var value: String {
        switch metric {
        case .elapsed: metrics.formattedElapsed
        case .distance: metrics.formattedDistance
        case .currentPace: metrics.formattedPace
        }
    }

    private var label: String {
        switch metric {
        case .elapsed: "시간"
        case .distance: "km"
        case .currentPace: "/km"
        }
    }

    private var accessibilityValue: String {
        switch metric {
        case .elapsed: metrics.formattedElapsed
        case .distance: "\(metrics.formattedDistance) 킬로미터"
        case .currentPace: metrics.currentPaceSecondsPerKilometer == nil ? "측정 중" : metrics.formattedPace
        }
    }
}

private struct WatchSecondaryMetrics: View {
    let metrics: WatchRunMetrics

    var body: some View {
        HStack(spacing: 6) {
            metric("거리", value: metrics.formattedDistance, unit: "km")
            metric("페이스", value: metrics.formattedPace, unit: "/km")
            metric("심박수", value: heartRate, unit: "bpm")
        }
        .accessibilityElement(children: .combine)
    }

    private var heartRate: String {
        guard let heartRate = metrics.heartRateBeatsPerMinute else { return "--" }
        return String(Int(heartRate.rounded()))
    }

    private func metric(_ title: String, value: String, unit: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("\(title) \(unit)")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(PacingWatchTheme.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 40)
        .padding(.vertical, 4)
        .background(PacingWatchTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
