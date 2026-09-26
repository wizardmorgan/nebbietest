# nebbie-mudlet-dashboard

Dashboard Mudlet personale per **Nebbie Arcane** (`nebbie-complete-dashboard-package`).

## Dove è il codice adesso

| Posto | Stato |
|-------|--------|
| [github.com/wizardmorgan/nebbie-mudlet-dashboard](https://github.com/wizardmorgan/nebbie-mudlet-dashboard) | Repo **personale** — resta **vuoto** finché non fai push dal Mac (vedi sotto). |
| [nebbietest → branch `nebbie-mudlet-dashboard`](https://github.com/wizardmorgan/nebbietest/tree/nebbie-mudlet-dashboard) | **Sorgente attuale** + `.mpackage` (aggiornato dall’agent cloud). |

**Mudlet:** installa / aggiorna con **`npackageupdate`** (≥1.15.15) o URL raw:

`https://raw.githubusercontent.com/wizardmorgan/nebbietest/nebbie-mudlet-dashboard/nebbie-complete-dashboard-package.mpackage`

Non serve clonare nulla sul Mac solo per giocare.

## Sviluppo (agent / CI)

Push su `nebbietest` branch `nebbie-mudlet-dashboard`. Build:

```bash
python3 build-nebbie-complete-dashboard-package.py
lua tests/smoke_test_parsing.lua
```

## Riempire il repo personale (opzionale, una tantum)

Vedi **`PUBLISH.md`**. Sul Mac **prima** del push:

```bash
gh auth login
gh auth setup-git
```

Poi push da clone del branch su nebbietest (istruzioni complete in `PUBLISH.md`). Dopo un `main` pieno sul repo personale si può spostare l’URL raw lì; finché è vuoto, usa il branch su nebbietest.

Il server MUD resta in [`wizardmorgan/nebbietest`](https://github.com/wizardmorgan/nebbietest) (`src/gmcp.cpp` → URL package).
