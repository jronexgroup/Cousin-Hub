#!/usr/bin/env bash
# ── ADB over WiFi Setup ──────────────────────────────────────────────────────
# Run this on your server (Render, VPS, or local machine) to set up ADB
# and connect to your phone wirelessly.
#
# Prerequisites:
#   1. Enable Developer Options on your Android phone
#   2. Enable USB Debugging
#   3. Connect phone to computer via USB once, run: adb tcpip 5555
#   4. Disconnect USB — phone is now available over WiFi
#
# Usage:
#   bash scripts/setup_adb.sh 192.168.1.100
#   (use your phone's IP address)

set -euo pipefail

PHONE_IP="${1:-}"
PORT="${2:-5555}"

if [ -z "$PHONE_IP" ]; then
  echo "Usage: $0 <phone-ip> [port]"
  echo "  e.g. $0 192.168.1.100"
  exit 1
fi

echo "═══════════════════════════════════════════"
echo "  ADB over WiFi Setup"
echo "═══════════════════════════════════════════"

# Check if adb is installed
if ! command -v adb &> /dev/null; then
  echo "❌ adb not found. Installing..."
  if command -v apt-get &> /dev/null; then
    apt-get update && apt-get install -y android-tools-adb
  elif command -v apk &> /dev/null; then
    apk add android-tools
  elif command -v yum &> /dev/null; then
    yum install -y android-tools
  else
    echo "⚠️  Please install adb manually and re-run"
    exit 1
  fi
  echo "✅ adb installed"
fi

ADB_VER=$(adb version | head -1)
echo "📱 $ADB_VER"

# Kill any existing adb server
adb kill-server 2>/dev/null || true
sleep 1

# Start adb server
adb start-server
sleep 1

# Connect
echo "🔌 Connecting to ${PHONE_IP}:${PORT}..."
CONN_OUT=$(adb connect "${PHONE_IP}:${PORT}" 2>&1)
echo "   $CONN_OUT"

if echo "$CONN_OUT" | grep -qi "failed\|cannot connect\|unable"; then
  echo ""
  echo "❌ Connection failed."
  echo ""
  echo "Troubleshooting:"
  echo "  1. Is USB Debugging enabled on the phone?"
  echo "  2. Did you run 'adb tcpip 5555' while connected via USB?"
  echo "  3. Are the phone and this machine on the same network?"
  echo "  4. Can you ping ${PHONE_IP}?"
  exit 1
fi

echo ""
echo "✅ Connected! Checking device..."
sleep 1

DEVICE_STATE=$(adb devices | grep -v "List" | grep "${PHONE_IP}" | awk '{print $2}')
if [ "$DEVICE_STATE" == "device" ]; then
  echo "✅ Device is online and authorized"
  echo ""
  echo "📱 Device info:"
  adb shell getprop ro.product.model 2>/dev/null || echo "   (unknown model)"
  adb shell wm size 2>/dev/null || echo "   (unknown resolution)"
  echo ""
  echo "🎮 Ludo King installed:"
  if adb shell pm list packages | grep -q "com.ludo.king"; then
    echo "   ✅ com.ludo.king found"
  else
    echo "   ⚠️  com.ludo.king NOT found — please install Ludo King on the phone"
  fi
  echo ""
  echo "═══════════════════════════════════════════"
  echo "  Ready! Add these to your .env:"
  echo "═══════════════════════════════════════════"
  echo "  LUDO_BOT_DEVICE_IP=${PHONE_IP}:${PORT}"
  echo ""
  echo "Then run: node index.js"
else
  echo "⚠️  Device state: $DEVICE_STATE"
  echo "Check if you accepted the RSA fingerprint on the phone."
fi
