# Cousin Hub — Setup Guide

## Overview

Cousin Hub is a private family social app with a built-in Ludo King integration. This guide covers two parts:

- **Phase A** — Flutter app (Android)
- **Phase B** — Ludo Bot server (Node.js + ADB + OCR)

---

## Phase A: Flutter App

### Prerequisites

- Flutter SDK 3.44+ (`flutter --version`)
- Android SDK (API 31+)
- A Firebase project with Realtime Database and FCM enabled
- Service account JSON from Firebase Console

### Setup

```bash
# 1. Clone and install dependencies
git clone <your-repo>
cd Cousin-Hub
flutter pub get

# 2. Create .env or configure Firebase
#    Place your `google-services.json` in android/app/

# 3. Build APK
flutter build apk --release
```

### Firebase Realtime Database Structure

```
users/{uid}/
  ├── name, nickname, photoUrl, fcmToken
  └── ludoKingStats/
       ├── xp: int
       ├── wins: int
       ├── matches: int
       └── bestRank: int

ludoKingMatches/{matchId}/
  ├── hostUid, hostName
  ├── status: "waiting" | "finished" | "cancelled"
  ├── roomCode: string          ← bot writes this
  ├── deepLink: string           ← bot writes this
  ├── botStatus: string          ← bot writes this
  ├── botLeave: bool             ← host sets this
  ├── createdAt: timestamp
  └── players/{uid}/
       ├── name, status, joinedAt

ludoKingInvites/{uid}/{matchId}/
  ├── matchId, hostName, hostPhoto, timestamp

ludoKingResults/{matchId}/
  ├── roomCode, hostUid, hostName, date
  └── players/{uid}/
       ├── name, rank, xpEarned

notifications/  ← queued FCM notifications (sent by render_server/server.js)
  ├── toToken, title, body, data, sent, timestamp
```

---

## Phase B: Ludo Bot Server

The bot creates Ludo King rooms on a real Android phone via ADB over WiFi, reads the room code via OCR, and writes it to Firebase.

### How It Works

```
┌──────────────┐     1. New match        ┌─────────────────┐
│  Cousin Hub  │ ──── created ──────────→│  Firebase RTDB   │
│  (Flutter)   │                          │  ludoKingMatches │
└──────────────┘                          └────────┬────────┘
                                                   │ 2. Bot detects match
                                                   ▼
                                          ┌─────────────────┐
                                          │  Ludo Bot Server │
                                          │  (Node.js)       │
                                          └────────┬────────┘
                                                   │ 3. ADB over WiFi
                                                   ▼
                                          ┌─────────────────┐
                                          │  Android Phone   │
                                          │  (Ludo King app) │
                                          └────────┬────────┘
                                                   │ 4. OCR reads room code
                                                   ▼
                                          ┌─────────────────┐
                                          │  6-char code     │
                                          │  e.g. "AB3X9K"   │
                                          └────────┬────────┘
                                                   │ 5. Writes to Firebase
                                                   ▼
                                          ┌─────────────────┐
                                          │  Firebase RTDB   │
                                          │  roomCode +      │
                                          │  deepLink written│
                                          └────────┬────────┘
                                                   │ 6. Flutter app sees code
                                                   ▼
                                          ┌─────────────────┐
                                          │  Host opens      │
                                          │  lk.gggred.com/  │
                                          │  ?rmc=CODE...    │
                                          └─────────────────┘
```

### Prerequisites

- Android phone with:
  - Developer Options enabled (tap Build Number 7×)
  - USB Debugging enabled
  - Ludo King app installed
- Same WiFi network for phone and server
- Node.js 18+ on the server

### Step 1: Enable ADB over WiFi on the Phone

```bash
# 1. Connect phone via USB to any computer
# 2. Grant USB debugging permission on phone
# 3. Run:
adb tcpip 5555

# 4. Disconnect USB cable
# 5. Find phone's IP address:
#    Settings → About Phone → Status → IP Address
#    Or: adb shell ip addr show wlan0 | grep inet
```

### Step 2: Set Up the Bot Server

```bash
cd render_server/ludo_bot
npm install

# Run the automated ADB setup script:
bash scripts/setup_adb.sh 192.168.1.100
# (replace 192.168.1.100 with your phone's IP)
```

### Step 3: Configure Environment

```bash
export FIREBASE_DATABASE_URL="https://cousin-hub-default-rtdb.asia-southeast1.firebasedatabase.app"
export FIREBASE_SERVICE_JSON="$(cat /path/to/service-account.json | base64 -w0)"
export LUDO_BOT_DEVICE_IP="192.168.1.100:5555"
```

Optional vars:

| Variable | Default | Description |
|----------|---------|-------------|
| `LUDO_BOT_PACKAGE_NAME` | `com.ludo.king` | Ludo King app package |
| `LUDO_BOT_RECONNECT_SEC` | `30` | ADB health check interval (seconds) |

### Step 4: Start the Bot

```bash
node index.js
```

You should see:

```
✅ Firebase connected
🔌 Connecting to ADB device: 192.168.1.100:5555
📱 Device: 1080x1920 (preset: 1080x1920)
👀 Watching for new Ludo King matches...
```

### Step 5: (Optional) Calibrate Screen Coordinates

If the default presets don't match your phone's resolution or Ludo King layout:

```bash
node scripts/calibrate.js 192.168.1.100:5555
```

Follow the prompts — you'll tap each button on your phone and enter the coordinates.

### Step 6: Deploy on Render

1. Push the `render_server/ludo_bot` folder to a GitHub repo
2. Create a new Web Service on render.com
3. Set:
   - **Root Directory**: `render_server/ludo_bot`
   - **Build Command**: `npm install`
   - **Start Command**: `node index.js`
4. Add the environment variables above
5. Deploy

> **Important**: Render free tier can't do ADB-over-WiFi directly. You have two options:
> - **Option A**: Run the bot on a cheap VPS (Linode, DigitalOcean, Hetzner — \$5/mo)
> - **Option B**: Run the bot locally on your own machine with UptimeRobot pinging it
> - **Option C**: Render does work — keep the phone connected via ADB over WiFi on the same LAN as Render's servers (your home network)

---

## Flow: End to End

```
1. Host opens Flutter app → Ludo King (Official) → Create Match
2. Firebase gets: ludoKingMatches/{matchId} with status:"waiting"
3. Bot detects match → opens Ludo King on phone via ADB
4. Bot taps: Play → Multiplayer → Create Room
5. Bot takes screenshot → OCR extracts room code
6. Bot writes roomCode + deepLink to Firebase
7. Firebase notifies all invited cousins
8. Host sees room code in lobby → taps "Open Ludo King & Join Room"
9. `lk.gggred.com/?rmc=CODE&gt=0&po=0` opens and auto-joins room
10. Cousins do the same
11. When ready, host taps "Bot Leave Room" → bot leaves
12. After match, host declares results (1st/2nd/3rd/4th)
13. XP is awarded and leaderboard updates
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `adb: command not found` | Install: `apt install android-tools-adb` (or `brew install android-platform-tools`) |
| `adb connect failed` | Check phone is on same network. Re-run `adb tcpip 5555` via USB. |
| `unauthorized` device | Accept the RSA fingerprint on the phone screen. |
| OCR returns wrong code | Run calibration: `node scripts/calibrate.js <ip>` |
| Bot doesn't start | Check all 3 env vars are set correctly |
| Flutter build fails | Run `flutter clean && flutter pub get` first |
