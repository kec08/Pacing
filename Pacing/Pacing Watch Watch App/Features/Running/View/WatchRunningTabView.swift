import SwiftUI

struct WatchRunningTabView: View {
    @ObservedObject var viewModel: WatchRunningViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .starting, .failed:
                startView
            case let .countdown(value):
                countdownView(value)
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
        VStack(spacing: 4) {
            VStack(spacing: 4) {
                HStack(alignment: .top, spacing: 4) {
                    WatchDashboardMetric(
                        title: "현재 페이스",
                        value: viewModel.metrics.formattedPace,
                        unit: "/km",
                        valueSize: 29
                    )
                    WatchDashboardMetric(
                        title: "시간",
                        value: viewModel.metrics.formattedElapsed,
                        unit: "",
                        valueSize: 19,
                        alignment: .trailing
                    )
                }

                HStack(spacing: 4) {
                    WatchDashboardMetric(
                        title: "심박수",
                        value: heartRate,
                        unit: "bpm",
                        valueSize: 25
                    )
                    WatchDashboardMetric(
                        title: "거리",
                        value: viewModel.metrics.formattedDistance,
                        unit: "km",
                        valueSize: 25,
                        alignment: .trailing
                    )
                }
            }
            .padding(.top, 4)

            if viewModel.state == .paused {
                Text("일시정지됨")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(PacingWatchTheme.main500)
            }

            Spacer(minLength: 0)

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

    private func countdownView(_ value: Int) -> some View {
        Text("\(value)")
            .font(.system(size: 72, weight: .bold, design: .rounded))
            .foregroundStyle(PacingWatchTheme.main500)
            .monospacedDigit()
            .accessibilityLabel("러닝 시작까지 \(value)초")
            .transition(reduceMotion ? .identity : .scale.combined(with: .opacity))
    }

    private var heartRate: String {
        guard let heartRate = viewModel.metrics.heartRateBeatsPerMinute else { return "--" }
        return String(Int(heartRate.rounded()))
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

private struct WatchDashboardMetric: View {
    let title: String
    let value: String
    let unit: String
    let valueSize: CGFloat
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(PacingWatchTheme.textSecondary)
            Text(value)
                .font(.system(size: valueSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.65)
                .lineLimit(1)
            if !unit.isEmpty {
                Text(unit)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(PacingWatchTheme.textSecondary)
            } else {
                Spacer()
                    .frame(height: 12)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 63, alignment: alignment == .leading ? .leading : .trailing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(accessibilityValue)")
    }

    private var accessibilityValue: String {
        unit.isEmpty ? value : "\(value) \(unit)"
    }
}
