# Myst Asset Browser

Browser web per interrogare e filtrare gli asset statici del MUD Myst. Legge i file di worldbuilding in `mudroot/lib`, li importa in un database SQLite indicizzato e offre un'interfaccia con filtri mirati e ricerca full-text.

Utile per builder, wizard e chi sviluppa su Mudlet: trovare rapidamente oggetti, mob, stanze, reset di zona, shop e special proc senza aprire manualmente i file `.obj` / `.mob` / `.zon` / `.wld`.

## Requisiti

- Python 3.10+
- File sorgente Myst in una directory accessibile. Il tool li cerca automaticamente in:
  1. `$MYST_LIB_DIR` (se impostata)
  2. `mudroot/lib/` (setup di sviluppo / Docker)
  3. **root del repository** (branch `mudlet`: `myst.zon`, `myst.obj`, … sono versionati qui)
  4. `sirio_dockers/mudroot/lib/`

  File richiesti: `myst.obj`, `myst.mob`, `myst.zon`, `myst.wld`, `myst.shp`, `myst.spe`

## Avvio rapido

```bash
cd tools/myst-assets
./run.sh
```

Lo script crea il virtualenv (se manca), importa il database alla prima esecuzione e avvia il server su **http://localhost:8765**.

Porta personalizzata:

```bash
PORT=9000 ./run.sh
```

Directory asset personalizzata (se non è in root repo né in `mudroot/lib`):

```bash
export MYST_LIB_DIR=/percorso/con/myst.zon
./run.sh
```

## Avvio come demone (senza shell impegnata)

Per lasciare il server in background sulla LAN:

```bash
cd tools/myst-assets
./daemon.sh start      # avvia in background
./daemon.sh status     # verifica PID e URL LAN
./daemon.sh logs       # segue il log
./daemon.sh stop       # ferma il servizio
./daemon.sh restart
```

Il demone scrive il log in `logs/server.log` e il PID in `myst-assets.pid`.

### Systemd (opzionale, riavvio automatico al boot)

```bash
# Modifica User e percorsi in myst-assets.service.example, poi:
sudo cp myst-assets.service.example /etc/systemd/system/myst-assets.service
sudo systemctl daemon-reload
sudo systemctl enable --now myst-assets
journalctl -u myst-assets -f
```

## Accesso da altri PC sulla rete

Il server ascolta su **tutte le interfacce** (`HOST=0.0.0.0`, default). Da un altro dispositivo sulla stessa LAN:

```
http://192.168.0.60:8765/
```

