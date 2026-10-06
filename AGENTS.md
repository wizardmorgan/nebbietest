# Linee guida progetto (vincolanti)

## Dove va il codice — senza eccezioni

Salvo istruzione **esplicita** dell’utente in questo chat:

| Cosa | Dove pushare / PR |
|------|-------------------|
| UI portale (`public/`, `server.js`, `package.json`, Dockerfile UI, docs UI, wordpress SSO UI) | **`NebbieArcane/edit-portal`** (SSH deploy key `EDIT_PORTAL_SSH_KEY`) |
| Codice MUD / myst C++ (`src/edit_portal*`, `obj_edit_catalog*`, `obj_value*`, listino, sync Principi, **`scripts/mud-dev.sh`**, compose overlay mud) | **`wizardmorgan/nebbietest`** (tipicamente `feature/edit-portal`) |

**Non** pushare UI sul fork mud.  
**Non** pushare/sovrascrivere `NebbieArcane/Server` (repo di Montero): solo `fetch`/`merge` da `upstream`/`feature/Principi` nel lavoro locale o sul fork.

### Branch di lavoro

| Branch | Ruolo |
|--------|--------|
| `NebbieArcane/Server` `develop` | Produzione (ex `feature/Razze`) |
| `NebbieArcane/Server` `feature/Principi` | Base nuovi sviluppi Montero (= develop al momento del taglio) |
| `wizardmorgan/nebbietest` `feature/edit-portal` | C++ portale edit, basato su Principi |
| `NebbieArcane/edit-portal` `develop` | UI Node del portale |

### Remotes tipici (nucbuntu / agent)

- `upstream` → `NebbieArcane/Server` (`feature/Principi`) — read / merge in  
- `origin` o `mine` → `wizardmorgan/nebbietest` — push C++ / mud-dev  
- SSH `git@github.com:NebbieArcane/edit-portal.git` — push UI

### Script gestione locale

`scripts/mud-dev.sh` e `docs/nebbie-mud-dev.env.example` vivono sul **fork mud** (`wizardmorgan/nebbietest`).  
Sul clone nucbuntu: `~/NebbieArcane/Server/scripts/mud-dev.sh` con `PORTAL_UI_ROOT=~/NebbieArcane/edit-portal`.

Comandi sync Montero: `sync-principi` (alias legacy: `sync-razze`).
