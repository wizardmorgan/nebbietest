# Pubblicazione (repo `wizardmorgan/nebbie-mudlet-dashboard`)

**URL installazione Mudlet (unico canonico):**

`https://raw.githubusercontent.com/wizardmorgan/nebbie-mudlet-dashboard/main/nebbie-complete-dashboard-package.mpackage`

## Da questo repository

```bash
python3 build-nebbie-complete-dashboard-package.py
git add -A
git commit -m "release: ..."
git push origin main
```

**Cloud Agent / CI:** secret `WIZARDMORGAN_GITHUB_SSH_KEY` (deploy key con write su questo repo) oppure PAT con **Contents: write**.

Su **nebbietest**, lo script `scripts/publish-nebbie-mudlet-dashboard.sh` puo' ancora fare mirror da `docs/mudlet/` se serve; il canonical resta **solo** `main` di questo repo.
