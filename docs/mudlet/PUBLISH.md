# Pubblicazione — solo `wizardmorgan/nebbie-mudlet-dashboard`

**URL installazione Mudlet (unico canonico):**

`https://raw.githubusercontent.com/wizardmorgan/nebbie-mudlet-dashboard/main/nebbie-complete-dashboard-package.mpackage`

Repo: https://github.com/wizardmorgan/nebbie-mudlet-dashboard

## Dopo ogni modifica a `docs/mudlet/`

```bash
./scripts/publish-nebbie-mudlet-dashboard.sh
```

**Preferito (Cloud Agent):** secret `WIZARDMORGAN_GITHUB_SSH_KEY` = chiave privata OpenSSH dell’account **wizardmorgan** con accesso in scrittura a `nebbie-mudlet-dashboard` (non `EDIT_PORTAL_SSH_KEY`, che è deploy key su altri repo).

Alternativa: PAT **fine-grained** con **Contents: Read and write** solo su `wizardmorgan/nebbie-mudlet-dashboard` (`NEBBIE_MUDLET_DASHBOARD_PAT` negli secret del Cloud Agent **e** in **nebbietest → Settings → Secrets → Actions**).

### Se il push fallisce (403 / “Resource not accessible by personal access token”)

Il token in ambiente spesso è **sola lettura**: l’API risponde `permissions.push: true` ma `git push` e `PUT /contents` restano 403. Rigenera il PAT con **Contents: write** o usa la deploy key SSH.

**Deploy key (consigliata per Cloud Agent):**

1. Genera una coppia (`ssh-keygen -t ed25519 -C nebbie-mudlet-dashboard-cloud-agent`).
2. Su https://github.com/wizardmorgan/nebbie-mudlet-dashboard/settings/keys → **Add deploy key** → incolla la `.pub` → **Allow write access**.
3. Secret Cursor `WIZARDMORGAN_GITHUB_SSH_KEY` = contenuto della chiave privata.

Su **nebbietest** il workflow `publish-nebbie-mudlet-dashboard.yml` esegue lo stesso script al push su `nebbie-mudlet-dashboard` / `mudlet` (fallisce se il secret Actions è vuoto).

Il branch `nebbie-mudlet-dashboard` su **nebbietest** è solo copia di backup/sviluppo — **non** è l’URL da dare ai giocatori.
