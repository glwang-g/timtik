import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var timer: TimerEngine
    @ObservedObject var voice: VoiceCommandService
    @ObservedObject var history: HistoryStore
    @State private var countdownMinutes = 3
    @State private var showingHistory = false
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text(modeLabel)
                        .font(.headline)
                        .foregroundStyle(modeTint)
                    Text(timer.display)
                        .font(.system(size: 76, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text(timer.message)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [modeTint.opacity(0.20), modeTint.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 28)
                )
                .padding(.top, 18)
                .padding(.horizontal)

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
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("记录") { showingHistory = true }
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("提示音设置")
                }
            }
            .sheet(isPresented: $showingHistory) { HistoryView(history: history) }
            .sheet(isPresented: $showingSettings) { TimerSettingsView() }
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

    private var modeTint: Color {
        timerTint(for: timer.mode)
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
                            .foregroundStyle(timerTint(for: record.mode))
                        Text(timerModeName(for: record.mode))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(timerTint(for: record.mode))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(timerTint(for: record.mode).opacity(0.12), in: Capsule())
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

private struct TimerSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("timtik.audio.tick-profile") private var tickProfile = "crisp"
    @AppStorage("timtik.audio.short-tick-path") private var shortTickPath = ""
    @AppStorage("timtik.audio.long-tick-path") private var longTickPath = ""
    @AppStorage("timtik.audio.speech-enabled") private var speechEnabled = true
    @State private var importingShortTick = false
    @State private var importingLongTick = false
    @State private var importError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("节拍提示音") {
                    Picker("声音方案", selection: $tickProfile) {
                        Text("清脆").tag("crisp")
                        Text("柔和").tag("soft")
                        Text("静音").tag("silent")
                        Text("自定义音频").tag("custom")
                    }

                    if tickProfile == "custom" {
                        Button { importingShortTick = true } label: {
                            soundFileRow(title: "每秒短滴", path: shortTickPath)
                        }
                        Button { importingLongTick = true } label: {
                            soundFileRow(title: "每 5 秒长滴", path: longTickPath)
                        }
                        Text("导入后会复制到 App 内。未导入的项目会回退为清脆提示音。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("语音播报") {
                    Toggle("启用 15 秒报时", isOn: $speechEnabled)
                }

                if let importError {
                    Section {
                        Text(importError)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("提示音设置")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .fileImporter(isPresented: $importingShortTick, allowedContentTypes: [.audio]) { result in
                importSound(result, isLongTick: false)
            }
            .fileImporter(isPresented: $importingLongTick, allowedContentTypes: [.audio]) { result in
                importSound(result, isLongTick: true)
            }
        }
    }

    private func soundFileRow(title: String, path: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(path.isEmpty ? "选择音频" : URL(fileURLWithPath: path).lastPathComponent)
                .foregroundStyle(path.isEmpty ? Color.accentColor : Color.secondary)
                .lineLimit(1)
        }
    }

    private func importSound(_ result: Result<URL, Error>, isLongTick: Bool) {
        do {
            let source = try result.get()
            guard source.startAccessingSecurityScopedResource() else {
                importError = "无法读取选择的音频文件"
                return
            }
            defer { source.stopAccessingSecurityScopedResource() }

            let directory = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("TimtikSounds", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let fileName = isLongTick ? "long-tick" : "short-tick"
            let destination = directory
                .appendingPathComponent(fileName)
                .appendingPathExtension(source.pathExtension.isEmpty ? "m4a" : source.pathExtension)

            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: source, to: destination)
            if isLongTick {
                longTickPath = destination.path
            } else {
                shortTickPath = destination.path
            }
            importError = nil
        } catch {
            importError = "导入失败：\(error.localizedDescription)"
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
                            HStack(spacing: 6) {
                                Image(systemName: record.mode == .countdown ? "timer" : "stopwatch")
                                    .foregroundStyle(timerTint(for: record.mode))
                                Text(timerModeName(for: record.mode))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(timerTint(for: record.mode))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(timerTint(for: record.mode).opacity(0.12), in: Capsule())
                                Text("停止（\(record.reason)）")
                                    .font(.headline)
                            }
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

private func timerTint(for mode: TimerMode) -> Color {
    switch mode {
    case .stopwatch:
        .indigo
    case .countdown:
        .orange
    case .preparing:
        .mint
    case .idle:
        .secondary
    }
}

private func timerModeName(for mode: TimerMode) -> String {
    mode == .countdown ? "倒计时" : "计时"
}
