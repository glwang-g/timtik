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
                        Button("开始语音") { voice.startListening() }
                        Button("关闭") { voice.stopListening() }
                    }
                    Text(voice.transcript.isEmpty ? "支持：开始计时、倒计时 3 分钟、停止。" : "识别：\(voice.transcript)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("timtik")
            .toolbar {
                Button("记录") { showingHistory = true }
            }
            .sheet(isPresented: $showingHistory) { HistoryView(history: history) }
            .task { voice.startListening() }
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
