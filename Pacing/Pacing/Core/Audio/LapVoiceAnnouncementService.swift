import AVFoundation
import Foundation

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

        return "\(kilometer)킬로미터를 달렸습니다. 현재까지 총 시간은 \(elapsedMinutes)분 \(elapsedRemainingSeconds)초입니다. 평균 페이스는 킬로미터당 \(paceMinutes)분 \(paceRemainingSeconds)초입니다. 좋은 흐름이에요. 계속 달려볼까요?"
    }
}

protocol LapVoiceAnnouncing: AnyObject {
    func announce(_ announcement: LapVoiceAnnouncement)
    func stop()
}

final class LapVoiceAnnouncementService: NSObject, LapVoiceAnnouncing {
    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func announce(_ announcement: LapVoiceAnnouncement) {
        configureAudioSessionForAnnouncement()

        let utterance = AVSpeechUtterance(string: announcement.text)
        utterance.voice = preferredKoreanVoice()
        utterance.rate = 0.48
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        deactivateAudioSessionIfNeeded()
    }

    private func configureAudioSessionForAnnouncement() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playback,
                mode: .voicePrompt,
                policy: .longFormAudio,
                options: [
                    .duckOthers,
                    .interruptSpokenAudioAndMixWithOthers,
                    .allowBluetoothHFP,
                    .allowBluetoothA2DP
                ]
            )
            try session.setActive(true)
        } catch {
            // 음성 안내 실패가 러닝 측정을 중단시키지 않도록 오디오 세션 오류는 무시합니다.
        }
    }

    private func preferredKoreanVoice() -> AVSpeechSynthesisVoice? {
        let koreanVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.lowercased().hasPrefix("ko") }

        return koreanVoices.max { lhs, rhs in
            lhs.quality.rawValue < rhs.quality.rawValue
        } ?? AVSpeechSynthesisVoice(language: "ko-KR")
    }

    private func deactivateAudioSessionIfNeeded() {
        guard !synthesizer.isSpeaking else { return }
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }
}

extension LapVoiceAnnouncementService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        deactivateAudioSessionIfNeeded()
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        deactivateAudioSessionIfNeeded()
    }
}
