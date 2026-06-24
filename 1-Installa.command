#!/bin/bash
# ════════════════════════════════════════════════════════════
#  PRIMA NOTA DI CASSA — Installazione (da eseguire UNA volta)
#  Prepara l'ambiente, installa l'avvio automatico, apre l'app.
#  I dati restano in ~/Library/Application Support/PrimaNota/
#  e NON vengono mai toccati dagli aggiornamenti.
# ════════════════════════════════════════════════════════════
cd "$(dirname "$0")" || exit 1
HERE="$(pwd)"
clear
echo "════════════════════════════════════════"
echo "  PRIMA NOTA DI CASSA — Installazione"
echo "════════════════════════════════════════"
echo ""

# 1) Python 3 presente?
if ! command -v python3 &>/dev/null; then
  echo "Python 3 non è installato. Apro la pagina per scaricarlo."
  osascript -e 'display alert "Manca Python 3" message "Si aprirà la pagina di download. Installa Python 3, poi fai di nuovo doppio clic su 1-Installa." as critical' >/dev/null 2>&1
  open "https://www.python.org/downloads/"
  exit 1
fi

# 2) Ambiente virtuale locale + dipendenze
echo "→ Preparo l'ambiente Python (la prima volta richiede 1-2 minuti)..."
python3 -m venv venv 2>/dev/null
./venv/bin/python -m pip install --quiet --upgrade pip
./venv/bin/python -m pip install --quiet -r requirements.txt || {
  echo "ERRORE durante l'installazione delle dipendenze."; read -r -p "Premi Invio per chiudere..."; exit 1; }

# 3) Avvio automatico all'accensione del Mac (LaunchAgent)
echo "→ Configuro l'avvio automatico..."
PLIST="$HOME/Library/LaunchAgents/com.parizzi.prima-nota.plist"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>com.parizzi.prima-nota</string>
    <key>ProgramArguments</key>
    <array>
        <string>$HERE/venv/bin/python</string>
        <string>$HERE/app.py</string>
    </array>
    <key>WorkingDirectory</key><string>$HERE</string>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><true/>
    <key>StandardOutPath</key><string>/tmp/prima_nota.log</string>
    <key>StandardErrorPath</key><string>/tmp/prima_nota.log</string>
    <key>ExitTimeoutInterval</key><integer>15</integer>
</dict>
</plist>
EOF
launchctl unload "$PLIST" 2>/dev/null
launchctl load "$PLIST"

# 4) Attendi che il server risponda e apri il browser
echo "→ Avvio l'applicazione..."
for i in $(seq 1 30); do
  sleep 0.5
  curl -s http://localhost:5001 >/dev/null 2>&1 && break
done
open "http://localhost:5001"

echo ""
echo "════════════════════════════════════════"
echo "  Installazione completata!"
echo "  L'app si apre da sola su http://localhost:5001"
echo "  Per aggiornarla in futuro: doppio clic su 3-Aggiorna"
echo "════════════════════════════════════════"
echo ""
read -r -p "Premi Invio per chiudere questa finestra..."
