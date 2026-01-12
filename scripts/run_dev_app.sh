#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

swift build --package-path "$ROOT_DIR" -c debug

BIN="$ROOT_DIR/.build/debug/VoiceInput"
APP_DIR="$ROOT_DIR/.build/VoiceInput.app"

mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Keep the .app path stable to avoid macOS privacy permission re-prompts.
cp "$ROOT_DIR/app/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$BIN" "$APP_DIR/Contents/MacOS/VoiceInput"

chmod +x "$APP_DIR/Contents/MacOS/VoiceInput"

# Optional: ad-hoc sign the app so macOS treats it more consistently.
if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true
fi

# Prompt Accessibility permission immediately at launch (instead of waiting for hotkey usage)
open "$APP_DIR" --args --prompt-accessibility

echo "App launched: $APP_DIR"
