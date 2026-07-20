# Nebbie Arcane — Package Mudlet `nebbie-play-all`

Guida al package Mudlet per **Nebbie Arcane**: alias/trigger multiclasse, HUD HP/Mana/Move, buff/debuff, loot automatico.

Generato dal sorgente MUD (`src/spell_parser.cpp`, `src/interpreter.cpp`, `src/constants.cpp`).

---

## Cosa fa il package


| Funzione               | Descrizione                                                                            |
| ---------------------- | -------------------------------------------------------------------------------------- |
| **HUD**                | Gauge HP/Mana/Move dal prompt + pannello buff/debuff                                   |
| **Loot**               | Auto dopo kill mob: `look` + `corp` / `2.corp` / … + `pile` / `2.pile` / …             |
| **Alias**              | Scorciatoie incantesimi/skill (~170+), senza conflitti con `inv`/`eq`/`invis`/`ea`     |
| **Trigger**            | Cast, buff scaduti, debuff (veleno, maledizione, paralisi, …)                          |
| **Preset classe**      | 9 slot rapidi `q1`–`q9` per ognuna delle 11 classi (`nclass +` = tutte)               |
| **Salvataggio classe** | La classe scelta con `nclass` resta memorizzata per profilo Mudlet                     |


### Cosa invia al MUD

- Gli **incantesimi** usano nomi **inglesi tra apici**, come nel gioco: `cast 'fireball'`, `recall 'armor'`, `mind 'psychic crush'`.
- Le **skill** usano i comandi dedicati del server: `kick goblin`, `backstab orco`, `track lupo`, ecc.
- Se Mudlet risponde con **alias** (messaggio verde in console) il comando **non** va al MUD. Se il MUD risponde **Pardon?** l’alias non è attivo.

---

## File da scaricare

### Obbligatorio — package Mudlet


| File | Descrizione |
|------|-------------|
| **`nebbie-play-all.mpackage`** | Unico file da importare in Mudlet (script, alias, trigger, HUD). |

**Download (branch `mudlet`) — usa uno di questi link:**

https://github.com/wizardmorgan/nebbietest/raw/mudlet/docs/mudlet/nebbie-play-all.mpackage

https://raw.githubusercontent.com/wizardmorgan/nebbietest/mudlet/docs/mudlet/nebbie-play-all.mpackage

Salva il file con estensione `.mpackage` e installalo con **Alt+O** → *Install New Package*.

**Se vedi errori Lua o versione vecchia:** disinstalla `nebbie-play-all` da Package Manager, cancella la cartella `nebbie-play-all` nel profilo Mudlet, reinstalla il `.mpackage`, riavvia Mudlet, poi `nfix`.

### Opzionale — riferimento spell/skill


| File                              | Descrizione                                                                                                                                                |
| --------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`nebbie-spells-reference.txt`** | Elenco completo di incantesimi, skill, abbreviazioni e slot per classe. **Non** si importa in Mudlet: è solo consultazione (blocco note, secondo monitor). |
| **`nebbie-alias-index.txt`**      | Tutti gli alias e i pattern regex generati dal package.                                                                                                    |
| **`nebbie-trigger-index.txt`**    | Tutti i trigger e i pattern substring/regex.                                                                                                               |
| **[`PACKAGE-GUIDE.md`](PACKAGE-GUIDE.md)** | Guida completa: logica del package, alias e trigger spiegati in modo accessibile.                                                              |


Stesso branch del package:

https://raw.githubusercontent.com/wizardmorgan/nebbietest/mudlet/docs/mudlet/nebbie-spells-reference.txt

https://raw.githubusercontent.com/wizardmorgan/nebbietest/mudlet/docs/mudlet/nebbie-alias-index.txt

https://raw.githubusercontent.com/wizardmorgan/nebbietest/mudlet/docs/mudlet/nebbie-trigger-index.txt

### Solo per sviluppatori


