import Foundation

enum TimerMode: String, Codable {
    case idle
    case preparing
    case stopwatch
    case countdown
}

enum TimerCommand: Equatable {
    case startStopwatch
    case startCountdown(seconds: Int)
    case stop
}

struct TimerRecord: Codable, Identifiable {
    let id: UUID
    let mode: TimerMode
    let reason: String
    let elapsedSeconds: Int
    let remainingSeconds: Int?
    let recordedAt: Date

    var summary: String {
        if let remainingSeconds {
            return "剩余 \(TimeFormatter.words(remainingSeconds))"
        }
        return "已计时 \(elapsedSeconds) 秒"
    }
}

enum TimeFormatter {
    static func clock(_ seconds: Int) -> String {
        let value = max(0, seconds)
        return String(format: "%02d:%02d", value / 60, value % 60)
    }

    static func words(_ seconds: Int) -> String {
        let value = max(0, seconds)
        return "\(value / 60) 分 \(value % 60) 秒"
    }
}

enum CommandParser {
    static func parse(_ rawText: String) -> TimerCommand? {
        let text = rawText.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "，", with: "")
            .replacingOccurrences(of: "。", with: "")

        if ["停止", "停下", "暂停", "结束", "停止计时", "停止倒计时", "结束计时"].contains(where: text.contains) {
            return .stop
        }
        if text.contains("开始计时") || text.contains("开始秒表") {
            return .startStopwatch
        }
        let pattern = "倒计时(?:为|是)?(\\d+)(分钟|分|秒钟|秒)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let amountRange = Range(match.range(at: 1), in: text),
              let unitRange = Range(match.range(at: 2), in: text) else {
            return nil
        }
        let amount = Int(text[amountRange]) ?? 0
        guard amount > 0 else { return nil }
        let seconds = text[unitRange].contains("分") ? amount * 60 : amount
        return .startCountdown(seconds: min(seconds, 86_400))
    }
}
