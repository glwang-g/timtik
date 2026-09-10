# timtik iOS（SwiftUI）

这是 `br-ios` 分支上的原生 iOS 第一版工程。用 Xcode 15+ 打开 `Timtik.xcodeproj`，选择 iPhone 模拟器或真机即可构建；语音识别必须在真机上验证。

## 已实现的第一版

- 正向计时、秒/分钟倒计时和 3 秒预备。
- 每秒短滴、每 5 秒长滴、每 15 秒中文报时。
- 停止时按秒记录本地历史。
- 前台语音识别：开始计时、倒计时 `N` 秒/分钟、停止；“停止”在中间识别结果即响应。
- Siri / 快捷指令骨架：开始、倒计时、停止。Siri 唤起 App 后将命令交由界面处理。

## 运行前要做的两件事

1. 在 Xcode 的 **Signing & Capabilities** 选择你的 Apple Team，并把 Bundle Identifier 从 `com.example.timtik` 改为唯一值，例如 `com.wangguanglei.timtik`。
2. 在真机设置中允许“麦克风”和“语音识别”。模拟器不适合验证真实麦克风和 Siri。

## 结构与职责

```text
TimtikApp.swift                 App 生命周期，接收 Siri 挂起命令
Models/TimerModels.swift        状态、记录和语音命令解析
Services/TimerEngine.swift      计时状态机与节拍调度
Services/AudioCueService.swift  声音、触感和中文播报
Services/VoiceCommandService.swift  麦克风及中文语音识别
Services/HistoryStore.swift     UserDefaults 本地历史
Services/SiriIntents.swift      App Intents / Siri 快捷指令
Views/ContentView.swift         SwiftUI 页面
```

## SwiftUI 是怎样工作的

`TimerEngine` 是唯一的计时状态源。它发布 `mode`、显示秒数和提示文本；`ContentView` 订阅这些值，状态变化时页面自动刷新。计时本身以 `Date` 差值计算，而不是每秒累加，所以 App 短暂切后台再回来，时间仍正确。

语音服务只把识别出的口语转为 `TimerCommand`；计时服务负责真正开始或停止。音频、存储和 Siri 也各自独立。这样的分层使后续替换声音、增加模型或加入 Apple Watch 时不会把逻辑缠在一个页面里。

## 如果自己“古法编程”

可以按下面顺序写，先让每一步在真机可运行，再进入下一步：

1. 用 Xcode 新建 **App / SwiftUI / Swift** 项目，先在 `ContentView` 放一个 `Text("00:00")` 和两个按钮。
2. 写一个 `ObservableObject`：有 `mode`、`startedAt`、`duration`；用 `Task.sleep` 每 100ms 刷新显示，但始终以 `Date.now - startedAt` 算真实秒数。
3. 先实现手动开始、停止和 `UserDefaults` 记录。到这里 App 已经有可用核心。
4. 使用 `AVAudioEngine` 或导入 WAV/MP3，用 `AVAudioPlayer` 播放预备音和节拍；中文报时用 `AVSpeechSynthesizer`。
5. 在 `Info.plist` 增加麦克风、语音识别用途说明；用 `SFSpeechRecognizer` 和 `AVAudioEngine` 把话转文字，再用普通字符串规则解析命令。
6. 最后写 `AppIntent`。Siri 不需要 App 后台偷听：它识别“用 timtik 停止”，再把命令交给 App。

## iOS 的边界

- App 在前台可持续听命令；锁屏或切后台后不能依赖持续开麦。
- 后台计时要靠开始时间重新计算；倒计时结束提醒应补 `UserNotifications`，这一版尚未加入。
- Siri、真实语音识别、通知权限和签名必须在真机测试。