| File                      | Descrizione                                    |
| ------------------------- | ---------------------------------------------- |
| `nebbie-installer-core.lua` | Sorgente installer v2 (HUD, loot, debuff)      |
| `build-nebbie-package.py` | Rigenera `.mpackage` e `.txt` dal sorgente C++ |
| [`HELP.md`](HELP.md)                 | Guida installazione e troubleshooting          |
| [`PACKAGE-GUIDE.md`](PACKAGE-GUIDE.md) | **Guida completa**: logica del package + elenco alias/trigger |


---

## Installazione

1. Apri Mudlet e il **profilo** del personaggio (consigliato: un profilo per PG).
2. **Alt+O** → *Install New Package*.
3. Seleziona `nebbie-play-all.mpackage`.
4. In console dovresti vedere (dopo 1–3 secondi) un messaggio simile a:
  ```
   Nebbie v2.2.31: ...
   Tastierino: 8=north 2=south 4=west 6=east 9=up 3=down 5=look (Num Lock ON o OFF)
   Pronto: nclass +, q1, ngui | nfix nprompt ngmcp | nlist
  ```
5. Setup iniziale:
  ```
   nsetup
   nclass +
  ```
   (`nclass +` = tutte le classi; oppure `nclass m` per una sola, vedi tabella sotto).

### Reinstallazione pulita (se qualcosa non funziona)

1. **Alt+O** → disinstalla `nebbie-play-all` (e `nebbie-spells-skills` se presente).
2. **Scripts → Triggers** → cerca `nebbie-play-all` → elimina tutto il gruppo (trigger `perm` orfani).
3. **Scripts → Aliases** → elimina `reinstall fix` e altri duplicati `nebbie-play-all`.
4. Riavvia Mudlet.
5. Reinstalla il `.mpackage` dal link sopra (v2.1.2+).
6. Digita **una volta** `nfix`, poi `nsetup` e `nclass +`.

Se dopo il riavvio compaiono errori `onPrompt` (nil) **prima** di reinstallare, i trigger `perm` vecchi sono ancora nel profilo: ripeti i passi 2–4 oppure usa la pulizia d’emergenza sotto.

### Pulizia d’emergenza (senza `getAliasList`)

Su alcune versioni Mudlet `getAliasList()` **non esiste**. Usa `exists()` per nome:

```
lua local function k(n,t) local i=0 while exists(n,t)>0 and i<64 do if t=="trigger" then if disableTrigger then disableTrigger(n) end if killTrigger then killTrigger(n) end else if disableAlias then disableAlias(n) end if killAlias then killAlias(n) end end i=i+1 end end k("nebbie-play-all::prompt parse","trigger") k("reinstall fix","alias") k("nebbie-play-all::reinstall fix","alias") cecho("<green>Pulizia emergenza ok. Riavvia Mudlet.\n")
```

Poi riavvia Mudlet e reinstalla il package.

Con il package installato puoi anche usare:

```
npurge
```

(disattiva i `perm` vecchi noti, poi riavvia e `nfix`).

### Verifica versione

Nella riga di comando Mudlet:

```
lua cecho("<yellow>"..Nebbie.version)
```

Deve mostrare la versione corrente (es. `2.2.31`).

---

## Dove digitare i comandi


| Tipo                            | Dove                                                 |
| ------------------------------- | ---------------------------------------------------- |
| `nclass`, `q1`, `fb`, `heal`, … | **Riga di comando in basso** (come i comandi al MUD) |
| `lua echo(...)`                 | Riga di comando con prefisso `lua`                   |
| Install package                 | **Alt+O**                                            |


Se non vedi la riga in basso: menu **View** → **Command Line**.

---

## Setup multi-personaggio

Usa **un profilo Mudlet per personaggio**. La classe impostata con `nclass` viene salvata in:

`getMudletHomeDir()/nebbie-play-all-settings.lua`

Esempio:


| Profilo Mudlet | Comando una tantum | Classe    |
| -------------- | ------------------ | --------- |
| `Hayato_Ladro` | `nclass t`         | Ladro     |
| `Hayato_Mago`  | `nclass m`         | Mago      |
| `Hayato_Psi`   | `nclass I`         | Psionista |


