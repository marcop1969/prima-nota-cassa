#!/usr/bin/env python3
"""
Prima Nota di Cassa 2026
App Flask standalone — porta 5001 — http://localhost:5001
"""

import os
import json
import signal
import atexit
import threading
import datetime
from pathlib import Path
from flask import Flask, render_template, request, jsonify

app = Flask(__name__)

# ─── Persistenza dati — FUORI dalla cartella del codice ───────────
# I dati vivono in ~/Library/Application Support/PrimaNota/, separati
# dal codice: così gli aggiornamenti (git pull) NON li toccano mai.
DATA_DIR = Path.home() / 'Library' / 'Application Support' / 'PrimaNota'
DATA_DIR.mkdir(parents=True, exist_ok=True)
DATA_FILE   = DATA_DIR / 'prima_nota_data.json'
BACKUP_FILE = DATA_DIR / 'prima_nota_data.bak.json'
BACKUP_DIR  = DATA_DIR / 'backups'
BACKUP_DIR.mkdir(parents=True, exist_ok=True)

def _migra_dati_legacy():
    """Una-tantum: se i dati erano nella vecchia posizione (dentro la
    cartella del codice) li copia nella nuova SENZA cancellare l'originale."""
    import shutil
    vecchio     = Path(__file__).parent / 'prima_nota_data.json'
    vecchio_bak = Path(__file__).parent / 'prima_nota_data.bak.json'
    if vecchio.exists() and not DATA_FILE.exists():
        shutil.copy2(vecchio, DATA_FILE)
        if vecchio_bak.exists():
            shutil.copy2(vecchio_bak, BACKUP_FILE)
        print(f'  Dati migrati: {vecchio.name} -> {DATA_FILE}')

def _backup_giornaliero():
    """Copia di sicurezza giornaliera dei dati (una al giorno, mai cancellate)."""
    import shutil
    if not DATA_FILE.exists():
        return
    dest = BACKUP_DIR / f'prima_nota_{datetime.date.today().isoformat()}.json'
    try:
        if not dest.exists():
            shutil.copy2(DATA_FILE, dest)
    except Exception as e:
        print(f'  Backup giornaliero non riuscito: {e}')

_migra_dati_legacy()

# ─── Dati in memoria ──────────────────────────────
_dati_in_memoria: dict = {}
_lock = threading.Lock()

def _carica_da_disco():
    """Carica sempre fresco dal JSON — nessuna cache."""
    global _dati_in_memoria
    sorgente = None
    for path in (DATA_FILE, BACKUP_FILE):
        if path.exists():
            try:
                with open(path, 'r', encoding='utf-8') as f:
                    _dati_in_memoria = json.load(f)
                sorgente = path.name
                break
            except Exception as e:
                print(f'  ATTENZIONE: impossibile leggere {path.name}: {e}')
    if sorgente:
        giorni = sum(1 for k in _dati_in_memoria if not k.startswith('__'))
        print(f'  Dati caricati: {giorni} giorni da {sorgente}')
    else:
        _dati_in_memoria = {}
        print('  Nessun file dati trovato — partenza a vuoto.')

def _salva_su_disco():
    """Scrittura atomica: tmp → rename. Non corruttibile da SIGKILL a metà scrittura."""
    with _lock:
        tmp = DATA_FILE.with_suffix('.tmp')
        try:
            with open(tmp, 'w', encoding='utf-8') as f:
                json.dump(_dati_in_memoria, f, ensure_ascii=False, indent=2)
            # backup del precedente, poi rimpiazza atomicamente
            if DATA_FILE.exists():
                DATA_FILE.replace(BACKUP_FILE)
            tmp.replace(DATA_FILE)
            giorni = sum(1 for k in _dati_in_memoria if not k.startswith('__'))
            print(f'  Salvato: {giorni} giorni → {DATA_FILE.name}')
        except Exception as e:
            print(f'  ERRORE salvataggio: {e}')
            try: tmp.unlink()
            except Exception: pass

# ─── Salvataggio periodico di sicurezza (ogni 60 s) ───
def _avvia_salvataggio_periodico():
    def _loop():
        import time
        while True:
            time.sleep(60)
            if _dati_in_memoria:
                _salva_su_disco()
    t = threading.Thread(target=_loop, daemon=True)
    t.start()

