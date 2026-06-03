// ═════════════════════════════════════════════════════════════════════════════
// Ludo King Bot — Core Logic
// ═════════════════════════════════════════════════════════════════════════════
//
// Flow:
//  1. Watch Firebase `ludoKingMatches` for new matches where botStatus is missing
//  2. Create a room in Ludo King via ADB
//  3. OCR the room code from the screenshot
//  4. Write the real room code + deepLink back to Firebase
//  5. The bot stays in the room (keeps it alive)
//  6. Watch for botLeave signal → leave the room
//
// Env vars:
//  FIREBASE_DATABASE_URL   — required
//  FIREBASE_SERVICE_JSON   — required (base64-encoded service account JSON)
//  LUDO_BOT_DEVICE_IP      — optional (e.g. 192.168.1.100:5555; omit for same-device/Termux mode)
//  LUDO_BOT_PACKAGE_NAME   — optional (default com.ludo.king)
//  LUDO_BOT_RECONNECT_SEC  — optional (default 30)

const admin = require("firebase-admin");
const { Adb } = require("./adb");
const { detectResolution } = require("./config");

const PKG = process.env.LUDO_BOT_PACKAGE_NAME || "com.ludo.king";
const RECONNECT_SEC = parseInt(process.env.LUDO_BOT_RECONNECT_SEC || "30", 10);
const MAX_OCR_RETRIES = 5;
const OCR_RETRY_DELAY_MS = 2000;

class LudoKingBot {
  constructor() {
    this.adb = new Adb();
    this.db = null;
    this.resolution = null;
    this.activeMatchId = null;
    this.running = false;
  }

  // ── Firebase init ──────────────────────────────────────────────────────────

