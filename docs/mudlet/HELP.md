# Nebbie Arcane — Package Mudlet `nebbie-spells-skills`

Guida completa al package Mudlet per **Nebbie Arcane**: alias, trigger, pannello buff e slot rapidi per classe.

Il package è generato automaticamente dal codice sorgente del MUD (`src/spell_parser.cpp`, `src/interpreter.cpp`, `src/constants.cpp`).

---

## Cosa fa il package

| Funzione | Descrizione |
|----------|-------------|
| **Alias** | Scorciatoie per incantesimi, skill psi, skill da combattimento e utility (~170+ alias) |
| **Trigger** | Rileva messaggi italiani del MUD (cast, buff scaduti, errori mana, ecc.) |
| **Pannello GUI** | MiniConsole `NebbieBuffs` in alto a destra con timer buff |
| **Preset classe** | 9 slot rapidi `q1`–`q9` per ognuna delle 11 classi |
| **Salvataggio classe** | La classe scelta con `nclass` resta memorizzata per profilo Mudlet |

### Cosa invia al MUD

- Gli **incantesimi** usano nomi **inglesi tra apici**, come nel gioco: `cast 'fireball'`, `recall 'armor'`, `mind 'psychic crush'`.
- Le **skill** usano i comandi dedicati del server: `kick goblin`, `backstab orco`, `track lupo`, ecc.
- Se Mudlet risponde con **alias** (messaggio verde in console) il comando **non** va al MUD. Se il MUD risponde **Pardon?** l’alias non è attivo.

---

## File da scaricare

### Obbligatorio — package Mudlet

| File | Descrizione |
|------|-------------|
| **`nebbie-spells-skills.mpackage`** | Unico file da importare in Mudlet. Contiene script, alias e trigger. |

**Download (branch aggiornato):**

https://raw.githubusercontent.com/wizardmorgan/nebbietest/cursor/nebbie-mudlet-spells-skills-55b4/docs/mudlet/nebbie-spells-skills.mpackage

> **Attenzione:** il file sulla branch `sviluppo` / `main` può essere più vecchio. Usa il link sopra finché il PR non è mergiato.

Salva il file con estensione `.mpackage` e installalo con **Alt+O** → *Install New Package*.

### Opzionale — riferimento spell/skill

| File | Descrizione |
|------|-------------|
| **`nebbie-spells-reference.txt`** | Elenco completo di incantesimi, skill, abbreviazioni e slot per classe. **Non** si importa in Mudlet: è solo consultazione (blocco note, secondo monitor). |

Stesso branch del package:

https://raw.githubusercontent.com/wizardmorgan/nebbietest/cursor/nebbie-mudlet-spells-skills-55b4/docs/mudlet/nebbie-spells-reference.txt

### Solo per sviluppatori

| File | Descrizione |
|------|-------------|
| `build-nebbie-package.py` | Rigenera `.mpackage` e `.txt` dal sorgente C++ |
| `HELP.md` | Questa guida |

---

## Installazione

1. Apri Mudlet e il **profilo** del personaggio (consigliato: un profilo per PG).
2. **Alt+O** → *Install New Package*.
3. Seleziona `nebbie-spells-skills.mpackage`.
4. In console dovresti vedere (dopo 1–3 secondi) un messaggio simile a:
   ```
   Nebbie v1.0.12: 179 alias, 116 trigger.
   Pronto: nclass m, q1, fb, ngui
   ```
5. Imposta la classe **una volta** per profilo:
   ```
   nclass m
   ```
   (sostituisci `m` con la lettera della tua classe, vedi tabella sotto).

### Reinstallazione pulita (se qualcosa non funziona)

1. **Alt+O** → disinstalla `nebbie-spells-skills`.
2. **Scripts** → elimina manualmente lo script **"Nebbie Spells and Skills"** se è ancora presente.
3. Riavvia Mudlet.
4. Reinstalla il `.mpackage` dal link sopra.
5. Digita `nfix` oppure `nclass m`.

### Verifica versione

Nella riga di comando Mudlet:

```
lua cecho("<yellow>"..Nebbie.version)
```

