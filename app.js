const $ = (id) => document.getElementById(id);
const storageKey = "timtik.history.v1";
const soundDatabase = "timtik.custom-sounds.v1";
const soundStore = "sounds";
const state = {
  mode: "idle", startedAt: 0, durationSeconds: 0, elapsed: 0, lastSecond: -1,
  runId: 0, preparation: null, pendingMode: null, pendingDuration: 0,
  recognition: null, wantsListening: false, isListening: false, customSounds: {}
};
let audioContext;

const display = $("time-display");
const message = $("timer-message");
const modeLabel = $("mode-label");
const stopButton = $("stop-button");
const voiceStatus = $("voice-status");
const numberWords = { 零: 0, 〇: 0, 一: 1, 二: 2, 两: 2, 三: 3, 四: 4, 五: 5, 六: 6, 七: 7, 八: 8, 九: 9 };
const unitWords = { 十: 10, 百: 100, 千: 1000, 万: 10000 };

function format(seconds) {
  const whole = Math.max(0, Math.floor(seconds));
  return `${String(Math.floor(whole / 60)).padStart(2, "0")}:${String(whole % 60).padStart(2, "0")}`;
}
function formatWords(seconds) {
  const whole = Math.max(0, Math.floor(seconds));
  return `${Math.floor(whole / 60)} 分 ${whole % 60} 秒`;
}
function localTimestamp(date = new Date()) {
  const pad = (value) => String(value).padStart(2, "0");
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
}
function getAudio() { audioContext ??= new AudioContext(); return audioContext; }
function playBuffer(buffer) {
  const ctx = getAudio();
  const source = ctx.createBufferSource();
  const gain = ctx.createGain();
  source.buffer = buffer;
  gain.gain.value = Number($("volume").value) / 100;
  source.connect(gain).connect(ctx.destination);
  source.start();
}
function sound(kind, slot) {
  if (kind === "none") return;
  if (kind === "custom") {
    if (state.customSounds[slot]) playBuffer(state.customSounds[slot].buffer);
    return;
  }
  const ctx = getAudio();
  const oscillator = ctx.createOscillator();
  const gain = ctx.createGain();
  const options = {
    beep: [1280, "sine", 0.055], soft: [740, "sine", 0.12], tick: [560, "triangle", 0.18],
    click: [980, "square", 0.1], chime: [1047, "sine", 0.32]
  }[kind] ?? [1280, "sine", 0.055];
  oscillator.frequency.value = options[0]; oscillator.type = options[1];
  const level = Number($("volume").value) / 100 * 0.2;
  gain.gain.setValueAtTime(level, ctx.currentTime);
  gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + options[2]);
  oscillator.connect(gain).connect(ctx.destination);
  oscillator.start(); oscillator.stop(ctx.currentTime + options[2]);
}
function speak(text) {
  if (!("speechSynthesis" in window)) {
    message.textContent = "当前浏览器不支持语音报时；提示铃仍会播放。";
    return;
  }
  speechSynthesis.cancel();
  const utterance = new SpeechSynthesisUtterance(text);
  utterance.lang = "zh-CN"; utterance.rate = 1.05;
  utterance.onerror = () => { message.textContent = "语音报时未能播放；请检查浏览器的语音与自动播放设置。"; };
  speechSynthesis.speak(utterance);
}
function stopListening(note = "麦克风已关闭") {
  state.wantsListening = false;
  if (state.recognition && state.isListening) state.recognition.abort();
  state.isListening = false;
  voiceStatus.textContent = note;
}
function setIdle(note = "说“开始计时”或“倒计时 3 分钟”。") {
  if (state.preparation) clearTimeout(state.preparation);
  state.mode = "idle"; state.preparation = null; state.pendingMode = null; state.pendingDuration = 0;
  state.lastSecond = -1; state.runId += 1; stopButton.disabled = true;
  stopListening();
  modeLabel.textContent = "准备开始"; message.textContent = note;
}
function begin(mode, durationSeconds = 0) {
  if (state.mode === "preparing") clearTimeout(state.preparation);
  else if (state.mode !== "idle") stopAndRecord("新的开始命令");
  state.mode = mode; state.durationSeconds = durationSeconds; state.elapsed = 0; state.lastSecond = -1;
  state.preparation = null; state.pendingMode = null; state.pendingDuration = 0;
  state.startedAt = performance.now(); state.runId += 1; stopButton.disabled = false;
  modeLabel.textContent = mode === "countdown" ? "倒计时进行中" : "计时进行中";
  message.textContent = mode === "countdown" ? `剩余 ${formatWords(durationSeconds)}` : "每秒短滴；每 5 秒长滴。";
  update(state.runId);
}
function prepare(mode, durationSeconds = 0) {
  if (state.mode === "preparing") clearTimeout(state.preparation);
  else if (state.mode !== "idle") stopAndRecord("新的开始命令");
  state.mode = "preparing"; state.durationSeconds = durationSeconds; state.elapsed = 0;
  state.pendingMode = mode; state.pendingDuration = durationSeconds; state.runId += 1; stopButton.disabled = false;
  let remaining = 3;
  const cue = () => {
    if (remaining === 0) { state.preparation = null; begin(mode, durationSeconds); return; }
    modeLabel.textContent = "3 秒预备";
    display.textContent = `00:0${remaining}`;
    message.textContent = `${remaining} 秒后开始`;
    sound("chime", "announce");
    remaining -= 1;
    state.preparation = window.setTimeout(cue, 1000);
  };
  cue();
}
function update(runId) {
  if (runId !== state.runId || (state.mode !== "stopwatch" && state.mode !== "countdown")) return;
  state.elapsed = Math.floor((performance.now() - state.startedAt) / 1000);
  const visible = state.mode === "countdown" ? state.durationSeconds - state.elapsed : state.elapsed;
  if (state.mode === "countdown" && visible <= 0 && state.elapsed > 0) {
    display.textContent = "00:00";
    sound($("announce-sound").value, "announce"); speak("倒计时结束"); stopAndRecord("倒计时结束");
    return;
  }
  display.textContent = format(visible);
  if (state.elapsed !== state.lastSecond) {
    state.lastSecond = state.elapsed;
    if (state.elapsed > 0) {
      const isLongBeat = state.elapsed % 5 === 0;
      sound($(isLongBeat ? "tick-sound" : "beep-sound").value, isLongBeat ? "long" : "short");
      const interval = Math.max(1, Number($("announce-interval").value) || 15);
      if (state.elapsed % interval === 0) {
        sound($("announce-sound").value, "announce");
        speak(state.mode === "countdown" ? formatWords(visible) : `${state.elapsed} 秒`);
      }
    }
  }
  requestAnimationFrame(() => update(runId));
}
function history() { try { return JSON.parse(localStorage.getItem(storageKey) || "[]"); } catch { return []; } }
function renderHistory() {
  const records = history(); const list = $("history-list");
  list.innerHTML = "";
  if (!records.length) { list.innerHTML = '<li class="empty">还没有记录。</li>'; return; }
  records.forEach((item) => {
    const row = document.createElement("li");
    const label = document.createElement("strong");
    const details = document.createElement("span");
    label.textContent = item.label;
    details.textContent = item.valueText ?? `${item.count} 秒 · ${item.at}`;
    row.append(label, details); list.append(row);
  });
}
function stopAndRecord(reason = "手动停止") {
  if (state.mode === "idle") return;
  const isPreparing = state.mode === "preparing";
  if (!isPreparing) state.elapsed = Math.floor((performance.now() - state.startedAt) / 1000);
  const isCountdown = isPreparing ? state.pendingMode === "countdown" : state.mode === "countdown";
  const elapsedSeconds = Math.max(0, state.elapsed);
  const remainingSeconds = isCountdown ? Math.max(0, state.durationSeconds - elapsedSeconds) : null;
  const count = isCountdown ? remainingSeconds : elapsedSeconds;
  const countText = isCountdown ? `剩余 ${formatWords(remainingSeconds)}` : `已计时 ${elapsedSeconds} 秒`;
  const label = isCountdown ? `倒计时停止（${reason}）` : `计时停止（${reason}）`;
  const records = [{ label, count, elapsedSeconds, remainingSeconds, valueText: `${countText} · ${localTimestamp()}`, at: localTimestamp() }, ...history()].slice(0, 100);
  localStorage.setItem(storageKey, JSON.stringify(records));
  if ("speechSynthesis" in window && reason !== "倒计时结束") speechSynthesis.cancel();
  renderHistory(); setIdle(`已记录：${countText}。`);
}
function parseNumber(value) {
  if (/^\d+$/.test(value)) return Number(value);
  if (![...value].every((char) => char in numberWords || char in unitWords)) return NaN;
  if (![...value].some((char) => char in unitWords)) return Number([...value].map((char) => numberWords[char]).join(""));
  let total = 0; let section = 0; let digit = 0;
  for (const char of value) {
    if (char in numberWords) { digit = numberWords[char]; continue; }
    const unit = unitWords[char];
    if (unit === 10000) { total += (section + (digit || 1)) * unit; section = 0; digit = 0; }
    else { section += (digit || 1) * unit; digit = 0; }
  }
  return total + section + digit;
}
function countdownFromCommand(text) {
  const number = "[\\d零〇一二两三四五六七八九十百千万]+";
  const patterns = [
    new RegExp(`(?:开始)?倒计时(?:为|是)?(${number})(分钟|分|秒钟|秒)`),
    new RegExp(`(?:开始)?(${number})(分钟|分|秒钟|秒)(?:倒计时)?`)
  ];
  for (const pattern of patterns) {
    const match = text.match(pattern);
    if (!match) continue;
    const amount = parseNumber(match[1]);
    if (!Number.isFinite(amount) || amount < 1) return null;
    return Math.min(amount * (/分/.test(match[2]) ? 60 : 1), 86400);
  }
  return null;
}
function execute(command) {
  const text = command.replace(/[\s，。,.！!？?]/g, "");
  $("heard-command").textContent = `识别：${text || "（空）"}`;
  if (/停止/.test(text)) return stopAndRecord("语音停止");
  const durationSeconds = countdownFromCommand(text);
  if (durationSeconds) return prepare("countdown", durationSeconds);
  if (/开始计时|开始秒表/.test(text)) return prepare("stopwatch");
  message.textContent = "没有识别到命令。试试：开始计时、倒计时 90 秒、倒计时 3 分钟、停止。";
}
function startListening() {
  getAudio().resume();
  state.wantsListening = true;
  if (!state.recognition || state.isListening) return;
  try { state.recognition.start(); } catch { voiceStatus.textContent = "语音正在待命"; }
}
function setupRecognition() {
  const Recognition = window.SpeechRecognition || window.webkitSpeechRecognition;
  if (!Recognition) { voiceStatus.textContent = "浏览器不支持语音识别"; $("voice-button").disabled = true; return; }
  const recognition = new Recognition();
  recognition.lang = "zh-CN"; recognition.interimResults = false; recognition.continuous = true;
  recognition.onstart = () => { state.isListening = true; voiceStatus.textContent = "正在听…"; };
  recognition.onend = () => {
    state.isListening = false;
    if (!state.wantsListening) { voiceStatus.textContent = "麦克风已关闭"; return; }
    voiceStatus.textContent = "语音待命";
    window.setTimeout(startListening, 250);
  };
  recognition.onerror = (event) => {
    state.isListening = false;
    voiceStatus.textContent = event.error === "not-allowed" ? "请允许麦克风权限" : "语音未识别，继续待命";
    if (event.error === "not-allowed" || event.error === "service-not-allowed") {
      state.wantsListening = false;
    }
  };
  recognition.onresult = (event) => {
    for (let index = event.resultIndex; index < event.results.length; index += 1) {
      if (event.results[index].isFinal) execute(event.results[index][0].transcript);
    }
  };
  state.recognition = recognition;
}
function openSoundDatabase() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(soundDatabase, 1);
    request.onupgradeneeded = () => request.result.createObjectStore(soundStore);
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}
async function saveCustomSound(slot, file) {
  const db = await openSoundDatabase();
  await new Promise((resolve, reject) => {
    const request = db.transaction(soundStore, "readwrite").objectStore(soundStore).put({ name: file.name, blob: file }, slot);
    request.onsuccess = resolve; request.onerror = () => reject(request.error);
  });
  db.close();
}
async function loadCustomSounds() {
  try {
    const db = await openSoundDatabase();
    const entries = await Promise.all(["short", "long", "announce"].map((slot) => new Promise((resolve, reject) => {
      const request = db.transaction(soundStore).objectStore(soundStore).get(slot);
      request.onsuccess = () => resolve([slot, request.result]); request.onerror = () => reject(request.error);
    })));
    db.close();
    for (const [slot, saved] of entries) {
      if (!saved) continue;
      state.customSounds[slot] = { name: saved.name, buffer: await getAudio().decodeAudioData(await saved.blob.arrayBuffer()) };
      $("custom-" + slot + "-status").textContent = `已载入：${saved.name}`;
    }
  } catch { message.textContent = "无法载入已导入的提示音，将使用内置声音。"; }
}
function bindSoundUpload(slot) {
  $("custom-" + slot).addEventListener("change", async (event) => {
    const file = event.target.files[0];
    if (!file) return;
    try {
      const buffer = await getAudio().decodeAudioData(await file.arrayBuffer());
      state.customSounds[slot] = { name: file.name, buffer };
      await saveCustomSound(slot, file);
      $("custom-" + slot + "-status").textContent = `已导入：${file.name}`;
      const selector = $(slot === "short" ? "beep-sound" : slot === "long" ? "tick-sound" : "announce-sound");
      selector.value = "custom";
      message.textContent = `${file.name} 将作为${slot === "short" ? "短滴" : slot === "long" ? "长滴" : "报时"}提示音。`;
    } catch { $("custom-" + slot + "-status").textContent = "无法读取此音频文件"; }
  });
}

$("voice-button").onclick = startListening;
$("start-stopwatch").onclick = () => { getAudio().resume(); prepare("stopwatch"); };
document.querySelectorAll(".countdown-preset").forEach((button) => button.onclick = () => { getAudio().resume(); prepare("countdown", Number(button.dataset.minutes) * 60); });
$("start-countdown").onclick = () => { getAudio().resume(); prepare("countdown", Math.max(1, Number($("countdown-minutes").value) || 1) * 60); };
stopButton.onclick = () => stopAndRecord("手动停止");
$("clear-history").onclick = () => { localStorage.removeItem(storageKey); renderHistory(); };
$("more-button").onclick = () => $("more-dialog").showModal();
$("close-more").onclick = () => $("more-dialog").close();
$("more-dialog").addEventListener("click", (event) => { if (event.target === event.currentTarget) event.currentTarget.close(); });
["short", "long", "announce"].forEach(bindSoundUpload);
renderHistory(); setupRecognition(); loadCustomSounds();
if ("serviceWorker" in navigator) navigator.serviceWorker.register("./service-worker.js");
