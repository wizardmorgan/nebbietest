# Nebbie Arcane — GMCP (Mudlet)

<<<<<<< HEAD
Nebbie `myst` invia pacchetti **GMCP** (telnet option 201) in stile LEU/Clessidra. Il package `nebbie-play-all` v2.2.34+ li consuma con fallback al parser del prompt.
=======
Nebbie `myst` invia pacchetti **GMCP** (telnet option 201) in stile LEU/Clessidra.

**Package Mudlet consigliato:** `nebbie-complete-dashboard-package` (branch `mudlet`).
Il server espone GMCP indipendentemente dal client; il dashboard attuale usa il parser del
prompt per HUD/vitali — GMCP resta disponibile in Mudlet (`lua display(gmcp.char)`) e per
integrazioni future nel package.
>>>>>>> origin/mudlet

## Abilitare GMCP in Mudlet

1. **Impostazioni → Server → GMCP** — abilita GMCP per il profilo Nebbie.
2. Connetti al server.
3. In gioco: `lua display(gmcp.char)` — dovresti vedere `vitals` e `base`.
<<<<<<< HEAD
4. Nel package Nebbie: `ngmcp` per diagnostica, `nprompt` per il parser testuale.
=======
>>>>>>> origin/mudlet

## Pacchetti inviati dal server

### `char.vitals`

```json
{
  "hp": 654,
  "maxhp": 654,
  "mana": 533,
  "maxmana": 533,
  "move": 265,
  "maxmove": 265,
  "pow": 265,
  "maxpow": 265
}
```

`pow` / `maxpow` duplicano `move` per compatibilità con client stile LEU.

### `char.base`

```json
{
  "name": "Mirari",
  "class": "Thief",
  "level": 42,
  "experience": 284216936,
  "gold": 49287175,
  "toNext": 12345
}
```

### `Client.GUI` (solo al primo login GMCP)

```json
{
<<<<<<< HEAD
  "url": "https://raw.githubusercontent.com/wizardmorgan/nebbietest/mudlet/docs/mudlet/nebbie-play-all.mpackage",
  "version": "2.2.34"
=======
  "url": "https://raw.githubusercontent.com/wizardmorgan/nebbietest/mudlet/docs/mudlet/nebbie-complete-dashboard-package.mpackage",
  "version": "1.15.11"
>>>>>>> origin/mudlet
}
```

Mudlet può offrire il download automatico del package (come ClessidraLet).

## Aggiornamenti

- **Login / riconnessione:** `char.base` + `char.vitals` (+ `Client.GUI` una volta).
- **Ogni prompt in gioco:** `char.vitals` + `char.base` (se GMCP negoziato).

<<<<<<< HEAD
## Client `nebbie-play-all`

| Comando | Azione |
|---------|--------|
| `ngmcp` | Stato GMCP, ultimo evento, merge verso HUD |
| `nprompt` | Debug parser prompt (fallback) |
| `nsetup` | Reinstalla HUD |

Handler: `registerAnonymousEventHandler("gmcp.char", "Nebbie.fUpdateGMCP")`.

Se GMCP è attivo negli ultimi 3 secondi, il parser prompt non sovrascrive HP/MN/MV (ma aggiorna ancora fight line e buff codes).

=======
>>>>>>> origin/mudlet
## File sorgente server

| File | Ruolo |
|------|-------|
| `src/gmcp.cpp` | Negoziazione telnet, invio JSON |
| `src/gmcp.hpp` | API pubblica |
| `src/structs.hpp` | `descriptor_data::gmcp_enabled` |
| `src/comm.cpp` | Filtro IAC in input, `gmcp_on_prompt` |
| `src/interpreter.cpp` | `gmcp_send_all` al enter game |

## Roadmap

<<<<<<< HEAD
=======
- Handler GMCP opzionale in `nebbie-complete-dashboard-package` (oggi: solo prompt)
>>>>>>> origin/mudlet
- `char.affects` (buff/debuff strutturati)
- `room.info` (stanza, uscite)
- Richieste client `char.vitals.Get {}` on-demand
