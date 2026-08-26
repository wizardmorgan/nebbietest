# Nebbie — edit-portal con un solo repo (consigliato)

## Una directory sola: `~/NebbieArcane/Server`

Non **serve** `docker-vms/Server`. Quella directory era solo un clone del fork usato per testare edit-portal **senza** toccare NebbieArcane — utile se volevi `git pull origin feature/Razze` senza file edit-portal nel working tree.

Se il mud già gira su **NebbieArcane/Server**, usa **solo quella**:

| Cosa | Dove |
|------|------|
| MUD + myst + mysql | `~/NebbieArcane/Server` |
| `git pull` Montero | `origin feature/Razze` |
| edit-portal + `edit_portal.cpp` | stesso repo, branch locale (es. merge da `mine/feature/edit-portal`) |
| `mud-dev.sh` | `scripts/mud-dev.sh` (dal fork, non in upstream) |
| `docker-compose.override.yml` | locale, non committato |

`docker-vms/Server` è **opzionale** — puoi ignorarla o eliminarla.

## Git su un solo repo

```bash
cd ~/NebbieArcane/Server

# Remote fork (se non c'è)
git remote add mine https://github.com/wizardmorgan/nebbietest.git 2>/dev/null || true

# Porta edit-portal sul branch che usi (es. dopo pull Razze)
git fetch mine feature/edit-portal
git merge mine/feature/edit-portal
# oppure: git checkout -b feature/Razze-edit-portal mine/feature/edit-portal

# Aggiornamenti upstream Montero
git fetch origin feature/Razze
git merge origin/feature/Razze
```

File locali da **non** committare su upstream: `docker-compose.override.yml`, opzionale `scripts/mud-dev.sh` in `.git/info/exclude`.

## Config mud-dev

```bash
mkdir -p ~/.config/nebbie
cp docs/nebbie-mud-dev.env.example ~/.config/nebbie/mud-dev.env
# Tutti i path = NebbieArcane/Server

cp Confs/docker-compose.override.edit-api.example docker-compose.override.yml

./build.sh devel   # oppure docker compose run ... ./build.sh devel
~/NebbieArcane/Server/scripts/mud-dev.sh start
```

## Due directory (solo se insisti su pull Razze “pulito”)

Vedi sotto — **non necessario** se accetti un branch locale con edit-portal.

---

# (Opzionale) Due repo separati

| Risorsa | Dove vive |
|---------|-----------|
| `mysql_data/` | **NebbieArcane/Server** (un solo DB) |
| myst sorgente (solo Razze) | mount `NebbieArcane/Server` → `/app` |
| myst con edit API | mount `docker-vms/Server` → `/app` (branch edit-portal) |
| Web edit-portal | container da `docker-compose.edit-portal.yml` nel fork |

## Setup una tantum su nucbuntu

```bash
# 1) Config locale (non nel repo NebbieArcane)
mkdir -p ~/.config/nebbie
cp ~/docker-vms/Server/docs/nebbie-mud-dev.env.example ~/.config/nebbie/mud-dev.env
# Modifica i path se diversi

# 2) Su NebbieArcane: override Docker solo locale (porta 8090 API edit)
cp ~/docker-vms/Server/Confs/docker-compose.override.edit-api.example \
   ~/NebbieArcane/Server/docker-compose.override.yml
# docker-compose.override.yml NON va in git su NebbieArcane

# 3) Build myst con edit_portal (nel fork)
docker compose -f ~/NebbieArcane/Server/docker-compose.yml \
  run --rm --entrypoint "" \
  -v ~/docker-vms/Server:/app \
  mudcompiler ./build.sh devel
```

## Uso quotidiano

```bash
~/docker-vms/Server/scripts/mud-dev.sh          # help (default)
~/docker-vms/Server/scripts/mud-dev.sh dev    # dopo update Montero: sync-all + build + start
~/docker-vms/Server/scripts/mud-dev.sh start  # solo avvio (senza pull)
~/docker-vms/Server/scripts/mud-dev.sh status
```

Comandi git/build: `sync-razze`, `sync-edit`, `sync-all`, `update-razze`, `update-all`, `build`, `build-edit`, `health` — vedi `./scripts/mud-dev.sh help`.

## Aggiornare upstream senza conflitti

```bash
cd ~/NebbieArcane/Server
git fetch origin
git checkout feature/Razze
git pull origin feature/Razze
# Nessun merge da nebbietest qui
```

Aggiornare il fork edit:

```bash
cd ~/docker-vms/Server
git pull mine feature/edit-portal
```

Dopo pull upstream, ricompilare myst se cambia il C++:

```bash
# Razze only
docker compose -f ~/NebbieArcane/Server/docker-compose.yml run --rm --entrypoint "" \
  -v ~/NebbieArcane/Server:/app mudcompiler ./build.sh devel

# Con edit-portal
docker compose -f ~/NebbieArcane/Server/docker-compose.yml run --rm --entrypoint "" \
  -v ~/docker-vms/Server:/app mudcompiler ./build.sh devel
```

## mud-dev.sh

Lo script **non** è nel repo NebbieArcane ufficiale. Tenere una copia solo nel fork o invocare il path assoluto:

`~/docker-vms/Server/scripts/mud-dev.sh`

Opzionale: copia in NebbieArcane **senza commit**:

```bash
cp ~/docker-vms/Server/scripts/mud-dev.sh ~/NebbieArcane/Server/scripts/
echo 'scripts/mud-dev.sh' >> ~/NebbieArcane/Server/.git/info/exclude
```

## Verifica edit-portal

```bash
curl -s -X POST http://localhost:8090/internal/ping -H "X-Edit-Api-Secret: nebbie-edit-dev-secret"
curl -s http://localhost:3080/api/health
```

Log myst: `grep edit_portal ~/NebbieArcane/Server/mudroot/alarmud.log` (se log su volume NebbieArcane) oppure `mud-dev.sh logs`.
