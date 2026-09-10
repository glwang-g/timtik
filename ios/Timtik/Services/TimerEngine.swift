import Foundation

@MainActor
final class TimerEngine: ObservableObject {
    @Published private(set) var mode: TimerMode = .idle
    @Published private(set) var visibleSeconds = 0
    @Published private(set) var message = "准备就绪"

    private let audio: AudioCueService
    private let history: HistoryStore
    private var startedAt: Date?
    private var durationSeconds = 0
    private var preparationMode: TimerMode = .idle
    private var lastElapsed = -1
    private var runTask: Task<Void, Never>?

    init(audio: AudioCueService, history: HistoryStore) {
        self.audio = audio
        self.history = history
    }

    var display: String { TimeFormatter.clock(visibleSeconds) }
    var isRunning: Bool { mode == .preparing || mode == .stopwatch || mode == .countdown }

    func handle(_ command: TimerCommand) {
        switch command {
        case .startStopwatch: prepare(mode: .stopwatch, duration: 0)
        case let .startCountdown(seconds): prepare(mode: .countdown, duration: seconds)
        case .stop: stopAndRecord(reason: "语音停止")
        }
    }

    func prepare(mode nextMode: TimerMode, duration: Int) {
        if isRunning { stopAndRecord(reason: "新的开始命令") }
        audio.prepareForPlayback()
        mode = .preparing
        preparationMode = nextMode
        durationSeconds = duration
        visibleSeconds = 3
        message = "3 秒预备"
        runTask?.cancel()
        runTask = Task { [weak self] in
            guard let self else { return }
            for count in stride(from: 3, through: 1, by: -1) {
                guard !Task.isCancelled else { return }
                self.visibleSeconds = count
                self.message = "\(count) 秒后开始"
                self.audio.preparationCue()
                try? await Task.sleep(for: .seconds(1))
            }
            guard !Task.isCancelled else { return }
            self.begin(mode: nextMode, duration: duration)
        }
    }

    func stopAndRecord(reason: String = "手动停止") {
        guard mode != .idle else { return }
        let wasPreparing = mode == .preparing
        let runningMode = wasPreparing ? preparationMode : mode
        let elapsed = wasPreparing ? 0 : elapsedSeconds()
        let remaining = runningMode == .countdown ? max(0, durationSeconds - elapsed) : nil
        let record = TimerRecord(
            id: UUID(), mode: runningMode, reason: reason,
            elapsedSeconds: elapsed, remainingSeconds: remaining, recordedAt: .now
        )
        history.add(record)
        runTask?.cancel()
        runTask = nil
        if reason != "倒计时结束" { audio.stopSpeech() }
        mode = .idle
        preparationMode = .idle
        visibleSeconds = 0
        lastElapsed = -1
        message = "已记录：\(record.summary)"
    }

    private func begin(mode nextMode: TimerMode, duration: Int) {
        mode = nextMode
        durationSeconds = duration
        startedAt = .now
        lastElapsed = -1
        message = nextMode == .countdown ? "剩余 \(TimeFormatter.words(duration))" : "计时进行中"
        updateLoop()
    }

    private func updateLoop() {
        runTask?.cancel()
        runTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled && (self.mode == .stopwatch || self.mode == .countdown) {
                self.update()
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private func update() {
        let elapsed = elapsedSeconds()
        let visible = mode == .countdown ? durationSeconds - elapsed : elapsed
        if mode == .countdown, visible <= 0, elapsed > 0 {
            audio.announce("倒计时结束")
            stopAndRecord(reason: "倒计时结束")
            return
        }
        visibleSeconds = max(0, visible)
        guard elapsed != lastElapsed else { return }
        lastElapsed = elapsed
        guard elapsed > 0 else { return }
        if elapsed.isMultiple(of: 5) { audio.longTick() } else { audio.shortTick() }
        if elapsed.isMultiple(of: 15) {
            audio.announce(mode == .countdown ? TimeFormatter.words(visible) : "\(elapsed) 秒")
        }
    }

    private func elapsedSeconds() -> Int {
        guard let startedAt else { return 0 }
        return max(0, Int(Date.now.timeIntervalSince(startedAt)))
    }
}
