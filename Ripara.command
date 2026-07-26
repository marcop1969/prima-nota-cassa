#!/bin/bash
# ════════════════════════════════════════════════════════════
#  PRIMA NOTA DI CASSA — Ripara / Aggiorna una postazione
#
#  Da usare quando una postazione non si aggiorna o ha una
#  versione "staccata" (non collegata alla postazione principale).
#
#  SICURO: i dati non vengono MAI cancellati. Vivono in
#  ~/Library/Application Support/PrimaNota/ e prima di ogni
#  operazione ne viene fatta una copia di sicurezza.
# ════════════════════════════════════════════════════════════
set -u

DATI="$HOME/Library/Application Support/PrimaNota"
DEST="$HOME/PrimaNota"
REPO="https://github.com/marcop1969/prima-nota-cassa.git"
TS="$(date +%Y%m%d_%H%M%S)"

clear
echo "════════════════════════════════════════"
echo "  PRIMA NOTA — Riparazione postazione"
echo "════════════════════════════════════════"
echo ""

# ── 0) Serve git ────────────────────────────────────────────
if ! command -v git &>/dev/null; then
  echo "Manca 'git' (strumenti da sviluppatore Apple)."
  echo "Comparira' una finestra: premi INSTALLA, aspetta la fine,"
  echo "poi rilancia questo stesso comando."
  xcode-select --install 2>/dev/null
  read -r -p "Premi Invio per chiudere..."
  exit 1
fi

# ── 1) Dati al sicuro (prima di toccare qualsiasi cosa) ─────
mkdir -p "$DATI/backups"
echo "→ Metto al sicuro i dati..."
for f in "$DATI/prima_nota_data.json" \
         "$DEST/prima_nota_data.json" \
         "$HOME/prima_nota_2026/prima_nota_data.json"; do
  [ -f "$f" ] || continue
  cp -p "$f" "$DATI/backups/prima_della_riparazione_${TS}.json" 2>/dev/null \
    && echo "   copia salvata da: $f"
  # Se nella posizione ufficiale non c'e' nulla, portaceli (vecchie installazioni)
  if [ ! -f "$DATI/prima_nota_data.json" ]; then
    cp -p "$f" "$DATI/prima_nota_data.json" && echo "   dati riportati nella posizione corretta"
  fi
done
if [ -f "$DATI/prima_nota_data.json" ]; then
  echo "   dati presenti: $(wc -c < "$DATI/prima_nota_data.json" | tr -d ' ') byte"
else
  echo "   (nessun dato trovato: postazione nuova)"
fi
echo ""

# ── 2) Aggiorna oppure reinstalla ───────────────────────────
if [ -d "$DEST/.git" ]; then
  echo "→ Versione collegata: la aggiorno all'ultima."
  git -C "$DEST" fetch --quiet origin || { echo "   ERRORE: serve la connessione a internet."; read -r -p "Invio per chiudere..."; exit 1; }
  git -C "$DEST" reset --hard origin/main --quiet
else
  if [ -e "$DEST" ]; then
    mv "$DEST" "${DEST}_vecchia_${TS}"
    echo "→ Versione staccata: messa da parte in ${DEST}_vecchia_${TS}"
    echo "   (NON e' stata cancellata)"
  fi
  echo "→ Scarico la versione aggiornata..."
  git clone -q "$REPO" "$DEST" || { echo "   ERRORE: scaricamento non riuscito (internet?)."; read -r -p "Invio per chiudere..."; exit 1; }
fi
echo "   versione: $(git -C "$DEST" log --oneline -1 2>/dev/null | cut -c1-60)"
echo ""

# ── 3) Installazione (ambiente, avvio automatico, icona) ────
echo "→ Completo l'installazione..."
echo ""
exec bash "$DEST/1-Installa.command"
