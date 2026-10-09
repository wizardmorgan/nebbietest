# Pubblicare su `wizardmorgan/nebbie-mudlet-dashboard`

**Download canonico** (Mudlet Alt+O → Installa da URL, campo `website` nel package, GMCP `Client.GUI`):

`https://raw.githubusercontent.com/wizardmorgan/nebbie-mudlet-dashboard/main/nebbie-complete-dashboard-package.mpackage`

Repo: **https://github.com/wizardmorgan/nebbie-mudlet-dashboard**

## Da `nebbietest` (cloud agent / CI)

Dopo modifiche in `docs/mudlet/`:

```bash
./scripts/publish-nebbie-mudlet-dashboard.sh
```

Lo script: build `.mpackage`, sync su clone di `nebbie-mudlet-dashboard`, commit e push su `main`.

Copia di sviluppo su nebbietest (branch `nebbie-mudlet-dashboard`):

`https://github.com/wizardmorgan/nebbietest/tree/nebbie-mudlet-dashboard`

## Da Mac (manuale)

Stesso script, con `gh auth login` + `gh auth setup-git` se il push fallisce.

```bash
cd /path/to/nebbietest
./scripts/publish-nebbie-mudlet-dashboard.sh
```
