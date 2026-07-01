import SwiftUI
import MapKit
import Combine
import MusicKit
import MediaPlayer
import FirebaseAuth

struct RunningView: View {
    @StateObject private var viewModel = RunningViewModel()
    @StateObject private var musicVM = RunningMusicViewModel()
    @StateObject private var nearbyVM = NearbyRunnerViewModel()
    @StateObject private var listenVM = ListenTogetherViewModel()
    @State private var showSummary = false
    @State private var showMusicSheet = false
    @State private var showNearbySheet = false
    @State private var countdown: Int? = nil
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var showStopConfirm = false   // 정지 후 종료/재시작 버튼 표시
    @State private var stopHoldProgress: CGFloat = 0
    @State private var stopHoldTimer: Timer? = nil
    @State private var collapsedPinIDs: Set<String> = []
    @State private var mapZoomDistance: Double = 400
    @State private var isFollowingUser: Bool = true      // 내 위치 자동 추적
    @State private var isProgrammaticMove: Bool = false  // 코드 카메라 이동 플래그
    @State private var showListenSheet = false
    @State private var showPlaylistInSheet = false   // 음악 시트 내 플레이리스트 토글
    @State private var isSeeking = false             // 스크러버 드래그 중
    @State private var seekValue: Double = 0         // 드래그 중 임시 시간값

