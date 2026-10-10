# Pubblicazione — solo `wizardmorgan/nebbie-mudlet-dashboard`

**URL installazione Mudlet (unico canonico):**

`https://raw.githubusercontent.com/wizardmorgan/nebbie-mudlet-dashboard/main/nebbie-complete-dashboard-package.mpackage`

Repo: https://github.com/wizardmorgan/nebbie-mudlet-dashboard

## Dopo ogni modifica a `docs/mudlet/`

```bash
./scripts/publish-nebbie-mudlet-dashboard.sh
```

Richiede un PAT con scrittura sul repo personale (`NEBBIE_MUDLET_DASHBOARD_PAT` o `WIZARDMORGAN_GITHUB_PAT`).

Su **nebbietest** il workflow `publish-nebbie-mudlet-dashboard.yml` fa la stessa cosa se il secret `NEBBIE_MUDLET_DASHBOARD_PAT` è configurato nelle Actions del repo.

Il branch `nebbie-mudlet-dashboard` su **nebbietest** è solo copia di backup/sviluppo — **non** è l’URL da dare ai giocatori.
