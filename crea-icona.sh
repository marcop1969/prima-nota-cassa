#!/bin/bash
# ════════════════════════════════════════════════════════════
#  Crea l'icona "Prima Nota.app" e la mette sulla SCRIVANIA
#  e nelle APPLICAZIONI. Doppio clic = apre l'app nel browser.
#  Uso:  bash crea-icona.sh [CARTELLA_CODICE]
#  (default: ~/PrimaNota — la posizione delle "figlie")
# ════════════════════════════════════════════════════════════
CODE_DIR="${1:-$HOME/PrimaNota}"
APP_NAME="Prima Nota.app"
ICON_SRC="$CODE_DIR/icona.icns"

TMP="$(mktemp -d)"
APP="$TMP/$APP_NAME"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# ── Info.plist ──
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Prima Nota</string>
  <key>CFBundleDisplayName</key><string>Prima Nota</string>
  <key>CFBundleIdentifier</key><string>com.parizzi.prima-nota.launcher</string>
  <key>CFBundleVersion</key><string>1.0</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleExecutable</key><string>launcher</string>
  <key>CFBundleIconFile</key><string>icona</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>10.13</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

# ── launcher (placeholder __CODE_DIR__ sostituito dopo) ──
cat > "$APP/Contents/MacOS/launcher" <<'LAUNCH'
#!/bin/bash
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH
CODE="__CODE_DIR__"
# Server già attivo? apri e basta
if curl -s http://localhost:5001 >/dev/null 2>&1; then
  open "http://localhost:5001"; exit 0
fi
# Avvia il server
PLIST="$HOME/Library/LaunchAgents/com.parizzi.prima-nota.plist"
if [ -f "$PLIST" ]; then
  launchctl load "$PLIST" 2>/dev/null
elif [ -x "$CODE/venv/bin/python" ]; then
  nohup "$CODE/venv/bin/python" "$CODE/app.py" >/tmp/prima_nota.log 2>&1 &
elif command -v python3 >/dev/null 2>&1; then
  nohup python3 "$CODE/app.py" >/tmp/prima_nota.log 2>&1 &
fi
for i in $(seq 1 30); do sleep 0.5; curl -s http://localhost:5001 >/dev/null 2>&1 && break; done
open "http://localhost:5001"
LAUNCH
sed -i '' "s|__CODE_DIR__|$CODE_DIR|g" "$APP/Contents/MacOS/launcher"
chmod +x "$APP/Contents/MacOS/launcher"

# ── Icona ──
[ -f "$ICON_SRC" ] && cp "$ICON_SRC" "$APP/Contents/Resources/icona.icns"

# ── Installa: Scrivania + Applicazioni ──
DEST_DESK="$HOME/Desktop/$APP_NAME"
rm -rf "$DEST_DESK"; cp -R "$APP" "$DEST_DESK"

if cp -R "$APP" "/Applications/$APP_NAME" 2>/dev/null; then
  APPL="/Applications/$APP_NAME"
else
  mkdir -p "$HOME/Applications"
  rm -rf "$HOME/Applications/$APP_NAME"; cp -R "$APP" "$HOME/Applications/$APP_NAME"
  APPL="$HOME/Applications/$APP_NAME"
fi

# ── Rinfresca l'icona nel Finder ──
LSR="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
[ -x "$LSR" ] && "$LSR" -f "$DEST_DESK" "$APPL" 2>/dev/null
touch "$DEST_DESK" "$APPL" 2>/dev/null
rm -rf "$TMP"
echo "✓ Icona pronta su Scrivania e in: $APPL"