Deve mostrare la versione corrente (es. `1.0.12`). Nel pannello buff compare anche `=== Nebbie Buffs v1.0.12 ===`.

---

## Dove digitare i comandi

| Tipo | Dove |
|------|------|
| `nclass`, `q1`, `fb`, `heal`, … | **Riga di comando in basso** (come i comandi al MUD) |
| `lua echo(...)` | Riga di comando con prefisso `lua` |
| Install package | **Alt+O** |

Se non vedi la riga in basso: menu **View** → **Command Line**.

---

## Setup multi-personaggio

Usa **un profilo Mudlet per personaggio**. La classe impostata con `nclass` viene salvata in:

`getMudletHomeDir()/nebbie-spells-skills-settings.lua`

Esempio:

| Profilo Mudlet | Comando una tantum | Classe |
|----------------|-------------------|--------|
| `Hayato_Ladro` | `nclass t` | Ladro |
| `Hayato_Mago` | `nclass m` | Mago |
| `Hayato_Psi` | `nclass I` | Psionista |

Ai login successivi sullo stesso profilo la classe si ricarica automaticamente.

---

## Lettere classe (`nclass`)

Stesse lettere del comando `practice` / `pratice` in gioco:

| Lettera | Classe | Modalità cast automatica |
|---------|--------|--------------------------|
| `+` / `u` | Cast universale (multiclasse cast) | `cast` |
| `m` | Mago | `cast` |
| `s` | Stregone | `recall` |
| `c` | Chierico | `cast` |
| `d` | Druido | `cast` |
| `p` | Paladino | `cast` |
| `r` | Ranger | `cast` |
| `I` | Psionista | `mind` ( **`I` maiuscola** ) |
| `t` | Ladro | `cast` |
| `w` | Guerriero | `cast` |
| `k` | Monaco | `cast` |
| `b` | Barbaro | `cast` |

```
nclass +      → preset cast universale (consigliato per multiclasse cast)
nclass m c    → unisce slot Mago + Chierico
nclass m      → imposta Mago e salva
nclass        → elenca tutte le classi e gli slot q1–q9
```

### Personaggi multiclasse (es. Mago + Chierico)

Due modi supportati in v1.0.11+:

#### 1. Preset cast universale (`+`)

Per un **unico profilo** con tutte le classi che usano `cast` (mago, chierico, druido, paladino, ranger, ladro, guerriero, monaco, barbaro):

```
nclass +
```

Slot rapidi misti: heal, arm, san, fb, mm, lb, fly, ble, inv. La modalità resta `cast`; abbreviazioni (`fb`, `heal`, `bs`…) funzionano sempre. Stregone (`s`) e psi (`I`) restano preset separati perché usano `recall` e `mind`.

Alias: `nclass u` equivale a `nclass +`.

#### 2. Multiclasse esplicito (`nclass m c`)

Unisce gli slot `q1`–`q9` delle classi indicate (senza duplicati, nell’ordine digitato):

```
nclass m c     → Mago + Chierico (arm, shld, fly, mm, fb, heal, cser, cc, clight…)
nclass w t     → Guerriero + Ladro
```

Modalità default: `cast`. Per incantesimi da stregone usa `r` o `nrecall`; per psi usa `m` o `nmind`.

#### Alternativa: una classe alla volta

Puoi ancora alternare `nclass m` e `nclass c` se preferisci barre separate.

| Cosa cambia | `nclass m` | `nclass c` |
|-------------|------------|------------|
| Slot rapidi `q1`–`q9` | arm, fb, mm… | heal, san, ble… |
| Comando `c` | `cast '…'` | `cast '…'` |

Il MUD controlla quali incantesimi puoi usare; il package configura solo scorciatoie.

---

## Comandi principali

### Magia generica

| Comando | Invia al MUD | Note |
|---------|--------------|------|
| `c <spell> [tgt]` | `cast '<spell>' [tgt]` | Rispetta la modalità corrente |
| `r <spell> [tgt]` | `recall '<spell>' [tgt]` | Stregone |
| `m <spell> [tgt]` | `mind '<spell>' [tgt]` | Psi |
| `mem <spell>` | `memorize '<spell>'` | Stregone |
| `cast <spell> [tgt]` | come `c` | Alternativa esplicita |

