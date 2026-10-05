import AVFoundation
import CoreLocation
import SwiftUI
import UIKit
import Combine

enum RunShareTemplate: String, CaseIterable, Identifiable {
    case distance
    case summary
    case route

    var id: String { rawValue }

    var title: String {
        switch self {
        case .distance: "거리"
        case .summary: "기록"
        case .route: "경로"
        }
    }

    var description: String {
        switch self {
        case .distance: "KM만 표시"
        case .summary: "시간 · KM · 평균 페이스"
        case .route: "KM · 경로 · 위치"
        }
    }
}

struct RunRecordShareTemplatePickerView: View {
    let record: RunRecord
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTemplate: RunShareTemplate = .distance
    @State private var presentsCamera = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("공유 양식 선택")
                        .font(.title2.bold())
                    Text("사진 위에 러닝 기록을 담아 공유해 보세요.")
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                }

                VStack(spacing: 12) {
                    ForEach(RunShareTemplate.allCases) { template in
                        Button {
                            selectedTemplate = template
                        } label: {
                            HStack(spacing: 16) {
                                RunShareTemplatePreview(template: template, record: record)
                                    .frame(width: 104, height: 132)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .allowsHitTesting(false)
                                VStack(alignment: .leading, spacing: 7) {
                                    Text(template.title)
                                        .font(.headline)
                                        .foregroundStyle(Color.textPrimary)
                                    Text(template.description)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.textSecondary)
                                        .lineLimit(2)
                                }
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .contentShape(Rectangle())
                            .background(Color.backgroundPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(selectedTemplate == template ? Color.main500 : Color.surfaceBorder, lineWidth: selectedTemplate == template ? 2 : 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(template.title) 양식, \(template.description)")
                        .accessibilityAddTraits(selectedTemplate == template ? .isSelected : [])
                    }
                }

                Spacer()

                Button {
                    presentsCamera = true
                } label: {
                    Label("카메라 열기", systemImage: "camera.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)
            }
            .padding(20)
            .background(Color.backgroundSecondary)
            .navigationTitle("러닝 기록 공유")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") { dismiss() }
                        .tint(.white)
                }
            }
            .fullScreenCover(isPresented: $presentsCamera) {
                RunRecordShareCameraView(record: record, template: selectedTemplate)
            }
        }
    }
}

private struct RunShareTemplatePreview: View {
    let template: RunShareTemplate
    let record: RunRecord

    var body: some View {
        GeometryReader { proxy in
            let previewCanvasWidth: CGFloat = 225
            let previewCanvasHeight: CGFloat = 400
            let previewScale = min(
                proxy.size.width / previewCanvasWidth,
                proxy.size.height / previewCanvasHeight
            )

            ZStack {
                Color.black.opacity(0.9)
                RunSharePhotoOverlay(record: record, template: template, mode: .preview)
                    .frame(width: previewCanvasWidth, height: previewCanvasHeight)
                    .scaleEffect(previewScale)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
    }
}

struct RunRecordShareCameraView: View {
    let record: RunRecord
    let template: RunShareTemplate
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = RunShareCameraController()
    @State private var capturedImage: UIImage?
    @State private var presentsShareSheet = false
    @State private var locationName = "위치 정보 확인 중"
    @State private var isCapturing = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()
                if let capturedImage {
                    Image(uiImage: capturedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                } else if camera.isAuthorized {
                    RunShareCameraPreview(session: camera.session)
                        .ignoresSafeArea()
                }

                if capturedImage == nil, camera.isAuthorized {
                    RunSharePhotoOverlay(record: record, template: template, locationName: locationName)
                        .allowsHitTesting(false)
                        .ignoresSafeArea()
                }

                controls(previewSize: proxy.size)
            }
        }
        .ignoresSafeArea()
        .task {
            camera.start()
            locationName = await RunShareLocationResolver.name(for: record.routeCoordinates.first)
        }
        .onDisappear { camera.stop() }
        .sheet(isPresented: $presentsShareSheet) {
            if let capturedImage {
                RunShareSheet(items: [capturedImage])
            }
        }
        .alert("카메라를 사용할 수 없어요", isPresented: $camera.showsPermissionAlert) {
            Button("확인", role: .cancel) { dismiss() }
        } message: {
            Text("설정에서 카메라 접근을 허용한 뒤 다시 시도해 주세요.")
        }
    }

