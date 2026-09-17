import SwiftUI
import WatchKit

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
            }

            Spacer(minLength: 12)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 26)
    }

    private var dashboard: some View {
        VStack(spacing: 4) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    WatchDashboardMetric(
                        title: "",
                        value: viewModel.metrics.formattedPace,
                        unit: "현재 페이스",
                        valueSize: 48,
                        alignment: .center,
                        isPrimary: true
                    )
                    Button {
                        WKInterfaceDevice.current().play(.click)
                        viewModel.selectNextDisplayMetric()
                    } label: {
                        WatchDashboardMetric(
                            title: "",
                            value: cornerValue,
                            unit: cornerUnit,
                            valueSize: 14,
                            alignment: .trailing,
                            valueColor: PacingWatchTheme.textSecondary
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(viewModel.displayMetric.title), \(cornerValue)")
                    .accessibilityHint("탭하면 시간, 거리, 현재 페이스 표시를 변경합니다")
                }

                HStack(spacing: 26) {
                    WatchDashboardMetric(
                        title: "",
                        value: heartRate,
                        unit: "심박수",
                        valueSize: 23,
                        alignment: .center
                    )
                    .frame(width: 58)
                    WatchDashboardMetric(
                        title: "",
                        value: viewModel.metrics.formattedDistance,
                        unit: "총 거리",
                        valueSize: 23,
                        alignment: .center
                    )
                    .frame(width: 58)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 4)

            if viewModel.state == .paused {
                Text("일시정지됨")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(PacingWatchTheme.main500)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 28)
    }

    private func countdownView(_ value: Int) -> some View {
        Text("\(value)")
            .font(.system(size: 132, weight: .black, design: .rounded))
            .foregroundStyle(PacingWatchTheme.main500)
            .monospacedDigit()
            .accessibilityLabel("러닝 시작까지 \(value)초")
            .transition(reduceMotion ? .identity : .scale.combined(with: .opacity))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var heartRate: String {
        guard let heartRate = viewModel.metrics.heartRateBeatsPerMinute else { return "--" }
        return String(Int(heartRate.rounded()))
    }

    private var cornerValue: String {
        switch viewModel.displayMetric {
        case .elapsed: viewModel.metrics.formattedElapsed
        case .distance: viewModel.metrics.formattedDistance
        case .currentPace: viewModel.metrics.formattedPace
        }
    }

    private var cornerUnit: String {
        switch viewModel.displayMetric {
        case .elapsed: ""
        case .distance: "km"
        case .currentPace: "/km"
        }
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
    var isPrimary = false
    var valueColor: Color = PacingWatchTheme.main500

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            if !title.isEmpty {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(PacingWatchTheme.textSecondary)
            }
            Text(value)
                .font(.system(size: valueSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.65)
                .lineLimit(1)
                .foregroundStyle(valueColor)
            if !unit.isEmpty {
                Text(unit)
                    .font(.system(size: isPrimary ? 11 : 10, weight: .semibold))
                    .foregroundStyle(PacingWatchTheme.textSecondary)
            } else {
                Spacer()
                    .frame(height: 12)
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: isPrimary ? 96 : 56,
            alignment: isPrimary ? .center : resolvedAlignment
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title.isEmpty ? accessibilityValue : "\(title), \(accessibilityValue)")
    }

    private var accessibilityValue: String {
        unit.isEmpty ? value : "\(value) \(unit)"
    }

    private var resolvedAlignment: Alignment {
        if alignment == .leading { return .leading }
        if alignment == .center { return .center }
        return .trailing
    }
}
