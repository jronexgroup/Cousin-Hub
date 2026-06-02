#!/usr/bin/env node
// ── Calibration tool ──────────────────────────────────────────────────────────
// Guides you through finding button coordinates on your device.
// Run: node scripts/calibrate.js <device-ip>
//
// For each button:
//   1. An image of the expected screen is shown
//   2. You tap the button on your phone
//   3. The coordinates are recorded
//
// After calibration, paste the result into config.js

const { Adb } = require("../adb");
const readline = require("readline");

const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
const prompt = (q) => new Promise((r) => rl.question(q, r));

const STEPS = [
  { name: "playBtn",          desc: "Main menu → tap the 'Play' or 'Multiplayer' button" },
  { name: "multiplayerBtn",   desc: "After tapping Play → tap 'Multiplayer' or 'Online'" },
  { name: "createRoomBtn",    desc: "After tapping Multiplayer → tap 'Create Room' / 'New Room'" },
  { name: "roomCodeRegion",   desc: "Take a screenshot. The room code appears where? Enter as: leftFrac topFrac rightFrac bottomFrac (e.g. 0.25 0.35 0.75 0.50)" },
  { name: "backBtn",          desc: "Top-left back button coordinates" },
  { name: "inviteFriendsBtn", desc: "The 'Invite Friends' button coordinates (if visible)" },
];

async function main() {
  const deviceIp = process.argv[2];
  if (!deviceIp) {
    console.error("Usage: node scripts/calibrate.js <device-ip>");
    console.error("  e.g. node scripts/calibrate.js 192.168.1.100:5555");
    process.exit(1);
  }

  const adb = new Adb();
  console.log(`🔌 Connecting to ${deviceIp}...`);
  await adb.connect(deviceIp);

  // Get resolution
  const raw = await adb.exec("shell wm size");
  const m = raw.trim().match(/(\d+)x(\d+)/);
  if (!m) { console.error("Cannot detect resolution"); process.exit(1); }
  const w = parseInt(m[1], 10);
  const h = parseInt(m[2], 10);
  console.log(`📱 Resolution: ${w}x${h}`);

  console.log("\n═══════════════════════════════════════════");
  console.log("  Ludo King Bot — Screen Calibration");
  console.log("═══════════════════════════════════════════\n");
  console.log(`First, open Ludo King on your phone.`);
  console.log(`Then follow each step.\n`);

  const result = {};

  for (const step of STEPS) {
    console.log(`\n── ${step.name} ──────────────────────────`);
    console.log(`  ${step.desc}`);

    if (step.name === "roomCodeRegion") {
      // Manual entry
      const ans = await prompt("  Enter fractions (left top right bottom): ");
      const parts = ans.trim().split(/\s+/).map(Number);
      if (parts.length === 4 && parts.every((n) => !isNaN(n))) {
        result[step.name] = parts;
      } else {
        console.log("  Invalid. Using default 0.25 0.35 0.75 0.50");
        result[step.name] = [0.25, 0.35, 0.75, 0.50];
      }
    } else {
      await prompt("  Position your finger on the button, then press Enter");
      const rawPos = await adb.exec("shell getevent -l 2>/dev/null | head -20 || echo ''");
      // Alternative: use dumpsys input to get the last touch coordinates
      const lastTouch = await adb.exec("shell dumpsys input | grep 'TouchDown\\|TouchPosition' | tail -5");
      console.log(`  Raw touch data: ${lastTouch || "(no touch data — will prompt for manual entry)"}`);

      const ans = await prompt("  Enter x y coordinates in pixels (or press Enter to use finger): ");
      if (ans.trim()) {
        const [cx, cy] = ans.trim().split(/\s+/).map(Number);
        result[step.name] = [cx / w, cy / h];
        console.log(`  Recorded: (${(cx/w).toFixed(3)}, ${(cy/h).toFixed(3)})`);
      } else {
        // Try to read from /proc
        const proc = await adb.exec("shell cat /proc/last_touch 2>/dev/null || echo ''");
        console.log(`  Proc data: ${proc || "(not available)"}`);
        console.log("  Could not detect. Enter manually.");
        const manual = await prompt("  Enter x y in pixels: ");
        const [mx, my] = manual.trim().split(/\s+/).map(Number);
        result[step.name] = [mx / w, my / h];
        console.log(`  Recorded: (${(mx/w).toFixed(3)}, ${(my/h).toFixed(3)})`);
      }
    }
  }

  console.log("\n\n═══════════════════════════════════════════");
  console.log("  Your Calibration Preset");
  console.log("═══════════════════════════════════════════\n");
  console.log(`"${w}x${h}": {`);
  for (const [k, v] of Object.entries(result)) {
    const val = Array.isArray(v) ? `[${v.map((n) => n.toFixed(3)).join(", ")}]` : JSON.stringify(v);
    console.log(`  ${k}: ${val},`);
  }
  console.log("},");

  adb.disconnect();
  rl.close();
}

main().catch((e) => { console.error(e); process.exit(1); });
