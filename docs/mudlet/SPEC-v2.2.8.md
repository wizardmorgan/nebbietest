# Nebbie Arcane — Specifiche package Mudlet `nebbie-play-all` v2.2.8

Documento tecnico e funzionale del package Mudlet per **Nebbie Arcane**.  
Generato dal sorgente MUD (`src/spell_parser.cpp`, `src/interpreter.cpp`, `src/constants.cpp`) e dall’installer Lua v2.

---

## 1. Identificazione

| Campo | Valore |
|-------|--------|
| **Nome package** | `nebbie-play-all` |
| **Versione** | **2.2.8** |
| **File distribuzione** | `nebbie-play-all.mpackage` (~271 KB, zip non compresso) |
| **Branch repository** | `mudlet` |
| **Namespace globale Lua** | `Nebbie` |
| **Guard versione** | `NEBBIE_PKG_VER=2.2.8` nello script XML principale |
| **Mudlet minimo consigliato** | 4.21+ (barre HUD con `createLabel`; `getEpochTime` nativo) |

### Download

- https://github.com/wizardmorgan/nebbietest/raw/mudlet/docs/mudlet/nebbie-play-all.mpackage
- https://raw.githubusercontent.com/wizardmorgan/nebbietest/mudlet/docs/mudlet/nebbie-play-all.mpackage

### File sorgente (sviluppatori)

| File | Ruolo |
|------|--------|
| `docs/mudlet/nebbie-installer-core.lua` | Logica runtime (HUD, parser, loot, buff, `usa`/`nkey`) |
| `docs/mudlet/build-nebbie-package.py` | Generatore `.mpackage` e `nebbie-spells-reference.txt` |
| `docs/mudlet/nebbie-play-all-build/nebbie-play-all.xml` | Package XML generato |
| `docs/mudlet/nebbie-spells-reference.txt` | Riferimento spell/skill (solo consultazione) |
| `docs/mudlet/HELP.md` | Guida utente |
| `docs/mudlet/SPEC-v2.2.8.md` | Questo documento |

---

## 2. Scopo del package

Package unico che integra:

| Modulo | Descrizione |
|--------|-------------|
| **Alias/trigger multiclasse** | Scorciatoie incantesimi (~206 cast), skill dedicate, preset `q1`–`q9` per 12 classi |
| **HUD** | Barre HP/Mana/Move dal prompt + pannello buff/debuff + info combattimento |
| **Buff/debuff** | Tracciamento da cast, wear-off MUD, sync `attribute`, pre-scadenza |
| **Loot mob** | Automatico su exp reale; `look` + `get all corp` / `pile` numerati |
| **Cambio arma** | `usa <arma>` da borsa sulla schiena via parsing `eq` |
| **Database chiavi eq** | `nkey` per mappare nomi oggetto → parola chiave MUD |

### Comandi MUD **non** aliasati (liberi)

`inv`, `eq` — passano direttamente al server.

### Abbreviazioni riservate (mai create come alias standalone)

Tra le altre: `inv`, `eq`, `i`, `in`, `rest`, `sleep`, `kill`, `look`, `score`, `cast`, `recall`, `get`, `drop`, `wear`, `remove`, …

Eccezioni esplicite approvate: `invis`, `ea`, `ble`.

---

## 3. Architettura v2.2.8

### 3.1 Script incorporato (fix critico installazione)

A partire dalla **v2.2.8**, **tutto il codice** è incorporato nello **script XML** del package (`nebbie-play-all.xml` → script `Nebbie Play All`).  
**Non** si dipende più da `dofile` su `nebbie-install.lua` estratto nel profilo Mudlet.

| Componente | Tipo | Note |
|------------|------|------|
| Script principale | `perm` XML | Bootstrap + purge legacy + dati generati + `nebbie-installer-core.lua` |
| `nfix` | Alias XML `nebbie-fix` | Chiama `Nebbie.runFix()` |
| `npurge` | Alias XML `nebbie-purge` | Purge perm vecchi + messaggio reinstall |
| `nprompt` | Alias XML `nebbie-nprompt` | Chiama `Nebbie.debugPrompt()` |
| Alias/trigger runtime | `tempAlias` / `tempTrigger` | Creati da `Nebbie.install()` |
| Settings profilo | File esterno | `getMudletHomeDir()/nebbie-play-all-settings.lua` |

