import AVFoundation
import Foundation

extension Notification.Name {
    static let runningVoiceAnnouncementDidStart = Notification.Name("runningVoiceAnnouncementDidStart")
    static let runningVoiceAnnouncementDidFinish = Notification.Name("runningVoiceAnnouncementDidFinish")
}

struct LapVoiceAnnouncement: Equatable {
    let kilometer: Int
    let elapsedSeconds: Int
    let averagePaceMinutesPerKilometer: Double

    init?(
        kilometer: Int,
        elapsedSeconds: Int,
        averagePaceMinutesPerKilometer: Double
    ) {
        guard kilometer > 0,
              elapsedSeconds > 0,
              averagePaceMinutesPerKilometer.isFinite,
              averagePaceMinutesPerKilometer > 0
        else { return nil }

        self.kilometer = kilometer
        self.elapsedSeconds = elapsedSeconds
        self.averagePaceMinutesPerKilometer = averagePaceMinutesPerKilometer
    }

    var text: String {
        let elapsedMinutes = elapsedSeconds / 60
        let elapsedRemainingSeconds = elapsedSeconds % 60
        let paceSeconds = Int((averagePaceMinutesPerKilometer * 60).rounded())
        let paceMinutes = paceSeconds / 60
        let paceRemainingSeconds = paceSeconds % 60

        return "\(kilometer)킬로미터. \(elapsedMinutes)분 \(elapsedRemainingSeconds)초. 킬로미터당 페이스 \(paceMinutes)분 \(paceRemainingSeconds)초."
    }
}

enum RunningStateVoiceAnnouncement: Equatable {
    case started
    case paused
    case resumed

    var text: String {
        switch self {
        case .started:
            "운동을 시작합니다."
        case .paused:
            "운동을 정지합니다."
        case .resumed:
            "운동을 재개합니다."
        }
    }
}

struct RunCompletionVoiceAnnouncement: Equatable {
    static let openingText = "운동을 완료했습니다."
    let distanceKilometers: Double
    let elapsedSeconds: Int
    let averagePaceMinutesPerKilometer: Double

    init?(
        distanceKilometers: Double,
        elapsedSeconds: Int,
        averagePaceMinutesPerKilometer: Double
    ) {
        guard distanceKilometers.isFinite,
              distanceKilometers >= 0,
              elapsedSeconds >= 0,
              averagePaceMinutesPerKilometer.isFinite,
              averagePaceMinutesPerKilometer >= 0
        else { return nil }

        self.distanceKilometers = distanceKilometers
        self.elapsedSeconds = elapsedSeconds
        self.averagePaceMinutesPerKilometer = averagePaceMinutesPerKilometer
    }

    var detailsText: String {
        let elapsedHours = elapsedSeconds / 3_600
        let elapsedMinutes = (elapsedSeconds % 3_600) / 60
        let elapsedRemainingSeconds = elapsedSeconds % 60
        let elapsedText: String
        if elapsedHours > 0 {
            elapsedText = "\(elapsedHours)시간 \(elapsedMinutes)분 \(elapsedRemainingSeconds)초"
        } else {
            elapsedText = "\(elapsedMinutes)분 \(elapsedRemainingSeconds)초"
        }

        let paceText: String
        if averagePaceMinutesPerKilometer > 0 {
            let paceSeconds = Int((averagePaceMinutesPerKilometer * 60).rounded())
            paceText = "평균 페이스 \(paceSeconds / 60)분 \(paceSeconds % 60)초"
        } else {
            paceText = "평균 페이스 정보 없음"
        }

        return "총 거리 \(String(format: "%.2f", distanceKilometers))킬로미터. 총 시간 \(elapsedText). \(paceText)."
    }

    var text: String { "\(Self.openingText) \(detailsText)" }
}

protocol RunningVoiceAnnouncing: AnyObject {
    func announce(_ announcement: LapVoiceAnnouncement)
    func announce(_ announcement: RunningStateVoiceAnnouncement)
    /// 일시정지처럼 수치가 멈춘 시점에 결산 전체를 한 문장으로 미리 합성해 둔다. 재생은 하지 않는다.
    /// 이후 `announce(_:)`의 최종 문구가 같으면 합성 결과를 즉시 재생한다.
    func prepareCompletion(_ announcement: RunCompletionVoiceAnnouncement)
    func announce(_ announcement: RunCompletionVoiceAnnouncement)
    func stop()
}

final class LapVoiceAnnouncementService: NSObject, RunningVoiceAnnouncing {
    // The finish briefing must outlive dismissal of the running view.
    static let shared = LapVoiceAnnouncementService()
    private struct AudioSessionConfiguration {
        let category: AVAudioSession.Category
        let mode: AVAudioSession.Mode
        let policy: AVAudioSession.RouteSharingPolicy
        let options: AVAudioSession.CategoryOptions
    }

    private let synthesizer = AVSpeechSynthesizer()
    private let melo = MeloSpeechEngine.shared
    private var announcementSessionConfiguration: AudioSessionConfiguration?
    private var pendingTexts: [(text: String, synthesisTimeout: TimeInterval)] = []
    private var activeText: String?
    private var activeUtterance: AVSpeechUtterance?
    private var audioPlayer: AVAudioPlayer?
    private var generationID: UUID?

