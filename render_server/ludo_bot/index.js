#!/usr/bin/env node
// ═════════════════════════════════════════════════════════════════════════════
// Ludo King Bot — Entry Point
// ═════════════════════════════════════════════════════════════════════════════
//
// Creates Ludo King rooms on a real Android phone via ADB + OCR
// and manages them through Firebase Realtime Database.
//
// Usage:
//   FIREBASE_DATABASE_URL="..." \
//   FIREBASE_SERVICE_JSON="$(cat service-account.json | base64 -w0)" \
//   LUDO_BOT_DEVICE_IP="192.168.1.100:5555" \
//   node index.js
//
// or via Render:
//   Set the env vars in the Render dashboard → deploy this folder

const { LudoKingBot } = require("./bot");

// ── Validate env ──────────────────────────────────────────────────────────────

const REQUIRED = ["FIREBASE_DATABASE_URL", "FIREBASE_SERVICE_JSON", "LUDO_BOT_DEVICE_IP"];
for (const key of REQUIRED) {
  if (!process.env[key]) {
    console.error(`❌ Missing required env var: ${key}`);
    console.error("");
    console.error("   Required:");
    console.error("     FIREBASE_DATABASE_URL    — Firebase RTDB URL");
    console.error("     FIREBASE_SERVICE_JSON    — base64-encoded service account JSON");
    console.error("     LUDO_BOT_DEVICE_IP       — ADB-over-WiFi IP:port of the phone");
    console.error("");
    console.error("   Optional:");
    console.error("     LUDO_BOT_PACKAGE_NAME    — Ludo King package (default: com.ludo.king)");
    console.error("     LUDO_BOT_RECONNECT_SEC   — ADB health-check interval (default: 30)");
    console.error("");
    process.exit(1);
  }
}

// ── Start ─────────────────────────────────────────────────────────────────────

const bot = new LudoKingBot();

process.on("SIGINT", () => {
  console.log("\n🛑 Shutting down...");
  bot.stop();
  process.exit(0);
});

process.on("SIGTERM", () => {
  console.log("\n🛑 Shutting down...");
  bot.stop();
  process.exit(0);
});

process.on("uncaughtException", (e) => {
  console.error("💥 Uncaught exception:", e);
});

process.on("unhandledRejection", (e) => {
  console.error("💥 Unhandled rejection:", e);
});

bot.start().catch((e) => {
  console.error("❌ Fatal error:", e.message);
  process.exit(1);
});