**Guard anti-riavvio:**

```lua
local NEBBIE_PKG_VER = "2.2.8"
if Nebbie._loadedPkgVer == NEBBIE_PKG_VER and Nebbie._mainLoaded then return end
```

### 3.2 Contenuto `.mpackage` (zip)

| Entry zip | Contenuto |
|-----------|-----------|
| `config.lua` | `mpackage = "nebbie-play-all"` |
| `nebbie-play-all.xml` | Script + 3 alias XML |
| `nebbie-install.lua` | Copia generata (backup; **non** usata dal bootstrap v2.2.8) |

### 3.3 Flusso bootstrap (`Nebbie.boot()`)

1. `Nebbie.loadSettings()` — classe, posizione HUD, `lootAuto`, `attribAuto`, `eqKeywords`
2. `Nebbie.warnLegacyPackages()` — avvisa se `nebbie-spells-skills` è ancora installato
3. `Nebbie.pruneInvalidBuffs()` / `Nebbie.pruneExpiredBuffs()`
4. `Nebbie.purgeLegacyPermItems(true)` — disattiva perm orfani da versioni precedenti
5. Se già installato (`_installedVer == version` e alias attivi): ricarica GUI/classe/timer
6. Altrimenti: `Nebbie.install()` → test parser → `loadClass()` o preset `+`

### 3.4 Package legacy da disinstallare

- `nebbie-spells-skills` (sostituito da `nebbie-play-all`)

---

## 4. Statistiche contenuto generato

| Metrica | Valore |
|---------|--------|
| Incantesimi `cast` | **206** |
| Abilità `mind` | **22** |
| Skill dedicate | **~60** |
| Abbreviazioni spell | **153** |
| Alias runtime (stima) | **~160** (`tempAlias`) |
| Trigger runtime (stima) | **~85** gruppi (`tempTrigger`) |
| Alias XML permanenti | **3** (`nfix`, `npurge`, `nprompt`) |
| Classi preset | **12** (`+`, `m`, `s`, `c`, `d`, `p`, `r`, `I`, `t`, `w`, `k`, `b`) |
| Slot rapidi per classe | **9** (`q1`–`q9`) |

---

## 5. Installazione e verifica

### 5.1 Procedura consigliata

1. **Alt+O** → *Install New Package* → `nebbie-play-all.mpackage`
2. Attendere messaggio console: `Nebbie v2.2.8: N alias, M trigger`
3. Setup:
   ```
   nsetup
   nclass +
   ```
4. Opzionale sync buff reali: `nattrib on`

### 5.2 Reinstallazione pulita

1. Disinstalla `nebbie-play-all` (e `nebbie-spells-skills` se presente) da Package Manager
2. Elimina eventuali trigger/alias orfani in **Scripts**
3. **Riavvia Mudlet**
4. Reinstalla `.mpackage` (**~271 KB** — file più piccolo = cache/branch errata)
5. `nfix` → `nsetup` → `nclass +`

> **v2.2.8:** non è più necessario cancellare manualmente `nebbie-play-all/nebbie-install.lua` nel profilo per aggiornare il codice; lo script XML è autosufficiente. Una reinstall pulita resta consigliata se perm orfani persistono.

### 5.3 Verifica versione

```
lua cecho("<yellow>"..tostring(Nebbie.version))
```

Deve restituire **`2.2.8`**.

### 5.4 Verifica dimensione file

```bash
# deve essere ~271143 bytes
ls -la nebbie-play-all.mpackage
```

---

## 6. Persistenza settings

**File:** `getMudletHomeDir()/nebbie-play-all-settings.lua`  
**API:** `table.save` / `table.load` (Mudlet)

