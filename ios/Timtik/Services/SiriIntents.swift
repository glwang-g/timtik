import AppIntents

@available(iOS 16.0, *)
struct StartTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "开始 timtik 计时"
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        TimerCommandStore.enqueue(.startStopwatch)
        return .result()
    }
}

@available(iOS 16.0, *)
struct StartCountdownIntent: AppIntent {
    static var title: LocalizedStringResource = "开始 timtik 倒计时"
    static var openAppWhenRun = true

    @Parameter(title: "分钟") var minutes: Int

    func perform() async throws -> some IntentResult {
        TimerCommandStore.enqueue(.startCountdown(seconds: max(1, minutes) * 60))
        return .result()
    }
}

@available(iOS 16.0, *)
struct StopTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "停止 timtik"
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        TimerCommandStore.enqueue(.stop)
        return .result()
    }
}

@available(iOS 16.0, *)
struct TimtikShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartTimerIntent(), phrases: ["用\(.applicationName)开始计时"])
        AppShortcut(intent: StartCountdownIntent(), phrases: ["用\(.applicationName)倒计时"])
        AppShortcut(intent: StopTimerIntent(), phrases: ["用\(.applicationName)停止"])
    }
}
