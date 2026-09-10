import SwiftUI

@main
struct TimtikApp: App {
    @StateObject private var history: HistoryStore
    @StateObject private var timer: TimerEngine
    @StateObject private var voice = VoiceCommandService()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let history = HistoryStore()
        let timer = TimerEngine(audio: AudioCueService(), history: history)
        _history = StateObject(wrappedValue: history)
        _timer = StateObject(wrappedValue: timer)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(timer: timer, voice: voice, history: history)
                .onAppear {
                    voice.onCommand = { timer.handle($0) }
                    consumeSiriCommand()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { consumeSiriCommand() }
                }
        }
    }

    private func consumeSiriCommand() {
        guard let command = TimerCommandStore.dequeue() else { return }
        timer.handle(command)
    }
}