| Chiave | Tipo | Default | Descrizione |
|--------|------|---------|-------------|
| `class` | string | `+` | Classe o multiclasse (`m c`, `w t`, …) |
| `lootAuto` | bool | `true` | Loot automatico su kill mob |
| `attribAuto` | bool | `false` | Sync `attribute` ogni 90s |
| `eqKeywords` | table | `[]` | Chiavi eq custom (`nkey add`) |
| `guiLayout` | number | `8` | Versione layout HUD (`guiLayoutVer`) |
| `guiCustom` | bool | `false` | Posizione HUD personalizzata |
| `guiX`, `guiY` | number | — | Coordinate HUD se trascinato |

**Variabile profilo alternativa:** `nebbie_class` via `setVariable` / `getVariable`.

**Multi-personaggio:** un profilo Mudlet per PG; la classe si ricarica al login.

---

## 7. Comandi package

### 7.1 Setup e manutenzione

| Comando | Funzione |
|---------|----------|
| `nsetup` | Avvia HUD, parser prompt, barre HP/MN/MV; imposta classe `+` se assente |
| `nfix` | Reinstalla alias/trigger, ricrea GUI, ricarica classe salvata |
| `npurge` | Disattiva perm vecchi noti; poi riavvia Mudlet e `nfix` |
| `nprompt` | Debug parser prompt (stats, ultima riga, errori parse) |

### 7.2 Classe e slot rapidi

| Comando | Funzione |
|---------|----------|
| `nclass` | Elenca classi e slot `q1`–`q9` |
| `nclass <lettere>` | Imposta classe (`m`, `I`, …) o multiclasse (`m c`, `w t`) |
| `nclass +` / `nclass u` | Preset cast universale multiclasse |
| `q1` … `q9` | Esegue slot rapido (`q5 goblin` = slot 5 su bersaglio) |

#### Lettere classe

| Lettera | Classe | Modalità default |
|---------|--------|------------------|
| `+` / `u` | Cast universale | `cast` |
| `m` | Mago | `cast` |
| `s` | Stregone | `recall` |
| `c` | Chierico | `cast` |
| `d` | Druido | `cast` |
| `p` | Paladino | `cast` |
| `r` | Ranger | `cast` |
| `I` | Psionista (**I maiuscola**) | `mind` |
| `t` | Ladro | `cast` |
| `w` | Guerriero | `cast` |
| `k` | Monaco | `cast` |
| `b` | Barbaro | `cast` |

#### Slot rapidi per classe

| Classe | q1 | q2 | q3 | q4 | q5 | q6 | q7 | q8 | q9 |
|--------|----|----|----|----|----|----|----|----|-----|
| **+** (universale) | aid | arm | ble | shld | sskin | mirr | heal | san | invis |
| **Mago** | arm | shld | fly | mm | fb | lb | invis | str | tele |
| **Stregone** | arm | shld | mm | fb | lb | invis | str | fly | tele |
| **Chierico** | heal | cser | cc | clight | ble | san | pevil | devl | aid |
| **Druido** | bark | clightn | ent | snare | clight | fly | sskin | ffood | brew |
| **Paladino** | heal | loh | wc | ble | san | fs | hero | bld | pray |
| **Ranger** | track | clight | bark | camo | snk | carve | ffood | fwater | ent |
| **Psi** | pshld | mb | pcrush | lev | ptel | medit | blast | dw | psiport |
| **Ladro** | bs | snk | hide | stl | picklock | spy | tspy | disguise | eaves |
| **Guerriero** | kick | bash | resc | disarm | bel | parry | faid | dbash | climb |
| **Monaco** | man | fin | qp | leap | fd | kick | bash | dai | faid |
| **Barbaro** | berz | bel | kick | bash | camo | ffood | fwater | tan | faid |

### 7.3 Magia e skill

| Comando | Invia al MUD |
|---------|--------------|
| `c <spell> [tgt]` | `cast '<spell>' [tgt]` (rispetta modalità) |
| `r <spell> [tgt]` | `recall '<spell>' [tgt]` |
| `m <spell> [tgt]` | `mind '<spell>' [tgt]` |
| `mem <spell>` | `memorize '<spell>'` |
| `cast <spell> [tgt]` | come `c` |
| `ncast` / `nrecall` / `nmind` | Cambia modalità predefinita |
| `return` | `return` (fine `polymorph self`) |
| `<abbr>` | Abbreviazione spell/skill (es. `fb`, `heal`, `bs`) |

