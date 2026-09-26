# Pubblicare su GitHub (una tantum)

L’agent cloud non può creare repo sotto `wizardmorgan` (permesso GitHub). Da macchina tua:

```bash
cd nebbie-mudlet-dashboard   # oppure copia da /workspace/nebbie-mudlet-dashboard
gh repo create wizardmorgan/nebbie-mudlet-dashboard --private --source=. --remote=origin --push
```

Oppure crea un repo **vuoto** `nebbie-mudlet-dashboard` su GitHub, poi:

```bash
git remote add origin https://github.com/wizardmorgan/nebbie-mudlet-dashboard.git
git push -u origin main
```

Dopo il push, `npackageupdate` e GMCP `Client.GUI` usano:

`https://raw.githubusercontent.com/wizardmorgan/nebbie-mudlet-dashboard/main/nebbie-complete-dashboard-package.mpackage`