Ai login successivi sullo stesso profilo la classe si ricarica automaticamente.

---

## Lettere classe (`nclass`)

Stesse lettere del comando `practice` / `pratice` in gioco:


| Lettera   | Classe                             | Modalità cast automatica     |
| --------- | ---------------------------------- | ---------------------------- |
| `+` / `u` | Cast universale (multiclasse cast) | `cast`                       |
| `m`       | Mago                               | `cast`                       |
| `s`       | Stregone                           | `recall`                     |
| `c`       | Chierico                           | `cast`                       |
| `d`       | Druido                             | `cast`                       |
| `p`       | Paladino                           | `cast`                       |
| `r`       | Ranger                             | `cast`                       |
| `I`       | Psionista                          | `mind` ( `**I` maiuscola** ) |
| `t`       | Ladro                              | `cast`                       |
| `w`       | Guerriero                          | `cast`                       |
| `k`       | Monaco                             | `cast`                       |
| `b`       | Barbaro                            | `cast`                       |


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


| Cosa cambia           | `nclass m`   | `nclass c`      |
| --------------------- | ------------ | --------------- |
| Slot rapidi `q1`–`q9` | arm, fb, mm… | heal, san, ble… |
| Comando `c`           | `cast '…'`   | `cast '…'`      |


Il MUD controlla quali incantesimi puoi usare; il package configura solo scorciatoie.

---

## Comandi principali

### Magia generica


| Comando              | Invia al MUD             | Note                          |
| -------------------- | ------------------------ | ----------------------------- |
| `c <spell> [tgt]`    | `cast '<spell>' [tgt]`   | Rispetta la modalità corrente; supporta nomi multi-parola |
| `r <spell> [tgt]`    | `recall '<spell>' [tgt]` | Stregone                      |
| `m <spell> [tgt]`    | `mind '<spell>' [tgt]`   | Psi                           |
| `mem <spell>`        | `memorize '<spell>'`     | Stregone                      |
| `cast <spell> [tgt]` | come `c`                 | Alternativa esplicita         |

Incantesimi con più parole: `c power word kill goblin` oppure `c 'power word kill' goblin`. Per l’elenco completo: `nlist spells` o `nebbie-spells-reference.txt`.


### Modalità di cast (`c` usa la modalità attiva)


| Comando   | Effetto           |
| --------- | ----------------- |
| `ncast`   | modalità `cast`   |
| `nrecall` | modalità `recall` |
| `nmind`   | modalità `mind`   |


### Slot rapidi classe


| Comando     | Effetto                                           |
| ----------- | ------------------------------------------------- |
| `q1` … `q9` | Esegue lo slot 1–9 del preset della classe attiva |
| `q5 goblin` | Slot 5 sul bersaglio `goblin`                     |


### Package / GUI


| Comando  | Effetto                                               |
| -------- | ----------------------------------------------------- |
| `ngui`   | Mostra o nasconde il pannello buff                    |
| `npos`   | Riposiziona il pannello in alto a destra              |
| `nfix`   | Reinstalla alias/trigger e ricarica la classe salvata |
| `npurge` | Disattiva alias/trigger `perm` vecchi (poi riavvia e `nfix`) |
| `nlist`  | Indice documentazione (alias/trigger/spells)          |
| `nlist aliases` | Elenca alias installati in Mudlet              |
| `nlist triggers` | Elenca trigger installati                     |
| `nlist spells` | Aiuto incantesimi multi-parola                   |
| `nkeys`  | Reinstalla binding tastierino numerico              |
| `return` | Torna dalla forma `polymorph self`                    |

### Tastierino numerico

Funziona con **Num Lock acceso o spento** (layout roguelike: nord in alto):

