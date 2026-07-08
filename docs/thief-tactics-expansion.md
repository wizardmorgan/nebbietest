# Espansione tattiche Ladro (livelli 5–51)

Documento di riferimento per sviluppatori e tester. Branch: `cursor/thief-tactics-expansion-3a37`.

## Panoramica

Quattordici nuove abilità ladro (skill **295–308**), crafting da reagenti acquistabili in Myst, hook di combattimento (veleno on-hit, hamstring che blocca tumble, ecc.) e capstone **Find the Seam** al ladro 51 mono-classe.

Implementazione principale: `src/thief_tactics.cpp`, `src/thief_tactics.hpp`.

---

## Modifiche al codice

| Area | File | Cosa fa |
|------|------|---------|
| Skill, crafting, combattimento | `src/thief_tactics.cpp` | Ricette, comandi, proc veleno, passive |
| Costanti vnum reagenti | `src/utils.hpp` | `THIEF_ING_*` (18072, 18001–18003, 18073–18074) |
| Definizione skill | `src/spells.hpp` | `SKILL_POCKET_SAND` … `SKILL_FIND_THE_SEAM` (295–308) |
| Nomi skill / practice | `src/constants.cpp` | Stringhe per `practice thief` |
| List negozio | `src/shop.cpp` | `list` da tabella `producing[]` + stock keeper |
| Hook combattimento | `src/fight.cpp` | Cheap shot, poison proc, hamstring, find the seam, riposte |
| Gilda ladro | `src/spec_procs.cpp` | Practice nuove skill, lista gilda |
| Scheda skill | `src/act.info.cpp` | `skills` con gate livello ladro |
| Advance livello | (via `thief_on_advance_level`) | Auto-apprendimento skill al salire di livello |

### Comportamenti importanti

- **Ladro puro** (`OnlyClass`, mono): richiesto per Poisoncraft, Mix/Throw, Vault, Snatch, Find the Seam.
- **Apprendimento automatico**: al raggiungimento del livello gate, `thief_on_advance_level` imposta `SKILL_KNOWN` + `SKILL_KNOWN_THIEF` e `learned` minimo.
- **Veleno on-hit**: dopo `envenom`, l’arma ha cariche in `iGeneric1`/`iGeneric2`; in fight può proccare `apply_poison_effect`.
- **Hamstring**: affligge la vittima; chi ha hamstring non può usare `tumble`.
- **Find the Seam**: passiva su colpi perforanti / backstab vs armature con immunità perforante.

---

## Modifiche al mondo (produzione)

Patch applicata con:

```bash
./scripts/apply-production-world-patch.sh
./scripts/verify-thief-reagent-shops.sh
```

Fragment in `world-patches/thief-crafting/`. Dettaglio operativo: `world-patches/thief-crafting/WORKFLOW.txt`.