    @ViewBuilder
    private func controls(previewSize: CGSize) -> some View {
        VStack {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.42), in: Circle())
                }
            }
            .padding(.trailing, 12)
            .padding(.top, 56)

            Spacer()

            if let capturedImage {
                HStack(spacing: 14) {
                    Button("다시 촬영") { self.capturedImage = nil }
                        .buttonStyle(.bordered)
                    Button {
                        presentsShareSheet = true
                    } label: {
                        Label("공유", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .tint(.white)
                .foregroundStyle(.black)
                .padding(.bottom, 34)
            } else if camera.isAuthorized {
                Button {
                    guard !isCapturing else { return }
                    isCapturing = true
                    camera.capture { photo in
                        capturedImage = RunShareImageComposer.compose(
                            photo: photo,
                            record: record,
                            template: template,
                            locationName: locationName,
                            previewSize: previewSize
                        )
                        isCapturing = false
                    }
                } label: {
                    Group {
                        if isCapturing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Circle()
                                .stroke(.white, lineWidth: 5)
                                .frame(width: 76, height: 76)
                                .overlay { Circle().fill(.white).padding(7) }
                        }
                    }
                    .frame(width: 76, height: 76)
                }
                .disabled(isCapturing)
                .accessibilityLabel("사진 촬영")
                .padding(.bottom, 34)
            }
        }
        .foregroundStyle(.white)
    }
}

private struct RunSharePhotoOverlay: View {
    let record: RunRecord
    let template: RunShareTemplate
    let locationName: String
    let mode: RunShareOverlayMode

    init(
        record: RunRecord,
        template: RunShareTemplate,
        locationName: String = "위치 정보",
        mode: RunShareOverlayMode = .camera
    ) {
        self.record = record
        self.template = template
        self.locationName = locationName
        self.mode = mode
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading) {
                Image("PacingShareLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(148, proxy.size.width * 0.34), height: 42)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .offset(x: mode == .preview ? -28 : -32)
                    .accessibilityHidden(true)
                Spacer()
                templateLayout
                .offset(x: mode == .preview ? -8 : 0)
            }
            .padding(.horizontal, mode == .preview ? 4 : 16)
            .padding(
                .top,
                mode == .preview
                    ? max(34, proxy.size.height * 0.05)
                    : max(78, proxy.size.height * 0.09)
            )
            .padding(.bottom, mode == .preview ? 12 : proxy.size.height * 0.09)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
        }
    }

    private var distanceLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(format: "%.1f", record.distance))
                .font(.system(size: mode == .preview ? 56 : 50, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.45)
                .lineLimit(1)
            Text("KM")
                .font(.system(size: mode == .preview ? 16 : 14, weight: .bold, design: .rounded))
                .tracking(1.5)
                .padding(.leading, 5)
        }
    }

    @ViewBuilder
    private var templateLayout: some View {
        switch template {
        case .distance:
            distanceLayout
        case .summary:
            summaryLayout
        case .route:
            routeLayout
        }
    }

    private var summaryLayout: some View {
        VStack(alignment: .leading, spacing: 18) {
            shareMetric(value: durationText, label: "시간")
            shareMetric(value: formattedDistance, label: "거리")
            shareMetric(value: RunRecord.formattedPace(record.displayPace), label: "평균 페이스")
        }
    }

    private var routeLayout: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text(formattedDistance)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.55)
                .lineLimit(1)
            RunShareRouteLine(coordinates: record.routeCoordinates)
                .stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .frame(width: 50, height: 60)
            VStack(alignment: .leading, spacing: 5) {
                Text("러닝 위치")
                    .font(.system(size: 12, weight: .bold))
                Text(locationName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)
            }
        }
    }

    private func shareMetric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.55)
                .lineLimit(1)
            Text(label)
                .font(.caption.bold())
                .lineLimit(mode == .preview ? 1 : nil)
                .minimumScaleFactor(mode == .preview ? 0.5 : 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var durationText: String {
        let hours = record.duration / 3_600
        let minutes = (record.duration % 3_600) / 60
        let seconds = record.duration % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, seconds) : String(format: "%d:%02d", minutes, seconds)
    }

    private var formattedDistance: String {
        String(format: "%.1fkm", record.distance)
    }

}

private enum RunShareOverlayMode {
    case camera
    case preview
}

private struct RunShareRouteLine: Shape {
    let coordinates: [CLLocationCoordinate2D]