    var body: some View {
        ZStack {
            // 풀스크린 지도
            Map(position: $cameraPosition, interactionModes: [.pan, .zoom]) {
                if viewModel.locationManager.routeCoordinates.count >= 2 {
                    MapPolyline(coordinates: viewModel.locationManager.routeCoordinates)
                        .stroke(
                            LinearGradient(
                                colors: [Color.main500, Color(red: 0.18, green: 0.46, blue: 1.0)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 5
                        )
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

            // 맵 버튼 오버레이
            VStack {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        if viewModel.state == .idle {
                            // idle: 줌 +/-  +  내 위치
                            Button {
                                let newDist = max(100, mapZoomDistance / 1.5)
                                mapZoomDistance = newDist
                                recenterCamera(distance: newDist)
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.textPrimary)
                                    .frame(width: 40, height: 40)
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            Button {
                                let newDist = min(3000, mapZoomDistance * 1.5)
                                mapZoomDistance = newDist
                                recenterCamera(distance: newDist)
                            } label: {
                                Image(systemName: "minus")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.textPrimary)
                                    .frame(width: 40, height: 40)
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            Button {
                                isFollowingUser = true
                                recenterCamera(distance: mapZoomDistance)
                            } label: {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.main500)
                                    .frame(width: 40, height: 40)
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        } else {
                            // 러닝 중: 항상 내 위치 버튼 표시 (추적 중이면 파란색)
                            Button {
                                isFollowingUser = true
                                recenterCamera(distance: mapZoomDistance)
                            } label: {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(isFollowingUser ? Color.main500 : Color.textPrimary)
                                    .frame(width: 40, height: 40)
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                    .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                    .padding(.trailing, 16)
                    .padding(.top, 220)
                    .animation(.spring(duration: 0.3), value: viewModel.state)
                    .animation(.spring(duration: 0.3), value: isFollowingUser)
                }
                Spacer()
            }

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

            // 수신 요청 배너 (항상 최상단)
            if let request = listenVM.incomingRequest {
                VStack {
                    incomingRequestBanner(session: request)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .top)
                                    .combined(with: .opacity)
                                    .combined(with: .scale(scale: 0.96, anchor: .top)),
                                removal: .opacity.combined(with: .move(edge: .top))
                            )
                        )
                    Spacer()
                }
                .animation(.spring(response: 0.42, dampingFraction: 0.86), value: listenVM.incomingRequest?.id)
                .zIndex(10)
            }

            // 같이 듣기 플로팅 버튼 (세션 활성 시 항상 표시)
            if let session = listenVM.activeSession, session.status == "active" {
                VStack {
                    HStack {
                        Spacer()
                        Button { showListenSheet = true } label: {
                            ZStack(alignment: .topTrailing) {
                                ZStack {
                                    Circle()
                                        .fill(Color.main500)
                                        .frame(width: 48, height: 48)
                                        .shadow(color: Color.main500.opacity(0.4), radius: 8, y: 4)
                                    Image(systemName: "music.note")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                                // 인원 배지
                                ZStack {
                                    Circle().fill(Color.white).frame(width: 20, height: 20)
                                    Text("2")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Color.main500)
                                }
                                .offset(x: 4, y: -4)
                            }
                        }
                        .padding(.trailing, 16)
                    }
                    .padding(.top, 6)
                    Spacer()
                }
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(duration: 0.4), value: session.id)
                .zIndex(11)
            }

            // 카운트다운 풀스크린 오버레이 (같이 듣기 버튼 zIndex 11보다 위)
            if let cd = countdown {
                ZStack {
                    Color.black.opacity(0.85)
                        .ignoresSafeArea()
                    Text("\(cd)")
                        .font(.system(size: 160, weight: .black))
                        .foregroundStyle(Color.main500)
                        .transition(.scale(scale: 1.4).combined(with: .opacity))
                        .id(cd)
                }
                .zIndex(20)
            }
        }
        .onReceive(viewModel.locationManager.$currentLocation.compactMap { $0 }) { loc in
            if (viewModel.state == .running || viewModel.state == .paused) && isFollowingUser {
                recenterCamera(distance: mapZoomDistance)
            }
        }
        .onMapCameraChange(frequency: .continuous) { context in
            guard !isProgrammaticMove else { return }
            mapZoomDistance = min(max(context.camera.distance, 100), 3000)
            isFollowingUser = false
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            guard !isProgrammaticMove else { return }
            let dist = context.camera.distance
            mapZoomDistance = min(max(dist, 100), 3000)
            guard dist > 3000 || dist < 100 else { return }
            let clamped = min(max(dist, 100), 3000)
            let center = viewModel.locationManager.currentLocation?.coordinate
                ?? context.camera.centerCoordinate
            // 관성 이동이 완전히 끝난 뒤 스냅백 (즉시 덮어쓰면 충돌)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                isProgrammaticMove = true
                withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
                    cameraPosition = .camera(MapCamera(centerCoordinate: center, distance: clamped))
                }
                isFollowingUser = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    isProgrammaticMove = false
                }
            }
        }
        .task { await musicVM.requestAuthorization() }
        .onAppear {
            viewModel.musicViewModel = musicVM
            startAppBroadcast()
            listenVM.startObservingRequests()
        }
        .onDisappear {
            if let uid = Auth.auth().currentUser?.uid {
                RealtimeDBService.shared.stopBroadcast(uid: uid)
            }
            nearbyVM.stopObserving()
            listenVM.stopObservingRequests()
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
            // 곡 바뀌면 즉시 브로드캐스트
            if let uid = Auth.auth().currentUser?.uid {
                let nickname = UserDefaults.standard.string(forKey: "nickname") ?? "러너"
                RealtimeDBService.shared.startBroadcast(uid: uid, nickname: nickname) {
                    self.viewModel.locationManager.currentLocation?.coordinate
                } songProvider: {
                    (self.musicVM.currentSong?.title ?? "", self.musicVM.currentSong?.artistName ?? "")
                }
            }
            // 호스트면 세션에도 브로드캐스트
            listenVM.broadcastIfHost(musicVM: musicVM)
        }
        .preferredColorScheme(.light)
        .sheet(isPresented: $showMusicSheet) { musicSheet }
        .sheet(isPresented: $showNearbySheet) { nearbySheet }
        .sheet(isPresented: $showListenSheet) { listenSheet }
        .fullScreenCover(isPresented: $showSummary) {
            RunSummaryView(
                distance: viewModel.distance,
                elapsedSeconds: viewModel.elapsedSeconds,
                avgPace: viewModel.avgPace,
                routeCoordinates: viewModel.locationManager.routeCoordinates,
                onSave: {
                    let savedDistance = viewModel.distance
                    let savedElapsedSeconds = viewModel.elapsedSeconds
                    let savedAveragePace = viewModel.avgPace
                    let savedRouteCoordinates = viewModel.locationManager.routeCoordinates
                    Task {
                        await viewModel.saveRecord(
                            distance: savedDistance,
                            elapsedSeconds: savedElapsedSeconds,
                            avgPace: savedAveragePace,
                            routeCoordinates: savedRouteCoordinates
                        )
                    }
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
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 0) {
                        // MARK: 앨범 커버
                        let artSize: CGFloat = 260
                        let fallbackArtwork = musicVM.nowPlayingSnapshot?.artwork
                        Group {
                            if musicVM.queueSongs.isEmpty, let fallbackArtwork {
                                Image(uiImage: fallbackArtwork)
                                    .resizable()
                                    .scaledToFill()
                                    .clipShape(RoundedRectangle(cornerRadius: 24))
                                    .frame(width: artSize, height: artSize)
                            } else if musicVM.queueSongs.isEmpty {
                                artworkPlaceholder
                                    .frame(width: artSize, height: artSize)
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
                                                ArtworkImage(artwork, width: artSize, height: artSize)
                                                    .clipShape(RoundedRectangle(cornerRadius: 24))
                                            } else {
                                                artworkPlaceholder
                                            }
                                        }
                                        .frame(width: artSize, height: artSize)
                                        .tag(idx)
                                    }
                                }
                                .tabViewStyle(.page(indexDisplayMode: .never))
                                .frame(width: artSize, height: artSize)
                            }
                        }
                        .scaleEffect(musicVM.isPlaying ? 1.0 : 0.88)
                        .shadow(color: .black.opacity(musicVM.isPlaying ? 0.3 : 0.15), radius: musicVM.isPlaying ? 20 : 10, y: 8)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: musicVM.isPlaying)
                        .padding(.top, 28)
                        .padding(.bottom, 28)

                        // MARK: 곡 정보
                        let insertEdge: Edge = musicVM.isGoingForward ? .trailing : .leading
                        let removeEdge: Edge = musicVM.isGoingForward ? .leading : .trailing
                        VStack(alignment: .leading, spacing: 4) {
                            Text(musicVM.displaySongTitle)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .id(musicVM.currentSong?.id.rawValue ?? musicVM.nowPlayingSnapshot?.songStoreID)
                                .transition(.asymmetric(
                                    insertion: .move(edge: insertEdge).combined(with: .opacity),
                                    removal: .move(edge: removeEdge).combined(with: .opacity)
                                ))
                            Text(musicVM.displayArtistName)
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .id(musicVM.displayArtistName)
                                .transition(.asymmetric(
                                    insertion: .move(edge: insertEdge).combined(with: .opacity),
                                    removal: .move(edge: removeEdge).combined(with: .opacity)
                                ))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .animation(.easeInOut(duration: 0.25), value: musicVM.currentSong?.id)
                        .padding(.horizontal, 28)

                        // MARK: 스크러버
                        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                            let duration = musicVM.playbackDuration
                            let current: Double = isSeeking
                                ? seekValue
                                : (duration > 0 ? min(musicVM.currentPlaybackTime, duration) : 0)
                            let progress: Double = duration > 0 ? current / duration : 0

                            VStack(spacing: 4) {
                                Slider(
                                    value: Binding(
                                        get: { progress },
                                        set: { val in
                                            isSeeking = true
                                            seekValue = val * duration
                                        }
                                    ),
                                    in: 0...1,
                                    onEditingChanged: { editing in
                                        if !editing {
                                            musicVM.seek(to: seekValue)
                                            isSeeking = false
                                        }
                                    }
                                )
                                .tint(Color.main500)

                                HStack {
                                    Text(formatPlaybackTime(current))
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(duration > 0 ? "-\(formatPlaybackTime(max(0, duration - current)))" : "-0:00")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 28)
                            .padding(.top, 16)
                        }

                        // MARK: 재생 컨트롤
                        HStack(spacing: 52) {
                            Button {
                                Task { await musicVM.skipToPrevious() }
                            } label: {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: 30))
                                    .foregroundStyle(.primary)
                            }

                            Button {
                                Task { await musicVM.togglePlayPause() }
                            } label: {
                                Image(systemName: musicVM.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 68))
                                    .foregroundStyle(Color.main500)
                            }

                            Button {
                                Task { await musicVM.skipToNext() }
                            } label: {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 30))
                                    .foregroundStyle(.primary)
                            }
                        }
                        .padding(.top, 20)

                        // MARK: 음량 슬라이더
                        HStack(alignment: .center, spacing: 10) {
                            Image(systemName: "speaker.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .frame(width: 16)
                            VolumeSliderView()
                                .frame(height: 28)
                                .offset(y: 5)
                            Image(systemName: "speaker.wave.3.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .frame(width: 18)
                        }
                        .padding(.horizontal, 28)
                        .padding(.top, 48)

                        // 하단 플레이리스트 버튼 공간 확보
                        Color.clear.frame(height: 80)
                    }
                }
                .scrollIndicators(.hidden)

                // MARK: 플레이리스트 토글 버튼 (하단 고정)
                VStack(spacing: 0) {
                    // 플레이리스트 섹션 (토글 시 슬라이드업)
                    if showPlaylistInSheet {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("내 플레이리스트")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Button {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        showPlaylistInSheet = false
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(Color(.systemGray3))
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 16)

                            if musicVM.isLoading {
                                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 16)
                            } else if musicVM.playlists.isEmpty {
                                Text("플레이리스트가 없어요")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 14) {
                                        ForEach(musicVM.playlists, id: \.id) { playlist in
                                            Button {
                                                Task { await musicVM.play(playlist: playlist) }
                                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                                    showPlaylistInSheet = false
                                                }
                                            } label: {
                                                VStack(spacing: 8) {
                                                    Group {
                                                        if let artwork = playlist.artwork {
                                                            ArtworkImage(artwork, width: 88, height: 88)
                                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                                        } else {
                                                            ZStack {
                                                                RoundedRectangle(cornerRadius: 12)
                                                                    .fill(Color(.systemGray5))
                                                                    .frame(width: 88, height: 88)
                                                                Image(systemName: "music.note.list")
                                                                    .font(.system(size: 24))
                                                                    .foregroundStyle(Color.main500)
                                                            }
                                                        }
                                                    }
                                                    .frame(width: 88, height: 88)
                                                    .shadow(color: .black.opacity(0.12), radius: 4, y: 2)

                                                    Text(playlist.name)
                                                        .font(.system(size: 11, weight: .medium))
                                                        .foregroundStyle(.primary)
                                                        .lineLimit(1)
                                                        .frame(width: 88)
                                                }
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                            Spacer().frame(height: 8)
                        }
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.1), radius: 10, y: -4)
                        .padding(.horizontal, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // 글래스 버튼
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showPlaylistInSheet.toggle()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 15, weight: .semibold))
                            Text("플레이리스트")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(showPlaylistInSheet ? Color.main500 : .primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(showPlaylistInSheet ? Color.main500.opacity(0.4) : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    .shadow(color: .black.opacity(0.08), radius: 8, y: -2)
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showPlaylistInSheet)
            }
            .navigationTitle("음악")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                musicVM.syncCurrentState()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("완료") {
                        showMusicSheet = false
                        showPlaylistInSheet = false
                    }
                    .foregroundStyle(Color.main500)
                }
            }
            // 곡이 바뀌면 스크러버 초기화 (드래그 잔상 방지)
            .onChange(of: musicVM.currentSong?.id) { _, _ in
                isSeeking = false
                seekValue = 0
            }
        }
        .presentationBackground(.ultraThinMaterial)
    }

    private func formatPlaybackTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let s = Int(seconds)
        return "\(s / 60):\(String(format: "%02d", s % 60))"
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

    // MARK: - 같이 듣기 배너

    private func incomingRequestBanner(session: ListenSession) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(Color.main500).frame(width: 36, height: 36)
                    Text(String(session.hostNickname.prefix(1)))
                        .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("같이 듣기 요청")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.main500)
                    Text("\(session.hostNickname)님이 함께 듣고 싶어해요")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                    if !session.songTitle.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "music.note")
                                .font(.system(size: 11)).foregroundStyle(Color.main500)
                            Text("\(session.songTitle) - \(session.artistName)")
                                .font(.system(size: 12)).foregroundStyle(Color.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer()
            }
            HStack(spacing: 10) {
                Button {
                    Task { await listenVM.acceptRequest(musicVM: musicVM) }
                } label: {
                    Label("수락", systemImage: "checkmark")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 36)
                        .background(Color.main500).clipShape(RoundedRectangle(cornerRadius: 10))
                }
                Button {
                    listenVM.declineRequest()
                } label: {
                    Label("거절", systemImage: "xmark")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.textSecondary)
                        .frame(maxWidth: .infinity).frame(height: 36)
                        .background(Color(.systemGray5)).clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.14), radius: 16, y: 8)
        .padding(.horizontal, 16)
        .padding(.top, 56)
    }

    // MARK: - 같이 듣기 시트
    private var listenSheet: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
            VStack(spacing: 0) {
                if let session = listenVM.activeSession {
                    let myUID = Auth.auth().currentUser?.uid ?? ""
                    let partnerName = session.hostUID == myUID ? session.guestNickname : session.hostNickname
                    let myName = session.hostUID == myUID ? session.hostNickname : session.guestNickname
                    let listenDuration = listenVM.sessionStartDate.map { Int(timeline.date.timeIntervalSince($0)) } ?? 0

                    VStack(spacing: 20) {
                        listenAlbumHeader(session: session)
                            .padding(.top, 16)

                        // 참여자 카드 목록
                        ScrollView {
                            VStack(spacing: 6) {
                                listenParticipantCard(
                                    name: myName,
                                    isMe: true,
                                    role: listenVM.isHost ? "호스트" : "게스트",
                                    song: session.songTitle,
                                    artist: session.artistName,
                                    duration: listenDuration
                                )
                                listenParticipantCard(
                                    name: partnerName,
                                    isMe: false,
                                    role: listenVM.isHost ? "게스트" : "호스트",
                                    song: session.songTitle,
                                    artist: session.artistName,
                                    duration: listenDuration
                                )
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 4)
                        }

                        Spacer()

                        // 종료 버튼
                        Button {
                            listenVM.endSession()
                            showListenSheet = false
                        } label: {
                            Text("같이 듣기 종료")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color.main500)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                    }
                } else {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("같이 듣기 세션이 없어요")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            .navigationTitle("같이 듣기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("완료") { showListenSheet = false }
                        .foregroundStyle(Color.main500)
                }
            }
            } // TimelineView
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(.systemBackground))
        .preferredColorScheme(.light)
    }

    private func listenParticipantCard(name: String, isMe: Bool, role: String, song: String, artist: String, duration: Int) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(isMe ? Color.main500 : Color.main500.opacity(0.12))
                    .frame(width: 42, height: 42)
                Text(String(name.prefix(1)))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(isMe ? .white : Color.main500)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(role)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isMe ? Color.main500 : Color.textSecondary)
                }
                if !song.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "music.note")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.main500)
                        Text(artist.isEmpty ? song : "\(song) - \(artist)")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(1)
                    }
                }
                // 함께 들은 시간
                let mins = duration / 60
                let secs = duration % 60
                Text(mins > 0 ? "\(mins)분 \(secs)초 함께 들음" : "\(secs)초 함께 들음")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(.tertiaryLabel))
            }

            Spacer()
        }
        .padding(.vertical, 10)
    }

    private func listenAlbumHeader(session: ListenSession) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            listenArtwork(session: session)
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(alignment: .leading, spacing: 8) {
                Text(session.songTitle.isEmpty ? "재생 중인 곡" : session.songTitle)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(2)
                Text(session.artistName.isEmpty ? "Apple Music" : session.artistName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
                Rectangle()
                    .fill(Color.gray300.opacity(0.55))
                    .frame(height: 1)
                    .padding(.top, 10)
            }
            .padding(.horizontal, 24)
        }
    }

    @ViewBuilder
    private func listenArtwork(session: ListenSession) -> some View {
        let size: CGFloat = 220
        if let url = URL(string: session.artworkURL), !session.artworkURL.isEmpty {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    listenArtworkPlaceholder
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.16), radius: 18, y: 10)
        } else {
            listenArtworkPlaceholder
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: .black.opacity(0.12), radius: 14, y: 8)
        }
    }

    private var listenArtworkPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.main500.opacity(0.12))
            Image(systemName: "music.note")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(Color.main500)
        }
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

            // 같이 듣기 버튼
            Button {
                showNearbySheet = false
                listenVM.sendRequest(to: runner, musicVM: musicVM)
            } label: {
                Text(listenVM.activeSession != nil ? "듣는 중" : "같이 듣기")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(listenVM.activeSession != nil ? Color.textSecondary : Color.main500)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(listenVM.activeSession != nil ? Color.gray300 : Color.main500, lineWidth: 1)
                    )
            }
            .disabled(listenVM.activeSession != nil)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - 카메라

    private func recenterCamera(distance: Double) {
        guard let coord = viewModel.locationManager.currentLocation?.coordinate else { return }
        isProgrammaticMove = true
        withAnimation(.interpolatingSpring(stiffness: 40, damping: 12)) {
            cameraPosition = .camera(MapCamera(centerCoordinate: coord, distance: distance))
        }
        // 애니메이션 완료 후 플래그 해제 (0.6초면 충분)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            isProgrammaticMove = false
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

// MARK: - MPVolumeView 래퍼
private struct VolumeSliderView: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let v = MPVolumeView(frame: .zero)
        v.showsRouteButton = false
        v.showsVolumeSlider = true
        v.setVolumeThumbImage(UIImage(), for: .normal) // 기본 thumb 제거 후 재설정
        // 트랙 컬러
        v.tintColor = UIColor(Color.main500)
        // 커스텀 thumb (작은 흰 원, 그림자)
        let size = CGSize(width: 16, height: 16)
        let renderer = UIGraphicsImageRenderer(size: size)
        let thumb = renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1)
            ctx.cgContext.setShadow(offset: CGSize(width: 0, height: 1), blur: 2, color: UIColor.black.withAlphaComponent(0.25).cgColor)
            UIColor.white.setFill()
            ctx.cgContext.fillEllipse(in: rect)
        }
        v.setVolumeThumbImage(thumb, for: .normal)
        v.setVolumeThumbImage(thumb, for: .highlighted)
        return v
    }
    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
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
