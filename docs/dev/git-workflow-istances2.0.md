# Git workflow — feature/istances2.0 (Server)

Ambiente di riferimento: **nucbuntu** `nebbie@100.112.168.62`  
Clone di lavoro: `/home/nebbie/docker-vms/Server`

## Convenzione remote (già in uso su nucbuntu)

| Remote   | Repository                         | Ruolo                          |
|----------|------------------------------------|--------------------------------|
| `origin` | `NebbieArcane/Server`              | **Ufficiale** — da qui scarichi |
| `mine`   | `wizardmorgan/nebbietest`          | **Tuo fork** — qui pushi        |

> Nota: molti tutorial usano `upstream`+`origin` al contrario.  
> Su nucbuntu **non rinominare** se non serve: la convenzione sopra è coerente e documentata.

## Branch

| Branch                 | Dove vive        | Scopo                                      |
|------------------------|------------------|--------------------------------------------|
| `feature/istances2.0`  | origin + mine    | Sviluppo istanze / procarea / dimensioni   |
| `mudlet`               | solo **mine**    | Package Mudlet (lavoro separato)           |
| `develop`              | origin + mine    | Linea release (non usare per istances)     |

## Stato attuale (assessment 2026-06)

- Clone su `feature/istances2.0`, tracking `mine/feature/istances2.0`
- Ultimo commit locale: `f404186` — *Stack Docker consumer e tooling locale* (**tenere**)
- Ufficiale `origin/feature/istances2.0` ha **3 commit** in più dopo il punto comune `006db79`:
  - `2c50ec7` flag INSTANCE
  - `2f0da2e` fatigue tesoro
  - `9188132` tier gruppo + identify affect
- Modifica locale non committata: `mudroot/lib/mud_mail`

## Sync routine (consigliato)

```bash
cd /home/nebbie/docker-vms/Server

# 1. Sistema modifiche locali
git status
git add -p && git commit -m "..."   # oppure: git stash push -m "wip"

# 2. Sincronizza
./scripts/sync-upstream-istances.sh

# 3. In caso di conflitti: risolvi, poi
git add .
git commit   # se merge
# oppure: git rebase --continue   # se hai usato --rebase
git push mine feature/istances2.0
```

### Rebase (storia lineare, opzionale)

```bash
./scripts/sync-upstream-istances.sh --rebase
```

Dopo un rebase che riscriva storia già pushata: `git push --force-with-lease mine feature/istances2.0`  
(usare solo se sai che nessun altro lavora sullo stesso branch del fork)

## Verifica autenticazione GitHub

```bash
cd /home/nebbie/docker-vms/Server
git ls-remote origin HEAD    # lettura pubblica, sempre ok
git ls-remote mine HEAD      # ok senza auth
git push mine feature/istances2.0 --dry-run   # verifica push (non invia)
```

Se il push chiede credenziali o fallisce:

```bash
# Token HTTPS (sostituisci USER e TOKEN)
git remote set-url mine https://USER:TOKEN@github.com/wizardmorgan/nebbietest.git

# Oppure SSH (se hai chiave su GitHub)
git remote set-url mine git@github.com:wizardmorgan/nebbietest.git
ssh -T git@github.com
```

## Mudlet (branch separato)

Il package Mudlet è su `mine/mudlet`, non mescolarlo con `feature/istances2.0`.

Opzioni:

1. **Secondo clone** (più semplice):  
   `git clone -b mudlet https://github.com/wizardmorgan/nebbietest.git ~/docker-vms/nebbietest-mudlet`
2. **Git worktree** (stesso repo, due cartelle):  
   `git worktree add ../nebbietest-mudlet mudlet`

## Prima configurazione (nuovo clone)

```bash
git clone -b feature/istances2.0 https://github.com/wizardmorgan/nebbietest.git Server
cd Server
git remote add origin https://github.com/NebbieArcane/Server.git
git remote rename origin official-tmp 2>/dev/null || true
# Se origin era il fork:
git remote rename origin mine
git remote add origin https://github.com/NebbieArcane/Server.git
git fetch --all --prune
git branch -u mine/feature/istances2.0
```

Su nucbuntu la configurazione è già corretta.
