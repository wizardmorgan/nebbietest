# NebbieDash identify sync (VPS)

Hub HTTPS per `nebbie-ident-db` tra PC diversi. Mudlet parla JSON con questo
servizio; davanti metti **nginx / caddy / stunnel** (TLS). Il processo ascolta
di default solo su `127.0.0.1`.

## Requisiti

- Python 3.10+
- Token lungo casuale (`NEBBIE_IDENT_TOKEN`)

## Avvio rapido

```bash
export NEBBIE_IDENT_TOKEN="$(openssl rand -hex 32)"
export NEBBIE_IDENT_DATA="$HOME/nebbie-ident-sync/ident-db.json"
export NEBBIE_IDENT_HOST=127.0.0.1
export NEBBIE_IDENT_PORT=8787
python3 server.py
```

Health (senza auth):

```bash
curl -s http://127.0.0.1:8787/health
```

## API

| Metodo | Path | Auth | Note |
|--------|------|------|------|
| GET | `/health` | no | stato + conteggio entry |
| GET | `/v1/ident?page=1&page_size=5` | Bearer | pagine piccole (limite Mudlet ~10k sul body GET) |
| POST | `/v1/ident/merge` | Bearer | body `{"entries":{...}}`; risposta compatta |

Header: `Authorization: Bearer <token>` oppure `X-Nebbie-Token: <token>`.

Merge: vince l’entry con `lastAt` più alto; `byCharacter` viene unito.

## TLS / ufficio / Tailscale

- **Casa (internet)**: reverse proxy HTTPS pubblico → `127.0.0.1:8787`
- **Tailscale**: stesso proxy sulla IP Tailscale, oppure solo LAN Tailscale
- **Ufficio + stunnel**: termina TLS/stunnel sul VPS e inoltra a `127.0.0.1:8787`
  (stesso percorso che usi già per il MUD)

Esempio nginx:

```nginx
location /nebbie-ident/ {
  proxy_pass http://127.0.0.1:8787/;
  proxy_set_header Host $host;
  proxy_set_header Authorization $http_authorization;
}
```

In Mudlet la base URL sarà ad es. `https://tuo.vps/nebbie-ident` (senza slash finale).

## Mudlet

Nel file preferenze `profiles/ndashboard/nebbie-dash-preferences.txt`:

```
ident_sync_url = https://tuo.vps/nebbie-ident
ident_sync_token = <stesso token del server>
ident_sync_on_boot = off
```

Poi in gioco:

- `nidentsync` — pull a pagine + merge + push
- `nidentpull` — solo scarica/merge
- `nidentpush` — solo invia il DB locale
- `nidentsync status` — URL mascherato + stato

Non condividere il token; non finisce nei log del package (solo URL base).

## systemd (esempio)

Vedi `nebbie-ident-sync.service.example`.
