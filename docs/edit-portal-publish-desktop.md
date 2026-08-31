# Pubblicare `NebbieArcane/edit-portal` via GitHub Desktop

Repo ufficiale UI: https://github.com/NebbieArcane/edit-portal (solo portale).  
C++ / myst restano in `NebbieArcane/Server` (o fork `wizardmorgan/nebbietest`).

I Cloud Agent Cursor su questo fork **non** hanno push sul repo privato org finché
l’app GitHub Cursor non include `edit-portal`. Pubblicazione UI: **GitHub Desktop**.

## Primo import

1. GitHub Desktop → **Clone** `NebbieArcane/edit-portal`.
2. Scarica il tarball solo-portale dall’agent (artifact
   `nebbie_edit_portal_only_YYYYMMDD.tgz`) oppure riesportalo dalla cartella
   `edit-portal/` + docs/script come in `docs/edit-portal-two-repos.md`.
3. Estrai **nella root** del clone (non in una sottocartella `edit-portal/`):

   ```bash
   cd ~/path/al/clone/edit-portal
   tar -xzf ~/Downloads/nebbie_edit_portal_only_YYYYMMDD.tgz
   ```

4. Desktop → rivedi i file → **Commit** → **Push origin**.

Contenuto atteso in root: `server.js`, `public/`, `package.json`,
`docker-compose.yml`, `docs/`, `scripts/`, `wordpress/`, `README.md`.

## Aggiornamenti successivi

1. Sviluppo quotidiano UI/API Node: branch `feature/edit-portal` su
   `wizardmorgan/nebbietest` (o merge locale in Server).
2. Quando vuoi pubblicare l’UI ufficiale: chiedi all’agent un **nuovo tarball**
   (o esporta a mano), estrailo nel clone Desktop, Commit + Push.

Le modifiche C++ (`src/edit_portal.cpp`, catalogo, …) **non** vanno in
`NebbieArcane/edit-portal`: restano PR verso Server / fork mud.
