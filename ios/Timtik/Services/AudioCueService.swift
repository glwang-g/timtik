import AVFoundation
import UIKit

@MainActor
final class AudioCueService {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let speech = AVSpeechSynthesizer()
    private var customPlayer: AVAudioPlayer?
    private var isConfigured = false

    func prepareForPlayback() {
        guard !isConfigured else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            // Voice recognition and timer cues may run together. A playback-only
            // session would tear down the microphone when the first tick plays.
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .duckOthers, .allowBluetoothHFP])
            try session.setActive(true)
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: nil)
            try engine.start()
            isConfigured = true
        } catch {
            // The UI remains usable without custom tones; speech and haptics still provide feedback.
        }
    }

    func shortTick() {
        switch shortTickProfile {
        case "silent": return
        case "custom" where playCustomTone(pathKey: "timtik.audio.short-tick-path"): return
        case "soft": tone(frequency: 880, duration: 0.08, style: .soft)
        default: tone(frequency: 1_280, duration: 0.055, style: .light)
        }
    }

    func longTick() {
        switch longTickProfile {
        case "silent": return
        case "custom" where playCustomTone(pathKey: "timtik.audio.long-tick-path"): return
        case "soft": tone(frequency: 440, duration: 0.22, style: .soft)
        default: tone(frequency: 560, duration: 0.18, style: .medium)
        }
    }
    func preparationCue() { tone(frequency: 1_047, duration: 0.32, style: .rigid) }

    func announce(_ text: String) {
        guard UserDefaults.standard.object(forKey: "timtik.audio.speech-enabled") as? Bool ?? true else { return }
        prepareForPlayback()
        speech.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        speech.speak(utterance)
    }

    func stopSpeech() { speech.stopSpeaking(at: .immediate) }

    private var shortTickProfile: String {
        UserDefaults.standard.string(forKey: "timtik.audio.short-tick-profile") ?? "crisp"
    }

    private var longTickProfile: String {
        UserDefaults.standard.string(forKey: "timtik.audio.long-tick-profile") ?? "crisp"
    }

    private func playCustomTone(pathKey: String) -> Bool {
        guard let path = UserDefaults.standard.string(forKey: pathKey), !path.isEmpty else { return false }
        do {
            prepareForPlayback()
            customPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
            customPlayer?.prepareToPlay()
            customPlayer?.play()
            return true
        } catch {
            return false
        }
    }

    private func tone(frequency: Double, duration: Double, style: UIImpactFeedbackGenerator.FeedbackStyle) {
        prepareForPlayback()
        UIImpactFeedbackGenerator(style: style).impactOccurred()
        guard isConfigured else { return }

        // The simulator's output route is normally stereo while an iPhone route
        // may differ (for example Bluetooth).  A scheduled buffer must exactly
        // match the player node's output format; a hard-coded mono buffer causes
        // an Objective-C audio exception instead of a recoverable Swift error.
        let format = player.outputFormat(forBus: 0)
        let sampleRate = format.sampleRate
        guard sampleRate > 0, format.channelCount > 0 else { return }
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channels = buffer.floatChannelData else { return }
        buffer.frameLength = frameCount
        for index in 0 ..< Int(frameCount) {
            let progress = Double(index) / sampleRate
            let envelope = Float(max(0, 1 - progress / duration) * 0.18)
            let sample = sin(Float(2 * Double.pi * frequency * progress)) * envelope
            for channel in 0 ..< Int(format.channelCount) {
                channels[channel][index] = sample
            }
        }
        player.scheduleBuffer(buffer, at: nil)
        if !player.isPlaying { player.play() }
    }
}
