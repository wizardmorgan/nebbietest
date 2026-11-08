# Nebbie unified dashboard (Mudlet)

Repository ufficiale del package Mudlet **`nebbie-complete-dashboard-package`** per Nebbie Arcane.

## Installazione

URL canonico del pacchetto:

`https://cdn.jsdelivr.net/gh/wizardmorgan/nebbie-mudlet-dashboard@main/nebbie-complete-dashboard-package.mpackage`

In Mudlet, nella command line:

```text
lua installPackage("https://cdn.jsdelivr.net/gh/wizardmorgan/nebbie-mudlet-dashboard@main/nebbie-complete-dashboard-package.mpackage")
```

Oppure trascina il link `.mpackage` sul profilo (Mudlet 4.11+). **Non** esiste un bottone “Installa da URL” in Package Manager (Alt+O).

Aggiornamenti successivi: **`npackageupdate`** in gioco.

## Sviluppo

| File | Ruolo |
|------|--------|
| `nebbie-complete-dashboard-package-core.lua` | Logica Lua (sorgente) |
| `build-nebbie-complete-dashboard-package.py` | Genera `.mpackage` + XML di build |
| `analysis/` | Requisiti, changelog, USAGE |
| `tests/` | Smoke test parsing e verify batch |

```bash
python3 build-nebbie-complete-dashboard-package.py
```

Vedi `PUBLISH.md` per il push su `main`.

## Scope

Solo il package unified dashboard. I vecchi package Mudlet (`nebbie-play-all`, spells-skills, ecc.) non fanno parte di questo repository.