  _initFirebase() {
    const dbUrl = process.env.FIREBASE_DATABASE_URL;
    if (!dbUrl) throw new Error("FIREBASE_DATABASE_URL is required");

    const serviceJson = process.env.FIREBASE_SERVICE_JSON;
    if (!serviceJson) throw new Error("FIREBASE_SERVICE_JSON is required (base64-encoded)");

    let serviceAccount;
    try {
      serviceAccount = JSON.parse(Buffer.from(serviceJson, "base64").toString("utf-8"));
    } catch {
      throw new Error("FIREBASE_SERVICE_JSON must be base64-encoded service account JSON");
    }

    if (admin.apps.length === 0) {
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        databaseURL: dbUrl,
      });
    }
    this.db = admin.database();
    console.log("✅ Firebase connected");
  }

  // ── Start ──────────────────────────────────────────────────────────────────

  async start() {
    this.running = true;
    this._initFirebase();

    const deviceIp = process.env.LUDO_BOT_DEVICE_IP;

    if (deviceIp) {
      // Remote ADB device
      console.log(`🔌 Connecting to ADB device: ${deviceIp}`);
      await this.adb.connect(deviceIp);
    } else {
      // Same-device mode (Termux) — auto-connect to local ADB
      console.log("📱 No LUDO_BOT_DEVICE_IP set — trying same-device ADB...");
      const ok = await this.adb.autoConnectLocal();
      if (!ok) {
        throw new Error(
          "Could not find an ADB device. For same-device mode:\n" +
          "  1. Enable Developer Options & Wireless Debugging\n" +
          "  2. Run: adb connect 127.0.0.1:<port>\n" +
          "  3. Or set LUDO_BOT_DEVICE_IP env var"
        );
      }
    }

    this.resolution = await detectResolution(this.adb);
    console.log(`📱 Device: ${this.resolution.width}x${this.resolution.height} (preset: ${this.resolution.key})`);

    // Kill any stale Ludo King session
    await this.adb.killApp(PKG);
    await this._sleep(1500);

    // Start watching Firebase
    this._watchMatches();
    console.log("👀 Watching for new Ludo King matches...");

    // Periodic health check — reconnect ADB if needed
    this._healthLoop();
  }

  stop() {
    this.running = false;
    if (this.activeMatchId) {
      this._stopWatchingMatch(this.activeMatchId);
    }
    this.adb.disconnect();
  }

  // ── Firebase watcher ───────────────────────────────────────────────────────

  _watchMatches() {
    const matchesRef = this.db.ref("ludoKingMatches");

    matchesRef.on("child_added", async (snap) => {
      if (!this.running) return;
      try {
        await this._handleNewMatch(snap.key, snap.val());
      } catch (e) {
        console.error(`❌ Error handling match ${snap.key}:`, e.message);
      }
    });
  }

  async _handleNewMatch(matchId, data) {
    // Only process matches that need a bot
    if (!data || data.botStatus || data.creationMethod === "manual" || data.status === "finished" || data.status === "cancelled") {
      return;
    }

    console.log(`\n🎯 New match detected: ${matchId}`);
    console.log(`   Host: ${data.hostName || "?"}  Players: ${Object.keys(data.players || {}).length}`);

    this.activeMatchId = matchId;
    const matchRef = this.db.ref(`ludoKingMatches/${matchId}`);

    try {
      // Step 1: Mark bot as busy
      await matchRef.update({ botStatus: "creating_room", botStartedAt: Date.now() });

      // Step 2: Create room in Ludo King
      const roomCode = await this._createRoom();

      // Step 3: Write room code + deep link back
      const deepLink = `https://lk.gggred.com/?rmc=${roomCode}&gt=0&po=0`;
      await matchRef.update({
        roomCode,
        deepLink,
        botStatus: "in_room",
        botRoomCode: roomCode,
        botJoinedAt: Date.now(),
      });
      console.log(`✅ Room created! Code: ${roomCode}`);
      console.log(`🔗 Deep link: ${deepLink}`);

      // Step 4: Watch for botLeave signal
      this._watchForLeave(matchId);

    } catch (e) {
      console.error(`❌ Failed to create room for ${matchId}:`, e.message);
      await matchRef.update({ botStatus: `error: ${e.message.substring(0, 80)}` });
      this.activeMatchId = null;
    }
  }

  // ── Room creation ──────────────────────────────────────────────────────────

  async _createRoom() {
    // Make sure Ludo King is open
    console.log("   Launching Ludo King...");
    await this.adb.killApp(PKG);
    await this._sleep(1000);
    await this.adb.launchApp(PKG);
    await this._sleep(4000);

    const R = this.resolution;
    const W = R.width;
    const H = R.height;

    // Tap "Play" / "Multiplayer" (main menu)
    console.log("   Tapping Play...");
    await this.adb.tapFraction(R.playBtn[0], R.playBtn[1], W, H);
    await this._sleep(2000);

    // Tap "Multiplayer" / "Online"
    console.log("   Tapping Multiplayer...");
    await this.adb.tapFraction(R.multiplayerBtn[0], R.multiplayerBtn[1], W, H);
    await this._sleep(2000);

    // Tap "Create Room" / "New Room"
    console.log("   Tapping Create Room...");
    await this.adb.tapFraction(R.createRoomBtn[0], R.createRoomBtn[1], W, H);
    await this._sleep(3000);

    // OCR: extract room code from screenshot
    console.log("   Reading room code via OCR...");
    const code = await this._ocrWithRetry(R.roomCodeRegion, W, H);
    if (!code) {
      throw new Error("OCR could not extract a valid room code after retries");
    }

    console.log(`   📋 Raw OCR result: ${code}`);

    // Validate code format
    if (!this.adb.isValidRoomCode(code)) {
      // Try again after a longer wait
      console.warn("   ⚠️  Invalid code format, retrying once more...");
      await this._sleep(3000);
      const code2 = await this._ocrWithRetry(R.roomCodeRegion, W, H);
      if (!code2 || !this.adb.isValidRoomCode(code2)) {
        throw new Error(`OCR returned invalid code: ${code2 || code}`);
      }
      return code2;
    }

    return code;
  }

  async _ocrWithRetry(cropRegion, width, height) {
    for (let i = 0; i < MAX_OCR_RETRIES; i++) {
      const code = await this.adb.extractRoomCode(cropRegion, width, height);
      if (code && this.adb.isValidRoomCode(code)) {
        return code;
      }
      console.log(`   OCR attempt ${i + 1}/${MAX_OCR_RETRIES}: "${code || "(empty)"}"`);
      await this._sleep(OCR_RETRY_DELAY_MS);
    }
    return null;
  }

  // ── Leave detection ────────────────────────────────────────────────────────

  _watchForLeave(matchId) {
    const leaveRef = this.db.ref(`ludoKingMatches/${matchId}/botLeave`);

    const listener = leaveRef.on("value", async (snap) => {
      if (!this.running) return;

      if (snap.val() === true) {
        console.log(`🚪 Bot leave signal received for ${matchId}`);
        leaveRef.off("value", listener);

        try {
          // Press back to leave the room
          await this.adb.back();
          await this._sleep(1000);
          await this.adb.back();  // Back to main menu
          await this._sleep(500);

          // Close Ludo King
          await this.adb.killApp(PKG);

          await this.db.ref(`ludoKingMatches/${matchId}`).update({
            botStatus: "departed",
            botDepartedAt: Date.now(),
          });
          console.log(`✅ Bot left room ${matchId}`);

          if (this.activeMatchId === matchId) {
            this.activeMatchId = null;
          }
        } catch (e) {
          console.error(`❌ Error leaving room ${matchId}:`, e.message);
        }
      }
    });
  }

  _stopWatchingMatch(matchId) {
    this.db.ref(`ludoKingMatches/${matchId}/botLeave`).off();
  }

  // ── Health check ───────────────────────────────────────────────────────────

  _healthLoop() {
    setInterval(async () => {
      try {
        const online = await this.adb.isOnline();
        if (!online && this.running) {
          console.warn("⚠️  ADB device offline. Reconnecting...");
          const ip = process.env.LUDO_BOT_DEVICE_IP || this.adb.deviceIp;
          if (ip) {
            try { await this.adb.connect(ip); } catch (e) {
              console.error("❌ Reconnect failed:", e.message);
            }
          } else {
            console.warn("⚠️  No device IP configured, cannot reconnect");
          }
        }
      } catch (e) {
        console.error("⚠️  Health check error:", e.message);
      }
    }, RECONNECT_SEC * 1000);

    // Also: periodically check Firebase for stale matches where bot is "creating_room"
    // but the process never completed (server restart, crash, etc.)
    setInterval(() => {
      this._cleanupStaleMatches();
    }, 60000);
  }

  async _cleanupStaleMatches() {
    try {
      const snap = await this.db.ref("ludoKingMatches")
        .orderByChild("botStatus")
        .equalTo("creating_room")
        .once("value");

      if (!snap.exists()) return;

      const now = Date.now();
      const staleTimeout = 120000;  // 2 minutes

      snap.forEach((child) => {
        const data = child.val();
        if (data.botStartedAt && (now - data.botStartedAt > staleTimeout)) {
          console.warn(`🧹 Cleaning stale match: ${child.key}`);
          child.ref.update({ botStatus: "stale_timeout" });
        }
      });
    } catch (e) {
      // ignore
    }
  }

  // ── Utility ────────────────────────────────────────────────────────────────

  _sleep(ms) {
    return new Promise((r) => setTimeout(r, ms));
  }
}

module.exports = { LudoKingBot };
