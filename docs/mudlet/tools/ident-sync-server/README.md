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
| GET | `/health` | no | stato + conteggio entry (+ config) |
| GET | `/v1/ident?page=1&page_size=5` | Bearer | pagine piccole (limite Mudlet ~10k sul body GET) |
| POST | `/v1/ident/merge` | Bearer | body `{"entries":{...}}`; risposta compatta |
| GET | `/v1/config/files` | Bearer | elenco file config syncati |
| GET | `/v1/config?file=NAME&page=1` | Bearer | pagine entry di un file |
| POST | `/v1/config/merge` | Bearer | body `{"files":{name:{"entries":{…}}}}` |
| GET | `/v1/ach?toon=NAME&page=1` | Bearer | pagine lista achievement di un toon |
| POST | `/v1/ach/merge` | Bearer | body `{"toons":{name:{"lista":{…}}}}` |

Header: `Authorization: Bearer <token>` oppure `X-Nebbie-Token: <token>`.

**Ident merge**: vince l’entry con `lastAt` più alto; `byCharacter` viene unito.

**Config merge**: **solo additivo** — inserisce chiavi mancanti, non
sovrascrive valori già presenti. Dati in `NEBBIE_CONFIG_DATA` (default:
stessa cartella di `ident-db.json` → `config-db.json`).

**Ach merge**: per toon, per achievement; vince il `prog` più alto (pari → `t`
più alto). Dati in `NEBBIE_ACH_DATA` (default `ach-db.json`).

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

URL di produzione: `https://nebbie.wizmorgan.it/nebbie-ident` (già default nel
package). All’avvio, se manca il token, Mudlet chiede solo quello
(`nidentsync token …`); `nidentsync skip` rimanda a dopo.

Preferenze `profiles/ndashboard/nebbie-dash-preferences.txt`:

```
ident_sync_url = https://nebbie.wizmorgan.it/nebbie-ident
ident_sync_token = <stesso token del server>
ident_sync_on_boot = off
ident_sync_skip_prompt = off
```

Comandi:

- `nidentsync` — pull a pagine + merge + push (identify DB)
- `nidentpull` / `nidentpush`
- `nidentsync token <segreto>` — salva token (+ sync)
- `nidentsync skip` / `setup` — non chiedere all’avvio / ripropone
- `nidentsync status` — URL mascherato + stato
- `ncfgsync` / `ncfgpull` / `ncfgpush` / `ncfgsync list` — sync file
  config `ndashboard` (merge additivo; stesso token)

Non condividere il token; non finisce nei log del package (solo URL base).

Dopo un aggiornamento del server, riavvia il servizio systemd (nuovo file
`config-db.json` creato al primo merge).

## systemd (esempio)

Vedi `nebbie-ident-sync.service.example`.
