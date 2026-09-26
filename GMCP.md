# Nebbie Arcane — GMCP (Mudlet)

Nebbie `myst` invia pacchetti **GMCP** (telnet option 201) in stile LEU/Clessidra.

**Package Mudlet:** repo [`wizardmorgan/nebbie-mudlet-dashboard`](https://github.com/wizardmorgan/nebbie-mudlet-dashboard)  
File installabile: `nebbie-complete-dashboard-package.mpackage` (branch `main`).

## Abilitare GMCP in Mudlet

1. **Impostazioni → Server → GMCP** — abilita GMCP per il profilo Nebbie.
2. Connetti al server.
3. In gioco: `lua display(gmcp.char)` — dovresti vedere `vitals` e `base`.

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
  "url": "https://raw.githubusercontent.com/wizardmorgan/nebbie-mudlet-dashboard/main/nebbie-complete-dashboard-package.mpackage",
  "version": "1.15.14"
}
```

Mudlet può offrire il download automatico del package (come ClessidraLet).

## Aggiornamenti

- **Login / riconnessione:** `char.base` + `char.vitals` (+ `Client.GUI` una volta).
- **Ogni prompt in gioco:** `char.vitals` + `char.base` (se GMCP negoziato).

## File sorgente server

| File | Ruolo |
|------|-------|
| `src/gmcp.cpp` | Negoziazione telnet, invio JSON |
| `src/gmcp.hpp` | API pubblica |
| `src/structs.hpp` | `descriptor_data::gmcp_enabled` |
| `src/comm.cpp` | Filtro IAC in input, `gmcp_on_prompt` |
| `src/interpreter.cpp` | `gmcp_send_all` al enter game |

## Roadmap

- Handler GMCP opzionale in `nebbie-complete-dashboard-package` (oggi: solo prompt)
- `char.affects` (buff/debuff strutturati)
- `room.info` (stanza, uscite)
- Richieste client `char.vitals.Get {}` on-demand
