# Edit portal su nucbuntu — layout ufficiale

Due directory:

| Path | Repo | Contenuto |
|------|------|-----------|
| `~/NebbieArcane/Server` | Server (+ remote `mine` per C++ portal) | myst, mysql, `edit_portal.cpp` |
| `~/NebbieArcane/edit-portal` | **NebbieArcane/edit-portal** | UI Node (`public/`, `server.js`) |

Lo script di gestione mud vive sul **fork mud** (clone Server):

`~/NebbieArcane/Server/scripts/mud-dev.sh`  
(sorgente git: `wizardmorgan/nebbietest`, non `NebbieArcane/Server` upstream)

La UI si aggiorna da `~/NebbieArcane/edit-portal` (`sync-ui`).

Base Montero: **`feature/Principi`** (Razze = produzione/`develop`).

## Setup una tantum

### 1) Deploy key SSH (UI)

Vedi `docs/edit-portal-ssh-deploy.md`. Su nucbuntu:

```bash
# private key già in ~/.ssh/edit_portal_deploy (chmod 600)
export GIT_SSH_COMMAND='ssh -i ~/.ssh/edit_portal_deploy -o IdentitiesOnly=yes'
GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
  git clone git@github.com:NebbieArcane/edit-portal.git ~/NebbieArcane/edit-portal
```

### 2) Config mud-dev

```bash
mkdir -p ~/.config/nebbie
cp ~/NebbieArcane/Server/docs/nebbie-mud-dev.env.example \
   ~/.config/nebbie/mud-dev.env
# verifica PORTAL_UI_ROOT / MUD_ROOT / PRINCIPI_BRANCH=feature/Principi
```

### 3) Override API myst (porta 8090)

```bash
cp ~/NebbieArcane/Server/Confs/docker-compose.override.edit-api.example \
   ~/NebbieArcane/Server/docker-compose.override.yml
# oppure da docs/ nel clone UI se presente
```

## Uso quotidiano

```bash
MD=~/NebbieArcane/Server/scripts/mud-dev.sh

$MD sync-ui                 # pull develop da NebbieArcane/edit-portal
$MD sync-mud                # pull C++ portal (mine/feature/edit-portal)
$MD sync-principi           # merge Montero feature/Principi (tree mud pulito!)
$MD sync-all                # principi + mud C++ + UI

$MD build                   # ricompila myst
$MD build-edit              # rebuild immagine UI
$MD start                   # myst + UI
$MD start-edit              # solo UI
$MD status
$MD doctor                  # dopo upgrade OS / problemi docker
$MD deploy-edit             # sync mud+ui + build + start
```

**Regola fissa:** UI → solo `NebbieArcane/edit-portal`.  
MUD/C++/`mud-dev.sh` → solo `wizardmorgan/nebbietest` (mai sovrascrivere il Server di Montero).

## Sync Principi (conflitti / WIP locali)

Prima di `sync-principi` / `sync-all`:

```bash
cd ~/NebbieArcane/Server
git stash push -u -m "wip before sync"
# oppure: git status  → working tree pulito
```

Poi `$MD sync-all` (o procedura in `docs/sync-principi-procedure.md` sul clone Server).

## Dopo upgrade sistema operativo

```bash
docker --version
docker compose version
$MD doctor
$MD health
# se serve ripartire da zero container:
docker rm -f mudcompiler nebbie-edit-portal 2>/dev/null || true
$MD rebuild-myst
$MD build-edit && $MD start
```

## Porte

| Servizio | Porta |
|----------|-------|
| edit-portal web | 3080 |
| myst edit API | 8090 |
| mysql | 33306 (interno compose) |
| mud telnet | 4002 |
