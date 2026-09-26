# Repo personale vs branch su nebbietest

**Non serve clonare sul Mac** per usare il dashboard in Mudlet.

Il package aggiornato è già online (branch su `nebbietest`):

`https://raw.githubusercontent.com/wizardmorgan/nebbietest/nebbie-mudlet-dashboard/nebbie-complete-dashboard-package.mpackage`

In Mudlet: **Gestione pacchetti → Installa da URL** (oppure `npackageupdate` se il package punta già a un URL raw).

---

## Se vuoi comunque copiare su `wizardmorgan/nebbie-mudlet-dashboard`

GitHub **non accetta la password dell’account** su `git push` HTTPS.  
Messaggio tipico: *Password authentication is not supported*.

### Metodo consigliato: GitHub CLI (Mac)

```bash
brew install gh
gh auth login
```

Durante `gh auth login` scegli: **GitHub.com** → **HTTPS** → **Yes** per configurare git → **Login with a web browser**.

Poi:

```bash
gh auth setup-git
```

Ora il push usa un token, non la password:

```bash
cd nebbie-mudlet-dashboard   # la tua cartella clonata
git remote -v                # deve essere wizardmorgan/nebbie-mudlet-dashboard
git branch -M main
git push -u origin main
```

Se non hai ancora clonato:

```bash
git clone --branch nebbie-mudlet-dashboard --single-branch \
  https://github.com/wizardmorgan/nebbietest.git nebbie-mudlet-dashboard
cd nebbie-mudlet-dashboard
git remote remove origin
git remote add origin https://github.com/wizardmorgan/nebbie-mudlet-dashboard.git
git branch -M main
gh auth setup-git
git push -u origin main
```

### Alternativa: SSH (se hai già una chiave su GitHub)

```bash
git remote set-url origin git@github.com:wizardmorgan/nebbie-mudlet-dashboard.git
ssh -T git@github.com
git push -u origin main
```

### Non usare

- La **password GitHub** quando git chiede `Password for 'https://…'` — non funziona più.
- Un **token PAT** va incollato al posto della password **solo** se non usi `gh auth setup-git`; con `gh` è più semplice.

---

## URL dopo push su repo personale

`https://raw.githubusercontent.com/wizardmorgan/nebbie-mudlet-dashboard/main/nebbie-complete-dashboard-package.mpackage`

Finché `main` sul repo personale è vuoto o vecchio, resta valido l’URL del branch **nebbietest** in cima a questo file.
