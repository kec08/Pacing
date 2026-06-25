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
                // 상단 수평 스크롤 뮤직 카드
                musicScrollSection
                    .padding(.top, 60)

                // 실시간 스탯 오버레이 (러닝 중에만)
                if viewModel.state != .idle {
                    runningStatsOverlay
                        .padding(.top, 10)
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

    // MARK: - 상단 수평 스크롤 뮤직 카드

    private var musicScrollSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if musicVM.isLoading {
                    ForEach(0..<3, id: \.self) { _ in
                        musicCardSkeleton
                    }
                } else if musicVM.recentSongs.isEmpty {
                    emptyMusicCard
                } else {
                    ForEach(musicVM.recentSongs, id: \.id) { song in
                        musicCardItem(song: song)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // 가로 레이아웃 카드 (앨범아트 왼쪽, 곡정보 오른쪽)
    private func musicCardItem(song: Song) -> some View {
        Button { showMusicSheet = true } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(width: 48, height: 48)
                    if let artwork = song.artwork {
                        ArtworkImage(artwork, width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.main500)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(song.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                    Text(song.artistName)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                }
                .frame(width: 100, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var emptyMusicCard: some View {
        Button { showMusicSheet = true } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(width: 48, height: 48)
                    Image(systemName: "music.note")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.main500)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("음악 선택")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    Text("Apple Music")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var musicCardSkeleton: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5).opacity(0.6))
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5).opacity(0.6))
                    .frame(width: 80, height: 11)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5).opacity(0.6))
                    .frame(width: 56, height: 10)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
            // 탭바 포함 아래까지 그라데이션 확장
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: Color(.systemBackground).opacity(0.4), location: 0.25),
                    .init(color: Color(.systemBackground).opacity(0.82), location: 0.5),
                    .init(color: Color(.systemBackground), location: 0.68),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 340)
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)

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
            sideButton(icon: "music.note", label: "음악") {
                showMusicSheet = true
            }

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

            sideButton(icon: "person.2.fill", label: "주변") {
                // TODO: 주변 사용자 찾기
            }
        }
    }

    // MARK: - running/paused 컨트롤

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
                VStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.backgroundSecondary)
                            .frame(width: 200, height: 200)
                        Image(systemName: "music.note")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.main500)
                    }

                    if let song = musicVM.recentSongs.first {
                        Text(song.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                        Text(song.artistName)
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
