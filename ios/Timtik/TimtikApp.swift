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
                    timer.requestNotificationPermission()
                    voice.startListening()
                }
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
                        consumeSiriCommand()
                        voice.startListening()
                    case .background:
                        // iOS does not permit continuous speech recognition while
                        // locked or in the background. Siri remains the voice entry.
                        voice.stopListening()
                    case .inactive:
                        break
                    @unknown default:
                        break
                    }
                }
        }
    }

    private func consumeSiriCommand() {
        guard let command = TimerCommandStore.dequeue() else { return }
        timer.handle(command)
    }
}
