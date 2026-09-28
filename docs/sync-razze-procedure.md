# Riallineare Montero (`feature/Razze`) — procedura fissa (nucbuntu)

Setup tipico (un solo clone):

| Voce | Valore |
|------|--------|
| Path | `~/NebbieArcane/Server` |
| Branch di lavoro | `feature/edit-portal` |
| Remote Montero | `upstream` → `https://github.com/NebbieArcane/Server` |
| Remote fork | `mine` → `https://github.com/wizardmorgan/nebbietest.git` |

In `~/.config/nebbie/mud-dev.env` deve esserci almeno:

```bash
MUD_ROOT="${HOME}/NebbieArcane/Server"
EDIT_REPO="${HOME}/NebbieArcane/Server"
MUD_APP_ROOT="${HOME}/NebbieArcane/Server"
RAZZE_REMOTE=upstream
RAZZE_BRANCH=feature/Razze
EDIT_REMOTE=mine
EDIT_BRANCH=feature/edit-portal
```

**Non** usare `origin` se non esiste (nel tuo clone non c’è).

---

## A) Caso normale — sempre partendo dal fork aggiornato

**Importante:** working tree **pulito**, poi allinea a `mine`, poi sync Razze.  
Se hai modifiche locali (`utility.cpp`, `act.wizard.cpp`, …) Git blocca il merge con *local changes would be overwritten*.

```bash
cd ~/NebbieArcane/Server
git checkout feature/edit-portal
git status                    # deve essere pulito (niente M / unmerged)

# 0) se hai WIP locali da tenere:
git stash push -u -m "wip before sync"
# (se NON ti servono: git restore src/utility.cpp src/act.wizard.cpp …)

# 1) prendi tutto ciò che è già sul fork (agent / altri sync)
git fetch mine
git reset --hard mine/feature/edit-portal

# 2) porta dentro Montero (solo se manca ancora qualcosa)
git fetch upstream feature/Razze
git log --oneline HEAD..upstream/feature/Razze   # vuoto = già allineato
./scripts/mud-dev.sh sync-razze                  # salta se la riga sopra è vuota

# 3) pubblica e builda
git push mine feature/edit-portal
./scripts/mud-dev.sh build    # o: rebuild-myst

# 4) ripristina WIP (se avevi fatto stash)
git stash pop                 # risolvi conflitti se compaiono
```

`sync-all` fa la stessa cosa di `sync-razze` sul clone unico + altri passi: **stesse regole** (tree pulito / stash prima).

Se `sync-razze` dice *già aggiornato*, il push può essere un no-op (già allineati) — ok.

Controllo rapido “manca qualcosa di Montero?”:

```bash
git fetch upstream feature/Razze
git log --oneline HEAD..upstream/feature/Razze
# se non stampa nulla → Razze è già in edit-portal
```

---

## B) Se compaiono conflitti

Non fare `checkout` / altri merge a metà. Due strade:

### B1 — Chiedi all’agent (consigliato se i conflitti sono su C++ condiviso)

1. Lascia il merge in corso **oppure** fai `git merge --abort` e aspetta.
2. Chiedi: *«Montero ha aggiornato Razze, riallinea feature/edit-portal»*.
3. L’agent fa merge su `wizardmorgan/nebbietest` (`feature/edit-portal`), risolve, pusha.
4. Sul nucbuntu:

```bash
cd ~/NebbieArcane/Server
git merge --abort 2>/dev/null || true
git checkout feature/edit-portal
git fetch mine
git reset --hard mine/feature/edit-portal
./scripts/mud-dev.sh build
```

### B2 — Risolvi a mano sul nucbuntu

```bash
cd ~/NebbieArcane/Server
git checkout feature/edit-portal
git fetch mine && git reset --hard mine/feature/edit-portal
./scripts/mud-dev.sh sync-razze
# sistema i file in conflitto, poi:
git add -A
git commit -m "Merge upstream/feature/Razze into feature/edit-portal"
git push mine feature/edit-portal
./scripts/mud-dev.sh build
```

---

## C) Errori tipici sul nucbuntu

### C1 — `Merging is not possible because you have unmerged files`

Sei a metà di un merge precedente (conflitti non chiusi). **Non** rilanciare `sync-razze` così.

```bash
cd ~/NebbieArcane/Server
git merge --abort 2>/dev/null || true
git fetch mine
git reset --hard mine/feature/edit-portal
# poi solo se l'agent non ha già syncato:
./scripts/mud-dev.sh sync-razze
git push mine feature/edit-portal
./scripts/mud-dev.sh build
```

Se `merge --abort` fallisce, il `reset --hard` a `mine/...` ripulisce comunque.

### C1b — `Your local changes … would be overwritten by merge`

Hai file modificati e non committati (es. `src/utility.cpp`, `src/act.wizard.cpp`). Il merge di Razze non parte finché il tree non è pulito.

**Tieni le modifiche:**

```bash
cd ~/NebbieArcane/Server
git status
git stash push -u -m "wip before sync"
git fetch mine
git reset --hard mine/feature/edit-portal
# se l'agent ha già syncato Razze, NON serve sync-razze di nuovo:
git log --oneline HEAD..upstream/feature/Razze   # deve essere vuoto
./scripts/mud-dev.sh build
git stash pop
```

**Scarta le modifiche** (irreversibile su quei file):

```bash
git restore src/act.wizard.cpp src/utility.cpp   # adatta i path
# oppure: git reset --hard HEAD
```

### C2 — Push rifiutato: `rejected … (fetch first)`

Succede quando l’agent (o un altro sync) ha già pushato sul fork mentre sul nucbuntu hai fatto un merge locale parallelo.

**Se non hai modifiche locali da tenere** (caso tipico dopo un `sync-razze` ridondante):

```bash
cd ~/NebbieArcane/Server
git fetch mine
git reset --hard mine/feature/edit-portal
./scripts/mud-dev.sh build
```

Poi, solo se serve ancora Montero più nuovo:

```bash
./scripts/mud-dev.sh sync-razze
git push mine feature/edit-portal
```

**Se proprio vuoi tenere il merge locale** e unirlo al fork (raro):

```bash
git fetch mine
git merge mine/feature/edit-portal
# risolvi conflitti se ci sono
git push mine feature/edit-portal
```

Non usare `git push --force` su `feature/edit-portal` a meno che non ti sia stato chiesto esplicitamente.

---

## D) Solo aggiornare senza rebuild

```bash
git fetch mine && git reset --hard mine/feature/edit-portal
./scripts/mud-dev.sh sync-razze
git push mine feature/edit-portal
```

---

## Comandi utili di controllo

```bash
git remote -v
git branch -vv
git fetch mine
git fetch upstream feature/Razze
git log --oneline HEAD..mine/feature/edit-portal          # cosa manca dal fork
git log --oneline HEAD..upstream/feature/Razze            # cosa manca da Montero
git log --oneline upstream/feature/Razze..HEAD | head     # cosa hai in più (edit-portal)
```

---

## Cosa non fare

- Non `git pull origin …` se `origin` non esiste.
- Non `sync-razze` **senza** prima `git fetch mine` + allineamento al fork (crea merge duplicati → push rejected).
- Non `checkout feature/Razze` a merge incompleto (errore *needs merge*).
- Non confondere **`NebbieArcane/edit-portal`** (solo UI Node) con questo sync mud: Razze/C++ stanno sempre in **Server / nebbietest**.
