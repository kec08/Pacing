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
            "러닝을 시작합니다."
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
    private var completionPrefetchID: UUID?
    private var completionDetailsText: String?
    private var completionDetailsAudio: Data?
    private var isCompletionPrefetching = false
    private var completionRemainingText: String?
    private var completionRemainingAudio: Data?
    private var isCompletionRemainingPrefetching = false

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

    func announce(_ announcement: RunCompletionVoiceAnnouncement) {
        let details = announcement.detailsText
        let parts = details.components(separatedBy: ". ")
        guard parts.count > 1 else {
            speak(RunCompletionVoiceAnnouncement.openingText)
            speak(details, synthesisTimeout: 15)
            return
        }
        let first = parts[0] + "."
        let remaining = parts.dropFirst().joined(separator: ". ")
        let requestID = UUID()
        completionPrefetchID = requestID
        completionDetailsText = first
        completionDetailsAudio = nil
        completionRemainingText = remaining
        completionRemainingAudio = nil
        isCompletionPrefetching = true
        isCompletionRemainingPrefetching = true
        melo.synthesize(first) { [weak self] audio in
            guard let self, self.completionPrefetchID == requestID else { return }
            self.isCompletionPrefetching = false
            if self.activeText == first {
                self.generationID = nil
                if let audio { self.playMelo(audio, text: first) }
                else { self.speakWithSystemVoice(first) }
            } else {
                self.completionDetailsAudio = audio
            }
        }
        melo.synthesize(remaining) { [weak self] audio in
            guard let self, self.completionPrefetchID == requestID else { return }
            self.isCompletionRemainingPrefetching = false
            if self.activeText == remaining {
                self.generationID = nil
                if let audio { self.playMelo(audio, text: remaining) }
                else { self.speakWithSystemVoice(remaining) }
            } else {
                self.completionRemainingAudio = audio
            }
        }
        speak(RunCompletionVoiceAnnouncement.openingText)
        speak(first, synthesisTimeout: 15)
        speak(remaining, synthesisTimeout: 15)
    }

    private func speak(_ text: String, synthesisTimeout: TimeInterval = 1.2) {
        pendingTexts.append((text, synthesisTimeout))
        startNextIfNeeded()
    }

    private func startNextIfNeeded() {
        guard activeText == nil, !pendingTexts.isEmpty else { return }
        let (text, synthesisTimeout) = pendingTexts.removeFirst()
        activeText = text
        if completionDetailsText == text {
            if let audio = completionDetailsAudio {
                completionDetailsAudio = nil
                playMelo(audio, text: text)
                return
            }
            if isCompletionPrefetching {
                let requestID = UUID()
                generationID = requestID
                scheduleSynthesisFallback(for: text, requestID: requestID, timeout: synthesisTimeout)
                return
            }
        }
        if completionRemainingText == text {
            if let audio = completionRemainingAudio {
                completionRemainingAudio = nil
                playMelo(audio, text: text)
                return
            }
            if isCompletionRemainingPrefetching {
                let requestID = UUID()
                generationID = requestID
                scheduleSynthesisFallback(for: text, requestID: requestID, timeout: synthesisTimeout)
                return
            }
        }

        // Fixed state prompts are bundled MeloTTS clips so the first cue starts at once.
        if let clip = Self.bundledClip(for: text),
           let url = Bundle.main.url(forResource: clip, withExtension: "wav"),
           let audio = try? Data(contentsOf: url) {
            playMelo(audio, text: text)
            return
        }

        guard melo.isReady else {
            NSLog("MeloTTS is still loading; using the system Korean voice")
            speakWithSystemVoice(text)
            return
        }

        let requestID = UUID()
        generationID = requestID
        melo.synthesize(text) { [weak self] audio in
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
            if text == self.completionDetailsText || text == self.completionRemainingText {
                self.completionPrefetchID = nil
                self.isCompletionPrefetching = false
                self.isCompletionRemainingPrefetching = false
            }
            NSLog("MeloTTS inference exceeded %.1f seconds; using the system Korean voice", timeout)
            self.speakWithSystemVoice(text)
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
        pendingTexts.removeAll()
        generationID = nil
        completionPrefetchID = nil
        completionDetailsText = nil
        completionDetailsAudio = nil
        isCompletionPrefetching = false
        completionRemainingText = nil
        completionRemainingAudio = nil
        isCompletionRemainingPrefetching = false
        activeText = nil
        activeUtterance = nil
        audioPlayer?.stop()
        audioPlayer = nil
        synthesizer.stopSpeaking(at: .immediate)
        restoreAudioSessionAfterAnnouncement()
    }

    private func finishCurrentAnnouncement() {
        guard let finishedText = activeText else { return }
        if finishedText == completionRemainingText ||
            (completionRemainingText == nil && finishedText == completionDetailsText) {
            completionPrefetchID = nil
            completionDetailsText = nil
            completionDetailsAudio = nil
            isCompletionPrefetching = false
            completionRemainingText = nil
            completionRemainingAudio = nil
            isCompletionRemainingPrefetching = false
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
                    .duckOthers,
                    .interruptSpokenAudioAndMixWithOthers,
                    .allowBluetoothHFP,
                    .allowBluetoothA2DP
                ]
            )
            try session.setActive(true)
            announcementSessionConfiguration = previousConfiguration
        } catch {
            // Audio session failure must not interrupt running measurement or the fallback voice.
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
        // MusicKit shares the app audio session. Deactivation can stop the song.
        if let configuration = announcementSessionConfiguration {
            try? AVAudioSession.sharedInstance().setCategory(
                configuration.category,
                mode: configuration.mode,
                policy: configuration.policy,
                options: configuration.options
            )
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