| Tasto (Num Lock ON) | Tasto (Num Lock OFF) | Comando |
| ------------------- | -------------------- | ------- |
| `5`                 | Canc / Clear         | `look`  |
| `8`                 | Freccia su           | `north` |
| `2`                 | Freccia giù          | `south` |
| `6`                 | Freccia destra       | `east`  |
| `4`                 | Freccia sinistra     | `west`  |
| `9`                 | PagSu                | `up`    |
| `3`                 | PagGiù               | `down`  |

I binding sono nel package (gruppo **Nebbie Keypad** in Keys). Se non rispondono dopo l’aggiornamento:

1. Reinstalla `nebbie-play-all.mpackage` (non basta solo `nfix` la prima volta)
2. Digita `nkeys` per forzare la reinstallazione dei binding
3. Verifica in Mudlet: **Keys → Nebbie Keypad** che i tasti siano attivi


### Abbreviazioni incantesimi (esempi)


| Abbrev   | Incantesimo    |
| -------- | -------------- |
| `fb`     | fireball       |
| `mm`     | magic missile  |
| `lb`     | lightning bolt |
| `heal`   | heal           |
| `arm`    | armor          |
| `shld`   | shield         |
| `inv`    | invisibility   |
| `san`    | sanctuary      |
| `clight` | cure light     |
| `cc`     | cure critic    |


L’elenco completo è in `nebbie-spells-reference.txt`.

### Abbreviazioni skill (esempi)


| Abbrev  | Comando      |
| ------- | ------------ |
| `bs`    | backstab     |
| `k`     | kick         |
| `b`     | bash         |
| `sn`    | sneak        |
| `hi`    | hide         |
| `tr`    | track        |
| `med`   | meditate     |
| `pshld` | shield (psi) |
| `dw`    | doorway      |
| `berz`  | berserk      |


---

## Slot rapidi per classe (`q1`–`q9`)

Ogni slot esegue l’abbreviazione indicata (cast, recall, mind o skill).


| Classe        | q1    | q2     | q3     | q4     | q5     | q6    | q7     | q8     | q9    |
| ------------- | ----- | ------ | ------ | ------ | ------ | ----- | ------ | ------ | ----- |
| **Mago**      | arm   | shld   | fly    | mm     | fb     | lb    | inv    | str    | tel   |
| **Stregone**  | arm   | shld   | mm     | fb     | lb     | inv   | str    | fly    | tel   |
| **Chierico**  | heal  | cser   | cc     | clight | ble    | san   | pevil  | de     | aid   |
| **Druido**    | bark  | cl     | ent    | snare  | clight | fly   | sskin  | ffood  | brew  |
| **Paladino**  | heal  | loh    | wc     | ble    | san    | fs    | hero   | bld    | pray  |
| **Ranger**    | tr    | clight | bark   | camo   | sn     | carve | ffood  | fwater | ent   |
| **Psi**       | pshld | mb     | pcrush | lev    | ptel   | med   | blast  | dw     | port  |
| **Ladro**     | bs    | sn     | hi     | stl    | pick   | spy   | tspy   | dis    | ed    |
| **Guerriero** | k     | b      | res    | disarm | bel    | parry | fa     | dbash  | climb |
| **Monaco**    | man   | fin    | qp     | sl     | fd     | k     | b      | dai    | fa    |
| **Barbaro**   | berz  | bel    | k      | b      | camo   | ffood | fwater | tan    | fa    |


---

## Pannello buff `NebbieBuffs`

- **Posizione:** alto a destra (non copre prompt e log).
- **Aggiornamento:** ogni secondo.
- **Contenuto:** buff attivi, tempo trascorso, countdown stimato, stato colore.


| Stato    | Significato                                    |
| -------- | ---------------------------------------------- |
| **OK**   | Buff attivo                                    |
| **!**    | In scadenza (messaggio “pre-scadenza” del MUD) |
| **SCAD** | Countdown stimato esaurito                     |


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


