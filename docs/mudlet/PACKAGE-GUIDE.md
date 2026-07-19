# Nebbie Play All — Guida completa al package Mudlet

**Package:** `nebbie-play-all`  
**Versione documentata:** 2.2.33  
**Gioco:** Nebbie Arcane (MUD testuale italiano)

Questa guida spiega **cosa fa il package**, **come funziona** (in termini comprensibili) e contiene l’**elenco completo di alias e trigger** installati automaticamente.

Per installazione rapida e troubleshooting vedi anche [`HELP.md`](HELP.md).

---

## A cosa serve

`nebbie-play-all` è un pacchetto Mudlet che ti aiuta a giocare su Nebbie Arcane senza digitare ogni volta comandi lunghi. In sintesi:

| Area | Cosa fa per te |
|------|----------------|
| **Scorciatoie** | Abbreviazioni per incantesimi e skill (`fb` → `cast 'fireball'`) |
| **Barra rapida** | 9 slot per classe (`q1`–`q9`) con i sortilegi più usati |
| **HUD** | Barre HP / Mana / Movimento e pannello buff/debuff |
| **Automazioni** | Loot dopo kill, recupero armi, fame/sete, sync equipaggiamento |
| **Tastierino** | Movimento con il keypad numerico (stile roguelike) |

Il package **non** sostituisce il gioco: invia comandi al MUD come faresti tu a mano. Se il MUD risponde `Pardon?`, il comando non è valido per il tuo personaggio o l’alias non è attivo.

---

## Concetti base (senza tecnicismi)

### Alias

Un **alias** intercetta ciò che scrivi nella riga di comando **prima** che arrivi al MUD.

- Esempio: scrivi `fb goblin` → Mudlet invia `cast 'fireball' goblin`
- Se Mudlet mostra un messaggio verde tipo «Alias: cast 'fireball' goblin», l’alias ha funzionato
- Se vedi `Pardon?` dal MUD, il testo è arrivato al gioco ma non è un comando valido

### Trigger

Un **trigger** osserva i **messaggi che il MUD ti manda** e reagisce automaticamente.

- Esempio: quando leggi «armatura magica vacilla», il pannello buff segnala che `armor` sta per scadere
- Esempio: quando guadagni esperienza da un kill, parte il loot automatico sui resti

### Tasti (Keys)

Alcuni comandi sono legati al **tastierino numerico** (gruppo **Nebbie Keypad** in Mudlet → Keys). Funzionano con Num Lock acceso o spento.

### Comandi che iniziano con `n`

I comandi `nfix`, `nclass`, `ngui`, `nloot`, ecc. sono **comandi del package**, non del MUD. Servono a configurare Mudlet. I comandi nativi del gioco come `inv`, `eq`, `look`, `north` restano liberi (il package evita di sovrascriverli).

---

## Come si carica il package

1. Installi `nebbie-play-all.mpackage` da **Alt+O** (Package Manager).
2. Mudlet importa un piccolo **loader** e scarica/carica `nebbie-install.lua` nella cartella del profilo (`nebbie-play-all/`).
3. All’avvio (o con `nfix`) il package **crea** alias e trigger temporanei in memoria.
4. La **classe** scelta con `nclass` viene salvata in un file nel profilo Mudlet.

```
Installazione .mpackage
        ↓
Loader + nebbie-install.lua
        ↓
Nebbie.boot() → Nebbie.install()
        ↓
~185 alias + ~85 trigger + tasti keypad
```

**`nfix`** — reinstalla tutto (utile dopo aggiornamenti o se qualcosa smette di funzionare).  
**`npurge`** — disattiva vecchi elementi permanenti rimasti da versioni precedenti (poi riavvia Mudlet e `nfix`).

---

## Le funzioni principali

### 1. HUD — barre e pannello buff

**Comandi:** `nsetup` (avvia), `ngui` / `nhud` (mostra/nasconde), `npos` (riposiziona in alto a destra)

Il package legge il **prompt** del gioco (la riga con `H:… M:… V:…`) e aggiorna tre barre:

- **HP** (vita)
- **Mana**
- **Movimento**

Accanto c’è un pannello con i **buff attivi** e i **debuff** (veleno, maledizione, ecc.), con stato OK / in scadenza / scaduto.

**Come lo fa:** un trigger regex sul prompt chiama il parser; un trigger su `attribute` (con gag per non intasare lo schermo) sincronizza la durata dei buff.

