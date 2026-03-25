#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/.build/VoiceInput.app"
APP_BIN="$APP_DIR/Contents/MacOS/VoiceInput"
APP_PID=""

cleanup() {
  local exit_code=${1:-0}

  if [[ -n "$APP_PID" ]] && kill -0 "$APP_PID" >/dev/null 2>&1; then
    echo
    echo "Stopping VoiceInput (pid: $APP_PID)..."
    kill -TERM "$APP_PID" >/dev/null 2>&1 || true
    wait "$APP_PID" >/dev/null 2>&1 || true
  fi

  exit "$exit_code"
}

trap 'cleanup 130' INT
trap 'cleanup 143' TERM

swift build --package-path "$ROOT_DIR" -c debug

BIN="$ROOT_DIR/.build/debug/VoiceInput"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Keep the .app path stable to avoid macOS privacy permission re-prompts.
cp "$ROOT_DIR/app/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$BIN" "$APP_DIR/Contents/MacOS/VoiceInput"

chmod +x "$APP_BIN"

# Optional: ad-hoc sign the app so macOS treats it more consistently.
if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true
fi

if pgrep -f "$APP_BIN" >/dev/null 2>&1; then
  echo "VoiceInput is already running from $APP_BIN, stopping the previous instance first..."
  pkill -f "$APP_BIN" >/dev/null 2>&1 || true
  sleep 1
fi

echo "App launched in attached dev mode: $APP_DIR"
echo "Logs stay attached to this terminal. Press Ctrl+C to stop the app."

NSUnbufferedIO=YES "$APP_BIN" --prompt-accessibility &
APP_PID=$!

wait "$APP_PID"
APP_EXIT_CODE=$?
APP_PID=""

exit "$APP_EXIT_CODE"
