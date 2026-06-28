import SwiftUI
import MapKit
import Combine
import MusicKit
import FirebaseAuth

struct RunningView: View {
    @StateObject private var viewModel = RunningViewModel()
    @StateObject private var musicVM = RunningMusicViewModel()
    @StateObject private var nearbyVM = NearbyRunnerViewModel()
    @State private var showSummary = false
    @State private var showMusicSheet = false
    @State private var showNearbySheet = false
    @State private var countdown: Int? = nil
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var showStopConfirm = false   // 정지 후 종료/재시작 버튼 표시
    @State private var stopHoldProgress: CGFloat = 0
    @State private var stopHoldTimer: Timer? = nil
    @State private var collapsedPinIDs: Set<String> = []

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
                // 주변 러너 핀
                ForEach(nearbyVM.nearbyRunners) { runner in
                    Annotation("", coordinate: runner.coordinate) {
                        runnerMapPin(runner: runner)
                    }
                }
            }
            .mapStyle(.standard)
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // 뮤직 카드: idle 상태에서만 표시
                if viewModel.state == .idle {
                    musicScrollSection
                        .padding(.top, 44)
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
        .onAppear {
            viewModel.musicViewModel = musicVM
            startAppBroadcast()
        }
        .onDisappear {
            if let uid = Auth.auth().currentUser?.uid {
                RealtimeDBService.shared.stopBroadcast(uid: uid)
            }
            nearbyVM.stopObserving()
        }
        .onReceive(viewModel.locationManager.$currentLocation.compactMap { $0 }) { loc in
            nearbyVM.updateMyLocation(loc.coordinate)
        }
        .onChange(of: viewModel.state) { _, newState in
            if newState == .finished {
                nearbyVM.stopObserving()
            }
        }
        .onChange(of: musicVM.currentSong) { _, _ in
            // 곡 바뀌면 즉시 업데이트
            if let uid = Auth.auth().currentUser?.uid {
                let nickname = UserDefaults.standard.string(forKey: "nickname") ?? "러너"
                RealtimeDBService.shared.startBroadcast(uid: uid, nickname: nickname) {
                    self.viewModel.locationManager.currentLocation?.coordinate
                } songProvider: {
                    (self.musicVM.currentSong?.title ?? "", self.musicVM.currentSong?.artistName ?? "")
                }
            }
        }
        .preferredColorScheme(.light)
        .sheet(isPresented: $showMusicSheet) { musicSheet }
        .sheet(isPresented: $showNearbySheet) { nearbySheet }
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
        VStack(alignment: .leading, spacing: 10) {
            Text("플레이리스트")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    if musicVM.isLoading {
                        ForEach(0..<5, id: \.self) { _ in musicCardSkeleton }
                    } else if musicVM.playlists.isEmpty {
                        ForEach(dummyMusicCards, id: \.title) { card in
                            dummyMusicCard(title: card.title, artist: card.artist)
                        }
                    } else {
                        ForEach(musicVM.playlists, id: \.id) { playlist in
                            playlistCardItem(playlist: playlist)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func playlistCardItem(playlist: Playlist) -> some View {
        Button {
            Task { await musicVM.play(playlist: playlist) }
            showMusicSheet = true
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(width: 44, height: 44)
                    if let artwork = playlist.artwork {
                        ArtworkImage(artwork, width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.main500)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(playlist.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                    Text("플레이리스트")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textSecondary)
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

            sideButton(icon: "person.2.fill", label: "주변") { showNearbySheet = true }
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

                    sideButton(icon: "person.2.fill", label: "주변") { showNearbySheet = true }
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
            ZStack {
                Color.clear

                VStack(spacing: 0) {
                    // 앨범 커버
                    if musicVM.queueSongs.isEmpty {
                        artworkPlaceholder
                            .frame(width: 220, height: 220)
                            .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
                            .padding(.top, 36)
                            .padding(.bottom, 28)
                    } else {
                        TabView(selection: Binding(
                            get: { musicVM.currentSongIndex },
                            set: { newIndex in
                                musicVM.isGoingForward = newIndex > musicVM.currentSongIndex
                                musicVM.currentSongIndex = newIndex
                                Task { await musicVM.play(at: newIndex) }
                            }
                        )) {
                            ForEach(musicVM.queueSongs.indices, id: \.self) { idx in
                                let song = musicVM.queueSongs[idx]
                                Group {
                                    if let artwork = song.artwork {
                                        ArtworkImage(artwork, width: 220, height: 220)
                                            .clipShape(RoundedRectangle(cornerRadius: 20))
                                    } else {
                                        artworkPlaceholder
                                    }
                                }
                                .frame(width: 220, height: 220)
                                .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
                                .padding(.top, 12)
                                .padding(.bottom, 28)
                                .tag(idx)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .frame(height: 276)
                        .padding(.top, 24)
                    }

                    // 곡 정보
                    let insertEdge: Edge = musicVM.isGoingForward ? .trailing : .leading
                    let removeEdge: Edge = musicVM.isGoingForward ? .leading : .trailing
                    VStack(spacing: 6) {
                        Text(musicVM.currentSong?.title ?? "플레이리스트를 선택하세요")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .id(musicVM.currentSong?.id)
                            .transition(.asymmetric(
                                insertion: .move(edge: insertEdge).combined(with: .opacity),
                                removal: .move(edge: removeEdge).combined(with: .opacity)
                            ))
                        Text(musicVM.currentSong?.artistName ?? "Apple Music")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .id(musicVM.currentSong?.artistName)
                            .transition(.asymmetric(
                                insertion: .move(edge: insertEdge).combined(with: .opacity),
                                removal: .move(edge: removeEdge).combined(with: .opacity)
                            ))
                    }
                    .animation(.easeInOut(duration: 0.25), value: musicVM.currentSong?.id)
                    .padding(.horizontal, 32)

                    // 재생 컨트롤
                    HStack(spacing: 48) {
                        Button {
                            Task { await musicVM.skipToPrevious() }
                        } label: {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.primary)
                        }

                        Button {
                            Task { await musicVM.togglePlayPause() }
                        } label: {
                            Image(systemName: musicVM.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 64))
                                .foregroundStyle(Color.main500)
                        }

                        Button {
                            Task { await musicVM.skipToNext() }
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.primary)
                        }
                    }
                    .padding(.top, 28)

                    // 플레이리스트 섹션
                    VStack(alignment: .leading, spacing: 12) {
                        Text("내 플레이리스트")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 24)

                        if musicVM.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                        } else if musicVM.playlists.isEmpty {
                            Text("플레이리스트가 없어요")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(musicVM.playlists, id: \.id) { playlist in
                                        Button {
                                            Task { await musicVM.play(playlist: playlist) }
                                        } label: {
                                            VStack(spacing: 8) {
                                                Group {
                                                    if let artwork = playlist.artwork {
                                                        ArtworkImage(artwork, width: 100, height: 100)
                                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                                    } else {
                                                        ZStack {
                                                            RoundedRectangle(cornerRadius: 12)
                                                                .fill(.ultraThinMaterial)
                                                                .frame(width: 100, height: 100)
                                                            Image(systemName: "music.note.list")
                                                                .font(.system(size: 28))
                                                                .foregroundStyle(Color.main500)
                                                        }
                                                    }
                                                }
                                                .frame(width: 100, height: 100)
                                                .shadow(color: .black.opacity(0.15), radius: 6, y: 3)

                                                Text(playlist.name)
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundStyle(.primary)
                                                    .lineLimit(1)
                                                    .frame(width: 100)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                    }
                    .padding(.top, 32)

                    Spacer()
                }
            }
            .navigationTitle("음악")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("완료") { showMusicSheet = false }
                        .foregroundStyle(Color.main500)
                }
            }
        }
        .presentationBackground(.ultraThinMaterial)
    }

    private var artworkPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .frame(width: 220, height: 220)
            Image(systemName: "music.note")
                .font(.system(size: 60))
                .foregroundStyle(Color.main500)
        }
    }

    // MARK: - 러너 맵 핀 카드뷰

    @ViewBuilder
    private func runnerMapPin(runner: NearbyRunner) -> some View {
        let isCollapsed = collapsedPinIDs.contains(runner.id)
        let avatarColor: Color = runner.isMe ? Color.main500 : Color(.systemGray3)
        let cardBg: Color = runner.isMe ? Color.main500.opacity(0.12) : Color.clear
        let nameColor: Color = runner.isMe ? Color.main500 : Color(.label)

        Button {
            collapsedPinIDs.formSymmetricDifference([runner.id])
        } label: {
            VStack(spacing: 0) {

                // ── 풀 카드 (펼쳐진 상태) ──
                VStack(spacing: 0) {
                    HStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(avatarColor)
                                .frame(width: 26, height: 26)
                            Text(String(runner.nickname.prefix(1)))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        HStack(alignment: .top, spacing: 4) {
                            if !runner.songTitle.isEmpty {
                                Image(systemName: "music.note")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color.main500)
                                    .padding(.top, 16)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(runner.nickname)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(nameColor)
                                    .lineLimit(1)
                                if !runner.songTitle.isEmpty {
                                    Text(runner.songTitle)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color(.label))
                                        .lineLimit(1)
                                    if !runner.artist.isEmpty {
                                        Text(runner.artist)
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color(.secondaryLabel))
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground))
                            RoundedRectangle(cornerRadius: 12).fill(cardBg)
                        }
                        .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                    )
                    Triangle()
                        .fill(Color(.systemBackground))
                        .frame(width: 10, height: 6)
                }
                .scaleEffect(isCollapsed ? 0.1 : 1, anchor: .bottom)
                .opacity(isCollapsed ? 0 : 1)
                .animation(.easeInOut(duration: 0.4), value: isCollapsed)

                // ── 아바타 + 말풍선 뱃지 (항상 표시) ──
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(avatarColor)
                        .frame(width: 34, height: 34)
                        .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
                    Text(String(runner.nickname.prefix(1)))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)

                    // 음표 뱃지 (접힌 상태 + 노래 있을 때만)
                    if !runner.songTitle.isEmpty {
                        ZStack {
                            Circle()
                                .fill(Color(.systemBackground))
                                .frame(width: 18, height: 18)
                            Image(systemName: "music.note")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Color.main500)
                        }
                        .offset(x: 4, y: -4)
                        .scaleEffect(isCollapsed ? 1 : 0.1)
                        .opacity(isCollapsed ? 1 : 0)
                        .animation(.easeInOut(duration: 0.4), value: isCollapsed)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 앱 레벨 브로드캐스트

    private func startAppBroadcast() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let nickname = UserDefaults.standard.string(forKey: "nickname") ?? "러너"
        RealtimeDBService.shared.startBroadcast(uid: uid, nickname: nickname) { [self] in
            self.viewModel.locationManager.currentLocation?.coordinate
        } songProvider: { [self] in
            (self.musicVM.currentSong?.title ?? "", self.musicVM.currentSong?.artistName ?? "")
        }
        nearbyVM.startObserving(uid: uid)
    }

    // MARK: - 주변 러너 시트

    private var nearbySheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 필터 피커
                Picker("필터", selection: Binding(
                    get: { nearbyVM.selectedFilter },
                    set: { nearbyVM.changeFilter($0) }
                )) {
                    ForEach(RunnerFilter.allCases, id: \.self) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                Divider()

                if nearbyVM.nearbyRunners.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: nearbyVM.selectedFilter == .friends ? "person.2.slash" : "figure.run")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text(nearbyVM.selectedFilter == .friends ? "친구가 없어요" : "주변에 러너가 없어요")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                        Text(nearbyVM.selectedFilter == .friends ? "친구를 추가하면 여기서 볼 수 있어요" : "1km 반경 내 러닝 중인 사람이 없어요")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(nearbyVM.nearbyRunners) { runner in
                                nearbyRunnerCard(runner: runner)
                                Divider().padding(.leading, 72)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .navigationTitle("주변 러너")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("완료") { showNearbySheet = false }
                        .foregroundStyle(Color.main500)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(.systemBackground))
        .preferredColorScheme(.light)
    }

    private func nearbyRunnerCard(runner: NearbyRunner) -> some View {
        HStack(spacing: 14) {
            // 아바타
            ZStack {
                Circle()
                    .fill(Color.main500)
                    .frame(width: 44, height: 44)
                Text(String(runner.nickname.prefix(1)))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(runner.nickname)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)

                if !runner.songTitle.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "music.note")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.main500)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(runner.songTitle)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            if !runner.artist.isEmpty {
                                Text(runner.artist)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }

                Text(nearbyVM.formattedDistance(runner))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // 같이 듣기 버튼 (feat #08 예약)
            Button {
                // feat #08에서 구현
            } label: {
                Text("같이 듣기")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.main500)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.main500, lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
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

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