---

### 2. Magia — cast, recall, mind

**Comandi generici:**

| Comando | Effetto |
|---------|---------|
| `c <spell> [bersaglio]` | Lancia con `cast` (o la modalità attiva) |
| `r <spell> [bersaglio]` | `recall` (stregone) |
| `m <spell> [bersaglio]` | `mind` (psionista) |
| `mem <spell>` | `memorize` |
| `cast …` | Come `c` |

**Incantesimi con più parole:** il parser riconosce il nome più lungo possibile.

```
c power word kill goblin     → cast 'power word kill' goblin
c 'power word kill' goblin   → stesso risultato
c magic missile goblin       → cast 'magic missile' goblin
```

**Modalità di cast:** `ncast`, `nrecall`, `nmind` — cambiano cosa fa il comando `c` di default. La classe scelta con `nclass` imposta anche la modalità (es. stregone → recall, psi → mind).

**Abbreviazioni:** centinaia di alias brevi (`fb`, `heal`, `mm`, `bs`, …) generati dal sorgente del MUD. Alcuni nomi completi sono alias aggiuntivi (`aid`, `armor`, `bless`, …).

**Cosa non viene aliasato:** comandi MUD comuni come `inv`, `eq`, `rest`, `kill`, `look`, ecc., per evitare conflitti.

---

### 3. Classi e slot rapidi `q1`–`q9`

**Comandi:** `nclass`, `nclass <lettera>`, `nclass m c` (multiclasse), `q1` … `q9`

Ogni classe ha **9 slot** preconfigurati. `q3 goblin` esegue lo slot 3 sul bersaglio `goblin`.

| Lettera | Classe | Modalità default |
|---------|--------|------------------|
| `+` / `u` | Cast universale (multiclasse) | cast |
| `m` | Mago | cast |
| `s` | Stregone | recall |
| `c` | Chierico | cast |
| `d` | Druido | cast |
| `p` | Paladino | cast |
| `r` | Ranger | cast |
| `I` | Psionista (**I maiuscola**) | mind |
| `t` | Ladro | cast |
| `w` | Guerriero | cast |
| `k` | Monaco | cast |
| `b` | Barbaro | cast |

**Preset `nclass +`:** slot misti utili a chi ha più classi con `cast`.  
**Preset `nclass m c`:** unisce gli slot di Mago + Chierico (senza duplicati).

La scelta resta **salvata per profilo Mudlet** (un profilo = un personaggio consigliato).

#### Slot per classe

| Classe | q1 | q2 | q3 | q4 | q5 | q6 | q7 | q8 | q9 |
|--------|----|----|----|----|----|----|----|----|-----|
| **+** Cast universale | aid | arm | ble | shld | sskin | mirr | heal | san | invis |
| **m** Mago | arm | shld | fly | mm | fb | lb | invis | str | tele |
| **s** Stregone | arm | shld | mm | fb | lb | invis | str | fly | tele |
| **c** Chierico | heal | cser | cc | clight | ble | san | pevil | devl | aid |
| **d** Druido | bark | clightn | ent | snare | clight | fly | sskin | ffood | brew |
| **p** Paladino | heal | loh | wc | ble | san | fs | hero | bld | pray |
| **r** Ranger | track | clight | bark | camo | snk | carve | ffood | fwater | ent |
| **I** Psionista | pshld | mb | pcrush | lev | ptel | medit | blast | dw | psiport |
| **t** Ladro | bs | snk | hide | stl | picklock | spy | tspy | disguise | eaves |
| **w** Guerriero | kick | bash | resc | disarm | bel | parry | faid | dbash | climb |
| **k** Monaco | man | fin | qp | leap | fd | kick | bash | dai | faid |
| **b** Barbaro | berz | bel | kick | bash | camo | ffood | fwater | tan | faid |

*(Gli slot eseguono l’abbreviazione o il comando indicato; il tipo può essere cast, recall, mind o skill diretta.)*

---

### 4. Loot — raccolta resti mob

**Comandi:** `nloot` (manuale), `nloot on` / `nloot off` (automatico)

Dopo un kill (rileva il messaggio di esperienza guadagnata), se il loot auto è attivo:

1. Invia `look`
2. Cerca corpi → `corp`, `2.corp`, … fino a `9.corp`
3. Cerca pile di polvere → `pile`, `2.pile`, …

`nloot` senza argomenti fa la stessa sequenza una volta, subito.

---

