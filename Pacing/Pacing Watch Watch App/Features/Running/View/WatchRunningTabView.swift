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
                    Button { selectNextMetric() } label: {
                        WatchDashboardMetric(
                            title: "",
                            value: primaryValue,
                            unit: primaryLabel,
                            valueSize: 48,
                            alignment: .center,
                            isPrimary: true
                        )
                        .offset(y: 14)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .accessibilityLabel("\(primaryLabel), \(primaryValue)")
                    .accessibilityHint("탭하면 다음 러닝 지표를 표시합니다")
                    WatchDashboardMetric(
                        title: "",
                        value: viewModel.metrics.formattedElapsedIncludingHours,
                        unit: "",
                        valueSize: 14,
                        alignment: .trailing,
                        valueColor: PacingWatchTheme.textSecondary,
                        valueWeight: .medium
                    )
                    .offset(y: -10)
                    .accessibilityLabel("총 시간, \(viewModel.metrics.formattedElapsedIncludingHours)")
                }

                HStack(spacing: 18) {
                    Button { selectNextSecondaryMetric(at: 0) } label: {
                        WatchDashboardMetric(
                            title: "",
                            value: secondaryValue(at: 0),
                            unit: secondaryLabel(at: 0),
                            valueSize: 23,
                            alignment: .center
                        )
                    }
                    .buttonStyle(.plain)
                    .frame(width: 70, height: 64)
                    .background(Color.clear)
                    .contentShape(Rectangle())
                    .accessibilityLabel("\(secondaryLabel(at: 0)), \(secondaryValue(at: 0))")
                    .accessibilityHint("탭하면 다음 러닝 지표로 변경합니다")
                    Button { selectNextSecondaryMetric(at: 1) } label: {
                        WatchDashboardMetric(
                            title: "",
                            value: secondaryValue(at: 1),
                            unit: secondaryLabel(at: 1),
                            valueSize: 23,
                            alignment: .center
                        )
                    }
                    .buttonStyle(.plain)
                    .frame(width: 70, height: 64)
                    .background(Color.clear)
                    .contentShape(Rectangle())
                    .accessibilityLabel("\(secondaryLabel(at: 1)), \(secondaryValue(at: 1))")
                    .accessibilityHint("탭하면 다음 러닝 지표로 변경합니다")
                }
                .frame(maxWidth: .infinity)
                .offset(y: 8)
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
            .offset(y: -12)
    }

    private var primaryValue: String {
        viewModel.metrics.formattedValue(for: viewModel.displayMetric)
    }

    private var primaryLabel: String {
        viewModel.displayMetric.title
    }

    private func selectNextMetric() {
        WKInterfaceDevice.current().play(.click)
        viewModel.selectNextDisplayMetric()
    }

    private func selectNextSecondaryMetric(at index: Int) {
        WKInterfaceDevice.current().play(.click)
        viewModel.selectNextSecondaryMetric(at: index)
    }

    private func secondaryValue(at index: Int) -> String {
        viewModel.metrics.formattedValue(for: viewModel.secondaryMetrics[index])
    }

    private func secondaryLabel(at index: Int) -> String {
        viewModel.secondaryMetrics[index].title
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
    var valueWeight: Font.Weight = .bold

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            if !title.isEmpty {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(PacingWatchTheme.textSecondary)
            }
            Text(value)
                .font(.system(size: valueSize, weight: valueWeight, design: .rounded))
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
