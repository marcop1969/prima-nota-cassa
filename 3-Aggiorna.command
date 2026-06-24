#!/bin/bash
# ════════════════════════════════════════════════════════════
#  PRIMA NOTA DI CASSA — Aggiorna
#  Scarica l'ultima versione del codice dalla "madre" (GitHub)
#  e riavvia l'app. I DATI NON VENGONO MAI TOCCATI:
#  vivono in ~/Library/Application Support/PrimaNota/, fuori dal codice.
# ════════════════════════════════════════════════════════════
cd "$(dirname "$0")" || exit 1
HERE="$(pwd)"
clear
echo "════════════════════════════════════════"
echo "  PRIMA NOTA DI CASSA — Aggiornamento"
echo "════════════════════════════════════════"
echo ""

if ! command -v git &>/dev/null; then
  osascript -e 'display alert "Manca git" message "Apri Terminale e scrivi: xcode-select --install" as critical' >/dev/null 2>&1
  exit 1
fi

echo "Versione attuale: $(cat VERSIONE.txt 2>/dev/null || echo '?')"
echo "→ Cerco aggiornamenti dalla madre..."
git fetch --quiet origin 2>/dev/null

if git diff --quiet HEAD origin/main 2>/dev/null; then
  echo ""
  echo "Sei già aggiornato all'ultima versione. ✓"
  open -a Safari "http://localhost:5001"
  read -r -p "Premi Invio per chiudere..."
  exit 0
fi

# Allinea il codice all'ultima versione (i file dati sono fuori dal repo → intatti)
git reset --hard origin/main --quiet

# Le dipendenze potrebbero essere cambiate
[ -x "./venv/bin/python" ] && ./venv/bin/python -m pip install --quiet -r requirements.txt

# Riavvia
echo "→ Riavvio l'applicazione..."
PLIST="$HOME/Library/LaunchAgents/com.parizzi.prima-nota.plist"
if [ -f "$PLIST" ]; then
  launchctl unload "$PLIST" 2>/dev/null; sleep 2; launchctl load "$PLIST"
else
  pkill -f "$HERE/app.py" 2>/dev/null; sleep 1
  [ -x "./venv/bin/python" ] && nohup ./venv/bin/python "$HERE/app.py" >/tmp/prima_nota.log 2>&1 &
fi

for i in $(seq 1 30); do sleep 0.5; curl -s http://localhost:5001 >/dev/null 2>&1 && break; done
open -a Safari "http://localhost:5001"

echo ""
echo "Aggiornato alla versione: $(cat VERSIONE.txt 2>/dev/null || echo '?')  ✓"
echo "I tuoi dati sono intatti."
read -r -p "Premi Invio per chiudere..."
