# Rebalance PSI — Fase A e discipline metapsioniche

Documentazione delle novità introdotte dal rebalance psionico per mortali **L1–50**:
modifiche alle abilità esistenti (Fase A), sette nuove discipline metapsioniche (Fase B),
suddivisione dei maestri, migrazione al login e aggiornamenti correlati.

> **Branch di riferimento:** `feature/psi-phase-a-rebalance`  
> **Help in gioco:** voci aggiornate in `pages/helptbl` e `mudroot/lib/helptbl`  
> **Comandi utili:** `show skill I` (tabella progressione), `practice I` (skill conosciute)

---

## Indice

1. [Panoramica](#panoramica)
2. [Fase A — abilità esistenti ribilanciate](#fase-a--abilità-esistenti-ribilanciate)
3. [Fase B — nuove discipline metapsioniche (L39–50)](#fase-b--nuove-discipline-metapsioniche-l3950)
4. [Maestri psionici e progressione](#maestri-psionici-e-progressione)
5. [Migrazione personaggi esistenti](#migrazione-personaggi-esistenti)
6. [Silverleaf e immortali](#silverleaf-e-immortali)
7. [Note per builder e deploy](#note-per-builder-e-deploy)

---

## Panoramica

| Area | Cosa cambia |
|------|-------------|
| **Fase A** | Mind Wipe, Ultra Blast, Telekinesis, ESP, Hypnosis, Psionic Blast, NPC ipnotizzati |
| **Fase B** | 7 skill metapsioniche (ID 295–301), livelli PSI 39–50 |
| **Guildmaster** | Due ruoli distinti: base L1–39 e metapsionico L40–50 |
| **Login** | `migrate_psi_skills()` marca le skill PSI già apprese |
| **Help** | Nuove voci `METAPSIONIC`, skill singole, aggiornamento `PSIONIST` |

**Costanti in codice** (`src/spells.hpp`):

- `PSI_GUILD_BASIC_MAX_LEVEL = 39` — massimo insegnato dai GM base
- `PSI_METAPSIONIC_MIN_LEVEL = 40` — minimo insegnato da Kaelith / GM metapsionico

---

## Fase A — abilità esistenti ribilanciate

### Mind Wipe (`mind 'mind wipe' <nome>`)

| Parametro | Valore |
|-----------|--------|
| Livello PSI | 31 |
| Mana | 60 |
| Lag | 24 beat |

**Comportamento aggiornato:**

- **Su giocatori (PG):** non è più un wipe totale. Applica subbuglio mentale simile a Feeblemind:
  - INT **−3** per ~18 tick
  - Spellfail **+35**
  - Degradazione temporanea di **1 skill** (2 skill se il caster è ≥ L40), fino a −15 punti ciascuna
- **Su mostri (NPC):** debuff di combattimento invece della cancellazione completa:
  - Hitroll −(livello/4), minimo 2
  - Damroll −(livello/5), minimo 2
  - AC peggiorata di +(livello/3), minimo 2
  - +40 spellfail se il bersaglio è un caster
- Protetto da **Mindblank**; su PG già sotto Feeblemind non si riapplica
- Non è intrinsecamente aggressivo, ma un save fallito può far reagire il bersaglio

---

### Ultra Blast (`mind 'ultra blast'`)

| Parametro | Valore |
|-----------|--------|
| Livello PSI | 20 |
| Mana | 45 |
| Lag | 24 beat |

**Comportamento aggiornato:**

- Effetto **ad area**, ma colpisce **solo bersagli ostili**:
  - Nemici in combattimento con il caster (o viceversa)
  - Creature che odiano il caster (`Hates`)
  - Mob `ACT_AGGRESSIVE` che vedono il caster
- **Non** colpisce membri del gruppo del caster né immortali
- Danno: **`livello d6 + livello × 2`**
- Save dimezza il danno; **Tower of Iron Will** lo dimezza ancora
- Se il bersaglio non salva: **−2 hitroll** per 2 tick

---

### Telekinesis (`telekinesis <nome> <direzione>`)

| Parametro | Valore |
|-----------|--------|
| Livello PSI | 35 |
| Mana | 30 |
| Lag | 18 beat |

**Fuori combattimento:** sposta il bersaglio nella direzione indicata (serve una direzione valida). Save o resistenza (`ACT_SENTINEL` + `ACT_HUGE`) → il bersaglio attacca.

**In combattimento (novità):**

- Impulso telecinetico: **`livello d4`** danno psichico
- Save dimezza il danno; `ACT_HUGE` dimezza ancora
- Probabilità di far **sedere** il bersaglio:
  - ~55% base (+ livello/5), ~30% se ha salvato
  - Su `ACT_HUGE`: cap al **25%**
  - Massimo **85%**

---

### ESP (`esp` / `esp stop`)

| Parametro | Valore |
|-----------|--------|
| Livello PSI | 1 |
| Mana | 10 |
| Lag | 24 beat (all’attivazione) |

**Novità:**

- Durata: **`livello psionico × 2`** tick (minimo 4)
- All’attivazione rivela presenze **nascoste** (`AFF_HIDE`) nella stanza; con skill ≥ 90 può anche rimuovere l’hide
- Comando **`esp stop`** per terminare l’effetto prima della scadenza
- Durante ESP si leggono i pensieri di chi parla (comportamento esistente)

---

### Hypnosis (`hypnotize <nome>`)

| Parametro | Valore |
|-----------|--------|
| Livello PSI | 2 |
| Mana | 15 |
| Lag | 12 beat |
| Ostilità | Sì (25) |

**Comportamento aggiornato:**

- **NPC con INT &lt; 10:** pacificazione temporanea (non charm). Il mob smette di combattere il caster e perde l’odio verso di lui. **Non può rientrare in combattimento** finché dura l’effetto (`set_fighting` bloccato su NPC ipnotizzati non charm)
- **NPC con INT ≥ 10:** effetto simile a charm (12 tick), rimuove `ACT_AGGRESSIVE` se presente
- **Giocatori:** charm standard (24 tick)
- INT minima bersaglio: 4
- Documentato in help: **non funziona su sentinelle** (`ACT_SENTINEL`)

---

### Psionic Blast (`blast <nome>`)

| Parametro | Valore |
|-----------|--------|
| Livello PSI | 1 |
| Mana | 20 (25 al successo in combattimento) |
| Lag | **12 beat** (prima variabile) |

Il lag è stato reso esplicito e uniforme a **12 beat** dopo l’uso riuscito o fallito.

---

## Fase B — nuove discipline metapsioniche (L39–50)

Sintassi generale: `mind '<nome skill>'` oppure `mind '<nome skill>' <bersaglio>` dove richiesto.

| Skill | ID | Liv. | Mana | Lag | Bersaglio | Sintassi |
|-------|-----|------|------|-----|-----------|----------|
| **Ego Whip** | 295 | 39 | 35 | 18 | Nemico in stanza | `mind 'ego whip' <nome>` |
| **Psychic Vampirism** | 296 | 40 | 40 | 24 | Nemico in stanza | `mind 'psychic vampirism' <nome>` |
| **Metapsionic Surge** | 297 | 42 | 45 | 24 | Sé / alleato in stanza | `mind 'metapsionic surge'` |
| **Thought Barrier** | 298 | 44 | 50 | 24 | Sé / alleato in stanza | `mind 'thought barrier'` |
| **Neural Spike** | 299 | 46 | 55 | 24 | Nemico in stanza | `mind 'neural spike' <nome>` |
| **Mass Confusion** | 300 | 48 | 60 | 30 | Area (solo NPC) | `mind 'mass confusion'` |
| **Cataclysm Mind** | 301 | 50 | 80 | 36 | Area ostili | `mind 'cataclysm mind'` |

---

### Ego Whip — L39

Frustata psichica sul singolo bersaglio.

- Danno: **`livello d5`** (dimezzato su save)
- Se il bersaglio **non salva:** INT **−2** per `max(3, livello/8)` tick
- Spellfail skill: 10%
- Allineamento: malvagio (−1)

---

### Psychic Vampirism — L40

Drena energia mentale da un bersaglio.

- **Non utilizzabile su altri giocatori**
- Drain: `min(mana_vittima, max(10, livello × 3))`, dimezzato su save
- Il caster recupera **metà** del mana drenato (fino al massimo)
- Danno collaterale: `max(1, drain/4)`
- Spellfail: 10%

---

### Metapsionic Surge — L42

Buff offensivo su sé stessi (o bersaglio in stanza se specificato).

- Durata: `max(4, livello/4)` tick
- **+hitroll** e **+damroll** pari a `max(2, livello/10)`
- Non cumulabile: un solo Surge attivo alla volta
- Non ostile

---

### Thought Barrier — L44

Barriera mentale difensiva.

- Durata: `max(5, livello/3)` tick
- **AC migliorata** di `max(10, livello/2)` (modifier negativo su APPLY_AC)
- Non cumulabile con un’altra Thought Barrier attiva
- Non ostile

---

### Neural Spike — L46

Colpo psichico concentrato sul singolo bersaglio.

- Danno: **`livello d8 + livello`**
- Save dimezza; con **Tower of Iron Will** attiva il danno viene ulteriormente ridotto (fino a 0 se ha salvato)
- Senza save ma con Tower: danno dimezzato
- Spellfail: 10%

---

### Mass Confusion — L48

Debuff di stanza sui mostri nemici.

- Colpisce **solo NPC** nella stanza corrente (non PG, non gruppo, non immortali)
- Bersagli che **salvano** non sono affetti
- Durata: `max(3, livello/6)` tick
- Penalità (per affetto non salvato):
  - Hitroll −`max(2, livello/6)`
  - Damroll −`max(2, livello/8)`
  - AC +`max(2, livello/4)`
- Allineamento: malvagio (−1)

---

### Cataclysm Mind — L50

**Capstone** metapsionico — devastazione psichica ad area.

- Stessi criteri di bersaglio di **Ultra Blast** (solo ostili nella stanza)
- Danno: **`livello d8 + livello × 3`**
- Save e Tower of Iron Will dimezzano come Ultra Blast
- Su **NPC** che non salvano: **−3 hitroll** per 2 tick
- Mana 80, lag 36 beat — la skill PSI più costosa del mortale

---

## Maestri psionici e progressione

### Due scuole separate

| Mob | Vnum | Luogo | Procedura (`myst.spe`) | Insegna |
|-----|------|-------|------------------------|---------|
| Maestro psionico (base) | **21366** | Myst, stanza **3090** | `PsiGuildmaster` | L1–39 |
| **Kaelith**, maestro metapsionico | **21368** | Myst, stanza **3090** | `MetapsionicGuildmaster` | L40–50 |
| **Alrani** | **7808** | Accademia, stanza **7825** | `PsiGuildmaster` | L1–39 (invariato) |

### Comportamento in gioco

- **`practice`** presso il GM base (21366 o Alrani): elenco e training solo fino al livello skill **39**
- Al **gain** oltre il limite del GM base: messaggio che indica di cercare un maestro metapsionico
- **`practice`** presso Kaelith: solo skill con `min_level_psi ≥ 40`
- Kaelith rifiuta le discipline base; i GM base rifiutano quelle metapsioniche

### Requisito critico: `myst.spe`

Ogni mob guildmaster deve avere la riga procedura corretta in `myst.spe` (e in `mudroot/lib/myst.spe` dopo `./getworldlocal`):

```
M 21366 PsiGuildmaster
M 21368 MetapsionicGuildmaster
```

Senza `M 21368 MetapsionicGuildmaster`, Kaelith resta un mob normale e **non** risponde a `practice` / `gain` come maestro metapsionico. Questo è il punto che va verificato per primo in caso di problemi.

Per il contenuto dei mob (descrizioni, stanza, eq) vedi anche `docs/psi-guildmaster-mob-locale.md` e `docs/patches/myst.mob-psi-guildmasters.patch`.

---

## Migrazione personaggi esistenti

All’**login**, `migrate_psi_skills()` (`src/psi_skill_migration.cpp`, chiamata da `store_to_char()` in `db.cpp`) per ogni personaggio con classe PSI:

- Scorre tutte le skill con `min_level_psi` valido (1–49)
- Se la skill ha `learned > 0` ma mancano i flag:
  - imposta **`SKILL_KNOWN`**
  - imposta **`SKILL_KNOWN_PSI`**

Così `show skill I` e `practice I` mostrano correttamente le discipline già apprese prima dell’aggiornamento, incluse le metapsioniche per chi era già oltre il 39.

---

## Silverleaf e immortali

**Silverleaf** (vnum **#641**, `DruidGuildMaster` nell’area druidica) resta riservata ai **mortali** per le skill druidiche.

**Novità:** gli **immortali** che la raggiungono possono usare `practice` per **tutte** le discipline psioniche (incluso il blocco metapsionico L39–50), oltre agli incantesimi druidici. Implementato in `DruidGuildMaster` quando `GET_MOB_VNUM(guildmaster) == 641`.

---

## Note per builder e deploy

### File toccati dal rebalance

| Tipo | File principali |
|------|-----------------|
| Implementazione skill | `src/mindskills1.cpp`, `src/mind_use1.cpp` |
| Registro skill | `src/spell_list.cpp`, `src/spell_parser.cpp`, `src/constants.cpp` |
| Guildmaster | `src/spec_procs2.cpp`, `myst.spe`, `myst.mob`, `myst.zon` |
| Migrazione | `src/psi_skill_migration.cpp`, `src/db.cpp` |
| Help | `pages/helptbl`, `mudroot/lib/helptbl` |
| Combattimento | `src/fight.cpp` (NPC ipnotizzati pacificati) |

### Deploy consigliato

```bash
./getworldlocal
# se usi myst.mob locale personalizzato, copialo su mudroot/lib/myst.mob
./build.sh vagrant   # o il tuo flusso di build
# reboot / zreset zona Myst (30) se necessario
```

### Verifica rapida in gioco

1. Stanza **3090**: presenti #21366 e #21368
2. `practice` su #21366: lista fino a [39]
3. `practice` su Kaelith: lista da [39] Ego Whip / [40]+ metapsioniche
4. `show skill I` su un psi esistente: skill conosciute con flag corretti
5. Help: `help metapsionic`, `help ego whip`, ecc.

### Help in gioco (riferimento rapido)

- `help psionist` — panoramica classe e split maestri
- `help metapsionic` — introduzione discipline avanzate
- `help mind wipe`, `help ultra blast`, `help telekinesis`, `help esp`, `help hypnosis`
- `help ego whip`, `help psychic vampirism`, `help metapsionic surge`, `help thought barrier`
- `help neural spike`, `help mass confusion`, `help cataclysm mind`
- `help silverleaf`

---

*Documento generato per il branch `feature/psi-phase-a-rebalance` — giugno 2026.*