**Risoluzione spell:** `Nebbie.resolveSpell()` cerca in abbreviazioni, `castSpells`, `dedicatedSkills`, `mindSpells`.

**Auto-modalità:** spell in `mindSpells` forzano `mind` anche se modalità è `cast`.

### 7.4 HUD e GUI

| Comando | Funzione |
|---------|----------|
| `ngui` / `nhud` | Mostra/nasconde pannello HUD |
| `npos` | Riposiziona HUD in alto a destra (reset posizione custom) |

### 7.5 Buff sync (`attribute`)

| Comando | Funzione |
|---------|----------|
| `nattrib` | Invia `attribute` una volta; output gagged; aggiorna countdown buff |
| `nattrib on` | Sync automatico ogni **90 secondi** (gagged) |
| `nattrib off` | Disattiva sync automatico |

**Tick MUD:** `TICK_SECONDS = 4` — ogni tick `attribute` = 4 secondi reali.  
Durata buff: `ticks × 4` secondi quando `synced = true`.

### 7.6 Loot mob

| Comando | Funzione |
|---------|----------|
| `nloot` | Loot manuale: `look` → analisi corpi/pile → coda comandi |
| `nloot on` | Attiva loot auto (default) |
| `nloot off` | Disattiva loot auto |

**Trigger auto:** riga esatta `La tua esperienza e' aumentata di N punti.` (exp reale, no `$c` residui).  
**Delay:** 0,25s prima di `look`; 1,0s attesa parsing `look`; **0,5s** tra comandi in coda.

**Sequenza loot:**

1. `look` — conta corpi mob e pile
2. Per ogni corpo: `get all corp`, `get all 2.corp`, …
3. Per ogni pile: `get all pile`, `get all 2.pile`, …
4. Se `look` non trova nulla: fallback `get all corp` + `get all pile`

**Classificazione corpi (italiano):**

- **corp:** `il corpo di un/una/uno …`, `corpo sfigurato`
- **pile:** `pile of dust and bones`, polvere+ossa
- **pc:** `il corpo di Nome` (nome PG con iniziali maiuscole) — **escluso** dal loot

### 7.7 Cambio arma (`usa`)

| Comando | Funzione |
|---------|----------|
| `usa <arma>` | Cambio arma dalla borsa sullo slot `<sulla schiena>` |

**Sequenza (0,5s tra comandi):**

1. `eq` — parse `<impugnato>` e `<sulla schiena>`
2. `rem <chiave_borsa>`
3. `get <arma> <chiave_borsa>`
4. `rem <chiave_impugnato>` (se presente)
5. `wie <arma>`
6. `put <vecchia_arma> <chiave_borsa>` (se c’era impugnato)
7. `wear <chiave_borsa>`

**Timeout parse eq:** 1,5s; fallback poll ultime 80 righe buffer.

### 7.8 Database chiavi equipaggiamento (`nkey`)

| Comando | Funzione |
|---------|----------|
| `nkey` | Elenco chiavi (default + custom) |
| `nkey add <chiave> <testo>` | Aggiunge regola match sul nome eq |
| `nkey del <testo>` | Rimuove regola custom |

**Chiavi default:**

| Match nel nome eq | Chiave MUD |
|-------------------|------------|
| borsa inesauribile dei korred | `korred` |
| forza della natura | `forza` |
| elf slayer | `elf` |
| verdespina | `verdespina` |

**Guess automatico:** prima parola significativa del nome (stopword `del`, `dei`, `della`, … escluse).

---

## 8. HUD — specifiche interfaccia

### 8.1 Dimensioni e layout

| Parametro | Valore |
|-----------|--------|
| `guiW` × `guiH` | **600 × 680** px |
| `guiLayoutVer` | **8** |
| `guiHeaderH` | 28 px |
| `guiMargin` | 12 px |
| `guiGaugeH` | 22 px |
| `guiGaugeGap` | 6 px |
| `guiGaugeArea` | 96 px |
| `guiFontSize` | 11 |
| Posizione default | Alto a destra (`calcGUIPos`) |
| Aggiornamento pannello | Timer **1 secondo** |