# ─── Shutdown: SIGTERM (launchctl stop) + SIGINT (Ctrl+C) + atexit ───
def _handler_shutdown(signum, frame):
    print('\n  Shutdown — salvataggio finale...')
    _salva_su_disco()
    raise SystemExit(0)

signal.signal(signal.SIGTERM, _handler_shutdown)
signal.signal(signal.SIGINT,  _handler_shutdown)
atexit.register(_salva_su_disco)   # safety net se il processo termina in altro modo

# ─── Avvio ────────────────────────────────────────
_carica_da_disco()
_backup_giornaliero()
_avvia_salvataggio_periodico()


# ─── Routes ───────────────────────────────────────

@app.route('/')
@app.route('/prima-nota')
def prima_nota():
    return render_template('prima_nota.html')


@app.route('/api/prima-nota/carica', methods=['GET'])
def prima_nota_carica():
    """Restituisce i dati salvati sul disco."""
    return jsonify({'ok': True, 'dati': _dati_in_memoria, 'giorni': len(_dati_in_memoria)})


@app.route('/api/prima-nota/salva', methods=['POST'])
def prima_nota_salva():
    """Riceve i dati dal browser e li salva su disco.
    Le chiavi speciali (__sospesi__, ecc.) vengono preservate
    anche se il browser non le include nel payload."""
    global _dati_in_memoria
    payload = request.get_json(silent=True) or {}
    dati = payload.get('dati', {})
    if not isinstance(dati, dict):
        return jsonify({'ok': False, 'errore': 'Payload non valido'}), 400
    # Merge __sospesi__ con tombstone:
    # - il server è autorità su quali ID esistono
    # - il browser può aggiornare lo stato (rientro) di ID già noti al server
    # - il browser può aggiungere ID nuovi (non ancora nel server e non eliminati)
    # - ID in __sospesi_eliminati__ non vengono mai ripristinati (neanche da tab vecchi)
    if '__sospesi__' in _dati_in_memoria:
        eliminati = set(_dati_in_memoria.get('__sospesi_eliminati__', []))
        srv = {s['id']: s for s in _dati_in_memoria['__sospesi__'] if isinstance(s, dict) and 'id' in s}
        brw = {s['id']: s for s in dati.get('__sospesi__', []) if isinstance(s, dict) and 'id' in s}
        merged = dict(srv)
        for sid, entry in brw.items():
            if sid in eliminati:
                continue                    # tombstoned: non ripristinare mai
            if sid in merged:
                merged[sid] = entry         # aggiorna stato esistente (es. rientro)
            else:
                merged[sid] = entry         # nuovo sospeso aggiunto dal browser
        dati['__sospesi__'] = list(merged.values())
        # propaga la lista tombstone
        dati['__sospesi_eliminati__'] = list(eliminati | set(dati.get('__sospesi_eliminati__', [])))
    _dati_in_memoria = dati
    _salva_su_disco()
    giorni = sum(1 for k in _dati_in_memoria if not k.startswith('__'))
    return jsonify({'ok': True, 'giorni': giorni})


