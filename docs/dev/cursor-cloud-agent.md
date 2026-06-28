# Cursor Cloud Agent — dipendenze persistenti

## sshpass (e altri pacchetti di sistema)

I Cloud Agent partono da VM Ubuntu pulite. Per avere **sshpass su ogni agent**, committa nel repo:

| File | Ruolo |
|------|--------|
| `.cursor/Dockerfile` | Installa `sshpass`, `git`, `sudo`, toolchain base nell'immagine |
| `.cursor/environment.json` | Punta al Dockerfile + script `install` idempotente |
| `scripts/cursor-cloud-agent-install.sh` | Fallback `apt install sshpass` + `./getworldlocal` |

Cursor risolve la config in questo ordine: **`.cursor/environment.json` nel repo** → ambiente personale → ambiente team.

Dopo il primo merge di questi file:

1. Avvia un **nuovo Cloud Agent** sul branch `feature/istances2.0`
2. Cursor ricostruisce l'immagine dal Dockerfile (con cache dei layer)
3. Esegue `install` → snapshot interno → boot successivi più veloci

### Cosa NON basta

- Installare `sshpass` a mano in una sessione → perso al reboot (a meno di snapshot manuale dashboard)
- Solo `install-user.sh` nella config utente Cursor (fuori repo) → vale solo per te, non per il team

### Verifica su un agent

```bash
which sshpass
sshpass -V
```

### SSH verso nucbuntu (VPN)

```bash
sshpass -p 'PASSWORD' ssh -o StrictHostKeyChecking=no nebbie@100.112.168.62 'hostname'
```

**Non committare password.** Usa Cursor Secrets per `NUC_SSH_PASS` se serve all'agent.

### Aggiornare install-user.sh personale (opzionale)

Se hai ancora uno script in Cursor Dashboard → Cloud Agent → Install, puoi allinearlo:

```bash
bash scripts/cursor-cloud-agent-install.sh
```

Il file repo `.cursor/environment.json` ha priorità sul repo e sostituisce la necessità di duplicare logica lì.