| File | Modifica |
|------|----------|
| `myst.obj` | 6 ingredienti (#18072, #18001–#18003, #18073–#18074) **prima di `#99999`** |
| `myst.shp` | Negozi #3005 e #3006 con i 6 reagenti |
| `myst.zon` | Spawn mob 3042/3043 + reset `G` reagenti in inventario |
| `myst.mob` | Rimosso `ACT_THIEF` da Drunky, Spanky, Flasite |
| `myst.wld` | (opzionale `--flavor`) odore reagenti in gilde 3076 e 7828 |
| `mudroot/lib/helptbl` | Copia da `pages/helptbl` — **myst legge help da DATA_DIR dopo `chdir`** |
| `pages/helptbl` | Help testuale delle 14 skill nuove |

### Negozi reagenti

| Negozio | Mob | Stanza | Prodotti |
|---------|-----|--------|----------|
| #3005 | L'Attendente mago (3042) | 3047 (torre della magia) | estratto, resina, sale |
| #3006 | L'Attendente (3043) | 3003 (ingresso cappella) | olio, legante, fiale |

### Vnum ingredienti

Vedi `world-patches/thief-crafting/VNUMS.txt`. **Non usare** vnum con overlay in `mudroot/lib/objects/` (regola in `OVERLAYS.txt`).

| Vnum | Ingrediente (keyword inventario) |
|------|----------------------------------|
| 18072 | `toxic extract` / estratto tossico |
| 18001 | `nightshade resin` / resina morella |
| 18002 | `alkali salt` / sale alcalino |
| 18003 | `volatile oil` / olio volatile |
| 18073 | `binding agent` / agente legante |
| 18074 | `glass vial` / fiala di vetro |

---

## Nuove abilità (295–308)

Livello = **livello ladro** (classe thief), non livello totale PG.

| ID | Nome | Liv. | Mono | Comando | Tipo |
|----|------|------|------|---------|------|
| 295 | Pocket Sand | 5 | no | `sand <bersaglio>` | attiva |
| 296 | Cheap Shot | 8 | no | *(passiva in combattimento)* | passiva |
| 297 | Tumble | 12 | no | `tumble <direzione>` | attiva |
| 306 | Poisoncraft | 15 | **sì** | `poison <ricetta>`, `envenom <vial>` | crafting |
| 298 | Feint | 16 | no | `feint` | attiva |
| 299 | Riposte | 20 | no | *(passiva su schivata)* | passiva |
| 300 | Hamstring | 24 | no | `hamstring` | attiva |
| 301 | Circle Kick | 28 | no | `ckick <bersaglio>` | attiva |
| 302 | Gouge | 32 | no | `gouge <bersaglio>` | attiva |
| 303 | Gag | 36 | no | `gag <bersaglio>` | attiva |
| 304 | Vault | 42 | **sì** | `vault <alleato>` | attiva |
| 307 | Mix / Throw | 45 | **sì** | `mix <ricetta>`, `throwpotion <vial> <bersaglio>` | crafting |
| 305 | Snatch | 48 | **sì** | `snatch` | attiva |
| 308 | Find the Seam | 51 | **sì** | *(passiva su perforante/backstab)* | passiva |

**Nota nomi:** la skill si chiama *poisoncraft* in gilda/help, ma il **comando** è `poison`, non `poisoncraft`.

### Help in gioco

```text
help pocket
help poisoncraft
help hamstring
```

Il sistema help indicizza **parole singole** (`help pocket sand` non funziona; usare `help pocket`).

Dopo deploy: verificare `grep 'POCKET SAND' mudroot/lib/helptbl` e **riavviare** il consumer (`reload` non ricarica helptbl).

---

## Crafting — veleni (`poison`)

**Requisiti:** ladro puro, skill poisoncraft, ingredienti in inventario (keyword inglesi).

```text
poison <weak|numb|bleed|paralytic|nightfall|blacklotus>
envenom <vial>          # arma impugnata
```

| Ricetta | Liv. min | Ingredienti |
|---------|----------|-------------|
| weak | 15 | toxic extract, glass vial |
| numb | 18 | toxic extract, nightshade resin, glass vial |
| bleed | 20 | toxic extract, volatile oil, glass vial |
| paralytic | 24 | nightshade resin, binding agent, glass vial |
| nightfall | 30 | nightshade resin, toxic extract, volatile oil, glass vial |
| blacklotus | 40 | nightshade resin, toxic extract, alkali salt, binding agent, glass vial |

Dopo `poison …` si ottiene un vial in inventario. `envenom vial` (o `envenom blacklotus`) applica il veleno all’arma impugnata.

---

## Crafting — fiale (`mix`)

**Requisiti:** ladro puro, skill mix throw (liv. 45+ per la maggior parte).

```text
mix <acid|smoke|fire|choking|shrapnel|sand>
throwpotion <vial> <bersaglio>
```

| Ricetta | Liv. min | Ingredienti | Effetto |
|---------|----------|-------------|---------|
| sand | 5 | alkali salt, binding agent | sacchetto per pocket sand |
| acid | 15 | alkali salt, volatile oil, glass vial | singolo bersaglio |
| smoke | 20 | volatile oil, binding agent, glass vial | area stanza |
| fire | 25 | volatile oil, alkali salt, glass vial | singolo bersaglio |
| choking | 30 | nightshade resin, alkali salt, glass vial | area stanza |
| shrapnel | 35 | alkali salt, binding agent, glass vial | area stanza |

`blacklotus` è solo ricetta **veleno**, non `mix`.

---

## Gilda e practice

- Gilda ladro Myst: stanza **3076**
- Gilda ladro Thalos: stanza **7828**
- Parla col maestro ladro; senza argomenti mostra abilità praticabili al tuo livello.
- `practice thief` / `practise thief` — elenco skill conosciute.

Esempi practice:

```text
practise sand
practise feint
practise poisoncraft
```

---

## Test rapido (imm / PG alto livello)

### Verifica mondo

```bash
./scripts/verify-thief-reagent-shops.sh
```

### Imm — sessioni practice e skill

```text
@ prac talete 50
@ skills talete 306 80
@ known talete 306 17
```

(`17` = `SKILL_KNOWN` + `SKILL_KNOWN_THIEF`; ripetere per skill 295–308.)

Ladro 51 mono per Find the Seam:

```text
@ lev talete 51 4
```

(classe 4 = thief nell’indice `@ lev`.)

### Checklist in gioco

1. `list` nei negozi cappella + torre → 3 reagenti ciascuno
2. `poison weak` → `envenom vial` → combattimento
3. `mix acid` → `throwpotion vial <mob>`
4. `sand`, `feint`, `hamstring`, `ckick`, `gouge`, `gag` in fight
5. `vault <alleato>`, `snatch` (mono)
6. Perforante vs mob armato per Find the Seam (mono 51)

---

## Deploy

```bash
git pull origin cursor/thief-tactics-expansion-3a37
./scripts/apply-production-world-patch.sh
./scripts/verify-thief-reagent-shops.sh
SERVER_PORT=4003 ./docker-run.sh down
./docker-run.sh run --rm consumer ./build.sh sirio-docker
SERVER_PORT=4003 ./docker-run.sh up -d
```

---

## File correlati

| Path | Contenuto |
|------|-----------|
| `docs/thief-tactics-expansion.md` | Questo documento |
| `world-patches/thief-crafting/WORKFLOW.txt` | Workflow patch produzione |
| `world-patches/thief-crafting/VNUMS.txt` | Vnum reagenti |
| `world-patches/thief-crafting/OVERLAYS.txt` | Regola overlay `objects/` |
| `pages/helptbl` | Help in-game skill 295–308 |
| `scripts/apply-thief-world-patch.sh` | Script patch mondo |
| `scripts/verify-thief-reagent-shops.sh` | Diagnostica negozi/obj/help |
| `src/thief_tactics.cpp` | Logica skill e crafting |
