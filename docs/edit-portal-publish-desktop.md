# Pubblicare `NebbieArcane/edit-portal` via GitHub Desktop

Repo ufficiale UI: https://github.com/NebbieArcane/edit-portal (solo portale).  
C++ / myst restano in `NebbieArcane/Server` (o fork `wizardmorgan/nebbietest`).

I Cloud Agent Cursor su questo fork **non** hanno push sul repo privato org finché
l’app GitHub Cursor non include `edit-portal`. Pubblicazione UI: **GitHub Desktop**.

## Primo import

1. GitHub Desktop → **Clone** `NebbieArcane/edit-portal`.
2. Scarica lo ZIP del branch solo-portale sul fork (niente artifact cloud):

   - Branch: https://github.com/wizardmorgan/nebbietest/tree/publish/edit-portal-ui  
   - ZIP diretto: https://github.com/wizardmorgan/nebbietest/archive/refs/heads/publish/edit-portal-ui.zip  

3. Estrai lo ZIP e copia i file **nella root** del clone `edit-portal`  
   (ignora la cartella wrapper `nebbietest-publish-edit-portal-ui/` dello ZIP).
4. Desktop → rivedi i file → **Commit** → **Push origin**.

Contenuto atteso in root: `server.js`, `public/`, `package.json`,
`docker-compose.yml`, `docs/`, `scripts/`, `wordpress/`, `README.md`.

## Aggiornamenti successivi

**Target ufficiale:** sviluppo UI su `NebbieArcane/edit-portal` con **git flow**
(`feature/*` da `develop`/`main`). Vedi `edit-portal-git-flow.md`.

Finché un Cloud Agent non ha accesso a quel repo privato:

1. Si può ancora lavorare UI sul fork mud (`feature/edit-portal`) e ripubblicare
   lo snapshot `publish/edit-portal-ui`, oppure
2. Lavorare in locale/Desktop direttamente su `NebbieArcane/edit-portal`.

Le modifiche C++ (`src/edit_portal.cpp`, catalogo, …) **non** vanno in
`NebbieArcane/edit-portal`: restano PR verso Server / fork mud.