### 8.2 Elementi GUI

| Elemento | Nome Mudlet | Descrizione |
|----------|-------------|-------------|
| Barra trascinamento | `NebbieHUDBar` | Header grigio “Nebbie HUD — trascina qui” |
| Console info | `NebbieHUD` | Buff, debuff, stats, quick slot |
| Barra HP | `NebbieHP` | Verde `{45,200,70}` |
| Barra Mana | `NebbieMN` | Blu `{70,150,255}` |
| Barra Move | `NebbieMV` | Giallo `{230,190,50}` |

**Implementazione barre:** `createLabel` + `resizeWindow` (compatibile Mudlet 4.21 senza `setGauge`).  
Legacy `setGauge`/`deleteGauge` rimossi al layout v8.

### 8.3 Parser prompt

**Pattern regex trigger:** `H:\d+/\d+.*M:\d+/\d+.*V:\d+/\d+.*X:\d+`

**Campi estratti:**

| Campo | Pattern |
|-------|---------|
| Nome PG | Prima di `H:` |
| HP | `H:cur/max` o `Hcur/max` |
| Mana | `M:cur/max` |
| Move | `V:cur/max` |
| XP | `X:N` |
| Oro | `G:N` o `g:N` |
| Codici buff | `[[...]]` o `[...]` |
| Combattimento | `- cond/nome - cond-nome` dopo XP |

**Hook aggiuntivi:** `tempSubstringTrigger(" H:")` + `tempPromptTrigger` (se disponibile).

**Poll buffer:** ultime 5 righe se stats assenti.

### 8.4 Codici buff nel prompt (`PROMPT_SLOTS`)

Ordine caratteri in `[[------Tm---]]`:

| Pos | Codice | Buff |
|-----|--------|------|
| 1 | P | polymorph self / change form / tree |
| 2 | F | fireshield |
| 3 | S | sanctuary |
| 4 | I | invisibility |
| 5 | T | true sight |
| 6 | M | mirror images |
| 7 | D | prot energy drain |
| 8 | A | anti magic shell |
| 9 | Q | quest |

`-` o spazio = slot vuoto.

### 8.5 Pannello buff — stati

| Stato | Colore | Significato |
|-------|--------|-------------|
| **OK** | Verde | Buff attivo |
| **!** | Arancione | Pre-scadenza (messaggio MUD “soon”) |
| **SCAD** | Rosso | Countdown sincronizzato esaurito |
| `~` | — | Stima locale scaduta, non ancora sync `attribute` |

**Durate stimate locali (`buffDurations`, secondi):**

| Spell | Secondi | Spell | Secondi |
|-------|---------|-------|---------|
| armor, shield, fly, invisibility, sanctuary, … | 96 | faerie fire, mirror images | 48 |

Lista completa in `Nebbie.buffDurations` (27 spell con durata nota).

**Spell escluse dal tracking buff** (`noBuffSpells`): incantesimi istantanei/offensivi (fireball, heal, magic missile, …).

---

## 9. Trigger automatici

Tutti i trigger runtime sono **temporanei** (`tempTrigger` / `tempRegexTrigger`), namespace `nebbie-play-all::<nome>`.

### 9.1 Cast e buff

| Trigger | Pattern (italiano) | Azione |
|---------|-------------------|--------|
| cast started | `Pronunci le parole` | `onBuffApplied(spell)` da `'...'` |
| wearoff * | 35 pattern da `constants.cpp` | `onBuffWearOff` |
| soon * | 5 pattern pre-scadenza | `onBuffSoon` |

**Esempi wear-off:** `armatura magica`, `Torni visibile.`, `scudo magico si dissolve`, `aura bianca che ti circondava svanisce`, …

**Esempi soon:** `armatura magica vacilla`, `scudo magico tremola`, `Torni visibile per un momento`, …

### 9.2 Debuff

