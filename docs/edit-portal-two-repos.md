# Nebbie — due repo: upstream Razze + fork edit-portal

Quando **NebbieArcane/Server** deve restare allineato a `origin/feature/Razze` senza merge locali, usare **due directory** e un solo MySQL.

## Ruoli

| Path | Git | Contenuto |
|------|-----|-----------|
| `~/NebbieArcane/Server` | `git pull origin feature/Razze` | Upstream Montero — **non committare** edit-portal qui |
| `~/docker-vms/Server` | `git pull mine feature/edit-portal` | Fork: `edit-portal/`, `edit_portal.cpp`, `docker-compose.edit-portal.yml`, `mud-dev.sh` |

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
# Solo MUD Razze (sorgente NebbieArcane)
MUD_APP_ROOT=~/NebbieArcane/Server ~/docker-vms/Server/scripts/mud-dev.sh start-mud

# MUD + edit-portal (sorgente fork, myst con edit_portal)
~/docker-vms/Server/scripts/mud-dev.sh start

# Status
~/docker-vms/Server/scripts/mud-dev.sh status

# Stop tutto
~/docker-vms/Server/scripts/mud-dev.sh stop-all
```

Con `~/.config/nebbie/mud-dev.env` impostato, basta `~/docker-vms/Server/scripts/mud-dev.sh start`.

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