### Modalità di cast (`c` usa la modalità attiva)

| Comando | Effetto |
|---------|---------|
| `ncast` | modalità `cast` |
| `nrecall` | modalità `recall` |
| `nmind` | modalità `mind` |

### Slot rapidi classe

| Comando | Effetto |
|---------|---------|
| `q1` … `q9` | Esegue lo slot 1–9 del preset della classe attiva |
| `q5 goblin` | Slot 5 sul bersaglio `goblin` |

### Package / GUI

| Comando | Effetto |
|---------|---------|
| `ngui` | Mostra o nasconde il pannello buff |
| `npos` | Riposiziona il pannello in alto a destra |
| `nfix` | Reinstalla alias/trigger e ricarica la classe salvata |
| `return` | Torna dalla forma `polymorph self` |

### Abbreviazioni incantesimi (esempi)

| Abbrev | Incantesimo |
|--------|-------------|
| `fb` | fireball |
| `mm` | magic missile |
| `lb` | lightning bolt |
| `heal` | heal |
| `arm` | armor |
| `shld` | shield |
| `inv` | invisibility |
| `san` | sanctuary |
| `clight` | cure light |
| `cc` | cure critic |

L’elenco completo è in `nebbie-spells-reference.txt`.

### Abbreviazioni skill (esempi)

| Abbrev | Comando |
|--------|---------|
| `bs` | backstab |
| `k` | kick |
| `b` | bash |
| `sn` | sneak |
| `hi` | hide |
| `tr` | track |
| `med` | meditate |
| `pshld` | shield (psi) |
| `dw` | doorway |
| `berz` | berserk |

---

## Slot rapidi per classe (`q1`–`q9`)

Ogni slot esegue l’abbreviazione indicata (cast, recall, mind o skill).

| Classe | q1 | q2 | q3 | q4 | q5 | q6 | q7 | q8 | q9 |
|--------|----|----|----|----|----|----|----|----|-----|
| **Mago** | arm | shld | fly | mm | fb | lb | inv | str | tel |
| **Stregone** | arm | shld | mm | fb | lb | inv | str | fly | tel |
| **Chierico** | heal | cser | cc | clight | ble | san | pevil | de | aid |
| **Druido** | bark | cl | ent | snare | clight | fly | sskin | ffood | brew |
| **Paladino** | heal | loh | wc | ble | san | fs | hero | bld | pray |
| **Ranger** | tr | clight | bark | camo | sn | carve | ffood | fwater | ent |
| **Psi** | pshld | mb | pcrush | lev | ptel | med | blast | dw | port |
| **Ladro** | bs | sn | hi | stl | pick | spy | tspy | dis | ed |
| **Guerriero** | k | b | res | disarm | bel | parry | fa | dbash | climb |
| **Monaco** | man | fin | qp | sl | fd | k | b | dai | fa |
| **Barbaro** | berz | bel | k | b | camo | ffood | fwater | tan | fa |

---

## Pannello buff `NebbieBuffs`

- **Posizione:** alto a destra (non copre prompt e log).
- **Aggiornamento:** ogni secondo.
- **Contenuto:** buff attivi, tempo trascorso, countdown stimato, stato colore.

| Stato | Significato |
|-------|-------------|
| **OK** | Buff attivo |
| **!** | In scadenza (messaggio “pre-scadenza” del MUD) |
| **SCAD** | Countdown stimato esaurito |

Il pannello mostra anche la classe, la modalità cast e l’elenco `q1=… q2=…`.

Puoi spostarlo trascinando la **barra grigia** in alto (`Nebbie Buffs — trascina qui`); `npos` lo riporta in alto a destra.

---

## Trigger automatici

Il package intercetta messaggi **italiani** del server (con strip dei codici colore `$cNNNN`).

### Cast

- `Pronunci le parole, 'fireball'` → registra il buff e aggiorna il pannello.

### Buff scaduti (esempi)