### 5. Equipaggiamento e armi

**Comandi:** `neq`, `neq on`/`off`, `neq clear`, `nkey`, `nkey add`, `nkey del`, `usa <arma>`, `ndrop on`/`off`

- **`neq`** — sincronizza e mostra cosa hai impugnato / in spalla (cache locale)
- **`nkey`** — elenco parole chiave per richiamare oggetti dall’equipaggiamento (es. `korred` per una borsa specifica)
- **`usa spada`** — cambia arma usando la cache equip
- **`ndrop`** — se un’arma ti cade, tenta di recuperarla automaticamente

Il package legge le righe di `equipment` quando fai sync e ricorda nomi abbreviati per i comandi successivi.

---

### 6. Attribute, fame e sete

**Comandi:** `nattrib`, `nattrib on`/`off`, `nfood`, `nfood on`/`off`, `nfood item <oggetto>`

- **`nattrib`** — chiede al MUD lo stato buff (`attribute`); l’output viene nascosto (gag) ma usato per aggiornare il pannello
- Con `nattrib on` la sync è automatica ogni ~90 secondi
- **`nfood`** — mangia/beve quando il MUD segnala fame o sete (se attivo)

---

### 7. Buff, debuff e messaggi di gioco

Il package **ascolta** messaggi italiani del MUD e aggiorna lo stato:

| Tipo | Esempio messaggio | Effetto |
|------|-------------------|---------|
| Cast riuscito | «Pronunci le parole, 'fireball'» | Registra buff |
| Scadenza buff | «L'armatura magica vacilla» | Avviso pre-scadenza |
| Buff finito | «La tua armatura magica svanisce» | Rimuove dal pannello |
| Debuff | «Sei paralizzato» | Mostra debuff HUD |
| Errore cast | «Non hai abbastanza mana» | (trigger silenzioso, per logica futura) |

I testi sono allineati a `src/constants.cpp` e aggiornati quando si rigenera il package dal sorgente C++.

---

### 8. Tastierino numerico

**Comando:** `nkeys` (reinstalla i binding se non rispondono)

| Tasto (Num Lock ON) | Tasto (Num Lock OFF) | Comando MUD |
|---------------------|----------------------|-------------|
| 5 | Canc / Clear | `look` |
| 8 | Freccia su | `north` |
| 2 | Freccia giù | `south` |
| 6 | Freccia destra | `east` |
| 4 | Freccia sinistra | `west` |
| 9 | PagSu | `up` |
| 3 | PagGiù | `down` |

Layout classico: nord in alto. I tasti sono nel gruppo **Nebbie Keypad** (Mudlet → Keys). Su Mac senza keypad fisico non sono disponibili.

---

### 9. Utilità e diagnostica

| Comando | Cosa fa |
|---------|---------|
| `nlist` | Indice documentazione |
| `nlist aliases` | Elenca alias attivi in Mudlet |
| `nlist triggers` | Elenca trigger attivi |
| `nlist spells` | Aiuto incantesimi multi-parola |
| `nprompt` | Debug parser prompt (per capire perché l’HUD non legge HP/Mana) |
| `ndiagnose` | Stato installazione |
| `return` | Invia `return` (torna da polymorph self) |

---

## Alias permanenti nel package (XML)

Oltre agli alias creati da `install()`, il file `.mpackage` include sempre questi alias «di servizio»:

| Alias | Comando |
|-------|---------|
| `nfix` | Reinstalla package |
| `npurge` | Pulizia perm vecchi |
| `nprompt` | Debug prompt |
| `nenable` | Riattiva loader |
| `ndiagnose` | Diagnostica |

---

## Elenco completo alias

*Generato automaticamente da `build-nebbie-package.py` — vedi `nebbie-alias-index.txt` per il file testuale puro.*

### Comandi package

