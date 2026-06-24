#!/bin/bash
# ════════════════════════════════════════════════════════════
#  PRIMA NOTA DI CASSA — Avvia / Apri
#  Avvia il server (se non già attivo) e apre il browser.
# ════════════════════════════════════════════════════════════
cd "$(dirname "$0")" || exit 1
HERE="$(pwd)"

# Se il server risponde già, apri e basta
if curl -s http://localhost:5001 >/dev/null 2>&1; then
  open -a Safari "http://localhost:5001"; exit 0
fi

PLIST="$HOME/Library/LaunchAgents/com.parizzi.prima-nota.plist"
if [ -f "$PLIST" ]; then
  launchctl load "$PLIST" 2>/dev/null
else
  # Nessun avvio automatico configurato: avvia a mano con il venv locale
  if [ -x "./venv/bin/python" ]; then
    nohup ./venv/bin/python "$HERE/app.py" >/tmp/prima_nota.log 2>&1 &
  else
    osascript -e 'display alert "Non ancora installato" message "Fai prima doppio clic su 1-Installa." as critical' >/dev/null 2>&1
    exit 1
  fi
fi

for i in $(seq 1 30); do
  sleep 0.5
  curl -s http://localhost:5001 >/dev/null 2>&1 && break
done
open -a Safari "http://localhost:5001"
