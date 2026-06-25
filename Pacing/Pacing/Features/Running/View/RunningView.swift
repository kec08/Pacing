import SwiftUI
import MapKit
import Combine
import MusicKit

struct RunningView: View {
    @StateObject private var viewModel = RunningViewModel()
    @StateObject private var musicVM = RunningMusicViewModel()
    @State private var showSummary = false
    @State private var showMusicSheet = false
    @State private var countdown: Int? = nil
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)

    var body: some View {
        ZStack {
            // 풀스크린 지도
            Map(position: $cameraPosition) {
                if viewModel.locationManager.routeCoordinates.count >= 2 {
                    MapPolyline(coordinates: viewModel.locationManager.routeCoordinates)
                        .stroke(Color.main500, lineWidth: 4)
                }
                UserAnnotation()
            }
            .mapStyle(.standard(elevation: .realistic))
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // 상단 뮤직 카드
                if viewModel.state == .idle || viewModel.state == .running || viewModel.state == .paused {
                    musicCard
                        .padding(.top, 60)
                }

                // 실시간 스탯 오버레이 (러닝 중에만)
                if viewModel.state != .idle {
                    runningStatsOverlay
                        .padding(.top, viewModel.state == .idle ? 0 : 12)
                }

                Spacer()

                // 하단 그라데이션 + 컨트롤
                bottomControlArea
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
        .task { await musicVM.requestAuthorization() }
        .sheet(isPresented: $showMusicSheet) { musicSheet }
        .fullScreenCover(isPresented: $showSummary) {
            RunSummaryView(
                distance: viewModel.distance,
                elapsedSeconds: viewModel.elapsedSeconds,
                avgPace: viewModel.avgPace,
                routeCoordinates: viewModel.locationManager.routeCoordinates,
                onSave: { showSummary = false; viewModel.reset() },
                onDiscard: { showSummary = false; viewModel.reset() }
            )
        }
    }

    // MARK: - 상단 뮤직 카드

    private var musicCard: some View {
        Button { showMusicSheet = true } label: {
            HStack(spacing: 12) {
                // 앨범 아트
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.backgroundSecondary.opacity(0.8))
                        .frame(width: 44, height: 44)
                    if musicVM.isLoading {
                        ProgressView().tint(Color.main500).scaleEffect(0.8)
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.main500)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    if let track = musicVM.recommendedTrack {
                        Text(track.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(1)
                        Text(track.artistName)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(1)
                    } else {
                        Text("음악 선택")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                        Text("Apple Music")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)
        }
    }

    // MARK: - 실시간 스탯 오버레이

    private var runningStatsOverlay: some View {
        HStack(spacing: 0) {
            overlayStatItem(value: viewModel.formattedDistance, label: "km")
            Divider().frame(height: 32).opacity(0.4)
            overlayStatItem(value: viewModel.formattedTime, label: "시간")
            Divider().frame(height: 32).opacity(0.4)
            overlayStatItem(value: viewModel.formattedPace, label: "페이스")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
    }

    private func overlayStatItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(Color.textPrimary)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 하단 그라데이션 + 컨트롤

    private var bottomControlArea: some View {
        ZStack(alignment: .bottom) {
            // 지도 → 컨트롤 배경 그라데이션 (나이키 런 클럽 스타일)
            LinearGradient(
                colors: [.clear, Color(.systemBackground).opacity(0.85), Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 220)
            .allowsHitTesting(false)

            // 컨트롤
            VStack(spacing: 20) {
                switch viewModel.state {
                case .idle:
                    idleControls
                case .running:
                    activeControls(isPaused: false)
                case .paused:
                    activeControls(isPaused: true)
                case .finished:
                    EmptyView()
                }
            }
            .padding(.bottom, 52)
        }
    }

    // MARK: - idle: 시작 버튼 + 좌우 버튼

    private var idleControls: some View {
        HStack(spacing: 32) {
            // 왼쪽: 음악
            sideButton(icon: "music.note", label: "음악") {
                showMusicSheet = true
            }

            // 시작 버튼 (카운트다운)
            ZStack {
                if let cd = countdown {
                    Text("\(cd)")
                        .font(.system(size: 44, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 100, height: 100)
                        .background(Color.main500)
                        .clipShape(Circle())
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Button { startCountdown() } label: {
                        Text("시작")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 100, height: 100)
                            .background(Color.main500)
                            .clipShape(Circle())
                    }
                }
            }
            .animation(.spring(duration: 0.3), value: countdown)

            // 오른쪽: 주변 사용자
            sideButton(icon: "person.2.fill", label: "주변") {
                // TODO: 주변 사용자 찾기
            }
        }
    }

    // MARK: - running/paused: 일시정지 + 종료

    private func activeControls(isPaused: Bool) -> some View {
        HStack(spacing: 28) {
            Button {
                isPaused ? viewModel.resume() : viewModel.pause()
            } label: {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isPaused ? .white : Color.textPrimary)
                    .frame(width: 72, height: 72)
                    .background(isPaused ? Color.main500 : Color(.systemGray5))
                    .clipShape(Circle())
            }

            Button {
                viewModel.stop()
                showSummary = true
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(Color.sub500)
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - 사이드 버튼

    private func sideButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 56, height: 56)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }

    // MARK: - 음악 시트

    private var musicSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 현재 재생 카드
                VStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.backgroundSecondary)
                            .frame(width: 200, height: 200)
                        Image(systemName: "music.note")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.main500)
                    }

                    if let track = musicVM.recommendedTrack {
                        Text(track.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                        Text(track.artistName)
                            .font(.system(size: 15))
                            .foregroundStyle(Color.textSecondary)
                    } else {
                        Text("Apple Music 라이브러리")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                        Text("러닝에 맞는 음악을 선택하세요")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.textSecondary)
                    }
                }

                // 재생 컨트롤 (임시 UI)
                HStack(spacing: 40) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.textPrimary)
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Color.main500)
                    Image(systemName: "forward.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.textPrimary)
                }

                Spacer()
            }
            .padding(.top, 32)
            .navigationTitle("음악")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("완료") { showMusicSheet = false }
                        .foregroundStyle(Color.main500)
                }
            }
        }
    }

    // MARK: - 카운트다운

    private func startCountdown() {
        countdown = 3
        Task {
            for i in stride(from: 3, through: 1, by: -1) {
                await MainActor.run { countdown = i }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            await MainActor.run {
                countdown = nil
                viewModel.start()
            }
        }
    }
}