| Comando                                 | Effetto                               |
| --------------------------------------- | ------------------------------------- |
| `lua cecho("<yellow>"..Nebbie.version)` | Versione package                      |
| `lua Nebbie.install()`                  | Reinstalla alias/trigger              |
| `lua Nebbie.loadClass()`                | Ricarica classe salvata               |
| `lua Nebbie.listClasses()`              | Elenco classi                         |
| `lua Nebbie.buffs`                      | Tabella buff (in Lua)                 |
| `lua Nebbie.setClass("t")`              | Imposta ladro da Lua                  |
| `lua Nebbie.toggleGUI()`                | Mostra/nasconde pannello              |
| `lua Nebbie.resetGUIPosition()`         | Riposiziona pannello in alto a destra |


---

## Risoluzione problemi


| Sintomo                               | Causa probabile                     | Soluzione                                                                                     |
| ------------------------------------- | ----------------------------------- | --------------------------------------------------------------------------------------------- |
| `Pardon?` dal MUD                     | Alias non attivo                    | `nfix`, reinstall pulita, verifica **Scripts → Aliases**                                      |
| Errore `setVariable`                  | Package vecchio                     | Installa v1.0.7+ dal link branch PR                                                           |
| Errore `getEpochTime`                 | Package vecchio su Mudlet recente   | Aggiorna package; Mudlet 4.21+ ha la funzione nativa                                          |
| Errore `classLine` nil                | Package vecchio                     | Reinstall v1.0.4+                                                                             |
| Alias eseguito due volte              | Duplicati da reinstall              | `nfix` o reinstall pulita                                                                     |
| Versione sbagliata dopo download      | File dalla branch errata            | Usa il link `cursor/nebbie-mudlet-spells-skills-55b4`                                         |
| Pannello copre il prompt              | Posizione salvata nel profilo       | `npos` o `nfix` (v1.0.9+ ricrea il pannello)                                                  |
| `nclass` ripetuto 3 volte             | Alias duplicati da reinstall        | `nfix` (v1.0.10+); in **Scripts** elimina eventuali copie extra di «Nebbie Spells and Skills» |
| Installazione bloccata su «unpacking» | Download corrotto o import bloccato | Riscarica il file (deve essere ~50 KB zip valido); evita Safari; usa v1.0.12+; riavvia Mudlet |
| `nclass` non salva                    | `table.save` non disponibile        | Aggiorna Mudlet; la v1.0.7+ usa file nel profilo                                              |
| `getAliasList` (a nil value)          | API assente su alcune versioni Mudlet | Usa `npurge` o pulizia d’emergenza con `exists()` (vedi sopra)                              |
| `onPrompt` (a nil value) × molti trigger | Trigger `perm` orfani nel profilo | Elimina trigger `nebbie-play-all` in Scripts, oppure pulizia d’emergenza, poi reinstall v2.1.1+ |
| `nfix` eseguito molte volte           | Alias `reinstall fix` duplicati     | `npurge`, riavvio Mudlet, reinstall; v2.1.2+ ha un solo `nfix` nel package                    |
| `nclass +` stampato due volte       | Alias `perm`/`temp` duplicati       | Aggiorna a v2.1.2+, `nfix` una volta; elimina alias `set class` in Scripts se restano         |
| `moveGauge: no such gauge` su nsetup | Alias HUD vecchio o gauge assente  | v2.1.2+ ricrea le gauge; `nfix` poi `nsetup`                                                  |
| `class +` → Pardon?                   | Comando MUD (manca la `n`)          | Usa `nclass +` (con **n** iniziale)                                                           |


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

- `docs/mudlet/nebbie-play-all.mpackage`
- `docs/mudlet/nebbie-spells-reference.txt`
- `docs/mudlet/nebbie-alias-index.txt`
- `docs/mudlet/nebbie-trigger-index.txt`

---

## Riferimenti

- [Mudlet — Package Manager](https://wiki.mudlet.org/w/Manual:Package_Manager)
- Codice sorgente spell: `src/spell_parser.cpp`
- Comandi skill: `src/interpreter.cpp`
- Messaggi buff: `src/constants.cpp` (`spell_wear_off_msg`)