| Debuff | Apply (substring) | Wear-off |
|--------|-------------------|----------|
| poison | `appare molto sofferente` | `veleno non scorre`, `sembrano meno forti ora` |
| curse | `maledett` | `Ti senti molto meglio` |
| paralyze | `pare impedit`, `Sei paralizzato` | `ricominci a muoverti`, `ricomincia a muoversi` |
| slowness | `rallentatore`, `Sembra che il mondo stia rallentando` | `movimenti riacquistano la loro velocita` |
| web | `dalle ragnatele`, `della ragnatela`, `di ragnatele`, `in ragnatele` | `ti liberi dalle`, `liberarsi dalla ragnatela` |
| heat stuff | `frigge`, `bruciare` | `raffredda` |
| blindness | `accecat` | `cecita` |
| feeblemind | `rimbecillit` | `piu' intelligente` |
| fear | `viene presa dal panico` | — |

**Filtro web:** `matchDebuffApply("web", plain)` richiede `ragnatela`/`ragnatele` nel testo (evita falsi positivi).

### 9.3 Errori cast/skill (fail triggers)

Pattern intercettati (script vuoto, per estensione/logging): concentrazione persa, mana insufficiente, `Usa la mente`/`Usa la memoria`, zona no-magic, backfire, fizzle, kick/backstab falliti, first aid CD, spell non implementata, …

### 9.4 Altri trigger

| Trigger | Pattern | Azione |
|---------|---------|--------|
| attrib gag | `Tu hai`, `Spells attivi`, `Spell :` | Parse/rimuovi righe durante `attribute` |
| eq parse wield | `<impugnato>`, `<sulla schiena>` | Parse slot per `usa` |
| look loot parse | corpi/pile | Conta target loot |
| mob kill exp loot | `^La tua esperienza e' aumentata di \d+ punti\.?$` | Avvia loot auto |

**Strip colori:** rimozione `$cNNNN` e sequenze ANSI `\27[...m` su tutte le righe trigger.

---

## 10. Regole MUD (comportamento alias)

1. **Apici obbligatori** per magia: `cast 'nome'`, `recall 'nome'`, `mind 'nome'`
2. **Stregone:** incantesimi memorizzati → `recall` (`r` / `nrecall`)
3. **Psi:** abilità psioniche → `mind` (`m` / `nmind`); `shield`, `portal`, `summon` restano comandi dedicati
4. **Nomi esatti** dal codice: `colour spray`, `slowness`, `polymorph self`, …
5. Se Mudlet mostra messaggio **verde** (alias eseguito) il comando **non** va al MUD
6. **Pardon?** dal MUD = alias non attivo → `nfix` o reinstall pulita

---

## 11. API Lua (console avanzata)

| Comando | Effetto |
|---------|---------|
| `lua cecho("<yellow>"..Nebbie.version)` | Versione package |
| `lua Nebbie.install()` | Reinstalla alias/trigger |
| `lua Nebbie.runFix()` | Come `nfix` |
| `lua Nebbie.boot()` | Riavvio logica principale |
| `lua Nebbie.reloadMainScript()` | Reset `_installedVer` + `boot()` |
| `lua Nebbie.loadClass()` | Ricarica classe salvata |
| `lua Nebbie.listClasses()` | Elenco classi |
| `lua Nebbie.buffs` | Tabella buff attivi |
| `lua Nebbie.debuffs` | Tabella debuff attivi |
| `lua Nebbie.stats` | Ultimo prompt parsato |
| `lua Nebbie.setClass("t")` | Imposta ladro |
| `lua Nebbie.toggleGUI()` | Mostra/nasconde HUD |
| `lua Nebbie.resetGUIPosition()` | Riposiziona HUD |
| `lua Nebbie.debugPrompt()` | Debug parser |
| `lua Nebbie.testPromptParse()` | Test parser su stringa campione |

---

## 12. Risoluzione problemi