    private enum CompletionClip {
        case synthesizing(UUID)
        case ready(Data)
        case failed
    }

    private static let completionLengthScale: Float = 1.16
    /// 결산은 끊김 없이 한 문장으로 합성하므로 합성 시간이 길다. 시스템 음성으로 대신하지 않는다.
    private static let completionSynthesisTimeout: TimeInterval = 30
    private var completionText: String?
    private var completionClip: CompletionClip?

    override init() {
        super.init()
        synthesizer.delegate = self
        melo.prepare()
    }

    func announce(_ announcement: LapVoiceAnnouncement) {
        speak(announcement.text)
    }

    func announce(_ announcement: RunningStateVoiceAnnouncement) {
        speak(announcement.text)
    }

    func prepareCompletion(_ announcement: RunCompletionVoiceAnnouncement) {
        prefetchCompletion(announcement.text)
    }

    func announce(_ announcement: RunCompletionVoiceAnnouncement) {
        let text = announcement.text
        if let active = activeText, Self.isCompletionText(active) {
            // 같은 결산이 이미 재생 중이거나 합성을 기다리는 중이면 그대로 둔다.
            if active == text { return }
            // 다른 수치의 결산이 이미 소리 나고 있으면 끊지 않는다.
            if audioPlayer != nil { return }
        }
        // 재생 중인 안내만 멈추고, 미리 합성해 둔 결산은 남겨 둔다.
        haltPlayback()
        // 일시정지 때 합성한 문구와 같으면 곧바로 재생하고, 다르면 지금 수치로 다시 합성한다.
        prefetchCompletion(text)
        speak(text, synthesisTimeout: Self.completionSynthesisTimeout)
    }

    /// 결산 문구는 수치가 바뀌어도 항상 완료 안내로 시작한다. 이 문구들은 기계음으로 대신하지 않는다.
    private static func isCompletionText(_ text: String) -> Bool {
        text.hasPrefix(RunCompletionVoiceAnnouncement.openingText)
    }

    /// 완료 안내와 상세 결산을 하나의 MeloTTS 입력으로 합성해 문장 사이 끊김 없이 이어서 들려준다.
    private func prefetchCompletion(_ text: String) {
        if completionText == text, let clip = completionClip {
            if case .failed = clip {} else { return }
        }
        if case .synthesizing? = completionClip {
            // 수치가 바뀐 이전 합성은 쓸모없다. 큐에서 아직 시작하지 않았다면 건너뛰게 한다.
            melo.cancelPendingSynthesis()
        }
        let requestID = UUID()
        completionText = text
        completionClip = .synthesizing(requestID)
        melo.synthesize(text, lengthScale: Self.completionLengthScale) { [weak self] audio in
            guard let self, self.completionText == text,
                  case .synthesizing(let currentID)? = self.completionClip,
                  currentID == requestID
            else { return }
            self.completionClip = audio.map(CompletionClip.ready) ?? .failed
            guard self.activeText == text else { return }
            self.generationID = nil
            if let audio {
                self.playMelo(audio, text: text)
            } else {
                NSLog("MeloTTS completion synthesis failed; briefing skipped")
                self.finishCurrentAnnouncement()
            }
        }
    }

    private func speak(_ text: String, synthesisTimeout: TimeInterval = 15) {
        pendingTexts.append((text, synthesisTimeout))
        startNextIfNeeded()
    }

    private func startNextIfNeeded() {
        guard activeText == nil, !pendingTexts.isEmpty else { return }
        let (text, synthesisTimeout) = pendingTexts.removeFirst()
        activeText = text
        if text == completionText, let clip = completionClip {
            switch clip {
            case .ready(let audio):
                playMelo(audio, text: text)
            case .synthesizing:
                // 합성 완료 콜백이 재생을 이어받는다. 제한 시간이 지나면 기계음 없이 건너뛴다.
                let requestID = UUID()
                generationID = requestID
                scheduleSynthesisFallback(for: text, requestID: requestID, timeout: synthesisTimeout)
            case .failed:
                finishCurrentAnnouncement()
            }
            return
        }

        // 시작·정지·재개는 지연 없이 안내해야 하므로 검증된 MeloTTS 번들을 즉시 재생한다.
        if let clip = Self.bundledClip(for: text),
           let url = Bundle.main.url(forResource: clip, withExtension: "wav"),
           let audio = try? Data(contentsOf: url) {
            playMelo(audio, text: text)
            return
        }

        let requestID = UUID()
        generationID = requestID
        let lengthScale: Float = text.contains("킬로미터") && text.contains("페이스") ? 1.16 : 0.98
        melo.synthesize(text, lengthScale: lengthScale) { [weak self] audio in
            guard let self, self.generationID == requestID, self.activeText == text else { return }
            self.generationID = nil
            if let audio {
                self.playMelo(audio, text: text)
            } else {
                self.speakWithSystemVoice(text)
            }
        }

        // A slow inference must never delay or drop a kilometer announcement.
        scheduleSynthesisFallback(for: text, requestID: requestID, timeout: synthesisTimeout)
    }

