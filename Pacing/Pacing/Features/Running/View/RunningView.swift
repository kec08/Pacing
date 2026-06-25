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
        VStack(spacing: 0) {
            // 상단 뮤직 카드 스크롤
            musicScrollSection
                .padding(.top, 12)
                .padding(.bottom, 10)

            // 고정 높이 지도 (인터랙션 비활성)
            mapSection

            // 러닝 중 스탯 바
            if viewModel.state != .idle {
                runningStatsBar
            }

            // 흰 배경 컨트롤 영역
            Spacer()
            controlSection
                .padding(.bottom, 24)
        }
        .background(Color(.systemBackground))
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

    // MARK: - 지도 (고정 높이, 줌/스크롤 비활성)

    private var mapSection: some View {
        Map(position: $cameraPosition, interactionModes: []) {
            if viewModel.locationManager.routeCoordinates.count >= 2 {
                MapPolyline(coordinates: viewModel.locationManager.routeCoordinates)
                    .stroke(Color.main500, lineWidth: 4)
            }
            UserAnnotation()
        }
        .mapStyle(.standard)
        .frame(height: 260)
        .onReceive(viewModel.locationManager.$currentLocation.compactMap { $0 }) { loc in
            if viewModel.state == .running {
                withAnimation(.easeInOut(duration: 1)) {
                    cameraPosition = .camera(MapCamera(
                        centerCoordinate: loc.coordinate,
                        distance: 500
                    ))
                }
            }
        }
    }

    // MARK: - 러닝 중 스탯 바

    private var runningStatsBar: some View {
        HStack(spacing: 0) {
            statBarItem(value: viewModel.formattedDistance, label: "km")
            Divider().frame(height: 28)
            statBarItem(value: viewModel.formattedTime, label: "시간")
            Divider().frame(height: 28)
            statBarItem(value: viewModel.formattedPace, label: "페이스")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
    }

    private func statBarItem(value: String, label: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.textPrimary)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 하단 컨트롤 (흰 배경)

    private var controlSection: some View {
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
        .padding(.top, 20)
    }

    // MARK: - idle: 시작 + 좌우 버튼

    private var idleControls: some View {
        HStack(spacing: 40) {
            sideButton(icon: "music.note", label: "음악") {
                showMusicSheet = true
            }

            // 시작 / 카운트다운 버튼
            ZStack {
                if let cd = countdown {
                    Text("\(cd)")
                        .font(.system(size: 44, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 96, height: 96)
                        .background(Color.main500)
                        .clipShape(Circle())
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Button { startCountdown() } label: {
                        Text("시작")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 96, height: 96)
                            .background(Color.main500)
                            .clipShape(Circle())
                    }
                }
            }
            .animation(.spring(duration: 0.3), value: countdown)

            sideButton(icon: "person.2.fill", label: "주변") {
                // TODO: 주변 사용자
            }
        }
    }

    // MARK: - 러닝 중 컨트롤

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
                    .frame(width: 52, height: 52)
                    .background(Color(.systemGray6))
                    .clipShape(Circle())
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }

    // MARK: - 뮤직 카드 스크롤

    private var musicScrollSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if musicVM.isLoading {
                    ForEach(0..<3, id: \.self) { _ in musicCardSkeleton }
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

    private func musicCardItem(song: Song) -> some View {
        Button { showMusicSheet = true } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(width: 44, height: 44)
                    if let artwork = song.artwork {
                        ArtworkImage(artwork, width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 16))
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
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var emptyMusicCard: some View {
        Button { showMusicSheet = true } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(width: 44, height: 44)
                    Image(systemName: "music.note")
                        .font(.system(size: 16))
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
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var musicCardSkeleton: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 5) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 80, height: 11)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 56, height: 10)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 음악 시트

    private var musicSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemGray6))
                        .frame(width: 200, height: 200)
                    Image(systemName: "music.note")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.main500)
                }

                VStack(spacing: 6) {
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
