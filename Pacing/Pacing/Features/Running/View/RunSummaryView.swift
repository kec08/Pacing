import SwiftUI
import MapKit
import CoreLocation

struct RunSummaryView: View {
    let distance: Double
    let elapsedSeconds: Int
    let avgPace: Double
    let routeCoordinates: [CLLocationCoordinate2D]
    let onSave: () -> Void
    let onDiscard: () -> Void

    @State private var mapSnapshot: UIImage?
    @State private var isGeneratingSnapshot = false

    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    statsHeader
                    routeMapSection
                    actionButtons
                }
            }
        }
        .navigationBarHidden(true)
        .task { await generateSnapshot() }
    }

    // MARK: - Stats Header (Nike 스타일)

    private var statsHeader: some View {
        VStack(spacing: 0) {
            // 상단 타이틀
            HStack {
                Text("러닝 완료")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 60)
            .padding(.bottom, 8)

            // 메인 거리 스탯
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(formattedDistance)
                    .font(.system(size: 72, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                Text("km")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
                    .padding(.bottom, 8)
                Spacer()
            }
            .padding(.horizontal, 24)

            // 시간 / 페이스 서브 스탯
            HStack(spacing: 0) {
                statItem(value: formattedTime, label: "시간")
                Divider().frame(height: 40).padding(.horizontal, 16)
                statItem(value: formattedAvgPace, label: "평균 페이스")
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(Color.backgroundPrimary)
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.textPrimary)
            Text(label)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.textSecondary)
        }
    }

    // MARK: - Route Map

    private var routeMapSection: some View {
        Group {
            if let snapshot = mapSnapshot {
                Image(uiImage: snapshot)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipped()
            } else if isGeneratingSnapshot {
                ZStack {
                    Color.backgroundSecondary
                    ProgressView()
                        .tint(Color.main500)
                }
                .frame(height: 300)
            } else {
                ZStack {
                    Color.backgroundSecondary
                    Text("경로 없음")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textSecondary)
                }
                .frame(height: 300)
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: onSave) {
                Text("저장하기")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.main500)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Button(action: onDiscard) {
                Text("삭제")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
    }

    // MARK: - Formatting

    private var formattedDistance: String {
        String(format: "%.2f", distance)
    }

    private var formattedTime: String {
        let h = elapsedSeconds / 3600
        let m = (elapsedSeconds % 3600) / 60
        let s = elapsedSeconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }

    private var formattedAvgPace: String {
        guard avgPace > 0 else { return "--'--\"" }
        let min = Int(avgPace)
        let sec = Int((avgPace - Double(min)) * 60)
        return String(format: "%d'%02d\"", min, sec)
    }

    // MARK: - Map Snapshot

    private func generateSnapshot() async {
        guard routeCoordinates.count >= 2 else { return }
        isGeneratingSnapshot = true

        let region = regionForCoordinates(routeCoordinates)
        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width)
        options.mapType = .standard
        options.showsBuildings = false

        let snapshotter = MKMapSnapshotter(options: options)
        do {
            let snapshot = try await snapshotter.start()
            let image = drawRoute(on: snapshot)
            await MainActor.run {
                self.mapSnapshot = image
                self.isGeneratingSnapshot = false
            }
        } catch {
            await MainActor.run { isGeneratingSnapshot = false }
        }
    }

    private func drawRoute(on snapshot: MKMapSnapshotter.Snapshot) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: snapshot.image.size)
        return renderer.image { ctx in
            snapshot.image.draw(at: .zero)

            let path = UIBezierPath()
            var first = true
            for coord in routeCoordinates {
                let point = snapshot.point(for: coord)
                if first { path.move(to: point); first = false }
                else { path.addLine(to: point) }
            }

            let cgCtx = ctx.cgContext
            cgCtx.setStrokeColor(UIColor(Color.main500).cgColor)
            cgCtx.setLineWidth(4)
            cgCtx.setLineCap(.round)
            cgCtx.setLineJoin(.round)
            path.stroke()
        }
    }

    private func regionForCoordinates(_ coords: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        let lats = coords.map(\.latitude)
        let lons = coords.map(\.longitude)
        let minLat = lats.min()!, maxLat = lats.max()!
        let minLon = lons.min()!, maxLon = lons.max()!
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.002),
            longitudeDelta: max((maxLon - minLon) * 1.4, 0.002)
        )
        return MKCoordinateRegion(center: center, span: span)
    }
}