    private func scheduleSynthesisFallback(for text: String, requestID: UUID, timeout: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
            guard let self, self.generationID == requestID, self.activeText == text else { return }
            self.generationID = nil
            if Self.isCompletionText(text) {
                NSLog("MeloTTS completion synthesis exceeded %.1f seconds; briefing skipped", timeout)
                if text == self.completionText { self.completionClip = .failed }
                self.finishCurrentAnnouncement()
            } else {
                NSLog("MeloTTS inference exceeded %.1f seconds; using the system Korean voice", timeout)
                self.speakWithSystemVoice(text)
            }
        }
    }

    private func playMelo(_ audio: Data, text: String) {
        do {
            let player = try AVAudioPlayer(data: audio)
            configureAudioSessionForAnnouncement()
            player.delegate = self
            player.prepareToPlay()
            guard player.play() else {
                NSLog("MeloTTS playback did not start; using the system Korean voice")
                speakWithSystemVoice(text)
                return
            }
            audioPlayer = player
            NotificationCenter.default.post(name: .runningVoiceAnnouncementDidStart, object: nil)
        } catch {
            NSLog("MeloTTS playback failed: %@", String(describing: error))
            speakWithSystemVoice(text)
        }
    }

    private static func bundledClip(for text: String) -> String? {
        switch text {
        case RunningStateVoiceAnnouncement.started.text: "melo_started"
        case RunningStateVoiceAnnouncement.paused.text: "melo_paused"
        case RunningStateVoiceAnnouncement.resumed.text: "melo_resumed"
        case RunCompletionVoiceAnnouncement.openingText: "melo_completed"
        default: nil
        }
    }

    private func speakWithSystemVoice(_ text: String) {
        if Self.isCompletionText(text) {
            NSLog("MeloTTS completion playback unavailable")
            finishCurrentAnnouncement()
            return
        }
        configureAudioSessionForAnnouncement()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = preferredKoreanVoice()
        utterance.rate = 0.48
        utterance.pitchMultiplier = 1.12
        utterance.volume = 1.0
        activeUtterance = utterance
        NotificationCenter.default.post(name: .runningVoiceAnnouncementDidStart, object: nil)
        synthesizer.speak(utterance)
    }

    func stop() {
        haltPlayback()
        // 아직 시작하지 않은 합성은 모두 버린다. 남겨 두면 다음 안내가 그 뒤에서 기다린다.
        melo.cancelPendingSynthesis()
        completionText = nil
        completionClip = nil
        restoreAudioSessionAfterAnnouncement()
    }

    private func haltPlayback() {
        pendingTexts.removeAll()
        generationID = nil
        activeText = nil
        activeUtterance = nil
        audioPlayer?.stop()
        audioPlayer = nil
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func finishCurrentAnnouncement() {
        guard let finishedText = activeText else { return }
        if finishedText == completionText {
            completionText = nil
            completionClip = nil
        }
        activeText = nil
        activeUtterance = nil
        audioPlayer = nil
        startNextIfNeeded()
        if activeText == nil { restoreAudioSessionAfterAnnouncement() }
    }

    private func configureAudioSessionForAnnouncement() {
        guard announcementSessionConfiguration == nil else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            let previousConfiguration = AudioSessionConfiguration(
                category: session.category,
                mode: session.mode,
                policy: session.routeSharingPolicy,
                options: session.categoryOptions
            )
            try session.setCategory(
                .playback,
                mode: .voicePrompt,
                policy: .default,
                options: [
                    .mixWithOthers,
                    .duckOthers
                ]
            )
            try session.setActive(true)
            announcementSessionConfiguration = previousConfiguration
        } catch {
            NSLog("[Pacing] 음성 안내 오디오 세션 설정 실패: %@", error.localizedDescription)
        }
    }

    private func preferredKoreanVoice() -> AVSpeechSynthesisVoice? {
        let koreanVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.lowercased().hasPrefix("ko") }
        return koreanVoices.max { lhs, rhs in
            lhs.quality.rawValue < rhs.quality.rawValue
        } ?? AVSpeechSynthesisVoice(language: "ko-KR")
    }

    private func restoreAudioSessionAfterAnnouncement() {
        if let configuration = announcementSessionConfiguration {
            let session = AVAudioSession.sharedInstance()
            // Ducking is released only when the prompt session deactivates.
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            try? session.setCategory(configuration.category, mode: configuration.mode,
                                     policy: configuration.policy, options: configuration.options)
            try? session.setActive(true)
            announcementSessionConfiguration = nil
        }
        NotificationCenter.default.post(name: .runningVoiceAnnouncementDidFinish, object: nil)
    }
}

extension LapVoiceAnnouncementService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        guard activeUtterance === utterance else { return }
        finishCurrentAnnouncement()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        guard activeUtterance === utterance else { return }
        finishCurrentAnnouncement()
    }
}

extension LapVoiceAnnouncementService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard audioPlayer === player else { return }
        finishCurrentAnnouncement()
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        guard audioPlayer === player, let activeText else { return }
        audioPlayer = nil
        speakWithSystemVoice(activeText)
    }
}