    func path(in rect: CGRect) -> Path {
        let points: [CGPoint]
        if coordinates.count >= 2 {
            let latitudes = coordinates.map(\.latitude)
            let longitudes = coordinates.map(\.longitude)
            let minLat = latitudes.min() ?? 0, maxLat = latitudes.max() ?? 1
            let minLon = longitudes.min() ?? 0, maxLon = longitudes.max() ?? 1
            let latSpan = max(maxLat - minLat, 0.00001)
            let lonSpan = max(maxLon - minLon, 0.00001)
            points = coordinates.map {
                CGPoint(x: rect.minX + CGFloat(($0.longitude - minLon) / lonSpan) * rect.width,
                        y: rect.maxY - CGFloat(($0.latitude - minLat) / latSpan) * rect.height)
            }
        } else {
            points = [CGPoint(x: rect.width * 0.25, y: rect.height * 0.9), CGPoint(x: rect.width * 0.7, y: rect.height * 0.15), CGPoint(x: rect.width * 0.55, y: rect.height * 0.6)]
        }
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        points.dropFirst().forEach { path.addLine(to: $0) }
        return path
    }
}

@MainActor
private enum RunShareImageComposer {
    static func compose(
        photo: UIImage,
        record: RunRecord,
        template: RunShareTemplate,
        locationName: String,
        previewSize: CGSize
    ) -> UIImage {
        let overlay = RunSharePhotoOverlay(record: record, template: template, locationName: locationName)
            .frame(width: previewSize.width, height: previewSize.height)
        let imageRenderer = ImageRenderer(content: overlay)
        let screenScale = UIScreen.main.scale
        imageRenderer.scale = screenScale
        guard let overlayImage = imageRenderer.uiImage else { return photo }
        let outputSize = CGSize(width: previewSize.width * screenScale, height: previewSize.height * screenScale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: outputSize, format: format)
        return renderer.image { _ in
            let scale = max(outputSize.width / photo.size.width, outputSize.height / photo.size.height)
            let photoSize = CGSize(width: photo.size.width * scale, height: photo.size.height * scale)
            let photoOrigin = CGPoint(
                x: (outputSize.width - photoSize.width) / 2,
                y: (outputSize.height - photoSize.height) / 2
            )
            photo.draw(in: CGRect(origin: photoOrigin, size: photoSize))
            overlayImage.draw(in: CGRect(origin: .zero, size: outputSize))
        }
    }
}

private enum RunShareLocationResolver {
    static func name(for coordinate: CLLocationCoordinate2D?) async -> String {
        guard let coordinate else { return "위치 정보 없음" }

        do {
            let placemark = try await CLGeocoder().reverseGeocodeLocation(
                CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            ).first
            guard let placemark else { return "위치 정보 없음" }
            let city = placemark.locality ?? placemark.subAdministrativeArea ?? placemark.administrativeArea
            let parts = [city, placemark.country].compactMap { $0 }.filter { !$0.isEmpty }
            return parts.isEmpty ? "위치 정보 없음" : parts.joined(separator: ", ")
        } catch {
            return "위치 정보 없음"
        }
    }
}

private final class RunShareCameraController: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    @Published var isAuthorized = false
    @Published var showsPermissionAlert = false
    private let output = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.pacing.run-share-camera")
    private var completion: ((UIImage) -> Void)?

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    self?.showsPermissionAlert = !granted
                }
                if granted { self?.configureAndStart() }
            }
        default:
            showsPermissionAlert = true
        }
    }

    func stop() { sessionQueue.async { if self.session.isRunning { self.session.stopRunning() } } }

    func capture(completion: @escaping (UIImage) -> Void) {
        self.completion = completion
        sessionQueue.async {
            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off
            settings.photoQualityPrioritization = .speed
            self.output.capturePhoto(with: settings, delegate: self)
        }
    }

    private func configureAndStart() {
        sessionQueue.async {
            guard self.session.inputs.isEmpty else {
                if !self.session.isRunning { self.session.startRunning() }
                return
            }
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input), self.session.canAddOutput(self.output) else {
                self.session.commitConfiguration()
                return
            }
            self.session.addInput(input)
            self.session.addOutput(self.output)
            self.output.maxPhotoQualityPrioritization = .speed
            self.session.commitConfiguration()
            self.session.startRunning()
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else { return }
        DispatchQueue.main.async { [weak self] in self?.completion?(image) }
    }
}

private struct RunShareCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> RunSharePreviewView {
        let view = RunSharePreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: RunSharePreviewView, context: Context) { uiView.previewLayer.session = session }
}

private final class RunSharePreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

private struct RunShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}
