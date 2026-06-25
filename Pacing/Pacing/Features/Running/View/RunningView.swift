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
    @State private var showStopConfirm = false   // 정지 후 종료/재시작 버튼 표시
    @State private var stopHoldProgress: CGFloat = 0
    @State private var stopHoldTimer: Timer? = nil

    var body: some View {
        ZStack {
            // 풀스크린 지도 (줌/스크롤 비활성)
            Map(position: $cameraPosition, interactionModes: []) {
                if viewModel.locationManager.routeCoordinates.count >= 2 {
                    MapPolyline(coordinates: viewModel.locationManager.routeCoordinates)
                        .stroke(Color.main500, lineWidth: 4)
                }
                if let loc = viewModel.locationManager.currentLocation {
                    Annotation("", coordinate: loc.coordinate) {
                        ZStack {
                            Circle()
                                .fill(Color.main500)
                                .frame(width: 16, height: 16)
                            Circle()
                                .fill(.white)
                                .frame(width: 8, height: 8)
                        }
                    }
                }
            }
            .mapStyle(.standard)
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // 뮤직 카드: idle 상태에서만 표시
                if viewModel.state == .idle {
                    musicScrollSection
                        .padding(.top, 60)
                }

                // 스탯 오버레이: idle이 아닐 때 상단으로 올라옴
                if viewModel.state != .idle {
                    runningStatsOverlay
                        .padding(.top, 60)
                        .padding(.horizontal, 0)
                }

                Spacer()

                controlSection
                    .padding(.bottom, 40)
            }

            // 카운트다운 풀스크린 오버레이
            if let cd = countdown {
                Color.black.opacity(0.85)
                    .ignoresSafeArea()
                Text("\(cd)")
                    .font(.system(size: 160, weight: .black))
                    .foregroundStyle(Color.main500)
                    .transition(.scale(scale: 1.4).combined(with: .opacity))
                    .id(cd)
            }
        }
        .onReceive(viewModel.locationManager.$currentLocation.compactMap { $0 }) { loc in
            if viewModel.state == .running {
                withAnimation(.linear(duration: 2)) {
                    cameraPosition = .camera(MapCamera(
                        centerCoordinate: loc.coordinate,
                        distance: 500
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
                onSave: {
                    Task { await viewModel.saveRecord() }
                    showSummary = false
                    viewModel.reset()
                },
                onDiscard: { showSummary = false; viewModel.reset() }
            )
        }
    }

    // MARK: - 뮤직 카드

    private let dummyMusicCards: [(title: String, artist: String)] = [
        ("음악 선택", "Apple Music"),
        ("Running Playlist", "Apple Music"),
        ("Workout Mix", "Apple Music"),
        ("Energy Boost", "Apple Music"),
        ("Top Hits", "Apple Music"),
    ]

    private var musicScrollSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if musicVM.isLoading {
                    ForEach(0..<5, id: \.self) { _ in musicCardSkeleton }
                } else if musicVM.recentSongs.isEmpty {
                    ForEach(dummyMusicCards, id: \.title) { card in
                        dummyMusicCard(title: card.title, artist: card.artist)
                    }
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
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func dummyMusicCard(title: String, artist: String) -> some View {
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
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                    Text(artist)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                }
                .frame(width: 100, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
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
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 러닝 중 스탯 오버레이

    private var runningStatsOverlay: some View {
        VStack(spacing: 0) {
            // 시간 (크게, 중앙)
            VStack(spacing: 2) {
                Text(viewModel.formattedTime)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)
                Text("시간")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider().opacity(0.3).padding(.horizontal, 24)

            // km / 페이스
            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text(viewModel.formattedDistance)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.textPrimary)
                    Text("km")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 40).opacity(0.3)

                VStack(spacing: 2) {
                    Text(viewModel.formattedPace)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.textPrimary)
                    Text("페이스")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 16)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 16)
    }

    // MARK: - 하단 컨트롤

    private var controlSection: some View {
        VStack(spacing: 20) {
            switch viewModel.state {
            case .idle:
                idleControls
            case .running:
                runningControls
            case .paused:
                pausedControls
            case .finished:
                EmptyView()
            }
        }
    }

    // idle: 음악 + 시작 + 주변
    private var idleControls: some View {
        HStack(spacing: 40) {
            sideButton(icon: "music.note", label: "음악") { showMusicSheet = true }

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                startCountdown()
            } label: {
                Text("시작")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 96, height: 96)
                    .background(Color.main500)
                    .clipShape(Circle())
            }
            .disabled(countdown != nil)

            sideButton(icon: "person.2.fill", label: "주변") { }
        }
    }

    // running: 좌(음악) + 정지(크게) + 우(주변) → 정지 탭 시 종료/재시작
    private var runningControls: some View {
        Group {
            if showStopConfirm {
                // 종료 (꾹 눌러야) / 다시 시작
                HStack(spacing: 24) {
                    // 종료 — 1초 꾹 누르기
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 4)
                            .frame(width: 80, height: 80)
                        Circle()
                            .trim(from: 0, to: stopHoldProgress)
                            .stroke(Color(white: 0.2), lineWidth: 4)
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.05), value: stopHoldProgress)

                        Image(systemName: "stop.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 80, height: 80)
                            .background(Color.black.opacity(0.85))
                            .clipShape(Circle())
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in startStopHold() }
                            .onEnded { _ in cancelStopHold() }
                    )

                    // 다시 시작
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showStopConfirm = false
                        viewModel.resume()
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 80, height: 80)
                            .background(Color.main500)
                            .clipShape(Circle())
                    }
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                // 좌(음악) + 정지(크게) + 우(주변)
                HStack(spacing: 32) {
                    sideButton(icon: "music.note", label: "음악") {
                        showMusicSheet = true
                    }

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        viewModel.pause()
                        showStopConfirm = true
                    } label: {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 100, height: 100)
                            .background(Color.main500)
                            .clipShape(Circle())
                    }

                    sideButton(icon: "person.2.fill", label: "주변") { }
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: showStopConfirm)
    }

    // paused: 이어서 / 종료 선택
    private var pausedControls: some View {
        HStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 4)
                    .frame(width: 80, height: 80)
                Circle()
                    .trim(from: 0, to: stopHoldProgress)
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.05), value: stopHoldProgress)

                Image(systemName: "stop.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 80, height: 80)
                    .background(Color.black.opacity(0.85))
                    .clipShape(Circle())
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in startStopHold() }
                    .onEnded { _ in cancelStopHold() }
            )

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showStopConfirm = false
                viewModel.resume()
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 80, height: 80)
                    .background(Color.main500)
                    .clipShape(Circle())
            }
        }
    }

    private func sideButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 52, height: 52)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }

    // MARK: - 종료 꾹 누르기

    private func startStopHold() {
        guard stopHoldTimer == nil else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        stopHoldTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            Task { @MainActor in
                stopHoldProgress += 0.05
                // 0.2마다 진동 — 충전 느낌
                if Int(stopHoldProgress * 20) % 4 == 0 {
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                }
                if stopHoldProgress >= 1.0 {
                    stopHoldTimer?.invalidate()
                    stopHoldTimer = nil
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    viewModel.stop()
                    showSummary = true
                    showStopConfirm = false
                    stopHoldProgress = 0
                }
            }
        }
    }

    private func cancelStopHold() {
        stopHoldTimer?.invalidate()
        stopHoldTimer = nil
        withAnimation(.easeOut(duration: 0.2)) { stopHoldProgress = 0 }
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
        Task {
            for i in stride(from: 3, through: 1, by: -1) {
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.2)) { countdown = i }
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) { countdown = nil }
                viewModel.start()
            }
        }
    }
}
