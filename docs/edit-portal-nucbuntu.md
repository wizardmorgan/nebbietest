# Portale Edit — deploy su nucbuntu (Docker)

Guida per testare **edit-portal** + API **myst** sullo stack `docker-compose.yml` del repo.

## Architettura

| Servizio | Porta host | Ruolo |
|----------|------------|--------|
| `mysql` | 3306 → 33306 interno | DB `nebbie` |
| `adminer` | 8080 | SQL browser |
| `mudcompiler` | 4000–4003, **8090** | `myst` + API edit (`edit_portal.cpp`) |
| `edit-portal` | **3080** | Web UI + login account |

Flusso: browser → `edit-portal:3080` → (MySQL auth) → API `http://mudcompiler:8090/internal/...` con header `X-Edit-Api-Secret`.

## Prerequisiti su nucbuntu

```bash
docker --version
docker compose version
git
dos2unix   # opzionale ma consigliato dopo copia da Windows
```

Directory di lavoro consigliata: `~/docker-vms/Server` (clone del fork).

## 1. Clone e branch

```bash
cd ~/docker-vms
git clone https://github.com/wizardmorgan/nebbietest.git Server
cd Server
git checkout feature/edit-portal
```

Allineamento periodico con Montero (`NebbieArcane/Server` branch `feature/Razze`):

```bash
git remote add upstream https://github.com/NebbieArcane/Server.git 2>/dev/null || true
git fetch upstream feature/Razze
git merge --no-edit upstream/feature/Razze
# oppure: ./scripts/sync-feature-razze.sh  (se origin punta a NebbieArcane)
```

## 2. Copia mudlib e dump (se nuovo ambiente)

```bash
# mudlib completa (da montero o backup)
rsync -a --exclude=gmon.out \
  /home/nebbie/monterotest/Server/mudroot/lib/ \
  ./mudroot/lib/

# dump MySQL (se DB vuoto)
./scripts/import-mysql-dump.sh /path/to/database_backup_2306.sql
```

Senza `mudroot/lib/myst.mob` il mud non parte.

## 3. Configurazione env

```bash
cp .env.edit-portal.example .env
# modifica SERVER_PORT (es. 4003 per Sirio), segreti se vuoi
```

`docker compose` legge `.env` automaticamente.

## 4. Normalizza script (se copiati da Windows)

```bash
dos2unix scripts/*.sh docker-compose.yml 2>/dev/null || true
chmod +x scripts/docker-entrypoint-mudcompiler.sh scripts/sync-feature-razze.sh
```

## 5. Build myst (con API edit)

Il codice `edit_portal.cpp` è compilato dentro `myst` (GLOB `src/*.cpp`).

```bash
export DOCKER_PLATFORM=linux/amd64
docker compose build edit-portal
docker compose run --rm --entrypoint "" mudcompiler ./build.sh devel
```

Verifica:

```bash
test -x mudroot/myst && echo "myst OK"
```

## 6. Avvio stack

```bash
docker compose up -d --build
docker compose ps
```

Atteso:

- `mysql` healthy
- `mudcompiler` running (telnet porta `SERVER_PORT`)
- `nebbie-edit-portal` running
- log myst: `edit_portal: API listening on port 8090`

## 7. Test funzionale

### Health

```bash
curl -s http://localhost:3080/api/health | jq .
curl -s -X POST http://localhost:8090/internal/ping \
  -H "X-Edit-Api-Secret: nebbie-edit-dev-secret" \
  -H "Content-Type: application/json" -d '{}'
```

### Web UI

Apri: **http://nucbuntu:3080** (o `http://localhost:3080`).

1. Login con email/password tabella `user` (stesso account del sito/mud).
2. Seleziona **toon di sessione** (determina ruolo):
   - **&lt; 51** → `limited` (no apply in MVP)
   - **51+** → `player` (edit sul proprio toon)
   - **≥ 57** → `staff` (qualsiasi toon, lista `object_instance`)
3. Seleziona **target toon** (staff: cerca altri PG).
4. Inventario da MySQL (`character_inventory`).
5. Se il **target è online** nel mud → messaggio warning; apply rifiutato (409).

### Telnet mud

```bash
telnet localhost 4003   # se SERVER_PORT=4003
```

**Regola:** il toon **target** dell'edit non deve essere collegato. Puoi essere online con un altro toon sullo stesso account.

## 8. Ruoli e permessi (implementati)

| Ruolo | Livello toon sessione | Inventario | Apply |
|-------|----------------------|------------|-------|
| `limited` | &lt; 51 | solo proprio toon | bloccato |
| `player` | 51–56 | solo proprio toon | affect + edit pool |
| `staff` | ≥ 57 (`QUESTMASTER`) | tutti i toon | come player + browse `object_instance` |

Staff web = parità con `oedit`/`oload`/`osave` (livello 57).

## 9. Pagamento

- Mega XP: campo `pay_xp` in API (unità **raw** come `character_stats.exp`; listino mega × 1_000_000).
- Rune: `pay_rune` → `p_rune_dei`.
- Principi (livello 51): riserva **400M XP** (`PRINCEEXP`) non spendibile.

Modalità combinata: imposta entrambi i valori nell’UI MVP.

## 10. Troubleshooting

| Problema | Azione |
|----------|--------|
| `myst missing` | Riesegui `./build.sh devel` nel container |
| `edit-api timeout` | myst non running o porta 8090 non esposta |
| `unauthorized` API | `EDIT_API_SECRET` diversa tra mudcompiler e edit-portal |
| Inventario vuoto | PG non migrato su MySQL o inventario solo in rent file |
| Apply 409 | disconnect il **target** toon dal mud |
| Login fallisce | password `user.password` è hash `crypt()` Unix |

Log:

```bash
docker compose logs -f mudcompiler
docker compose logs -f edit-portal
```

Rebuild dopo cambi C++:

```bash
docker compose run --rm --entrypoint "" mudcompiler ./build.sh devel
docker compose restart mudcompiler
```

## 11. Push sul fork

```bash
git add -A
git commit -m "Add edit portal web UI and myst internal API"
git push -u mine feature/edit-portal
```

## 12. Produzione (note)

- Cambiare **tutti** i segreti (`EDIT_API_SECRET`, `EDIT_SESSION_SECRET`).
- Esporre `edit-portal` solo via HTTPS (reverse proxy).
- Non pubblicare porta **8090** (solo rete Docker interna).
- SSO sito: fase successiva (mapping email → `user.id`).

## File principali

| Path | Descrizione |
|------|-------------|
| `src/edit_portal.cpp` | API HTTP su myst, queue sul game loop |
| `edit-portal/server.js` | Auth + proxy API |
| `scripts/docker-entrypoint-mudcompiler.sh` | Avvio myst dopo MySQL |
| `docker-compose.yml` | Servizi mysql + mudcompiler + edit-portal |
