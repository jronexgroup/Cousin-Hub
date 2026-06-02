const { execSync, exec } = require("child_process");
const fs = require("fs");
const path = require("path");
const os = require("os");
const sharp = require("sharp");
const Tesseract = require("tesseract.js");

const TMP = path.join(os.tmpdir(), "ludo_bot");

// ── Wrapper ───────────────────────────────────────────────────────────────────

class Adb {
  constructor(deviceIp = null) {
    this.deviceIp = deviceIp;  // e.g. "192.168.1.100:5555"
    this.serial = null;
    if (!fs.existsSync(TMP)) fs.mkdirSync(TMP, { recursive: true });
  }

  _prefix() {
    return this.serial ? `-s ${this.serial}` : "";
  }

  async exec(cmd, timeout = 30000) {
    const full = `adb ${this._prefix()} ${cmd}`;
    try {
      return execSync(full, { encoding: "utf-8", timeout, stdio: ["pipe", "pipe", "pipe"] }).trim();
    } catch (e) {
      throw new Error(`ADB error: ${full}\n${e.stderr?.toString?.() || e.message}`);
    }
  }

  // ── Connection ──────────────────────────────────────────────────────────────

  async connect(ip) {
    this.deviceIp = ip;
    const out = execSync(`adb connect ${ip}`, { encoding: "utf-8", timeout: 10000 });
    if (out.includes("failed") || out.includes("cannot connect")) {
      throw new Error(`ADB connect failed: ${out}`);
    }
    // Find the serial (usually the IP:port)
    const list = execSync("adb devices", { encoding: "utf-8", timeout: 5000 });
    for (const line of list.split("\n")) {
      if (line.includes(ip) && line.includes("device")) {
        this.serial = line.split(/\s+/)[0].trim();
        break;
      }
    }
    if (!this.serial) throw new Error(`Device ${ip} not found in adb devices`);
    console.log(`✅ ADB connected: ${this.serial}`);
    return this.serial;
  }

  disconnect() {
    if (this.deviceIp) {
      try { execSync(`adb disconnect ${this.deviceIp}`, { encoding: "utf-8", timeout: 5000 }); } catch (_) {}
    }
  }

  async isOnline() {
    try {
      const out = await this.exec("get-state", 5000);
      return out === "device";
    } catch { return false; }
  }

  // ── Screen interactions ─────────────────────────────────────────────────────

  async tap(x, y) {
    await this.exec(`shell input tap ${Math.round(x)} ${Math.round(y)}`);
  }

  async tapFraction(fx, fy, width, height) {
    await this.tap(fx * width, fy * height);
  }

  async swipe(x1, y1, x2, y2, ms = 300) {
    await this.exec(`shell input swipe ${Math.round(x1)} ${Math.round(y1)} ${Math.round(x2)} ${Math.round(y2)} ${ms}`);
  }

  async screenshot() {
    const remotePath = "/sdcard/ludo_bot_screen.png";
    const localPath = path.join(TMP, `screen_${Date.now()}.png`);
    await this.exec(`shell screencap -p ${remotePath}`);
    await this.exec(`pull ${remotePath} ${localPath}`);
    await this.exec(`shell rm ${remotePath}`);
    return localPath;
  }

  async screenshotBuffer() {
    const p = await this.screenshot();
    return fs.readFileSync(p);
  }

  async type(text) {
    // Use escape for special chars
    const safe = text.replace(/ /g, "%s").replace(/&/g, "\\&");
    await this.exec(`shell input text "${safe}"`);
  }

  async keyevent(key) {
    await this.exec(`shell input keyevent ${key}`);
  }

  // HOME, BACK, etc.
  async home() { await this.keyevent(3); }
  async back() { await this.keyevent(4); }

  // ── App management ──────────────────────────────────────────────────────────

  async launchApp(pkg = "com.ludo.king") {
    await this.exec(`shell monkey -p ${pkg} -c android.intent.category.LAUNCHER 1`);
  }

  async killApp(pkg = "com.ludo.king") {
    await this.exec(`shell am force-stop ${pkg}`);
  }

  async isAppRunning(pkg = "com.ludo.king") {
    const out = await this.exec(`shell pidof ${pkg}`, 5000);
    return out.length > 0;
  }

  // ── OCR ─────────────────────────────────────────────────────────────────────

  async extractRoomCode(cropRegion, width, height) {
    // cropRegion: [leftFrac, topFrac, rightFrac, bottomFrac]
    const [l, t, r, b] = cropRegion;
    const bx = Math.round(l * width);
    const by = Math.round(t * height);
    const bw = Math.round((r - l) * width);
    const bh = Math.round((b - t) * height);
    const screenPath = await this.screenshot();
    const croppedPath = path.join(TMP, `crop_${Date.now()}.png`);

    await sharp(screenPath)
      .extract({ left: bx, top: by, width: bw, height: bh })
      .grayscale()
      .normalize()
      .sharpen()
      .toFile(croppedPath);

    const { data: { text } } = await Tesseract.recognize(croppedPath, "eng", {
      tessedit_char_whitelist: "ABCDEFGHJKLMNPQRSTUVWXYZ23456789",
      logger: () => {},
    });

    // Extract a 6-char alphanumeric code (uppercase, no 0/O/1/I)
    const codes = text.match(/[A-HJ-NP-Z2-9]{5,8}/g);
    const result = codes ? codes[0].substring(0, 6) : null;

    // Cleanup temp files
    try { fs.unlinkSync(screenPath); } catch (_) {}
    try { fs.unlinkSync(croppedPath); } catch (_) {}

    return result;
  }

  // ── Room code validation ────────────────────────────────────────────────────

  isValidRoomCode(code) {
    return /^[A-HJ-NP-Z2-9]{6}$/.test(code);
  }
}

module.exports = { Adb };
