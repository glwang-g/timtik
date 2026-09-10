import Foundation

/// App Intents write a pending command here. The foreground app consumes it on activation.
enum TimerCommandStore {
    private static let key = "timtik.ios.pending-command"

    static func enqueue(_ command: TimerCommand) {
        let value: String
        switch command {
        case .startStopwatch: value = "stopwatch"
        case let .startCountdown(seconds): value = "countdown:\(seconds)"
        case .stop: value = "stop"
        }
        UserDefaults.standard.set(value, forKey: key)
    }

    static func dequeue() -> TimerCommand? {
        guard let value = UserDefaults.standard.string(forKey: key) else { return nil }
        UserDefaults.standard.removeObject(forKey: key)
        if value == "stopwatch" { return .startStopwatch }
        if value == "stop" { return .stop }
        if value.hasPrefix("countdown:"), let seconds = Int(value.dropFirst("countdown:".count)) {
            return .startCountdown(seconds: seconds)
        }
        return nil
    }
}