| Pattern | Effetto |
|---------|---------|
| `nsetup` | Avvia HUD |
| `ngui` / `nhud` | Mostra/nasconde pannello buff |
| `npos` | Riposiziona pannello |
| `nfix` | Reinstalla alias/trigger |
| `npurge` | Disattiva perm vecchi |
| `nprompt` | Debug parser prompt |
| `ndiagnose` | Diagnostica installazione |
| `nkeys` | Reinstalla binding tastierino |
| `nlist` | Indice documentazione |
| `nlist aliases` | Elenca alias installati |
| `nlist triggers` | Elenca trigger installati |
| `nlist spells` | Aiuto incantesimi multi-parola |
| `ncast` | Modalità cast |
| `nrecall` | Modalità recall |
| `nmind` | Modalità mind |
| `nclass` | Elenca classi e slot |
| `nclass <classe>` | Imposta classe |
| `nclass m c` | Multiclasse (unisce slot) |
| `nattrib` | Sync attribute |
| `nattrib on` / `off` | Sync automatica ogni 90s |
| `nloot` | Loot manuale |
| `nloot on` / `off` | Loot auto dopo kill |
| `usa <arma>` | Cambio arma da spalla |
| `nkey` | Elenco chiavi eq |
| `nkey add` / `del` | Gestione chiavi custom |
| `neq` | Mostra cache eq + sync |
| `neq on` / `off` / `clear` | Sync eq automatico / svuota |
| `ndrop on` / `off` | Recupero arma caduta |
| `nfood` / `on` / `off` / `item` | Fame/sete automatica |
| `return` | Torna da polymorph |

### Cast generico

| Pattern | Invia al MUD |
|---------|--------------|
| `c <spell> [tgt]` | `cast 'spell' [tgt]` |
| `cast <spell> [tgt]` | come `c` |
| `r <spell> [tgt]` | `recall 'spell' [tgt]` |
| `m <spell> [tgt]` | `mind 'spell' [tgt]` |
| `mem <spell>` | `memorize 'spell'` |
| `q1` … `q9 [tgt]` | Slot rapidi classe attiva |

### Abbreviazioni incantesimi

| Abbreviazione | Incantesimo |
|---------------|-------------|
| `ab` | acid blast |
| `aid` | aid |
| `adead` | animate dead |
| `arm` | armor |
| `bark` | barkskin |
| `ble` | bless |
| `blind` | blindness |
| `clightn` | call lightning |
| `chain` | chain lightning |
| `cmon` | charm monster |
| `charm` | charm person |
| `ct` | chill touch |
| `cs` | colour spray |
| `cmd` | command |
| `coc` | cone of cold |
| `cfood` | create food |
| `cwater` | create water |
| `cblind` | cure blind |
| `cc` | cure critic |
| `clight` | cure light |
| `cser` | cure serious |
| `curse` | curse |
| `dev` | detect evil |
| `dinv` | detect invisibility |
| `dmag` | detect magic |
| `dpois` | detect poison |
| `disint` | disintegrate |
| `devl` | dispel evil |
| `dom` | domination |
| `ea` | earthquake |
| `earmor` | enchant armor |
| `ewep` | enchant weapon |
| `edrain` | energy drain |
| `ffire` | faerie fire |
| `fear` | fear |
| `feeble` | feeblemind |
| `fb` | fireball |
| `fshld` | fireshield |
| `fs` | flamestrike |
| `fly` | fly |
| `harm` | harm |
| `haste` | haste |
| `heal` | heal |
| `is` | ice storm |
| `ident` | identify |
| `infra` | infravision |
| `invis` | invisibility |
| `knock` | knock |
| `kalign` | know alignment |
| `lb` | lightning bolt |
| `mm` | magic missile |
| `mana` | mana |
| `ms` | meteor swarm |
| `mburn` | mind burn |
| `mwipe` | mind wipe |
| `mirr` | mirror images |
| `para` | paralyze |
| `pois` | poison |
| `poly` | polymorph self |
| `psiport` | portal |
| `prism` | prismatic spray |
| `pevil` | protection from evil |
| `ptel` | psionic teleport |
| `pcrush` | psychic crush |
| `reinc` | reincarnate |
| `rcurse` | remove curse |
| `rpara` | remove paralysis |
| `rpois` | remove poison |
| `resu` | resurrection |
| `san` | sanctuary |
| `slife` | sense life |
| `shld` | shield |
| `sg` | shocking grasp |
| `csleep` | sleep |
| `slow` | slowness |
| `snare` | snare |
| `sskin` | stone skin |
| `telek` | telekinesis |
| `tsight` | true sight |
| `wb` | water breath |
| `weak` | weakness |
| `wrec` | word of recall |

### Abbreviazioni skill

