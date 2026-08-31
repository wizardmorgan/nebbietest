# Edit portal — perché il deploy sembra “non funzionare”

## Non è (solo) “due repo”

Su nucbuntu usi **un solo clone** (`~/NebbieArcane/Server`) con due remote (`origin` = Razze, `mine` = edit-portal).  
I due repo erano un’opzione storica (`docker-vms/Server`); **non servono** se tutto vive in NebbieArcane.

I problemi reali sono **architetturali nel workflow Docker + avvio myst**, non il fork git in sé.

## Tre cause ricorrenti

### 1. Build ≠ processo in esecuzione

| Cosa | Dove |
|------|------|
| **Build** | `docker compose run --rm mudcompiler ./build.sh` → scrive `mudroot/myst` sul **host** |
| **Myst attivo** | Processo avviato mesi fa con `mud-dev.sh start-mud` **dentro** un container long-lived |

`docker compose restart mudcompiler` **non** sostituisce un myst avviato manualmente con `docker exec`.  
`restart` riavvia solo l’entrypoint del container; se myst è stato lanciato a mano, resta il **binario vecchio in RAM** (o un processo figlio separato).

**Sintomo:** host `mudroot/myst` data 22:16, container `/app/mudroot/myst` data 17:28, ping senza `portal_api_version`.

### 2. Bind mount “congelato” alla creazione del container

Il container `mudcompiler` creato da `mud-dev.sh` monta `MUD_APP_ROOT:/app` **solo alla creazione**.

Se il container è nato quando `MUD_APP_ROOT` puntava a `~/docker-vms/Server` e oggi compili in `~/NebbieArcane/Server`:

- il **build** aggiorna NebbieArcane/Server/mudroot/myst
- il **container** legge ancora docker-vms/Server/mudroot/myst

**Sintomo:** MD5 host ≠ MD5 container (vedi `./scripts/mud-dev.sh doctor`).

**Fix:** `docker rm -f mudcompiler` poi `./scripts/mud-dev.sh rebuild-myst`.

### 3. Git merge bloccato → script vecchi

Merge fallito per modifiche locali a `scripts/verify-myst-portal.sh` → **non arrivano** `rebuild-myst`, fix path config, ecc.

**Sintomo:** `Comando sconosciuto: rebuild-myst` nonostante fetch ok.

**Fix:**

```bash
git stash push -m "local verify" -- scripts/verify-myst-portal.sh
git merge --no-edit mine/feature/edit-portal
git stash pop   # opzionale
```

### 4. `start-edit --remove-orphans` uccide MySQL

Il file `docker-compose.edit-portal.yml` contiene **solo** `edit-portal`.
Con `--remove-orphans`, Compose considera mysql/adminer “orfani” e li **elimina**.
Sintomo: `Container server-mysql-1 Removed`, poi `myst <defunct>`, ping :8090 fallito.

**Fix immediato:**

```bash
./scripts/mud-dev.sh start          # riparte mysql + myst + edit-portal
# oppure separato:
cd ~/NebbieArcane/Server
docker compose up -d mysql adminer
./scripts/mud-dev.sh start-mud
./scripts/mud-dev.sh start-edit     # SENZA remove-orphans (rimosso dallo script)
```

## Workflow consigliato (un solo repo)

```bash
cd ~/NebbieArcane/Server
git fetch mine feature/edit-portal
git merge --no-edit mine/feature/edit-portal

./scripts/mud-dev.sh doctor
./scripts/mud-dev.sh rebuild-myst
./scripts/mud-dev.sh start-edit    # OBBLIGATORIO: setta MUD_STACK_NETWORK e ricrea il container Node
./scripts/verify-myst-portal.sh    # deve mostrare portal_api_version: 8
```

**NON usare** a mano:
`docker compose -f docker-compose.edit-portal.yml up ...`
senza `MUD_STACK_NETWORK` — fallisce con `network declared as external, but could not be found`
e **resta in esecuzione il container web vecchio** (JS/CSS non aggiornati).

Dopo `start-edit`, in alto a destra deve comparire `UI build 8`. Se non c’è: hard refresh
(Ctrl+Shift+R) o finestra anonima.

Restare loggati dopo F5 è normale (cookie di sessione): usa **Logout** se vuoi rivedere login.

## Cosa deve essere vero alla fine

1. `./scripts/mud-dev.sh doctor` → mount `/app` = `~/NebbieArcane/Server`, MD5 host = container  
2. Ping `8090` → `"portal_api_version": 8`  
3. Header web → `UI build 8`  
4. Salvataggio categorie staff → scrive `mudroot/lib/edit_system.json` senza errore  
5. `pgrep myst` → `-d mudroot/lib` (non `-d lib` da script vecchio)

## Due modi di avviare myst (scegliere uno)

| Metodo | Pro | Contro |
|--------|-----|--------|
| **docker-compose entrypoint** (`docker compose up -d mudcompiler`) | Sempre stesso avvio, env EDIT_SYSTEM_CONFIG | Meno familiare per telnet dev |
| **mud-dev.sh start-mud** | Telnet su porta dev | Deve usare container con mount corretto |

Non mescolare: build con `compose run`, myst avviato a mano in container creato mesi fa, restart senza kill.
