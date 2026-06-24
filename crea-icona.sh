#!/bin/bash
# ════════════════════════════════════════════════════════════
#  Crea UNA sola app "Prima Nota.app" in APPLICAZIONI e UN solo
#  alias sulla SCRIVANIA che la apre. Doppio clic = apre l'app
#  in SAFARI. Uso:  bash crea-icona.sh [CARTELLA_CODICE]
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

# ── launcher (apre SEMPRE in Safari) ──
cat > "$APP/Contents/MacOS/launcher" <<'LAUNCH'
#!/bin/bash
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH
CODE="__CODE_DIR__"
# Server già attivo? apri in Safari e basta
if curl -s http://localhost:5001 >/dev/null 2>&1; then
  open -a Safari "http://localhost:5001"; exit 0
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
open -a Safari "http://localhost:5001"
LAUNCH
sed -i '' "s|__CODE_DIR__|$CODE_DIR|g" "$APP/Contents/MacOS/launcher"
chmod +x "$APP/Contents/MacOS/launcher"

# ── Icona ──
[ -f "$ICON_SRC" ] && cp "$ICON_SRC" "$APP/Contents/Resources/icona.icns"

# ── UNA sola app: in Applicazioni (o ~/Applications se non scrivibile) ──
rm -rf "/Applications/$APP_NAME" 2>/dev/null
if cp -R "$APP" "/Applications/$APP_NAME" 2>/dev/null; then
  APPL="/Applications/$APP_NAME"
else
  mkdir -p "$HOME/Applications"
  rm -rf "$HOME/Applications/$APP_NAME"; cp -R "$APP" "$HOME/Applications/$APP_NAME"
  APPL="$HOME/Applications/$APP_NAME"
fi

# ── UN solo alias sulla Scrivania (rimuove vecchie copie/alias) ──
rm -rf "$HOME/Desktop/$APP_NAME" 2>/dev/null
rm -f  "$HOME/Desktop/Prima Nota" 2>/dev/null
osascript >/dev/null 2>&1 <<OSA
tell application "Finder"
  try
    if exists file "Prima Nota" of desktop then delete file "Prima Nota" of desktop
  end try
  set a to make alias file to (POSIX file "$APPL") at (path to desktop folder)
  try
    set name of a to "Prima Nota"
  end try
end tell
OSA
# Se l'alias non è stato creato, metto una copia diretta come ripiego
if [ ! -e "$HOME/Desktop/Prima Nota" ] && [ ! -e "$HOME/Desktop/$APP_NAME" ]; then
  cp -R "$APP" "$HOME/Desktop/$APP_NAME"
fi

# ── Rinfresca le icone nel Finder ──
LSR="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
[ -x "$LSR" ] && "$LSR" -f "$APPL" 2>/dev/null
touch "$APPL" 2>/dev/null
rm -rf "$TMP"
echo "✓ UNA app in: $APPL  +  alias sulla Scrivania"
