# Cursor Cloud Agent — sshpass (guida breve)

## Cosa abbiamo messo nel repo (già pushato)

```
.cursor/Dockerfile              → installa sshpass nell'immagine VM
.cursor/environment.json        → dice a Cursor di usare quel Dockerfile
scripts/cursor-cloud-agent-install.sh  → fallback se manca qualcosa
```

**Tu non devi installare sshpass a mano su ogni agent.**  
Cursor lo installa quando **costruisce l'ambiente** da questi file.

---

## Cosa devi fare TU (una volta)

### Passo 1 — Assicurati che il repo sul fork abbia i file

Su nucbuntu (cartella Server):

```bash
cd ~/docker-vms/Server
git fetch mine
git merge mine/feature/istances2.0
ls -la .cursor/    # deve mostrare Dockerfile e environment.json
```

### Passo 2 — Avvia un NUOVO Cloud Agent

1. Apri **Cursor** → **Cloud Agents** (o lancia un agent su questo repo)
2. Scegli branch **`feature/istances2.0`** (o quello che usi di solito)
3. Cursor legge `.cursor/environment.json`, costruisce l'immagine, installa sshpass

> Se hai un **vecchio snapshot** salvato nella dashboard Cursor, può ignorare il Dockerfile nuovo.  
> In quel caso: Dashboard → Cloud Agents → Environments → elimina/aggiorna il vecchio ambiente per questo repo.

### Passo 3 — Verifica nell'agent

```bash
which sshpass
sshpass -V
```

Se vedi `sshpass 1.09` (o simile) → ok per sempre su quel tipo di agent.

---

## Cosa NON serve

| Azione | Perché no |
|--------|-----------|
| `apt install sshpass` a mano ogni volta | si perde al reboot |
| Solo `install-user.sh` nella config personale Cursor | non è nel repo, non vale per tutti |
| Modifiche solo su nucbuntu | i Cloud Agent sono VM separate in cloud |

---

## SSH verso nucbuntu dall'agent (opzionale)

Metti la password in **Cursor → Settings → Cloud Agent → Secrets** come `NUC_SSH_PASS`, poi:

```bash
sshpass -p "$NUC_SSH_PASS" ssh -o StrictHostKeyChecking=no nebbie@100.112.168.62 'hostname'
```

Non committare mai la password nel repo.
