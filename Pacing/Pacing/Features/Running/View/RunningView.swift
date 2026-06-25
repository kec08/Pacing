import SwiftUI
import MapKit
import Combine

struct RunningView: View {
    @StateObject private var viewModel = RunningViewModel()
    @State private var showSummary = false
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)

    var body: some View {
        ZStack {
            // 풀스크린 지도
            Map(position: $cameraPosition) {
                // 실시간 경로 Polyline
                if viewModel.locationManager.routeCoordinates.count >= 2 {
                    MapPolyline(coordinates: viewModel.locationManager.routeCoordinates)
                        .stroke(Color.main500, lineWidth: 4)
                }
                // 현재 위치 마커
                UserAnnotation()
            }
            .mapStyle(.standard(elevation: .realistic))
            .ignoresSafeArea()

            // 상단 실시간 스탯 오버레이
            if viewModel.state != .idle {
                VStack {
                    runningStatsOverlay
                    Spacer()
                }
            }

            // 하단 컨트롤
            VStack {
                Spacer()
                bottomControls
            }
        }
        .onReceive(viewModel.locationManager.$currentLocation.compactMap { $0 }) { loc in
            if viewModel.state == .running {
                withAnimation(.easeInOut(duration: 1)) {
                    cameraPosition = .camera(MapCamera(
                        centerCoordinate: loc.coordinate,
                        distance: 400,
                        heading: loc.course > 0 ? loc.course : 0
                    ))
                }
            }
        }
        .fullScreenCover(isPresented: $showSummary) {
            RunSummaryView(
                distance: viewModel.distance,
                elapsedSeconds: viewModel.elapsedSeconds,
                avgPace: viewModel.avgPace,
                routeCoordinates: viewModel.locationManager.routeCoordinates,
                onSave: {
                    showSummary = false
                    viewModel.reset()
                },
                onDiscard: {
                    showSummary = false
                    viewModel.reset()
                }
            )
        }
    }

    // MARK: - 상단 스탯 오버레이

    private var runningStatsOverlay: some View {
        HStack(spacing: 0) {
            overlayStatItem(value: viewModel.formattedDistance, label: "km")
            Divider().frame(height: 36).opacity(0.4)
            overlayStatItem(value: viewModel.formattedTime, label: "시간")
            Divider().frame(height: 36).opacity(0.4)
            overlayStatItem(value: viewModel.formattedPace, label: "페이스")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
        .padding(.top, 60)
    }

    private func overlayStatItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.textPrimary)
            Text(label)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 하단 컨트롤

    private var bottomControls: some View {
        VStack(spacing: 16) {
            switch viewModel.state {
            case .idle:
                startButton
            case .running:
                HStack(spacing: 24) {
                    pauseButton
                    stopButton
                }
            case .paused:
                HStack(spacing: 24) {
                    resumeButton
                    stopButton
                }
            case .finished:
                EmptyView()
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 48)
        .padding(.top, 16)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }

    private var startButton: some View {
        Button {
            viewModel.start()
        } label: {
            Text("시작")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 80, height: 80)
                .background(Color.main500)
                .clipShape(Circle())
        }
    }

    private var pauseButton: some View {
        Button {
            viewModel.pause()
        } label: {
            Image(systemName: "pause.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
                .frame(width: 64, height: 64)
                .background(Color.backgroundSecondary)
                .clipShape(Circle())
        }
    }

    private var resumeButton: some View {
        Button {
            viewModel.resume()
        } label: {
            Image(systemName: "play.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(Color.main500)
                .clipShape(Circle())
        }
    }

    private var stopButton: some View {
        Button {
            viewModel.stop()
            showSummary = true
        } label: {
            Image(systemName: "stop.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(Color.sub500)
                .clipShape(Circle())
        }
    }
}