@app.route('/api/prima-nota/parse-numbers', methods=['POST'])
def prima_nota_parse_numbers():
    """Converte un file .numbers della Prima Nota in JSON per l'app web."""
    if 'file' not in request.files:
        return jsonify({'ok': False, 'errore': 'Nessun file ricevuto'}), 400
    f = request.files['file']
    if not f.filename.lower().endswith('.numbers'):
        return jsonify({'ok': False, 'errore': 'File non .numbers'}), 400

    import tempfile
    import numbers_parser as _np

    MESI_NUMERI = {
        'gennaio': 1, 'febbraio': 2, 'marzo': 3, 'aprile': 4,
        'maggio': 5, 'giugno': 6, 'luglio': 7, 'agosto': 8,
        'settembre': 9, 'ottobre': 10, 'novembre': 11, 'dicembre': 12
    }
    BLOCK_SIZE = 14

    with tempfile.NamedTemporaryFile(suffix='.numbers', delete=False) as tmp:
        f.save(tmp.name)
        tmp_path = tmp.name

    try:
        doc = _np.Document(tmp_path)
        risultati = []

        for sheet in doc.sheets:
            month_name = sheet.name.lower().strip()
            if month_name not in MESI_NUMERI:
                continue
            month_num = MESI_NUMERI[month_name]

            for tbl in sheet.tables:
                rows = []
                for r in range(tbl.num_rows):
                    row = []
                    for c in range(tbl.num_cols):
                        try:
                            row.append(tbl.cell(r, c).value)
                        except Exception:
                            row.append(None)
                    rows.append(row)

                def _v(block, offset, col):
                    try:
                        val = block[offset][col]
                        return float(val) if val is not None else 0.0
                    except Exception:
                        return 0.0

                def _d(block, offset):
                    try:
                        return str(block[offset][1] or '').strip()
                    except Exception:
                        return ''

                r = 1
                while r + BLOCK_SIZE <= len(rows):
                    block = rows[r:r + BLOCK_SIZE]
                    date_val = block[0][0]
                    if not isinstance(date_val, datetime.datetime):
                        r += 1
                        continue

                    iso = f"2026-{month_num:02d}-{date_val.day:02d}"

                    cartasi   = _v(block, 1, 4)
                    amex      = _v(block, 2, 4)
                    bancomat  = _v(block, 3, 4)
                    sop1_val  = _v(block, 4, 4)
                    sop1_desc = _d(block, 4) or 'Sospeso'
                    sop2_val  = _v(block, 5, 4)
                    sop2_desc = _d(block, 5) or 'Sospeso (2)'

                    incasso_lordo = _v(block, 1, 7)

                    off6_desc = _d(block, 6).lower()
                    off6_val  = _v(block, 6, 3)
                    is_vers6  = 'vers' in off6_desc

                    off7_desc = _d(block, 7).lower()
                    off7_val  = _v(block, 7, 3)
                    is_vers7  = 'vers' in off7_desc

                    g = {
                        'iso': iso,
                        'note': '', 'ricevuta': '',
                        'incassoLordo': round(incasso_lordo, 2),
                        'ricevute': [],
                        'pos': [], 'bonifici': [], 'sospesi': [],
                        'extra': [], 'pagCont': [], 'versamenti': [],
                    }

                    if cartasi  > 0: g['pos'].append({'desc': 'POS / Cartasì', 'importo': round(cartasi,  2)})
                    if amex     > 0: g['pos'].append({'desc': 'Amex',           'importo': round(amex,     2)})
                    if bancomat > 0: g['pos'].append({'desc': 'Bancomat',        'importo': round(bancomat, 2)})
                    if sop1_val > 0: g['sospesi'].append({'desc': sop1_desc, 'importo': round(sop1_val, 2)})
                    if sop2_val > 0: g['sospesi'].append({'desc': sop2_desc, 'importo': round(sop2_val, 2)})

                    if off6_val > 0:
                        if is_vers6:
                            g['versamenti'].append({'desc': 'Versamento', 'importo': round(off6_val, 2)})
                        else:
                            g['pagCont'].append({'desc': _d(block, 6) or 'Pag. contanti', 'importo': round(off6_val, 2)})

                    if off7_val > 0:
                        if is_vers7:
                            g['versamenti'].append({'desc': 'Versamento', 'importo': round(off7_val, 2)})
                        else:
                            g['pagCont'].append({'desc': _d(block, 7) or 'Pag. contanti', 'importo': round(off7_val, 2)})

                    if incasso_lordo > 0 or off6_val > 0 or off7_val > 0:
                        risultati.append(g)

                    r += BLOCK_SIZE

        os.unlink(tmp_path)
        return jsonify({'ok': True, 'giorni': risultati, 'totale': len(risultati)})

    except Exception as e:
        try:
            os.unlink(tmp_path)
        except Exception:
            pass
        return jsonify({'ok': False, 'errore': str(e)}), 500


if __name__ == '__main__':
    print('=' * 50)
    print('  PRIMA NOTA DI CASSA 2026')
    print('  http://localhost:5001')
    print('=' * 50)
    app.run(host='127.0.0.1', port=5001, debug=False)