| Sintomo | Causa | Soluzione |
|---------|-------|-----------|
| Versione **2.2.2** o vecchia dopo install | Package/cache obsoleta o script esterno | Reinstall pulita; verifica file **~271 KB**; `nfix`; check `Nebbie.version` |
| `Pardon?` dal MUD | Alias non attivo | `nfix`, reinstall pulita |
| `onPrompt` (nil value) | Trigger perm orfani | Elimina trigger `nebbie-play-all` in Scripts; `npurge`; reinstall |
| `nfix` ripetuto molte volte | Alias duplicati | `npurge`, riavvio, reinstall v2.2.8 |
| `nclass` stampato 2+ volte | Alias duplicati | `nfix` una volta; elimina duplicati in Scripts |
| `moveGauge` / `setGauge` error | HUD vecchio | v2.2.8 usa label custom; `nfix` + `nsetup` |
| Barre HUD grigie/vuote | Prompt non parsato | Digita un comando; `nprompt`; verifica formato `H:/M:/V:/X:` |
| Buff a 00:00 / non ripartono | Sync attribute assente | `nattrib on`; cast registra stima locale, sync corregge |
| Debuff `web` fantasma | Pattern troppo larghi | Fix v2.1.9+: filtro `matchDebuffApply` |
| Loot su corpi PG | Classificazione errata | v2.2.x: esclude nomi PG da `il corpo di Nome` |
| `getAliasList` nil | API assente | Usa `npurge` o pulizia con `exists()` |
| `class +` → Pardon? | Manca `n` iniziale | Usa **`nclass +`** |

### Pulizia emergenza (senza `getAliasList`)

```
lua local function k(n,t) local i=0 while exists(n,t)>0 and i<64 do if t=="trigger" then if disableTrigger then disableTrigger(n) end if killTrigger then killTrigger(n) end else if disableAlias then disableAlias(n) end if killAlias then killAlias(n) end end i=i+1 end end k("nebbie-play-all::prompt parse","trigger") k("reinstall fix","alias") k("nebbie-play-all::reinstall fix","alias") cecho("<green>Pulizia emergenza ok. Riavvia Mudlet.\n")
```

---

## 13. Changelog rilevante (2.2.x)

| Versione | Modifiche principali |
|----------|---------------------|
| **2.2.8** | Codice **incorporato nello script XML**; niente dipendenza da `install.lua` esterno; `nfix`/`nprompt`/`npurge` su alias XML |
| 2.2.5 | Fix errore Lua `elseif` in `refreshGUI` |
| 2.2.4 | `usa <arma>` cambio arma da borsa; `nkey` database chiavi eq |
| 2.2.3 | Rimosso `reconcileAttribBuffs` che svuotava pannello buff |
| 2.2.2 | Sync tick buff da `attribute` (`nattrib`) |
| 2.2.1 | `pruneExpiredBuffs`, `normalizeBuffSpell`; fix buff 00:00 |
| 2.1.9 | Barre HUD custom (`createLabel`); debuff web ristretti |
| 2.1.x | HUD, loot, debuff, multiclasse consolidato |

---

## 14. Build (sviluppatori)

```bash
python3 docs/mudlet/build-nebbie-package.py
```

**Output:**

- `docs/mudlet/nebbie-play-all.mpackage`
- `docs/mudlet/nebbie-play-all-build/nebbie-install.lua`
- `docs/mudlet/nebbie-play-all-build/nebbie-play-all.xml`
- `docs/mudlet/nebbie-spells-reference.txt`

**Sorgenti C++:**

| File | Contenuto estratto |
|------|-------------------|
| `src/spell_parser.cpp` | Tabella `spells[]`, abbreviazioni, cast spells |
| `src/interpreter.cpp` | Skill dedicate |
| `src/constants.cpp` | `spell_wear_off_msg`, messaggi buff |

**Costanti build (`build-nebbie-package.py`):**

- `PKG_VER = "2.2.8"`
- `PACKAGE_NAME = "nebbie-play-all"`
- `INSTALLER_CORE = nebbie-installer-core.lua`

---

## 15. Riferimenti

- [Mudlet — Package Manager](https://wiki.mudlet.org/w/Manual:Package_Manager)
- `docs/mudlet/HELP.md` — guida utente
- `docs/mudlet/nebbie-spells-reference.txt` — elenco completo spell/skill/abbreviazioni

---

*Documento allineato a `nebbie-play-all` v2.2.8 — `Nebbie.version = "2.2.8"`, `NEBBIE_PKG_VER = "2.2.8"`.*
