# Workflow git su `NebbieArcane/edit-portal`

Repo ufficiale **solo UI** del portale. Il C++ (`edit_portal` in myst) resta in
`NebbieArcane/Server` / fork mud.

## Modello Git Flow (semplificato)

| Branch | Ruolo |
|--------|--------|
| `main` | stabile / deployabile |
| `develop` | integrazione quotidiana (se usata; altrimenti feature da `main`) |
| `feature/<nome>` | lavoro su una feature (git flow feature) |
| `hotfix/<nome>` | fix urgente da `main` |

### Nuova feature (da fare sul clone di `NebbieArcane/edit-portal`)

```bash
git checkout develop          # o main se non usate develop
git pull origin develop
git checkout -b feature/nome-breve
# …lavoro…
git push -u origin feature/nome-breve
# PR → develop (poi develop → main a rilascio)
```

Con **git-flow** CLI:

```bash
git flow init                 # una tantum (main + develop)
git flow feature start nome-breve
git flow feature publish nome-breve
git flow feature finish nome-breve   # merge in develop
```

### Cosa va in questo repo

- `server.js`, `public/`, `package.json`, `Dockerfile`, `docker-compose.yml`
- `docs/`, `scripts/`, `wordpress/mu-plugins`

### Cosa **non** va qui

- `src/edit_portal.cpp`, `obj_edit_catalog`, listino C++, myst — → Server / nebbietest

## Cloud Agent Cursor

Per sviluppare **qui** con un agent: avviare il Cloud Agent sul repo
`NebbieArcane/edit-portal` (non sul fork mud), con accesso GitHub/SSH al repo
privato. Finché l’agent gira su `wizardmorgan/nebbietest`, il lavoro UI va
esportato (branch `publish/edit-portal-ui` o Desktop).

## Export legacy dal fork mud

Branch snapshot solo-UI sul fork (per import/Desktop):

- https://github.com/wizardmorgan/nebbietest/tree/publish/edit-portal-ui  
- ZIP: https://github.com/wizardmorgan/nebbietest/archive/refs/heads/publish/edit-portal-ui.zip  

Vedi anche `edit-portal-publish-desktop.md`.
