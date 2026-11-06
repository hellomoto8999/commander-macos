#!/bin/bash
# Compila Commander e crea un bundle .app autonomo.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CONFIG="${1:-release}"

# Con i soli Command Line Tools l'SDK più recente usa macro SwiftUI che
# richiedono un plugin presente solo in Xcode. In quel caso usiamo l'SDK 26.5.
SDK_ARGS=()
if ! xcode-select -p 2>/dev/null | grep -q "Xcode.app"; then
    if [ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk" ]; then
        SDK_ARGS=(--sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk)
    elif [ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk" ]; then
        SDK_ARGS=(--sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk)
    fi
fi

echo "▸ Build ($CONFIG)…"
swift build -c "$CONFIG" "${SDK_ARGS[@]}"

BIN="$(swift build -c "$CONFIG" "${SDK_ARGS[@]}" --show-bin-path)/Commander"
APP="$ROOT/dist/Commander.app"

echo "▸ Creo il bundle…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Commander"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

if [ -f "$ROOT/Resources/AppIcon.icns" ]; then
    cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist" 2>/dev/null || true
fi

for lproj in "$ROOT"/Resources/*.lproj; do
    if [ -d "$lproj" ]; then
        cp -R "$lproj" "$APP/Contents/Resources/"
    fi
done

# Firma ad-hoc: necessaria per QuickLook e per l'esecuzione locale.
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
touch "$APP"

echo "✓ Creato: $APP"
echo "  Apri con: open \"$APP\""
