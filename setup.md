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

The bot creates Ludo King rooms on an Android phone, reads the room code via OCR, and writes it to Firebase so cousins can join.

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

### Two Ways to Run the Bot

| Approach | What you need | Best for |
|----------|--------------|----------|
| **A) Same device (Termux)** — bot + Ludo King on one old phone | Just the phone | Most people — zero cost, no separate server |
| **B) Separate server** — bot on a VPS/computer, Ludo King on phone | Phone + computer/VPS | If you already have a server running |

---

## Approach A: Same-Device Mode (Termux) — Recommended

Run the bot and Ludo King on the **same old Android phone**. No separate computer or VPS needed.

### How it works

Termux (a terminal emulator) runs the Node.js bot. The phone connects to itself via Android's **Wireless Debugging** feature, giving the bot permission to tap the screen, take screenshots, and launch Ludo King — all programmatically on the same device.

### Prerequisites

- An old Android phone (Android 8+)
- **Termux** installed from **[F-Droid](https://f-droid.org/en/packages/com.termux/)** — the Play Store version is abandoned and will NOT work
- **Ludo King** app installed on the same phone
- Developer Options enabled (tap "Build Number" 7× in Settings → About Phone)
- The phone must be on **WiFi** (Wireless Debugging disables on mobile data)

### Step 1: Install Termux & Dependencies

Open Termux and run:

```bash
# Update package list
pkg update && pkg upgrade -y

# Install Node.js, build tools, and ADB
pkg install nodejs-lts build-essential python android-tools
```

### Step 2: Get the Bot Code on the Phone

Option A — Git clone (if you have a repo):

```bash
pkg install git
git clone <your-repo-url>
cd Cousin-Hub/render_server/ludo_bot
```

Option B — Transfer via USB:

```bash
# On the phone, grant Termux storage access first:
termux-setup-storage

# Then copy files from a computer:
# (connect phone via USB, copy to internal storage, then in Termux:)
cp -r /sdcard/path/to/render_server/ludo_bot ./
cd ludo_bot
```

### Step 3: Install npm Dependencies

Critical: use `--os=linux` so sharp (image processing) installs correctly on Termux.

```bash
npm install --os=linux
```

This installs all dependencies including a WASM fallback for sharp since native android-arm64 binaries aren't available.

### Step 4: Enable ADB Self-Connect

This lets the bot control the phone from within Termux:

1. Go to **Settings → Developer Options → Wireless Debugging** → toggle **ON**
2. Tap **"Pair device with pairing code"** — you'll see an IP, port, and 6-digit code
3. In Termux, pair and connect:

```bash
# Replace <pairing-port>, <pairing-code>, and <connection-port> with what you see on screen
adb pair 127.0.0.1:<pairing-port> <pairing-code>

# Example:
adb pair 127.0.0.1:42867 284639

# Then connect:
adb connect 127.0.0.1:<connection-port>

# Example:
adb connect 127.0.0.1:42865
```

4. Verify it worked:

```bash
adb devices
# Should show: 127.0.0.1:<port>  device
```

> **Note**: You need to re-pair after every reboot. The connection persists until the phone disconnects from WiFi or Wireless Debugging is turned off.

### Step 5: Configure Firebase

Export these environment variables every time you start the bot (or add them to `~/.profile`):

```bash
export FIREBASE_DATABASE_URL="https://cousin-hub-default-rtdb.asia-southeast1.firebasedatabase.app"
export FIREBASE_SERVICE_JSON="$(cat /path/to/service-account.json | base64 -w0)"
```

To get `service-account.json`:
1. Go to [Firebase Console](https://console.firebase.google.com/) → Project Settings → Service Accounts
2. Click "Generate New Private Key"
3. Download the JSON file
4. Transfer it to your phone and place it somewhere Termux can read

### Step 6: Start the Bot

```bash
node index.js
```

You should see:

```
✅ Firebase connected
📱 No LUDO_BOT_DEVICE_IP set — trying same-device ADB...
✅ Using local ADB device: 127.0.0.1:42865
📱 Device: 1080x1920 (preset: 1080x1920)
👀 Watching for new Ludo King matches...
```

### Keeping the Bot Running

- **Screen off**: The bot works with the screen off on most devices (Android keeps WiFi ADB alive)
- **Battery optimization**: Go to Settings → Apps → Termux → Battery → select "Unrestricted" to prevent Android from killing the bot
- **Keep session alive**: Use `tmux` to keep the bot running if you close Termux:

```bash
pkg install tmux
tmux new -s bot
node index.js
# Press Ctrl+B then D to detach
# Re-attach with: tmux attach -t bot
```

### Limitations

- You can't play Ludo King on the bot phone while it's running. It's dedicated to hosting rooms.
- Use your **main phone** to join matches and play.
- ADB self-connect needs to be re-setup after phone reboot (just re-run `adb connect`).

---

## Approach B: Separate Server (VPS / Computer)

Run the bot on a server/VPS that talks to a phone over WiFi. Use this if you already have a server running or want the bot on a different machine.

### Prerequisites

- Android phone with Developer Options and USB Debugging enabled
- Ludo King installed on the phone
- **Same WiFi network** for phone and server
- Server with Node.js 18+ installed

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

### Step 6: Deploy on Render (if using Render)

1. Push the `render_server/ludo_bot` folder to a GitHub repo
2. Create a new Web Service on render.com
3. Set:
   - **Root Directory**: `render_server/ludo_bot`
   - **Build Command**: `npm install`
   - **Start Command**: `node index.js`
4. Add the environment variables above (including `LUDO_BOT_DEVICE_IP`)
5. Deploy

> **Important**: Render free tier can't do ADB-over-WiFi directly. Use Approach A (Termux) instead, or run the bot on a cheap VPS (Linode, DigitalOcean, Hetzner — $5/mo).

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
9. lk.gggred.com/?rmc=CODE&gt=0&po=0 opens and auto-joins room
10. Cousins do the same
11. When ready, host taps "Bot Leave Room" → bot leaves
12. After match, host declares results (1st/2nd/3rd/4th)
13. XP is awarded and leaderboard updates
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Termux won't install packages | You installed from **Play Store** — uninstall and get it from **F-Droid** instead. The Play Store version is abandoned. |
| `adb: command not found` | On Termux: `pkg install android-tools`. On Linux: `apt install android-tools-adb`. |
| `adb connect` fails | Make sure phone is on WiFi. Wireless Debugging disables on mobile data. |
| `adb pair` fails | Make sure phone and Termux are on the same WiFi network. |
| `unauthorized` device | Accept the RSA fingerprint prompt on the phone screen. |
| `sharp` install fails | Use `npm install --os=linux` instead of plain `npm install` (critical for Termux). |
| `sharp` runtime error on Termux | Run `npm install @img/sharp-wasm32 --save` then re-install sharp. |
| OCR returns wrong code | Run calibration: `node scripts/calibrate.js <ip>` |
| Bot doesn't start after reboot | Re-run `adb connect 127.0.0.1:<port>` and re-export the Firebase env vars. |
| Bot stops after screen off | Disable battery optimization for Termux in Android Settings → Apps. |
| Flutter build fails | Run `flutter clean && flutter pub get` first. |