- armatura magica → armor
- `Torni visibile.` → invisibility
- aura bianca / sanctuary
- scudo magico, fly, haste, meditate, lay on hands, ecc.

### Pre-scadenza (esempi)

- `armatura magica vacilla`
- `scudo magico tremola`
- `Torni visibile per un momento`

### Errori cast / skill (esempi)

- `Perdi la tua concentrazione`
- `Non hai abbastanza energia`
- `Usa la mente` / `Usa la memoria`
- `Il mana si rifusa di scorrere` (zona no-magic)
- `non e' stato ancora inventato`

In console Mudlet compaiono righe `[buff]` o `[cast]` colorate.

---

## Regole importanti del MUD

1. **Apici obbligatori** per la magia: `cast 'nome'` — senza apici il server rifiuta il comando.
2. **Stregone:** incantesimi memorizzati vanno lanciati con `recall`, non `cast` (usa `r` o `nrecall` + `c`).
3. **Psi:** abilità psioniche con `mind` (usa `m` o `nmind`); `shield`, `portal`, `summon` restano comandi dedicati.
4. **Nomi esatti** dal codice: `colour spray` (non `color`), `slowness` (non `slow`), `polymorph self`, ecc.
5. **Polymorph:** `return` per tornare alla forma normale.

---

## Console Lua (avanzato)

| Comando | Effetto |
|---------|---------|
| `lua cecho("<yellow>"..Nebbie.version)` | Versione package |
| `lua Nebbie.install()` | Reinstalla alias/trigger |
| `lua Nebbie.loadClass()` | Ricarica classe salvata |
| `lua Nebbie.listClasses()` | Elenco classi |
| `lua Nebbie.buffs` | Tabella buff (in Lua) |
| `lua Nebbie.setClass("t")` | Imposta ladro da Lua |
| `lua Nebbie.toggleGUI()` | Mostra/nasconde pannello |
| `lua Nebbie.resetGUIPosition()` | Riposiziona pannello in alto a destra |

---

## Risoluzione problemi

| Sintomo | Causa probabile | Soluzione |
|---------|-----------------|-----------|
| `Pardon?` dal MUD | Alias non attivo | `nfix`, reinstall pulita, verifica **Scripts → Aliases** |
| Errore `setVariable` | Package vecchio | Installa v1.0.7+ dal link branch PR |
| Errore `getEpochTime` | Package vecchio su Mudlet recente | Aggiorna package; Mudlet 4.21+ ha la funzione nativa |
| Errore `classLine` nil | Package vecchio | Reinstall v1.0.4+ |
| Alias eseguito due volte | Duplicati da reinstall | `nfix` o reinstall pulita |
| Versione sbagliata dopo download | File dalla branch errata | Usa il link `cursor/nebbie-mudlet-spells-skills-55b4` |
| Pannello copre il prompt | Posizione salvata nel profilo | `npos` o `nfix` (v1.0.9+ ricrea il pannello) |
| `nclass` ripetuto 3 volte | Alias duplicati da reinstall | `nfix` (v1.0.10+); in **Scripts** elimina eventuali copie extra di «Nebbie Spells and Skills» |
| Installazione bloccata su «unpacking» | Download corrotto o import bloccato | Riscarica il file (deve essere ~50 KB zip valido); evita Safari; usa v1.0.12+; riavvia Mudlet |
| `nclass` non salva | `table.save` non disponibile | Aggiorna Mudlet; la v1.0.7+ usa file nel profilo |

### Reinstall rapida

```
nfix
```

---

## Rigenerare il package (sviluppatori)

Dal repository Nebbie:

```bash
python3 docs/mudlet/build-nebbie-package.py
```

Genera:

- `docs/mudlet/nebbie-spells-skills.mpackage`
- `docs/mudlet/nebbie-spells-reference.txt`

---

## Riferimenti

- [Mudlet — Package Manager](https://wiki.mudlet.org/w/Manual:Package_Manager)
- Codice sorgente spell: `src/spell_parser.cpp`
- Comandi skill: `src/interpreter.cpp`
- Messaggi buff: `src/constants.cpp` (`spell_wear_off_msg`)
