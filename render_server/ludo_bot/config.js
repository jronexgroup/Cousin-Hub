// Screen coordinate presets for Ludo King automation.
// Key:  "${width}x${height}"
// Values: tap points as {x, y} fractions of screen (0–1).
//
// To create a new preset:
//   1. Take a screenshot of Ludo King's main menu
//   2. Note the pixel coordinates of each button
//   3. Convert to fractions: x/width, y/height
//
// Built-in presets:
const PRESETS = {

  // 1080×1920 (most common 9:16 phone)
  "1080x1920": {
    playBtn:          [0.50, 0.75],
    multiplayerBtn:   [0.50, 0.50],
    createRoomBtn:    [0.50, 0.55],
    roomCodeRegion:   [0.25, 0.35, 0.75, 0.50],   // left, top, right, bottom (fractions)
    backBtn:          [0.05, 0.04],
    inviteFriendsBtn: [0.50, 0.62],
  },

  // 720×1280 (smaller 9:16)
  "720x1280": {
    playBtn:          [0.50, 0.72],
    multiplayerBtn:   [0.50, 0.48],
    createRoomBtn:    [0.50, 0.53],
    roomCodeRegion:   [0.22, 0.32, 0.78, 0.48],
    backBtn:          [0.05, 0.05],
    inviteFriendsBtn: [0.50, 0.60],
  },

  // 1440×2560 (high-res 9:16)
  "1440x2560": {
    playBtn:          [0.50, 0.76],
    multiplayerBtn:   [0.50, 0.50],
    createRoomBtn:    [0.50, 0.55],
    roomCodeRegion:   [0.26, 0.33, 0.74, 0.50],
    backBtn:          [0.04, 0.04],
    inviteFriendsBtn: [0.50, 0.63],
  },
};

// ── Resolution auto-detect ────────────────────────────────────────────────────

async function detectResolution(adb) {
  const raw = await adb.exec("shell wm size");
  const m = raw.trim().match(/(\d+)x(\d+)/);
  if (!m) throw new Error(`Cannot detect resolution from: ${raw}`);
  const w = parseInt(m[1], 10);
  const h = parseInt(m[2], 10);
  const key = `${w}x${h}`;

  let preset = PRESETS[key];
  if (!preset) {
    // Fallback: find closest aspect-ratio match
    const ratio = w / h;
    const candidates = Object.entries(PRESETS).map(([k, v]) => {
      const [pw, ph] = k.split("x").map(Number);
      return { key: k, preset: v, diff: Math.abs(pw / ph - ratio) };
    });
    candidates.sort((a, b) => a.diff - b.diff);
    preset = candidates[0].preset;
    console.warn(`⚠️  No exact preset for ${key}. Using closest: ${candidates[0].key}`);
  }

  return { width: w, height: h, key, ...preset };
}

module.exports = { PRESETS, detectResolution };
