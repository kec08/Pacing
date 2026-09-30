import AVFoundation
import Foundation
import MediaPlayer
import MusicKit

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

protocol RunningVoiceAnnouncing: AnyObject {
    func announce(_ announcement: LapVoiceAnnouncement)
    func announce(_ announcement: RunningStateVoiceAnnouncement)
    func stop()
}

final class LapVoiceAnnouncementService: NSObject, RunningVoiceAnnouncing {
    private enum PausedMusicPlayer {
        case application
        case system
    }

    private struct AudioSessionConfiguration {
        let category: AVAudioSession.Category
        let mode: AVAudioSession.Mode
        let policy: AVAudioSession.RouteSharingPolicy
        let options: AVAudioSession.CategoryOptions
    }

    private let synthesizer = AVSpeechSynthesizer()
    private let applicationMusicPlayer = ApplicationMusicPlayer.shared
    private let systemMusicPlayer = MPMusicPlayerController.systemMusicPlayer
    private var announcementSessionConfiguration: AudioSessionConfiguration?
    private var pendingUtteranceIDs = Set<ObjectIdentifier>()
    private var pausedMusicPlayer: PausedMusicPlayer?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func announce(_ announcement: LapVoiceAnnouncement) {
        speak(announcement.text)
    }

    func announce(_ announcement: RunningStateVoiceAnnouncement) {
        speak(announcement.text)
    }

    private func speak(_ text: String) {
        pauseMusicForAnnouncementIfNeeded()
        configureAudioSessionForAnnouncement()

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = preferredKoreanVoice()
        utterance.rate = 0.48
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        pendingUtteranceIDs.insert(ObjectIdentifier(utterance))
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        pendingUtteranceIDs.removeAll()
        restoreAudioSessionAfterAnnouncement()
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
                    .allowBluetoothHFP,
                    .allowBluetoothA2DP
                ]
            )
            try session.setActive(true)
            announcementSessionConfiguration = previousConfiguration
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

    private func restoreAudioSessionAfterAnnouncement() {
        guard pendingUtteranceIDs.isEmpty else { return }

        // MusicKit은 앱의 공유 오디오 세션을 사용한다. 음성 안내 뒤 세션 전체를
        // 비활성화하면 재생 중인 곡까지 멈출 수 있으므로, 안내 전 구성만 복원한다.
        if let configuration = announcementSessionConfiguration {
            try? AVAudioSession.sharedInstance().setCategory(
                configuration.category,
                mode: configuration.mode,
                policy: configuration.policy,
                options: configuration.options
            )
            announcementSessionConfiguration = nil
        }
        resumeMusicAfterAnnouncementIfNeeded()
    }

    private func pauseMusicForAnnouncementIfNeeded() {
        guard pausedMusicPlayer == nil else { return }

        if applicationMusicPlayer.state.playbackStatus == .playing {
            applicationMusicPlayer.pause()
            pausedMusicPlayer = .application
        } else if systemMusicPlayer.playbackState == .playing {
            systemMusicPlayer.pause()
            pausedMusicPlayer = .system
        }
    }

    private func resumeMusicAfterAnnouncementIfNeeded() {
        guard let pausedMusicPlayer else { return }

        Task { @MainActor [weak self] in
            guard let self,
                  self.pendingUtteranceIDs.isEmpty,
                  self.pausedMusicPlayer != nil
            else { return }

            self.pausedMusicPlayer = nil
            switch pausedMusicPlayer {
            case .application:
                try? await self.applicationMusicPlayer.play()
            case .system:
                self.systemMusicPlayer.play()
            }
        }
    }
}

extension LapVoiceAnnouncementService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        pendingUtteranceIDs.remove(ObjectIdentifier(utterance))
        restoreAudioSessionAfterAnnouncement()
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        pendingUtteranceIDs.remove(ObjectIdentifier(utterance))
        restoreAudioSessionAfterAnnouncement()
    }
}
