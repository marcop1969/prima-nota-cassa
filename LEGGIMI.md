# Prima Nota di Cassa 2026

App per la prima nota di cassa del Ristorante Parizzi. Gira in locale e si apre
nel browser su **http://localhost:5001**.

## Modello "madre / figlie"

- **Madre** = questo Mac (dove si fanno le modifiche al codice).
- **Figlie** = gli altri Mac che usano l'app, ognuno con i **propri dati**.

Le figlie si aggiornano scaricando il codice nuovo dalla madre (via GitHub),
**senza mai perdere i dati**.

### Dove stanno i dati (importantissimo)

I dati **non** stanno nella cartella del programma. Stanno in:

```
~/Library/Application Support/PrimaNota/
   ├── prima_nota_data.json        ← i dati
   ├── prima_nota_data.bak.json    ← backup automatico
   └── backups/                    ← una copia per ogni giorno (mai cancellata)
```

Per questo gli aggiornamenti del codice non li toccano mai.

## Comandi (doppio clic)

| File | Su quale Mac | Cosa fa |
|------|--------------|---------|
| `1-Installa.command` | figlia (una volta) | Prepara tutto e avvia l'app |
| `2-Avvia.command` | figlia | Apre l'app |
| `3-Aggiorna.command` | figlia | Scarica l'ultima versione dalla madre |
| `Pubblica-modifiche.command` | **madre** | Manda le modifiche su GitHub |

## Come si aggiorna (il flusso tipico)

1. Sulla **madre** si fanno le modifiche al codice.
2. Sulla madre: doppio clic su **Pubblica-modifiche** → va su GitHub.
3. Su ogni **figlia**: doppio clic su **3-Aggiorna** → scarica e riavvia.
   I dati della figlia restano intatti.

## Prima installazione di una figlia

Serve solo una volta, su ogni Mac nuovo:

1. Apri **Terminale** e incolla (l'indirizzo esatto te lo do dopo aver creato il repo):
   ```
   git clone <INDIRIZZO-GITHUB> ~/PrimaNota
   ```
2. Apri la cartella `PrimaNota` nella Home e fai doppio clic su **1-Installa**.

Da quel momento la figlia si aggiorna da sola con **3-Aggiorna**.
