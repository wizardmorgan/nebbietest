# Pubblicazione (repo `wizardmorgan/nebbie-mudlet-dashboard`)

**URL installazione Mudlet (unico canonico):**

`https://cdn.jsdelivr.net/gh/wizardmorgan/nebbie-mudlet-dashboard@main/nebbie-complete-dashboard-package.mpackage`

(Alternativa GitHub raw, a volte in cache:  
`https://raw.githubusercontent.com/wizardmorgan/nebbie-mudlet-dashboard/main/nebbie-complete-dashboard-package.mpackage`)

## Da questo repository

```bash
python3 build-nebbie-complete-dashboard-package.py
git add -A
git commit -m "release: ..."
git push origin main
```

**Cloud Agent:** secret `WIZARDMORGAN_GITHUB_SSH_KEY` (deploy key con write) oppure PAT con **Contents: write** su questo repository.
