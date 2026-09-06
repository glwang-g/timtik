const $ = (id) => document.getElementById(id);
const storageKey = "timtik.history.v1";
const state = { mode: "idle", startedAt: 0, durationSeconds: 0, elapsed: 0, lastSecond: -1, preparation: null, recognition: null };
let audioContext;

const display = $("time-display");
const message = $("timer-message");
const modeLabel = $("mode-label");
const stopButton = $("stop-button");
const voiceStatus = $("voice-status");

function format(seconds) {
  const whole = Math.max(0, Math.floor(seconds));
  return `${String(Math.floor(whole / 60)).padStart(2, "0")}:${String(whole % 60).padStart(2, "0")}`;
}
function getAudio() { audioContext ??= new AudioContext(); return audioContext; }
function sound(kind) {
  if (kind === "none") return;
  const ctx = getAudio();
  const oscillator = ctx.createOscillator();
  const gain = ctx.createGain();
  const options = { beep: [880, "sine", 0.06], soft: [660, "sine", 0.1], tick: [190, "triangle", 0.045], click: [340, "square", 0.025], chime: [1047, "sine", 0.24] }[kind] ?? [880, "sine", 0.06];
  oscillator.frequency.value = options[0]; oscillator.type = options[1];
  gain.gain.setValueAtTime(Number($("volume").value) / 100 * 0.2, ctx.currentTime);
  gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + options[2]);
  oscillator.connect(gain).connect(ctx.destination); oscillator.start(); oscillator.stop(ctx.currentTime + options[2]);
}
function speak(text) {
  if (!("speechSynthesis" in window)) return;
  speechSynthesis.cancel();
  const utterance = new SpeechSynthesisUtterance(text); utterance.lang = "zh-CN"; utterance.rate = 1.05; speechSynthesis.speak(utterance);
}
function setIdle(note = "说“开始计时”或“开始 3 分钟倒计时”。") {
  state.mode = "idle"; state.preparation = null; state.lastSecond = -1; stopButton.disabled = true;
  modeLabel.textContent = "准备开始"; message.textContent = note;
}
function begin(mode, durationSeconds = 0) {
  state.mode = mode; state.durationSeconds = durationSeconds; state.elapsed = 0; state.lastSecond = -1; state.startedAt = performance.now(); stopButton.disabled = false;
  modeLabel.textContent = mode === "countdown" ? "倒计时进行中" : "计时进行中";
  message.textContent = mode === "countdown" ? `剩余 ${format(durationSeconds)}` : "每秒滴声，每 5 秒嗒声。";
  update();
}
function prepare(mode, durationSeconds = 0) {
  if (state.mode !== "idle") stopAndRecord("新的开始命令");
  state.mode = "preparing"; state.durationSeconds = durationSeconds; state.elapsed = 0; stopButton.disabled = false;
  let count = 3; modeLabel.textContent = "3 秒预备";
  const cue = () => { display.textContent = `00:0${count}`; message.textContent = `${count} 秒后开始`; sound("chime"); count -= 1; if (count === 0) { clearInterval(state.preparation); state.preparation = null; begin(mode, durationSeconds); } };
  cue(); state.preparation = setInterval(cue, 1000);
}
function update() {
  if (state.mode !== "stopwatch" && state.mode !== "countdown") return;
  state.elapsed = Math.floor((performance.now() - state.startedAt) / 1000);
  const visible = state.mode === "countdown" ? state.durationSeconds - state.elapsed : state.elapsed;
  display.textContent = format(visible);
  if (visible < 0 || (state.mode === "countdown" && visible === 0 && state.elapsed > 0)) { display.textContent = "00:00"; sound("chime"); speak("倒计时结束"); stopAndRecord("倒计时结束"); return; }
  if (state.elapsed !== state.lastSecond) {
    state.lastSecond = state.elapsed;
    if (state.elapsed > 0) sound($("beep-sound").value);
    if (state.elapsed > 0 && state.elapsed % 5 === 0) sound($("tick-sound").value);
    const interval = Math.max(1, Number($("announce-interval").value) || 15);
    if (state.elapsed > 0 && state.elapsed % interval === 0) { sound($("announce-sound").value); speak(state.mode === "countdown" ? `剩余 ${Math.max(0, visible)} 秒` : `${state.elapsed} 秒`); }
  }
  requestAnimationFrame(update);
}
function history() { try { return JSON.parse(localStorage.getItem(storageKey) || "[]"); } catch { return []; } }
function renderHistory() {
  const records = history(); const list = $("history-list");
  list.innerHTML = records.length ? records.map((item) => `<li><strong>${item.label}</strong><span>${item.count} 秒 · ${item.at}</span></li>`).join("") : '<li class="empty">还没有记录。</li>';
}
function stopAndRecord(reason = "手动停止") {
  if (state.mode === "idle") return;
  if (state.preparation) clearInterval(state.preparation);
  const count = state.mode === "countdown" ? Math.max(0, state.durationSeconds - state.elapsed) : state.elapsed;
  const label = state.mode === "countdown" ? `倒计时停止（${reason}）` : `计时停止（${reason}）`;
  const records = [{ label, count, at: new Date().toLocaleString("zh-CN", { hour12: false }) }, ...history()].slice(0, 100);
  localStorage.setItem(storageKey, JSON.stringify(records)); renderHistory(); setIdle(`已记录：${count} 秒。`);
}
function execute(command) {
  const text = command.replace(/\s/g, ""); $("heard-command").textContent = `识别：${text || "（空）"}`;
  if (/停止(计时|倒计时)?/.test(text)) return stopAndRecord("语音停止");
  const match = text.match(/开始(?:倒计时)?(\d+)(?:分钟|分)(?:倒计时)?/);
  if (match) return prepare("countdown", Number(match[1]) * 60);
  if (/开始计时|开始秒表/.test(text)) return prepare("stopwatch");
  message.textContent = "没有识别到命令。试试：开始计时、开始 3 分钟倒计时、停止计时。";
}
function setupRecognition() {
  const Recognition = window.SpeechRecognition || window.webkitSpeechRecognition;
  if (!Recognition) { voiceStatus.textContent = "此浏览器请使用下方按钮"; return; }
  const recognition = new Recognition(); recognition.lang = "zh-CN"; recognition.interimResults = false; recognition.continuous = false;
  recognition.onstart = () => voiceStatus.textContent = "正在听…";
  recognition.onend = () => voiceStatus.textContent = "语音待命";
  recognition.onerror = () => voiceStatus.textContent = "语音未识别，请重试";
  recognition.onresult = (event) => execute(event.results[0][0].transcript);
  state.recognition = recognition;
}
$("voice-button").onclick = () => { getAudio().resume(); state.recognition?.start(); };
$("start-stopwatch").onclick = () => { getAudio().resume(); prepare("stopwatch"); };
document.querySelectorAll(".countdown-preset").forEach((button) => button.onclick = () => { getAudio().resume(); prepare("countdown", Number(button.dataset.minutes) * 60); });
$("start-countdown").onclick = () => { getAudio().resume(); prepare("countdown", Math.max(1, Number($("countdown-minutes").value) || 1) * 60); };
stopButton.onclick = () => stopAndRecord("手动停止");
$("clear-history").onclick = () => { localStorage.removeItem(storageKey); renderHistory(); };
renderHistory(); setupRecognition();
if ("serviceWorker" in navigator) navigator.serviceWorker.register("./service-worker.js");
