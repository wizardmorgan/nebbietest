# Rebalance PSI — documentazione completa

Documentazione del rebalance psionico per mortali **L1–50**: Fase A (abilità esistenti),
Fase B (discipline metapsioniche), infrastruttura GM, e classificazione dell’intero kit PSI.

> **Branch di riferimento:** `feature/psi-phase-a-rebalance` (+ aggiornamenti surge)  
> **Help in gioco:** `pages/helptbl` (deploy in `mudroot/lib/helptbl` via `./getworldlocal`)  
> **Comandi utili:** `show skill I`, `practice I`

---

## Indice

1. [Panoramica](#panoramica)
2. [Tassonomia del kit PSI](#tassonomia-del-kit-psi)
3. [Fase A — modifiche comportamentali](#fase-a--modifiche-comportamentali)
4. [Fase A — tabella lag (solo tuning)](#fase-a--tabella-lag-solo-tuning)
5. [Fase A — skill e poteri non modificati](#fase-a--skill-e-poteri-non-modificati)
6. [Fase B — discipline metapsioniche (L39–50)](#fase-b--discipline-metapsioniche-l3950)
7. [Adrenalize vs Surge](#adrenalize-vs-surge)
8. [Maestri psionici e progressione](#maestri-psionici-e-progressione)
9. [Silverleaf e immortali](#silverleaf-e-immortali)
10. [Note per builder e deploy](#note-per-builder-e-deploy)

---

## Panoramica

| Area | Contenuto |
|------|-----------|
| **Fase A — comportamento** | Mind Wipe, Ultra Blast, Telekinesis, ESP, Hypnosis, Psionic Blast, NPC ipnotizzati |
| **Fase A — tuning lag** | 13 poteri `mind` con soli beat ridotti (nessun cambio meccanico) |
| **Fase B** | 7 discipline metapsioniche (ID **309–315**), livelli PSI 39–50 |
| **Infrastruttura** | GM base L1–39 / metapsionico L40–50, help, Silverleaf immortali |
| **Post-rebalance** | **Surge** (`surge`) è una **skill** a comando dedicato, non un potere `mind` |

**Costanti** (`src/spells.hpp`):

- `PSI_GUILD_BASIC_MAX_LEVEL = 39`
- `PSI_METAPSIONIC_MIN_LEVEL = 40`

---

## Tassonomia del kit PSI

Il kit psionico si divide in tre famiglie. Questa distinzione è importante per capire
cosa è stato ribilanciato e cosa no.

### A) Skill a comando dedicato (non usano `mind '...'`)

| Comando | ID | Liv. PSI tipico | Modificata in rebalance? |
|---------|-----|-----------------|--------------------------|
| `blast` | 229 | 1 | sì (lag 12 beat) |
| `hypnotize` | 230 | 2 | sì (comportamento + costi) |
| `esp` / `esp stop` | 254 | 1 | sì |
| `meditate` | 231 | — | no |
| `scry` | 232 | — | no |
| `adrenalize` | 233 | 20 | no |
| **`surge`** | **311** | **42** | **sì (skill, non spell)** |
| `doorway` | 221 | — | no |
| `portal` | 222 | — | no |
| `summon` | 223 | — | no |
| `psi` / invisibilità psionica | 224 | 1 | no |
| `canibalize` | 225 | — | no |
| `flame shroud` | 226 | — | no |
| `aura sight` | 227 | — | no |
| `great sight` | 228 | — | no |
| `psi shield` | 241 | — | no |

### B) Poteri `mind '<nome>'` (skill nel registro, lancio via `mind`)

| Potere | ID | Modificata in rebalance? |
|--------|-----|--------------------------|
| Mind Burn | 268 | solo lag (24→12) |
| Clairvoyance | 269 | solo lag |
| Danger Sense | 270 | solo lag |
| Disintegrate | 271 | solo lag (24→30) |
| **Telekinesis** | 272 | **sì** (combat + lag 18) |
| Levitation | 273 | solo lag |
| Cell Adjustment | 274 | solo lag |
| Chameleon | 275 | solo lag |
| Psi Strength | 276 | solo lag |
| Probability Travel | 278 | no (lag invariato) |
| Psi Teleport | 279 | solo lag |
| **Domination** | 280 | no |
| **Mind Wipe** | 281 | **sì** |
| Psychic Crush | 282 | solo lag (34→24) |
| Tower of Iron Will | 283 | solo lag |
| Mindblank | 284 | no |
| Psychic Impersonation | 285 | no |
| **Ultra Blast** | 286 | **sì** |
| **Intensify** | 287 | no |

> **Nota su nomi fuorvianti:** `domination` e `intensify` **sono** skill psioniche
> (`mind 'domination'`, `mind 'intensify'`), non comandi standalone. Non esiste una skill
> PSI chiamata “tunnel”: il termine in codice indica il **flag di stanza** `TUNNEL`
> (limite occupanti), usato da teleport e viaggi planari — non un potere della classe.

### C) Discipline metapsioniche (Fase B, via `mind` tranne Surge)

| Potere | ID | Liv. | Comando |
|--------|-----|------|---------|
| Ego Whip | 309 | 39 | `mind 'ego whip'` |
| Psychic Vampirism | 310 | 40 | `mind 'psychic vampirism'` |
| **Metapsionic Surge** | **311** | **42** | **`surge [nome]`** |
| Thought Barrier | 312 | 44 | `mind 'thought barrier'` |
| Neural Spike | 313 | 46 | `mind 'neural spike'` |
| Mass Confusion | 314 | 48 | `mind 'mass confusion'` |
| Cataclysm Mind | 315 | 50 | `mind 'cataclysm mind'` |

---

## Fase A — modifiche comportamentali

### Mind Wipe (`mind 'mind wipe' <nome>`) — ID 281

| Parametro | Valore |
|-----------|--------|
| Livello PSI | 31 |
| Mana | 60 |
| Lag | 24 beat |

- **PG:** debuff mentale (INT −3, spellfail +35, degradazione 1–2 skill), non wipe totale
- **NPC:** debuff combattimento (hitroll, damroll, AC, spellfail su caster)
- Protetto da Mindblank; non aggressivo di default

### Ultra Blast (`mind 'ultra blast'`) — ID 286

| Parametro | Valore |
|-----------|--------|
| Livello PSI | 20 |
| Mana | 45 |
| Lag | 24 beat |

- Solo bersagli **ostili** in stanza (combattimento, hate, ACT_AGGRESSIVE)
- Danno: `livello d6 + livello × 2`; save e Tower dimezzano
- Debuff hitroll −2 (2 tick) se il bersaglio non salva

### Telekinesis (`telekinesis <nome> <dir>`) — ID 272

| Parametro | Valore |
|-----------|--------|
| Livello PSI | 35 |
| Mana | 30 |
| Lag | 18 beat |

- **Fuori combattimento:** sposta il bersaglio; save → aggro
- **In combattimento:** `livello d4` danno + probabilità di far sedere (cap 85%, 25% su ACT_HUGE)

### ESP (`esp` / `esp stop`) — ID 254

| Parametro | Valore |
|-----------|--------|
| Livello PSI | 1 |
| Mana | 10 |
| Lag | 24 beat |

- Durata: `livello psionico × 2` tick (min 4)
- Rileva AFF_HIDE; a skill ≥ 90 può rimuovere hide
- `esp stop` termina l’effetto

### Hypnosis (`hypnotize <nome>`) — ID 230

| Parametro | Valore |
|-----------|--------|
| Livello PSI | 2 |
| Mana | 15 (era 25) |
| Lag | 12 beat |
| INT min. bersaglio | 4 (era 8) |

- **NPC INT &lt; 10:** pacificazione (no re-aggro via `set_fighting`)
- **NPC INT ≥ 10:** charm 12 tick
- **PG:** charm 24 tick
- Check livello: `psi_level + 5` vs livello bersaglio

### Psionic Blast (`blast <nome>`) — ID 229

Lag uniformato a **12 beat** (prima variabile `PULSE_VIOLENCE * 2`).

### Fix combattimento — NPC ipnotizzati

In `src/fight.cpp`, NPC sotto ipnosi pacificante non possono rientrare in combattimento
via `set_fighting`.

---

## Fase A — tabella lag (solo tuning)

Nessun cambiamento meccanico: solo riduzione (o in un caso aumento) dei beat registrati
in `spell_list.cpp` per allineare i tempi di recupero al tier MU.

| ID | Potere `mind` | Lag prima | Lag dopo |
|----|---------------|-----------|----------|
| 268 | Mind Burn | 24 | **12** |
| 269 | Clairvoyance | 24 | **12** |
| 270 | Danger Sense | 24 | **12** |
| 271 | Disintegrate | 24 | **30** |
| 272 | Telekinesis | 24 | **18** |
| 273 | Levitation | 24 | **12** |
| 274 | Cell Adjustment | 24 | **12** |
| 275 | Chameleon | 24 | **12** |
| 276 | Psi Strength | 24 | **12** |
| 279 | Psi Teleport | 24 | **12** |
| 282 | Psychic Crush | 34 | **24** |
| 283 | Tower of Iron Will | 24 | **12** |
| 286 | Ultra Blast | 35 | **24** |

**Anche aggiornati (comandi, non `mind`):**

| ID | Comando | Lag |
|----|---------|-----|
| 230 | Hypnosis | **12** beat (registro + `do_hypnosis`) |
| 229 | Blast | **12** beat (`do_blast`) |

---

## Fase A — skill e poteri non modificati

Il rebalance **non ha toccato** meccanica, costi o lag di:

**Comandi dedicati:** meditate, scry, adrenalize, doorway, portal, summon, invisibilità
psionica, canibalize, flame shroud, aura sight, great sight, psi shield.

**Poteri `mind`:** domination, intensify, mindblank, psychic impersonation, probability
travel, mind over body (277), e tutti quelli della tabella lag la cui sola modifica è il beat.

**Metapsioniche (pre-Fase B):** nessuna — introdotte ex novo in Fase B.

---

## Fase B — discipline metapsioniche (L39–50)

### Tabella riepilogativa

| Skill | ID | Liv. | Mana | Lag | Tipo | Sintassi |
|-------|-----|------|------|-----|------|----------|
| Ego Whip | 309 | 39 | 35 | 18 | `mind` | `mind 'ego whip' <nome>` |
| Psychic Vampirism | 310 | 40 | 40 | 24 | `mind` | `mind 'psychic vampirism' <nome>` |
| Metapsionic Surge | 311 | 42 | 45 | — | **skill** | `surge [nome]` |
| Thought Barrier | 312 | 44 | 50 | 24 | `mind` | `mind 'thought barrier'` |
| Neural Spike | 313 | 46 | 55 | 24 | `mind` | `mind 'neural spike' <nome>` |
| Mass Confusion | 314 | 48 | 60 | 30 | `mind` | `mind 'mass confusion'` |
| Cataclysm Mind | 315 | 50 | 80 | 36 | `mind` | `mind 'cataclysm mind'` |

### Metapsionic Surge — ID 311

**Skill a comando** (come `adrenalize`), implementata in `do_surge` (`src/skills.cpp`).

| Parametro | Valore |
|-----------|--------|
| Sintassi | `surge` (self) oppure `surge <nome>` (alleato in stanza) |
| Mana | 45 |
| Fallimento | roll su `skill learned` (costo metà mana, `LearnFromMistake`) |
| Durata | `max(4, livello/4)` tick |
| Effetto | +hitroll e +damroll = `max(2, livello/10)` |
| Cumulo | no (un solo Surge attivo) |

### Altri poteri metapsionici (sintesi)

- **Ego Whip (309):** `livello d5`, INT −2 su fail save
- **Psychic Vampirism (310):** drain mana NPC, no PG
- **Thought Barrier (312):** AC migliorata `max(10, livello/2)`
- **Neural Spike (313):** `livello d8 + livello`, interazione Tower
- **Mass Confusion (314):** debuff stanza solo NPC
- **Cataclysm Mind (315):** capstone area ostili, `livello d8 + livello × 3`

---

## Adrenalize vs Surge

Entrambe sono **skill a comando** (non `mind`). Oggi coesistono con ruoli sovrapposti ma
non identici.

| | Adrenalize (L20) | Surge (L42) |
|--|------------------|-------------|
| Comando | `adrenalize <nome>` | `surge [nome]` |
| Mana | 15 | 45 |
| Durata | 5 tick | `max(4, livello/4)` |
| Hitroll | **−1..−4** | **+2..+5** |
| Damroll | +1..+4 | +2..+5 |
| AC | **+20** (peggiora) | invariata |
| Fallimento | roll skill | roll skill |
| Scuola | fondamentale | metapsionica |

### Proposte di differenziazione ulteriore

**Proposta A — Trade-off vs precisione (raccomandata, minimo intervento)**  
Mantenere lo stato attuale: Adrenalize resta il buff “frenetico” a breve (più danno, meno
precisione, peggior AC); Surge è il buff endgame pulito per chi ha superato il trade-off.
Eventuale ritocco: impedire Surge se Adrenalize è attivo (e viceversa).

**Proposta B — Ruolo party**  
Adrenalize: solo su **alleato** (supporto mid-level). Surge: solo su **sé stessi** (capstone
personale). Elimina l’overlap “chi buffo in gruppo?”.

**Proposta C — Specializzazione danno**  
Adrenalize: bonus solo a **damroll** e move regen, nessun hitroll. Surge: bonus a hitroll
**e** +5% danno su tutti i poteri `mind` e `blast` per la durata. Due identità: bruiser
fisico vs amplificatore psionico.

---

## Maestri psionici e progressione

| Mob | Vnum | Procedura | Insegna |
|-----|------|-----------|---------|
| Maestro psionico (base) | 21366 | `PsiGuildmaster` | L1–39 |
| Kaelith (metapsionico) | 21368 | `MetapsionicGuildmaster` | L40–50 |
| Alrani | 7808 | `PsiGuildmaster` | L1–39 |

In `myst.spe`:

```
M 21366 PsiGuildmaster
M 21368 MetapsionicGuildmaster
```

`practice` al GM base elenca fino a [39]; Kaelith elenca da [39] Ego Whip / [40]+.
**Surge** si apprende con `practice` presso Kaelith come le altre metapsioniche.

---

## Silverleaf e immortali

Silverleaf (#641): mortali = druidi; immortali = practice di tutte le discipline PSI
(incluso blocco metapsionico), implementato in `DruidGuildMaster` per vnum 641.

---

## Note per builder e deploy

### File principali

| Tipo | File |
|------|------|
| Skill/comandi | `src/skills.cpp` (`do_adrenalize`, `do_surge`, `do_blast`, `do_esp`, `do_hypnosis`) |
| Poteri mind | `src/mindskills1.cpp`, `src/mind_use1.cpp` |
| Registro | `src/spell_list.cpp`, `src/spell_parser.cpp`, `src/constants.cpp` |
| GM | `src/spec_procs2.cpp`, `myst.spe`, `myst.mob` |
| Help | `pages/helptbl` |
| Combattimento | `src/fight.cpp` |

### Deploy

```bash
./getworldlocal
./build.sh vagrant
```

### Verifica rapida

1. `practice` su Kaelith: Surge in lista [42]
2. `surge` su sé stessi: buff hit/dam, messaggio metapsionico
3. `mind 'metapsionic surge'` → **non** deve funzionare
4. `help surge`, `help adrenalize`

---

*Ultimo aggiornamento: luglio 2026 — surge come skill a comando, ID metapsionici 309–315.*
