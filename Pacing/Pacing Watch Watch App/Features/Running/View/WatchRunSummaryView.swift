import SwiftUI

struct WatchRunSummaryView: View {
    let metrics: WatchRunMetrics
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack {
                    Button("닫기", action: onDone)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .buttonStyle(.plain)
                    Spacer()
                }
                .offset(y: -30)
                .padding(.bottom, -30)
                summaryHeader
                WatchRunRouteView(points: metrics.routePoints)
                metricsGrid
                splitsSection
                Button("완료", action: onDone)
                    .tint(PacingWatchTheme.main500)
                    .padding(.top, 24)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 38)
        }
        .accessibilityLabel("러닝 종료 요약")
    }

    private var summaryHeader: some View {
        VStack(spacing: 2) {
            Text("러닝 종료")
                .font(.headline)
                .foregroundStyle(PacingWatchTheme.textPrimary)
            Text(metrics.formattedDistance)
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .foregroundStyle(PacingWatchTheme.main500)
                .monospacedDigit()
            Text("킬로미터")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PacingWatchTheme.textSecondary)
        }
    }

    private var metricsGrid: some View {
        VStack(spacing: 10) {
            HStack {
                metric(.averagePace)
                Spacer(minLength: 16)
                metric(.elapsed)
            }
            HStack {
                metric(.calories)
                Spacer(minLength: 16)
                metric(.elevationGain)
            }
            HStack {
                metric(.heartRate)
                Spacer(minLength: 16)
                metric(.distance)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var splitsSection: some View {
        if !metrics.splits.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("구간")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PacingWatchTheme.textPrimary)
                ForEach(metrics.splits) { split in
                    HStack {
                        Text("\(split.kilometer)")
                            .foregroundStyle(PacingWatchTheme.textSecondary)
                        Text(formatPace(split.paceSecondsPerKilometer))
                            .fontWeight(.semibold)
                        Spacer()
                        if let difference = split.differenceSeconds {
                            Text(formatDifference(difference))
                                .foregroundStyle(PacingWatchTheme.textSecondary)
                        }
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(PacingWatchTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }

    private func metric(_ metric: WatchRunDisplayMetric) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(metrics.formattedValue(for: metric))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(PacingWatchTheme.textPrimary)
                .monospacedDigit()
            Text(metric.title)
                .font(.caption2)
                .foregroundStyle(PacingWatchTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func formatPace(_ seconds: TimeInterval) -> String {
        let rounded = Int(seconds.rounded())
        return String(format: "%d'%02d\"", rounded / 60, rounded % 60)
    }

    private func formatDifference(_ seconds: TimeInterval) -> String {
        let rounded = Int(seconds.rounded())
        return String(format: "%+d\"", rounded)
    }
}

private struct WatchRunRouteView: View {
    let points: [WatchRunRoutePoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("러닝 경로")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PacingWatchTheme.textPrimary)

            if points.count >= 2 {
                Canvas { context, size in
                    var path = Path()
                    guard let first = points.first else { return }
                    path.move(to: CGPoint(x: first.x * size.width, y: first.y * size.height))
                    for point in points.dropFirst() {
                        path.addLine(to: CGPoint(x: point.x * size.width, y: point.y * size.height))
                    }

                    context.stroke(
                        path,
                        with: .linearGradient(
                            Gradient(colors: [PacingWatchTheme.purple, PacingWatchTheme.main500]),
                            startPoint: .zero,
                            endPoint: CGPoint(x: size.width, y: size.height)
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                    )
                }
                .frame(height: 100)
                .background(PacingWatchTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityLabel("러닝 경로")
            } else {
                Text("러닝 경로가 없어요")
                    .font(.caption2)
                    .foregroundStyle(PacingWatchTheme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 76, alignment: .center)
                    .background(PacingWatchTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}
