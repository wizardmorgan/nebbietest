# SSH deploy key per `NebbieArcane/edit-portal`

Chiave **dedicata** (solo questo repo), usata dai Cloud Agent per `git push`
via `git@github.com:NebbieArcane/edit-portal.git`.

## Setup una tantum

1. **GitHub** → repo `edit-portal` → Settings → **Deploy keys** → Add:
   - Title: `cursor-cloud-agent`
   - Key: la **public** key (ed25519) fornita dall’agent
   - **Allow write access**: sì

2. **Cursor secret** `EDIT_PORTAL_SSH_KEY` = contenuto completo della **private**
   key (blocco `BEGIN OPENSSH PRIVATE KEY` … `END`).

3. Nell’agent, dopo che il secret è iniettato:

   ```bash
   mkdir -p ~/.ssh && chmod 700 ~/.ssh
   printenv EDIT_PORTAL_SSH_KEY > ~/.ssh/edit_portal_deploy
   chmod 600 ~/.ssh/edit_portal_deploy
   ssh-keyscan -t ed25519,rsa github.com >> ~/.ssh/known_hosts 2>/dev/null
   export GIT_SSH_COMMAND='ssh -i ~/.ssh/edit_portal_deploy -o IdentitiesOnly=yes'
   git clone git@github.com:NebbieArcane/edit-portal.git
   ```

## Git flow (su quel clone)

```bash
git checkout develop   # o main
git checkout -b feature/nome
# …
git push -u origin feature/nome
```

Non riusare questa chiave su altri repo; non committare mai la private key.
