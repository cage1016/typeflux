#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/.build/VoiceInput.app"

swift build --package-path "$ROOT_DIR" -c debug

BIN="$ROOT_DIR/.build/debug/VoiceInput"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Keep the .app path stable to avoid macOS privacy permission re-prompts.
cp "$ROOT_DIR/app/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$BIN" "$APP_DIR/Contents/MacOS/VoiceInput"

chmod +x "$APP_DIR/Contents/MacOS/VoiceInput"

# Important: do not ad-hoc sign by default in dev mode.
# TCC/Accessibility may treat each fresh ad-hoc signature as a different app,
# which causes the permission entry to stop matching after rebuilds.
# If you want signing, provide a stable identity explicitly:
#   DEV_CODESIGN_IDENTITY="Apple Development: Your Name (...)" ./scripts/run_dev_app.sh
if [[ -n "${DEV_CODESIGN_IDENTITY:-}" ]] && command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign "$DEV_CODESIGN_IDENTITY" "$APP_DIR"
fi

# Prompt Accessibility permission immediately at launch (instead of waiting for hotkey usage)
open "$APP_DIR" --args --prompt-accessibility

echo "App launched: $APP_DIR"
