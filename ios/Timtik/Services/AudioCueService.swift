import AVFoundation
import UIKit

@MainActor
final class AudioCueService {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let speech = AVSpeechSynthesizer()
    private var isConfigured = false

    func prepareForPlayback() {
        guard !isConfigured else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            // Voice recognition and timer cues may run together. A playback-only
            // session would tear down the microphone when the first tick plays.
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .duckOthers, .allowBluetooth])
            try session.setActive(true)
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: nil)
            try engine.start()
            isConfigured = true
        } catch {
            // The UI remains usable without custom tones; speech and haptics still provide feedback.
        }
    }

    func shortTick() { tone(frequency: 1_280, duration: 0.055, style: .light) }
    func longTick() { tone(frequency: 560, duration: 0.18, style: .medium) }
    func preparationCue() { tone(frequency: 1_047, duration: 0.32, style: .rigid) }

    func announce(_ text: String) {
        prepareForPlayback()
        speech.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        speech.speak(utterance)
    }

    func stopSpeech() { speech.stopSpeaking(at: .immediate) }

    private func tone(frequency: Double, duration: Double, style: UIImpactFeedbackGenerator.FeedbackStyle) {
        prepareForPlayback()
        UIImpactFeedbackGenerator(style: style).impactOccurred()
        guard isConfigured else { return }

        let sampleRate = 44_100.0
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = frameCount
        for index in 0 ..< Int(frameCount) {
            let progress = Double(index) / sampleRate
            let envelope = Float(max(0, 1 - progress / duration) * 0.18)
            data[index] = sin(Float(2 * Double.pi * frequency * progress)) * envelope
        }
        player.scheduleBuffer(buffer, at: nil)
        if !player.isPlaying { player.play() }
    }
}