| Abbreviazione | Comando |
|---------------|---------|
| `aura` | aura |
| `bs` | backstab \<vittima\> |
| `bash` | bash \<vittima\> |
| `berz` | berserk |
| `bld` | blessing \<bersaglio\> |
| `bg` | bodyguard \<bersaglio\> |
| `brew` | brew |
| `carve` | carve \<cadavere\> |
| `climb` | climb \<direzione\> |
| `disarm` | disarm \<vittima\> |
| `disguise` | disguise |
| `dbash` | doorbash \<porta\> |
| `esp` | esp |
| `fd` | feign death |
| `ffood` | find food |
| `ftrap` | find traps |
| `fwater` | find water |
| `faid` | first aid |
| `flm` | flame |
| `forge` | forge \<arma\> \<materiale\> |
| `great` | great |
| `hide` | hide |
| `kick` | kick \<vittima\> |
| `loh` | lay on hands [bersaglio] |
| `parry` | parry |
| `picklock` | pick \<porta/cassa\> |
| `pray` | pray |
| `psiport` | portal \<nome\> |
| `pshld` | shield (psi) |
| `blast` | blast \<bersaglio\> |
| `qp` | quivering palm \<vittima\> |
| `scry` | scry \<nome\> |
| `sign` | sign |
| `snk` | sneak |
| `spot` | spot |
| `leap` | springleap |
| `spy` | spy |
| `stl` | steal \<oggetto\> \<vittima\> |
| `swim` | swim |
| `tan` | tan \<cadavere\> \<tipo\> |
| `track` | track \<nome\> |
| `tspy` | tspy |
| `wc` | warcry |

**Totale alias generati all’install:** ~185 (nomi interni `nebbie-play-all::<nome>`).

---

## Elenco completo trigger

*Generato automaticamente — vedi `nebbie-trigger-index.txt`.*

### HUD, equipaggiamento, loot

| Nome interno | Cosa osserva | Cosa fa |
|--------------|--------------|---------|
| `prompt parse` | Prompt `H:… M:… V:… X:…` (regex) | Aggiorna barre HUD |
| `attrib gag` | «Tu hai», «Spells attivi», «Spell :» | Sync buff da attribute (nascosto) |
| `eq parse wield` | «Stai usando», «impugnato», «tenuto», «sulla schiena» | Aggiorna cache equip |
| `look loot parse` | «il corpo di», «corpo sfigurato», «pile of dust» | Loot da look |
| `mob kill exp loot` | «La tua esperienza e' aumentata di N punti» | Avvia loot auto |
| `weapon drop hold` | «ti cade dalle mani» | Recupero arma |
| `weapon drop wield` | «e ti casca anche» | Recupero arma impugnata |
| `hunger thirst` | «Hai Fame.» / «Hai sete.» | `nfood` automatico |
| `cast started` | «Pronunci le parole» | Registra buff da cast |

### Buff scaduti (`wearoff`)

| Buff | Testo osservato (substring) |
|------|----------------------------|
| armor | armatura magica |
| bless | benedizione Divina |
| invisibility | Torni visibile. |
| sanctuary | aura bianca che ti circondava svanisce |
| fly | capacita' di volare svanisce |
| haste | Senti i tuoi movimenti rallentare |
| fireshield | scudo di fuoco |
| stone skin | pelle torna normale |
| shield | scudo magico si dissolve |
| sneak | Smetti di muoverti silenziosamente |
| meditate | meditato abbastanza |
| psi shield | creata dalla tua mente tremola |
| barkskin | pelle perde la consistenza |
| faerie fire | alone rosa |
| mirror images | immagine illusoria |
| strength | Non ti senti piu' cosi' |
| detect magic | presenza della magia |
| detect invisibility | vedere l'invisibile |
| protection from evil | protezione dal Male |
| anti magic shell | anti-magia |
| globe darkness | globo di oscurita' |
| minor invulnerability | globo protettivo attorno al tuo corpo si dissolve |
| lay on hands | Puoi curarti di nuovo |
| blessing | Puoi invocare i tuoi Dei di nuovo |
| first aid | Puoi medicarti di nuovo |
| spy | Puoi spiare di nuovo |
| disguise | Puoi mascherarti nuovamente |
| adrenalize | furia scompare |
| psionic blast | cervello si sta lentamente riprendendo |
| polymorph | Ritorni alla tua forma originale |
| web | ti liberi dalle ragnatele |
| paralyze | Lentamente ricominci a muoverti / ricominci a muoverti / ricomincia a muoversi |
| slowness | movimenti riacquistano la loro velocita |
| blindness | svanire la tua |
| heat stuff | equipaggiamento finalmente si |
| silence | Puoi parlare di nuovo |
| mana | protezione magica scompare |
| aid | Perdi l'aiuto Divino |

