import SwiftUI

struct ContentView: View {
    @ObservedObject var timer: TimerEngine
    @ObservedObject var voice: VoiceCommandService
    @ObservedObject var history: HistoryStore
    @State private var countdownMinutes = 3
    @State private var showingHistory = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text(modeLabel)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(timer.display)
                        .font(.system(size: 76, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text(timer.message)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 30)

                HStack(spacing: 12) {
                    Button("开始计时") { timer.handle(.startStopwatch) }
                        .buttonStyle(.borderedProminent)
                    Button("停止并记录") { timer.stopAndRecord() }
                        .buttonStyle(.bordered)
                        .disabled(!timer.isRunning)
                }

                HStack(spacing: 12) {
                    ForEach([3, 5, 15], id: \.self) { minutes in
                        Button("\(minutes) 分钟") {
                            timer.handle(.startCountdown(seconds: minutes * 60))
                        }
                        .buttonStyle(.bordered)
                    }
                }

                HStack {
                    Stepper("倒计时 \(countdownMinutes) 分钟", value: $countdownMinutes, in: 1 ... 1_440)
                    Button("开始") {
                        timer.handle(.startCountdown(seconds: countdownMinutes * 60))
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)

                Divider()

                VStack(spacing: 8) {
                    HStack {
                        Label(voice.status, systemImage: "mic.fill")
                            .foregroundStyle(voice.status == "正在听…" ? .red : .secondary)
                        Spacer()
                    }
                    Text(voice.transcript.isEmpty
                         ? "前台自动监听：开始计时、倒计时 3 分钟、停止。锁屏后可用 Siri。"
                         : "识别：\(voice.transcript)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                recentHistory

                Spacer()
            }
            .navigationTitle("timtik")
            .toolbar {
                Button("记录") { showingHistory = true }
            }
            .sheet(isPresented: $showingHistory) { HistoryView(history: history) }
        }
    }

    private var modeLabel: String {
        switch timer.mode {
        case .idle: "准备开始"
        case .preparing: "3 秒预备"
        case .stopwatch: "计时进行中"
        case .countdown: "倒计时进行中"
        }
    }

    private var recentHistory: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("最近记录")
                    .font(.headline)
                Spacer()
                Button("查看全部") { showingHistory = true }
                    .font(.footnote)
            }
            if history.records.isEmpty {
                Text("还没有记录")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(history.records.prefix(3)) { record in
                    HStack(spacing: 8) {
                        Image(systemName: record.mode == .countdown ? "timer" : "stopwatch")
                            .foregroundStyle(.tint)
                        Text(record.summary)
                            .lineLimit(1)
                        Spacer()
                        Text(record.recordedAt.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .font(.footnote)
                }
            }
        }
        .padding(.horizontal)
    }
}

private struct HistoryView: View {
    @ObservedObject var history: HistoryStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if history.records.isEmpty {
                    ContentUnavailableView("还没有记录", systemImage: "clock")
                } else {
                    ForEach(history.records) { record in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(record.mode == .countdown ? "倒计时" : "计时")停止（\(record.reason)）")
                                .font(.headline)
                            Text("\(record.summary) · \(record.recordedAt.formatted(date: .abbreviated, time: .standard))")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("计时记录")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("清空", role: .destructive) { history.clear() }
                }
                ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } }
            }
        }
    }
}
