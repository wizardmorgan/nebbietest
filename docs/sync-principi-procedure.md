# Riallineare Montero (`feature/Principi`) — procedura fissa (nucbuntu)

> `feature/Razze` è in produzione (= `develop`). La base di sviluppo Montero è **`feature/Principi`**.

## Mappa

| Cosa | Valore |
|------|--------|
| Clone mud | `~/NebbieArcane/Server` |
| Branch di lavoro | `feature/edit-portal` |
| Remote Montero | `upstream` → `NebbieArcane/Server` |
| Remote fork portal | `mine` → `wizardmorgan/nebbietest` |
| UI Node | `~/NebbieArcane/edit-portal` (`NebbieArcane/edit-portal`) |

Config consigliata in `~/.config/nebbie/mud-dev.env`:

```bash
PRINCIPI_REMOTE=upstream
PRINCIPI_BRANCH=feature/Principi
EDIT_REMOTE=mine
EDIT_BRANCH=feature/edit-portal
PORTAL_UI_ROOT="${HOME}/NebbieArcane/edit-portal"
```

**Importante:** working tree **pulito**, poi allinea a `mine`, poi sync Principi.  
(`sync-razze` resta un alias di `sync-principi`.)

## A) Sync quotidiano (script)

```bash
cd ~/NebbieArcane/Server
git status   # deve essere pulito, altrimenti stash
git stash push -u -m "wip before sync $(date +%F)"   # se serve

git checkout feature/edit-portal
./scripts/mud-dev.sh sync-all    # principi + mud + ui
# oppure solo Montero+C++:
#   ./scripts/mud-dev.sh sync-principi && ./scripts/mud-dev.sh sync-mud

./scripts/mud-dev.sh build
./scripts/mud-dev.sh build-edit
./scripts/mud-dev.sh start
./scripts/mud-dev.sh health
./scripts/mud-dev.sh doctor
```

Verifica allineamento:

```bash
git fetch upstream feature/Principi
git log --oneline HEAD..upstream/feature/Principi   # vuoto = già allineato
git push mine feature/edit-portal                   # se hai merge locali da pubblicare
```

## B) Agent / cloud

1. Montero aggiorna `feature/Principi`.
2. Chiedi: *«Montero ha aggiornato Principi, riallinea feature/edit-portal»*.
3. L’agent fa merge su `wizardmorgan/nebbietest` (`feature/edit-portal`), risolve, pusha.
4. Sul nucbuntu: `sync-mud` (o `sync-all`) + `build` + `start`.

## C) Errori tipici sul nucbuntu

### Working tree sporco / unmerged

```bash
git merge --abort   # se merge a metà
git stash push -u -m "wip"
git fetch mine && git reset --hard mine/feature/edit-portal
```

### Push rejected (fetch first)

```bash
git fetch mine
git reset --hard mine/feature/edit-portal
# poi ripeti sync-principi solo se serve
```

### UI non è un clone git

La UI deve stare in `~/NebbieArcane/edit-portal` (repo ufficiale), non nella cartella legacy `Server/edit-portal`.

```bash
# una tantum
GIT_SSH_COMMAND='ssh -i ~/.ssh/edit_portal_deploy -o IdentitiesOnly=yes' \
  git clone git@github.com:NebbieArcane/edit-portal.git ~/NebbieArcane/edit-portal
echo 'PORTAL_UI_ROOT=/home/nebbie/NebbieArcane/edit-portal' >> ~/.config/nebbie/mud-dev.env
```

### Dopo upgrade OS

```bash
docker --version && docker compose version
./scripts/mud-dev.sh doctor
./scripts/mud-dev.sh health
# se mount/container spuri:
docker rm -f mudcompiler nebbie-edit-portal 2>/dev/null || true
./scripts/mud-dev.sh rebuild-myst
./scripts/mud-dev.sh build-edit
./scripts/mud-dev.sh start
```

## Non fare

- Non sovrascrivere `NebbieArcane/Server` con push del fork.
- Non usare `git push --force` su `feature/edit-portal` senza richiesta esplicita.
- Non confondere **`NebbieArcane/edit-portal`** (solo UI Node) con questo sync mud.
