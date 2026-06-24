#!/bin/bash
# ════════════════════════════════════════════════════════════
#  PRIMA NOTA DI CASSA — Pubblica modifiche  (SOLO sulla MADRE)
#  Manda su GitHub le modifiche fatte al codice su questo Mac.
#  Da qui le "figlie" le riceveranno con il loro 3-Aggiorna.
# ════════════════════════════════════════════════════════════
cd "$(dirname "$0")" || exit 1
clear
echo "════════════════════════════════════════"
echo "  PUBBLICA MODIFICHE (madre → GitHub)"
echo "════════════════════════════════════════"
echo ""

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Questa cartella non è un repository Git. Installazione madre non completata."
  read -r -p "Premi Invio per chiudere..."; exit 1
fi

# Niente da pubblicare?
if git diff --quiet && git diff --cached --quiet && [ -z "$(git status --porcelain)" ]; then
  echo "Nessuna modifica da pubblicare."
  read -r -p "Premi Invio per chiudere..."; exit 0
fi

# Aggiorna il timbro di versione (data + ora)
echo "$(date '+%-d/%m/%Y %H:%M')" > VERSIONE.txt

echo "Modifiche da pubblicare:"
git status --short
echo ""
read -r -p "Scrivi una breve descrizione (Invio per usare la data): " MSG
[ -z "$MSG" ] && MSG="aggiornamento del $(date '+%-d/%m/%Y %H:%M')"

git add -A
git commit -m "$MSG" --quiet
echo "→ Invio a GitHub..."
if git push --quiet origin main; then
  echo ""
  echo "Pubblicato! ✓   Versione: $(cat VERSIONE.txt)"
  echo "Sulle altre macchine: doppio clic su 3-Aggiorna."
else
  echo ""
  echo "ERRORE durante l'invio. Controlla la connessione o il login GitHub (gh auth login)."
fi
echo ""
read -r -p "Premi Invio per chiudere..."
