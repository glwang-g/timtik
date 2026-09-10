import AVFoundation
import Speech

@MainActor
final class VoiceCommandService: NSObject, ObservableObject {
    @Published private(set) var status = "语音尚未启动"
    @Published private(set) var transcript = ""

    var onCommand: ((TimerCommand) -> Void)?
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    func startListening() {
        Task {
            let allowed = await requestPermissions()
            guard allowed else {
                status = "请允许麦克风和语音识别权限"
                return
            }
            startRecognition()
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        recognitionTask?.cancel()
        request = nil
        recognitionTask = nil
        status = "麦克风已关闭"
    }

    private func requestPermissions() async -> Bool {
        let speechAllowed = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        let microphoneAllowed = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { continuation.resume(returning: $0) }
        }
        return speechAllowed && microphoneAllowed
    }

    private func startRecognition() {
        guard let recognizer, recognizer.isAvailable else {
            status = "中文语音识别当前不可用"
            return
        }
        stopListening()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .duckOthers, .allowBluetooth])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            self.request = request
            let input = audioEngine.inputNode
            let format = input.outputFormat(forBus: 0)
            // A Simulator can report a zero-Hz, zero-channel input route when it
            // has no microphone source. Installing a tap for that format throws
            // an Objective-C exception (rather than a Swift error), so validate
            // before installing it and leave the rest of the timer usable.
            guard format.sampleRate > 0, format.channelCount > 0 else {
                self.request = nil
                try? session.setActive(false, options: .notifyOthersOnDeactivation)
                status = "没有可用麦克风输入，可手动计时"
                return
            }
            input.installTap(onBus: 0, bufferSize: 1_024, format: format) { buffer, _ in request.append(buffer) }
            audioEngine.prepare()
            try audioEngine.start()
            status = "正在听…"

            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }
                if let result {
                    Task { @MainActor in
                        let text = result.bestTranscription.formattedString
                        self.transcript = text
                        // Stop commands react to partial text; start commands wait for a final result.
                        if case .stop? = CommandParser.parse(text) {
                            self.onCommand?(.stop)
                            self.stopListening()
                        } else if result.isFinal, let command = CommandParser.parse(text) {
                            self.onCommand?(command)
                        }
                    }
                }
                if error != nil {
                    Task { @MainActor in self.status = "语音待命" }
                }
            }
        } catch {
            status = "无法启动麦克风：\(error.localizedDescription)"
        }
    }
}
