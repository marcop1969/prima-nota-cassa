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
# Flask è essenziale: se fallisce, fermati
./venv/bin/python -m pip install --quiet flask || {
  echo "ERRORE: impossibile installare Flask (serve la connessione a internet)."; read -r -p "Premi Invio per chiudere..."; exit 1; }
# numbers-parser serve solo per importare i file .numbers: se fallisce, l'app funziona lo stesso
./venv/bin/python -m pip install --quiet numbers-parser || echo "  (Nota: la funzione 'Importa .numbers' non sarà disponibile, ma l'app funziona comunque)"

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
open -a Safari "http://localhost:5001"

# 5) Crea l'icona sulla Scrivania e nelle Applicazioni
echo "→ Creo l'icona sulla Scrivania e nelle Applicazioni..."
bash "$HERE/crea-icona.sh" "$HERE"

echo ""
echo "════════════════════════════════════════"
echo "  Installazione completata!"
echo "  Trovi l'icona 'Prima Nota' sulla Scrivania"
echo "  e nelle Applicazioni. Doppio clic per aprirla."
echo "  Per aggiornarla in futuro: doppio clic su 3-Aggiorna"
echo "════════════════════════════════════════"
echo ""
read -r -p "Premi Invio per chiudere questa finestra..."