### Pre-scadenza buff (`soon`)

| Buff | Testo osservato |
|------|-----------------|
| armor | armatura magica vacilla |
| sanctuary | aura bianca che ti circonda inizia |
| shield | scudo magico tremola |
| invisibility | Torni visibile per un momento |
| fly | stai perdendo la capacita' di volare |

### Affect immediati (self)

| Affect | Testo osservato |
|--------|-----------------|
| web | ragnatele che ti avvolgono / ricopert |
| paralyze | Sei paralizzato |
| slowness | mondo stia rallentando |
| blindness | accecat |
| heat stuff | frigge |
| fear | presa dal panico |
| silence | non riesci a parlare |

### Debuff

| Debuff | Apply (substring) | Wear-off (substring) |
|--------|-------------------|----------------------|
| poison | appare molto sofferente | veleno non scorre / sembrano meno forti ora |
| curse | maledett | Ti senti molto meglio |
| feeblemind | rimbecillit | piu' intelligente |

### Errori cast / skill (`fail`)

| Codice | Testo osservato |
|--------|-----------------|
| concentrazione | Perdi la tua concentrazione |
| no_mana | Non hai abbastanza |
| no_level | Devi ancora crescere |
| no_mem | Non hai questo incantesimo memorizzato |
| usa_mind | Usa la mente |
| usa_recall | Usa la memoria |
| no_quotes | simboli sacri della |
| unknown | Fantastico! Non e' successo nulla |
| unimplemented | non e' stato ancora inventato |
| backfire | ti si ritorce contro |
| fizzle | fallisce miseramente |
| no_magic_zone | Il mana si rifusa di scorrere |
| no_mind_zone | Non riesci a concentrarti abbastanza in questo posto |
| anti_magic | scudo anti-magia |
| first_aid_cd | Devi aspettare ancora un po' prima di poter medicare |
| kick_fail | Non riesci ad avvicinarti abbastanza per calciare |
| backstab_fail | Non riesci ad avvicinarti abbastanza |

**Totale trigger generati all’install:** ~85.

---

## Tasti keypad (Keys XML)

| Nome interno | Tasto | Comando |
|--------------|-------|---------|
| `nebbie-keypad look num` | 5 (Num Lock ON) | look |
| `nebbie-keypad look nav` | Clear (Num Lock OFF) | look |
| `nebbie-keypad north num` | 8 | north |
| `nebbie-keypad north nav` | Freccia su | north |
| `nebbie-keypad south num` | 2 | south |
| `nebbie-keypad south nav` | Freccia giù | south |
| `nebbie-keypad east num` | 6 | east |
| `nebbie-keypad east nav` | Freccia destra | east |
| `nebbie-keypad west num` | 4 | west |
| `nebbie-keypad west nav` | Freccia sinistra | west |
| `nebbie-keypad up num` | 9 | up |
| `nebbie-keypad up nav` | PagSu | up |
| `nebbie-keypad down num` | 3 | down |
| `nebbie-keypad down nav` | PagGiù | down |

---

## File correlati nel repository

| File | Contenuto |
|------|-----------|
| [`HELP.md`](HELP.md) | Guida installazione e troubleshooting |
| [`nebbie-spells-reference.txt`](nebbie-spells-reference.txt) | Elenco spell/skill dal sorgente C++ |
| [`nebbie-alias-index.txt`](nebbie-alias-index.txt) | Indice alias (testo puro, generato) |
| [`nebbie-trigger-index.txt`](nebbie-trigger-index.txt) | Indice trigger (testo puro, generato) |
| `nebbie-installer-core.lua` | Logica HUD, loot, install (sviluppatori) |
| `build-nebbie-package.py` | Rigenera `.mpackage` e indici |

**Download package:**  
https://raw.githubusercontent.com/wizardmorgan/nebbietest/mudlet/docs/mudlet/nebbie-play-all.mpackage

---

## Note per sviluppatori

Il package viene **rigenerato** dal sorgente del MUD (`spell_parser.cpp`, `interpreter.cpp`, `constants.cpp`). Le abbreviazioni e i messaggi buff restano allineati al server quando si esegue:

```bash
python3 docs/mudlet/build-nebbie-package.py
```

Non installare contemporaneamente `nebbie-spells-skills` e `nebbie-play-all`: condividono la tabella globale `Nebbie` e possono entrare in conflitto.
