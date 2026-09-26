# nebbie-mudlet-dashboard

Dashboard Mudlet personale per **Nebbie Arcane** (`nebbie-complete-dashboard-package`): equip, spell attivi, speedwalk, loot/split, ecc.

Il server MUD resta in [`wizardmorgan/nebbietest`](https://github.com/wizardmorgan/nebbietest); questo repo contiene **solo** il client Mudlet.

## Installazione

1. Scarica [`nebbie-complete-dashboard-package.mpackage`](https://raw.githubusercontent.com/wizardmorgan/nebbie-mudlet-dashboard/main/nebbie-complete-dashboard-package.mpackage)  
   oppure in Mudlet: **`npackageupdate`** (dopo il primo install da file/URL).
2. GMCP `Client.GUI` sul server punta allo stesso URL (vedi `GMCP.md`).

## Sviluppo

```bash
python3 build-nebbie-complete-dashboard-package.py
lua tests/smoke_test_parsing.lua
```

Documentazione: cartella `analysis/` (`USAGE.md`, `CHANGELOG.md`).

## Aggiornamenti in gioco

- **`npackageupdate`** — disinstalla e reinstalla dal branch `main` di questo repo.
- **`nspeedwalks`** — ricarica `getMudletHomeDir()/nebbie-speedwalks.txt`.