(sostituisci con l'IP reale della macchina host).

### Se hai timeout dalla LAN

1. **Verifica che il demone sia in esecuzione** sulla macchina host:
   ```bash
   ./daemon.sh status
   curl -s http://127.0.0.1:8765/api/meta | head
   ```

2. **Verifica l'ascolto su 0.0.0.0** (non solo localhost):
   ```bash
   ss -tlnp | grep 8765
   # deve mostrare 0.0.0.0:8765 o *:8765
   ```

3. **Firewall Ubuntu (ufw)** — causa più frequente del timeout:
   ```bash
   sudo ufw allow 8765/tcp
   sudo ufw status
   ```

4. **Test dalla macchina host** usando l'IP LAN:
   ```bash
   curl -s http://192.168.0.60:8765/api/meta | head
   ```
   Se funziona in locale ma non dall'altro PC, il problema è firewall o rete (guest Wi‑Fi isolato, VLAN, ecc.).

### Se curl funziona ma il browser va in timeout

Causa più frequente: il browser usa **HTTPS** (Firefox “HTTPS-Only”, Chrome “Always use secure connections”). Il server espone solo **HTTP** sulla porta 8765.

```
✗  https://192.168.0.60:8765/   → timeout
✓  http://192.168.0.60:8765/    → corretto
```

Digita `http://` esplicitamente, oppure disattiva HTTPS-Only nelle impostazioni del browser per gli indirizzi locali.

Script di diagnostica (dalla macchina host):

```bash
./check-lan.sh
```

Verifica anche dal **PC client** (non solo dall'host):

```bash
curl -v http://192.168.0.60:8765/health
curl -v http://192.168.0.60:8765/static/app.js
```

Se `/api/meta` risponde a curl ma `/` o `/static/app.js` no, il problema è sul frontend statico.

Dopo `git pull`, riavvia il demone per caricare le correzioni:

```bash
./daemon.sh restart
```

Usa `./daemon.sh start` (non `run.sh` con `RELOAD=1`) per l'accesso LAN: `--reload` di uvicorn può creare problemi da altri PC.

Variabili utili:

```bash
HOST=0.0.0.0 PORT=8765 ./daemon.sh start
```

## Struttura del progetto

```
tools/myst-assets/
├── README.md           # questa documentazione
├── run.sh              # avvio foreground (sviluppo)
├── daemon.sh           # start/stop/status demone in background
├── check-lan.sh        # diagnostica accesso HTTP/LAN
├── _common.sh          # setup condiviso venv e lib dir
├── myst-assets.service.example  # unit systemd opzionale
├── requirements.txt    # dipendenze Python (FastAPI, uvicorn)
├── myst_parser.py      # parser dei file Myst (allineato a db.cpp)
├── myst_enums.py       # decodifica flag da shutils/enums.json
├── import_db.py        # import in SQLite + FTS5
├── server.py           # API REST e frontend statico
├── myst_assets.db      # database generato (non versionato)
└── static/
    ├── index.html
    ├── app.js
    └── style.css
```

## File sorgente supportati

Il parser replica la logica di boot del MUD (`src/db.cpp`, `src/shop.cpp`):

| File | Contenuto |
|------|-----------|
| `myst.obj` | Oggetti: keywords, descrizioni, tipo, flag, valori, affect, extra desc |
| `myst.mob` | Mob: stats, ACT/AFF, allineamento, razza, tipo S/A/L/B/N |
| `myst.zon` | Zone (range VNUM, lifespan, reset) e comandi M/O/G/E/P/D |
| `myst.wld` | Stanze: flag, settore, teleport, uscite, extra desc |
| `myst.shp` | Shop: prodotti, margini, keeper, orari |
| `myst.spe` | Special proc su mob/oggetti/stanze |

I flag numerici con `|` (es. `8192\|16384`) vengono interpretati come OR bitwise, come in `fread_number()` del MUD.

## Interfaccia web

All'apertura del browser sono disponibili sette tab:

| Tab | Cosa contiene |
|-----|----------------|
| **Oggetti** | Tutti i prototipi da `myst.obj` |
| **Mob** | Tutti i prototipi da `myst.mob` |
| **Stanze** | Tutte le room da `myst.wld` |
| **Zone** | Elenco zone con range VNUM |
| **Reset zone** | Comandi di reset (caricamento mob/oggetti, porte) |
| **Shop** | Negozi e keeper |
| **Special proc** | Procedure speciali (`myst.spe`) |

### Filtri disponibili

**Oggetti**

- Ricerca testo (FTS) su keywords, nome, descrizioni
- VNUM min / max
- Zona (per range VNUM)
- Tipo oggetto (`ITEM_WEAPON`, `ITEM_ARMOR`, …)
- **Extra flags (tutti)** — nomi separati da virgola; l'oggetto deve averli tutti (es. `ONLY-CLASS, ANTI-RANGER` per oggetti riservati ai ranger; con ONLY-CLASS i flag ANTI-* indicano le classi ammesse)
- Extra flag (bit, uno qualsiasi) e wear flag (valore bitmask)

**Mob**

- Ricerca testo (FTS)
- VNUM, zona, livello min/max
- Razza, tipo mob (`S`, `A`, `L`, …)
- Flag ACT e AFF (bitmask)

**Stanze**

- Ricerca testo (FTS) su nome e descrizione
- VNUM, zona, tipo settore, room flag

**Zone**

- Nome, numero zona

**Reset zone**

- Comando (`M`, `O`, `G`, `E`, `P`, `D`)
- VNUM mob/oggetto/stanza negli argomenti
- Zona, testo libero sulla riga raw

**Shop**

- Keeper (VNUM mob), stanza (VNUM room)

**Special proc**

- Tipo (`M`, `O`, `R`, …), VNUM, nome procedura

Cliccando una riga si apre il **pannello dettaglio** a destra con tutti i campi (affect, uscite, messaggi shop, ecc.).

## Import e aggiornamento database

### Automatico

- Alla prima esecuzione di `./run.sh` se `myst_assets.db` non esiste
- All'avvio del server (`server.py`) se il database manca
- Dal pulsante **Reimporta da mudroot/lib** nell'header dell'interfaccia

### Manuale

```bash
cd tools/myst-assets
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/python import_db.py
```

Opzioni:

```bash
.venv/bin/python import_db.py \
  --lib-dir /percorso/a/mudroot/lib \
  --db /percorso/a/myst_assets.db
```

Dopo aver modificato `myst.obj`, `myst.mob` o altri file in `mudroot/lib`, eseguire un reimport per aggiornare il database.

## API REST

Base URL: `http://localhost:8765`

| Endpoint | Descrizione |
|----------|-------------|
| `GET /api/meta` | Conteggi record, elenco zone, enum per i filtri |
| `GET /api/objects` | Lista oggetti filtrata |
| `GET /api/objects/{vnum}` | Dettaglio oggetto |
| `GET /api/mobiles` | Lista mob filtrata |
| `GET /api/mobiles/{vnum}` | Dettaglio mob |
| `GET /api/rooms` | Lista stanze filtrata |
| `GET /api/rooms/{vnum}` | Dettaglio stanza |
| `GET /api/zones` | Lista zone |
| `GET /api/zones/{zone_index}/resets` | Reset di una zona |
| `GET /api/resets` | Ricerca globale sui reset |
| `GET /api/shops` | Lista shop |
| `GET /api/specials` | Lista special proc |
| `POST /api/reimport` | Rigenera il database da `mudroot/lib` |

Parametri comuni di paginazione: `limit` (max 500), `offset`.

### Esempi

Tutti i mob aggressivi con livello ≥ 30 nella zona index 3:

```
GET /api/mobiles?zone_index=3&level_min=30&act_flag=32
```

Oggetti contenenti "spada" nel testo:

```
GET /api/objects?q=spada
```

Reset che caricano il mob 191:

```
GET /api/resets?command=M&arg_vnum=191
```

## Schema database

SQLite con tabelle:

- `zones` — metadati zona (bottom/top VNUM, lifespan, reset_mode)
- `objects`, `mobiles`, `rooms` — asset principali con `zone_index` derivato dal range
- `zone_resets` — ogni riga di reset con comando e argomenti
- `shops`, `specials` — dati ausiliari
- `objects_fts`, `mobiles_fts`, `rooms_fts` — indici FTS5 per ricerca testuale

I campi `*_text` e `type_name` / `race_name` / `sector_name` sono etichette leggibili decodificate da `shutils/enums.json`.

## Relazione con il codice MUD

| Componente tool | Equivalente MUD |
|-----------------|-----------------|
| `myst_parser.py` | `boot_world()`, `boot_zones()`, `read_obj_from_file()`, `read_mobile()`, `boot_the_shops()` |
| `myst_enums.py` | `#define` in `structs.hpp` / `enums.json` |
| `zone_index` | Indice in `zone_table[]` (non confondere con `zone_num` nel file `.zon`) |

Il tool **non** sostituisce il boot del gioco: è un ausilio offline per consultazione e analisi.

## Risoluzione problemi

**`uvicorn: No such file or directory`** — il virtualenv esiste ma le dipendenze non sono state installate:

```bash
rm -rf .venv
./run.sh
```

Oppure reinstalla senza cancellare il venv:

```bash
.venv/bin/pip install -r requirements.txt
.venv/bin/python -m uvicorn server:app --host 0.0.0.0 --port 8765 --reload
```

**`FileNotFoundError: myst.zon`** — imposta la directory asset:

```bash
export MYST_LIB_DIR=~/docker-vms/nebbietest-mudlet   # root repo su mudlet
./run.sh
```

## Sviluppo

Avvio con reload automatico (già in `run.sh`):

```bash
.venv/bin/python -m uvicorn server:app --host 0.0.0.0 --port 8765 --reload
```

Dopo modifiche al parser o allo schema:

1. Aggiornare `import_db.py` se servono nuove colonne
2. Eliminare `myst_assets.db` o usare `POST /api/reimport`
3. Verificare con `import_db.py` da riga di comando

## Note

- La directory asset viene **rilevata automaticamente** (`myst_paths.py`). Sul branch `mudlet` i file sono nella root del repo, non in `mudroot/lib` (quella cartella ignora i `.obj`/`.zon` in git).
- Il record `#99999` in fondo a `myst.obj` (sentinel `%%`) viene ignorato se incompleto.
- Mob con VNUM duplicato nel file: vince l'ultima occorrenza (`INSERT OR REPLACE`).
- La directory `mudroot/lib` usata di default in assenza di auto-detect è la prima candidata valida tra quelle elencate in `myst_paths.py`.
