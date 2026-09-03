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

**Importante:** prima allinea il clone a `mine`, poi sync Razze. Se salti il `fetch`/`reset`, rischi un secondo merge locale e il push rifiutato (`fetch first`).

```bash
cd ~/NebbieArcane/Server
git checkout feature/edit-portal
git status                    # working tree pulito (niente merge a metà)

# 1) prendi tutto ciò che è già sul fork (agent / altri sync)
git fetch mine
git reset --hard mine/feature/edit-portal

# 2) porta dentro Montero
./scripts/mud-dev.sh sync-razze
# = fetch upstream/feature/Razze + merge su HEAD

# 3) pubblica e builda
git push mine feature/edit-portal
./scripts/mud-dev.sh build    # o: rebuild-myst
```

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

## C) Push rifiutato: `rejected … (fetch first)`

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
