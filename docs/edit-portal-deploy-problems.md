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

## Workflow consigliato (un solo repo)

```bash
cd ~/NebbieArcane/Server
git fetch mine feature/edit-portal
git merge --no-edit mine/feature/edit-portal

./scripts/mud-dev.sh doctor          # diagnosi mount + md5 + ping
./scripts/mud-dev.sh rebuild-myst  # build + ricrea container se mount errato + avvio
./scripts/verify-myst-portal.sh    # deve mostrare portal_api_version: 8

docker compose up -d --build edit-portal
```

## Cosa deve essere vero alla fine

1. `./scripts/mud-dev.sh doctor` → mount `/app` = `~/NebbieArcane/Server`, MD5 host = container  
2. Ping `8090` → `"portal_api_version": 8`  
3. Salvataggio categorie staff → scrive `mudroot/lib/edit_system.json` senza errore  
4. `pgrep myst` → `-d mudroot/lib` (non `-d lib` da script vecchio)

## Due modi di avviare myst (scegliere uno)

| Metodo | Pro | Contro |
|--------|-----|--------|
| **docker-compose entrypoint** (`docker compose up -d mudcompiler`) | Sempre stesso avvio, env EDIT_SYSTEM_CONFIG | Meno familiare per telnet dev |
| **mud-dev.sh start-mud** | Telnet su porta dev | Deve usare container con mount corretto |

Non mescolare: build con `compose run`, myst avviato a mano in container creato mesi fa, restart senza kill.
