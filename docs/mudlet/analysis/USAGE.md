# USAGE — nebbie-complete-dashboard-package

Guida rapida ai comandi (alias) del package, scritta dopo il primo test reale dell'utente
(segnalazione barre laterali grigie + richiesta istruzioni alias, 2026-08-08).

## Come installare/aggiornare

Il file `.mpackage` aggiornato sta sul branch **`mudlet`** (non su `develop`):
`docs/mudlet/nebbie-complete-dashboard-package.mpackage` nel repo GitHub.

1. In Mudlet: `Package Manager` (icona valigetta, o `Giocatore → Gestione pacchetti`).
2. Se `nebbie-complete-dashboard-package` è già installato, **disinstallalo** (bottone `-`).
3. **Chiudi completamente Mudlet** e riaprilo (solo “riconnessione” non basta: altrimenti resta
   in memoria la vecchia versione, es. v1.14.1, anche dopo un install).
4. Installa (bottone `+`) il `.mpackage` scaricato dal branch **`mudlet`**.
5. In output deve comparire **`[NebbieDash] v1.15.2 pronto`** (numero allineato al CHANGELOG).
   Se vedi ancora **1.14.x**, hai installato un file vecchio o non hai riavviato Mudlet: ripeti
   disinstall → **quit Mudlet** → reinstall. Poi `nresync` dopo il login.

## Icona e descrizione nella "Gestione pacchetti"

Dalla 1.3.0 il pacchetto include un'icona e una descrizione interna, visibili aprendo
`Giocatore → Gestione pacchetti` in Mudlet e selezionando `nebbie-complete-dashboard-package`
nell'elenco degli installati (prima mancavano entrambe). La descrizione riassume la versione
corrente e va aggiornata ad ogni release (promemoria lasciato direttamente nel codice sorgente,
`build-nebbie-complete-dashboard-package.py`).

## Alias disponibili

Nessun alias invia comandi al MUD in automatico all'avvio (scelta deliberata, vedi
`RECOMMENDATION.md` §3): tutti vanno digitati a mano quando servono.

| Alias | Cosa fa |
|---|---|
| `nresync` | Invia `eq` al MUD, aspetta 1.5s, poi invia `attrib`. Aggiorna la cache equip+spell del personaggio corrente e ridisegna il pannello. **Usalo dopo ogni login/riconnessione.** |
| `neq` | Invia solo `eq` e aggiorna il pannello equip. |
| `nattrib` | Invia solo `attrib` e aggiorna il pannello spell. |
| `nchar <nome>` | Forza manualmente il personaggio attivo (es. `nchar NomiyaMaki`), utile se il rilevamento automatico dal prompt non è ancora scattato (nessun comando ancora digitato in gioco). |
| `ngui` | Mostra/nasconde il pannello laterale (bordo destro). |
| `nlayout` | Ripristina larghezza (320px) e font (11pt) di default del pannello. |
| `nfont <numero>` | Cambia la dimensione del testo nel pannello (6–24, default 11). |
| `nwidth <equip\|right> <numero>` | Fissa una larghezza manuale (150–900px) per la colonna equip (sinistra) o spell/speedwalk (destra), **disattivando** l'adattamento automatico per quella colonna. Senza indicare `equip`/`right` agisce sulla destra (retrocompatibilità). |
| `nwidth <equip\|right> auto` | Riattiva la larghezza automatica per quella colonna (default per entrambe): si allarga/restringe da sola in base al contenuto più lungo visibile, senza mai superare il 60% della finestra di Mudlet. |
| `nheights <percentuale>` | Regola quanta altezza della colonna destra va a "Spell attivi" (10–90, il resto va a "Speedwalk"; default 40). |
| `nleftheights <percentuale>` | Regola quanta altezza della colonna sinistra va a "Equip" (10–90, il resto va a "Armi"; default 60). |
| `nclanslot <on\|off>` | Mostra/nasconde il 22° slot equip placeholder "simbolo del clan" (nascosto di default, non ancora confermato in un `eq` reale). |
| `nitemlen <numero>` | Cambia quanti caratteri della descrizione oggetto mostrare prima di troncare con "…" (10–300, default 42). Alzalo se preferisci vedere più testo (andrà più facilmente a capo), abbassalo per evitare il più possibile il word-wrap. |
| `nfix` | Reinstalla trigger e GUI senza disinstallare il package (utile se qualcosa sembra "bloccato"). |
| `c <spell> [bersaglio]` | Invia `cast '<spell>' <bersaglio>` — **sempre con bersaglio** (default: PG attivo). Es. `c heal` → `cast 'heal' NomiyaMaki`; `c heal bob` → `cast 'heal' bob`. |
| `r <spell> [bersaglio]` | Come sopra con `recall` (sorcerer). |
| `m <spell> [bersaglio]` | Come sopra con `mind` (psionico). |
| `nclass <c\|r\|m>` | Imposta **per sempre** per il personaggio attivo quale comando usano pannello e shortcut (`cast`/`recall`/`mind`). Una volta per PG (es. mago → `nclass c`). |
| `nspellaliases` | Elenco shortcut globali + spell nel pannello + `nclass` del PG attivo. |
| `nspellaliasesreload` | Ricarica `nebbie-spell-shortcuts.txt` e `nebbie-cast-spells.txt` dopo modifiche manuali. |
| `nspellwarn <n>` | Sotto quanti tick residui una spell attiva nel pannello viene mostrata in rosso invece che verde (default 5). |
| `nforgetspell <nome>` | Toglie una riga dall'elenco pannello in memoria (e da vecchi dati `knownSpellOrder` se presente); aggiorna anche `nebbie-cast-spells.txt` a mano per renderlo permanente. |
| `nspeedwalks` | Ricarica gli speedwalk dal file di configurazione dopo averlo modificato (vedi sotto), senza riavviare Mudlet. |
| `nspeeddelay <secondi>` | Pausa tra un movimento e il successivo quando esegui uno speedwalk (default 0.35s). |
| `nhelp` | Mostra/nasconde la finestra con l'elenco di tutti questi comandi (stessa finestra del tasto "? Comandi", vedi sotto). |
| `nloot` | Prende le monete dal cadavere presente (prova sia `get all.coin corp` che `get all.coin pile`, per cadaveri normali e "pile of bones"). Normalmente non serve digitarlo: scatta da solo, vedi sotto. |
| `nautoloot <on\|off>` | Attiva/disattiva il loot automatico alla fine di ogni combattimento a cui partecipi (default **on**). |
| `nautosplit <on\|off>` | Attiva/disattiva lo split automatico col gruppo dopo ogni loot riuscito (default **on**). |
| `nsplit <numero>` | Divide manualmente un importo col gruppo (equivalente a digitare `split <numero>`), utile per casi non coperti da `nloot`. |
| `nautostand <on\|off>` | Attiva/disattiva il rialzarsi automatico (`stand`) dopo una caduta (default **on**). |
| `nautodisarm <on\|off>` | Attiva/disattiva il recupero automatico dell'arma dopo un disarmo (default **on**). |
| `.<numero><comando>` | Ripete il comando N volte, es. `.4s` invia `s` quattro volte (funziona con qualsiasi comando: `.3 kill goblin` invia `kill goblin` tre volte). |
| `nautofeed <on\|off>` | Attiva/disattiva la macro automatica fame/sete (default **on**), vedi sotto. |
| `nhungermacros` | Ricarica le macro fame/sete dal file di configurazione dopo averlo modificato (vedi sotto), senza riavviare Mudlet. |
| `nitemkeywords` | Ricarica le parole chiave per oggetto (condivise tra tutti i personaggi) dal file di configurazione dopo averlo modificato (vedi sotto), senza riavviare Mudlet. |

## Pannello Armi (sotto l'Equip, colonna sinistra)

Elenco persistente per personaggio di tutte le armi che hai impugnato almeno una volta, con il tipo
di danno (slash/blunt/pierce) quando noto. Si popola da solo:

1. Impugni un'arma (`wield <qualcosa>`) → l'arma compare nell'elenco con tipo "?" (ancora sconosciuto).
2. Esegui tu, quando vuoi, `identify` su quell'arma → il pacchetto legge l'output e aggiorna il tipo
   di danno mostrato (slash/blunt/pierce). **`identify` non viene mai inviato in automatico** dal
   pacchetto: è un comando/spell che costa una "ondata di stanchezza", quindi resta sempre una tua
   scelta quando eseguirlo.

Clicca il nome di un'arma in elenco per **cambiare arma con un solo click**: il pacchetto invia da
solo, in sequenza, `rem`+`put` dell'arma che stai impugnando adesso (letta dal pannello Equip, slot
"impugnato") nello zaino, poi `get`+`wield` dell'arma che hai scelto — usando lo stesso zaino (slot
"sulla schiena") e lo stesso criterio di parole chiave (override da `nebbie-item-keywords.txt` se
presente, altrimenti euristica automatica) già usato per il recupero arma dopo un disarmo e per le
macro fame/sete. Se non stai impugnando nulla, salta direttamente a `get`+`wield`. Se clicchi l'arma
che hai già impugnata, non invia nulla.

L'altezza di questo pannello rispetto all'Equip si regola con `nleftheights` (vedi tabella sopra).

## Loot e split automatico

Alla fine di ogni combattimento a cui partecipi (riconosciuto da due messaggi reali del gioco: "La
tua parte di esperienza è di N punti." per la quota di gruppo, oppure "La tua esperienza è aumentata
di N punti." per un'uccisione in solitaria — anche con N=0), se `nautoloot` è attivo (default sì) il
pacchetto prende da solo le monete dal cadavere presente. Appena il gioco conferma il bottino
(`C'erano N monete.`), se `nautosplit` è attivo (default sì) e sei in gruppo, invia da solo `split N`
con l'importo appena raccolto — verificando prima che tu sia in gruppo leggendo l'output del comando
`group`. Se non sei in gruppo, il bottino resta semplicemente tuo, senza inviare nulla. Se più loot
scattano quasi contemporaneamente (es. un incantesimo ad area che uccide più mostri in un colpo), gli
importi si accumulano in un unico controllo gruppo/split invece di avviarne più di uno in
sovrapposizione (evita split inviati/non inviati in base al controllo sbagliato).

I due automatismi sono indipendenti: puoi disattivare solo il loot (`nautoloot off`, es. se preferisci
farlo tu a mano con `nloot` quando vuoi) o solo lo split (`nautosplit off`, usando poi `nsplit
<numero>` quando ti serve), oppure entrambi.

## Rialzarsi e recupero arma automatici

Se cadi a terra (riconosciuto dal messaggio del gioco `Inciampi e cadi per terra.`), il pacchetto
invia da solo `stand` — disattivabile con `nautostand off`. **Nota**: questo è solo uno dei possibili
messaggi di caduta; se ne trovi altri, segnalali così vengono aggiunti.

Se vieni disarmato (`Ti disarmano e ... vola dalla tua presa.`), il pacchetto legge il nome dell'arma
direttamente da quel messaggio, lo ripulisce da articoli/preposizioni italiane per ottenere le parole
chiave con cui il gioco identifica l'oggetto (es. "la Flamberga di Boris" → "flamberga boris") e invia
da solo `get <parole chiave>` seguito da `wield <parole chiave>` — disattivabile con `nautodisarm
off`.

## Ripetizione comandi

Scrivi `.` seguito da un numero e un comando per ripeterlo quella quantità di volte, con la stessa
pausa tra un invio e l'altro già usata per gli speedwalk (`nspeeddelay`). Esempi: `.4s` invia `s`
quattro volte; `.3 kill goblin` invia `kill goblin` tre volte. Limite di sicurezza: 99 ripetizioni.

## Batch admin (`nbatch`) — solo Sirio connesso

Utility di amministrazione (non gameplay): esegue in sequenza comandi definiti da te, su righe
lette da un CSV. **Pensato per il profilo Mudlet di Sirio** (admin immortale). Ogni sequenza
inizia automaticamente con **`nchar Sirio`** (comando Mudlet locale, non inviato al MUD) per
impostare il personaggio attivo nel pacchetto.

Due file nella home del profilo Mudlet (`getMudletHomeDir()`):

| File | Contenuto |
|------|-----------|
| `nebbie-batch-commands.txt` | Un comando per riga; placeholder `$1`..`$4` |
| `nebbie-batch-items.csv` | Righe oggetto (CSV con intestazione) |

**CSV — colonne** (prima riga obbligatoria):

```
nome-toon,key,vnum-attuale,vnum-originale
GreenBlade,equilibrio EDGreenBlade,34424,9030
GreenBlade,egida foresta EDGreenBlade,34512,15809
```

- `$1` = `nome-toon` (es. `GreenBlade`) — anche nome file log
- `$2` = `key` normalizzata: **minuscolo**, spazi → **trattini** (es. `egida-foresta-edgreenblade`)
- `$3` = `vnum-attuale`, `$4` = `vnum-originale`

**Comandi Mudlet**:

| Comando | Azione |
|---------|--------|
| `nbatch` | Esegue tutte le righe CSV |
| `nbatch greenblade` | Solo righe il cui `nome-toon` matcha (case-insensitive) |
| `nbatchreload` | Ricarica entrambi i file |
| `nidentbatch` | Identify batch: stesso CSV input, output unico CSV risultati |
| `nidentbatch greenblade` | Solo righe del toon indicato |
| `nidentbatchreload` | Ricarica `nebbie-ident-batch-commands.txt` e CSV input |

### Identify batch (`nidentbatch`) — solo Sirio connesso

Stesso **CSV input** di `nbatch` (`nebbie-batch-items.csv`, colonne `$1`..`$4`).
Comandi in un file separato:

| File | Contenuto |
|------|-----------|
| `nebbie-ident-batch-commands.txt` | Sequenza identify (default: oload $3, poi **$o**) |

| Comando | Azione |
|---------|--------|
| `nidentbatch` | Tutte le righe CSV → un file risultati |
| `nidentbatch greenblade` | Solo quel toon |
| `nidentbatch resume` | Riprende saltando righe già nel CSV di oggi (append) |
| `nidentbatch resume greenblade` | Resume solo per quel toon |
| `nidentbatchreload` | Ricarica comandi identify + CSV |

**Scopo tipico**: aggiornare i campi **name** nel CSV/server. Sequenza:

1. `oload $3` — carica l'oggetto in inventario Sirio
2. **`cast 'identify' $ed`** / **`junk $ed`** — keyword **`ED` + nome-toon** (colonna `$1`)
   (es. `Montero` → `EDMontero`, `Shelin` → `EDShelin`). Anche **`$o`** = stesso valore.
   **Non** usare `$2` (colonna key spesso vuota). **Non** usare `stat`: cerca nel mondo, non
   l'oggetto oloadato.
3. Il **CSV output** prende il **nome completo** da identify (es. `verse13 move lips EDEchoes`)

La colonna `key` del CSV può restare vuota; per stat/identify/junk conta solo **`ED`+toon**.

**Output**: un solo file per giorno, es. `nebbie-ident-results-2026-09-22.csv`
nella home del profilo. **Una riga per oggetto**, formato (10 colonne):

```
object-name,type,extra-flags,vnum-attuale,vnum-originario,affect-1,affect-2,affect-3,affect-4,affect-5
eterea armatura Fouler EDFouler,ARMOR,GLOW MAGIC ... EDIT PERSONAL,34595,6618,RESISTANCE by SLASH,WIS by 2,SPELLFAIL by -15,SAVING_ALL by -1,MANA-REGEN by 50
```

Colonne **`affect-1` … `affect-5`**: testo dopo **`Ti puo' dare :`** in identify (max 5;
se l'oggetto ne ha meno, le colonne restanti sono vuote).

Il quinto campo base è il **`V-Number Originario`** dall'output di `identify` (es. `V-Number Originario: 8304` → `8304`).
Più batch nello stesso giorno **appendono** righe allo stesso file. **Nessun** log testuale
per-toon (`<Toon>-YYYY-MM-DD.txt`) per `nidentbatch` — solo il CSV (i log per-toon restano per `nbatch`).

**Ripresa dopo errore**: se il batch si ferma (es. `Non hai con te niente del genere` su
`cast 'identify'`), le righe già identifyate restano nel CSV. Correggi il problema (oggetto
mancante, typo ED+toon, ecc.) e lancia **`nidentbatch resume`** — salta i `vnum-attuale` già
presenti nel CSV di oggi e continua con le righe rimanenti in append. Opzionale filtro toon:
`nidentbatch resume astaroth`.

**Timing oload**: se compaiono sysmess o lag tra `oload` e `Adesso hai ...`, il batch attende
entrambi (messaggio + prompt) prima di proseguire — non si ferma più al prompt intermedio.

**Autosplit**: dopo `C'erano N monete.` (o `C'era una miserabile moneta.`) il pacchetto invia
`group` e, se sei in gruppo, `split N`. Funziona anche con risposta **`Your group consists of:`**
(senza nome gruppo) e con codici colore Nebbie (`$c0015...`).

Sequenza comandi di default (`nebbie-ident-batch-commands.txt`):

```
nchar Sirio
oload $3
cast 'identify' $ed
junk $ed
```

### Verifica log (`nbatchverify`)

Dopo aver eseguito `nbatch`, controlla che ogni riga CSV abbia prodotto tutti i comandi
attesi e (se previsto) il messaggio `Ho salvato ... con il vnum ... (originale ...)`.

| Comando | Azione |
|---------|--------|
| `nbatchverify` | Verifica tutti i toon nel CSV (log di oggi) |
| `nbatchverify GreenBlade` | Solo quel toon, log di oggi |
| `nbatchverify GreenBlade 2026-09-21` | Toon + data esplicita |

Scrive un report in `<Toon>-YYYY-MM-DD.verify.txt` nella home del profilo.

**Verifica offline** (copia log + CSV dal profilo Mudlet sul PC):

```bash
python3 docs/mudlet/tests/verify_batch_log.py \
  --csv nebbie-batch-items.csv \
  --commands nebbie-batch-commands.txt \
  --log GreenBlade-2026-09-21.txt
```

Opzionale, se hai anche i file oggetto salvati dal server (`objects/<vnum>`):

```bash
python3 docs/mudlet/tests/verify_batch_log.py ... \
  --objects-dir /path/to/mudroot/lib/objects
```

**Comportamento**: ogni riga CSV inizia con `nchar Sirio` (se non già presente nel file
comandi). Tra un comando MUD e l'altro attende il **prompt** del gioco (o, dopo `oedit`,
la riga menu `-->`); cattura **tutto** l'output a schermo e lo appende al log. Se compare un
messaggio di errore MUD noto, **ferma** l'intero batch.

**Flag EDIT (`oedit`)**: per marcare un oggetto come modificabile puoi inserire nel file comandi
`oedit $2` (dopo `oload $3` o dove preferisci). Il batch attende la riga `-->` del menu
interattivo, poi invia la riga speciale **`[enter]`** (invio vuoto) per uscire dal menu prima
del comando successivo.

**Log**: un file per ogni `nome-toon` e giorno, es. `GreenBlade-2026-09-21.txt` nella home del
profilo. Più batch nello stesso giorno → nuova sezione con data/ora. Ogni riga CSV e ogni comando
inviato sono tracciati con timestamp.

Esempio sequenza comandi (file `nebbie-batch-commands.txt`, workflow osave):

```
nchar Sirio
oload $3
stat $2
oedit $2
[enter]
cast 'identify' $2
osave $2 $3 $4
stat $2
cast 'identify' $2
```

Comandi **locali Mudlet** (non inviati al MUD): `nchar Sirio`, `[enter]` (invio vuoto).

Sequenza identify (`nebbie-ident-batch-commands.txt`) — `nchar Sirio`, poi **`$o`** dopo oload:

```
nchar Sirio
oload $3
cast 'identify' $ed
junk $ed
```

## Fame/sete: macro configurabile per personaggio

Quando il gioco mostra `Hai Fame.` o `Hai sete.`, se `nautofeed` è attivo (default sì) il pacchetto
esegue la sequenza di comandi che **tu** scrivi in un file di testo, una riga per personaggio:

```
getMudletHomeDir()/nebbie-hunger-macros.txt
```

(stessa cartella del profilo usata per `nebbie-speedwalks.txt`, tipicamente qualcosa come
`~/.config/mudlet/profiles/<NomeProfilo>/nebbie-hunger-macros.txt` su macOS/Linux). Se il file non
esiste, viene creato automaticamente al primo avvio con la spiegazione del formato e un esempio
commentato.

**Formato di ogni riga**:

```
NomePersonaggio: comando1, comando2, ...
```

**Segnaposto `{zaino}`**: viene sostituito automaticamente con **una singola parola chiave**
(l'ultima parola significativa del nome dell'oggetto, tipicamente il nome proprio, es. "Korred" da
"Borsa Inesauribile dei Korred") dell'oggetto che il personaggio ha equipaggiato nello slot `<sulla
schiena>` (letta dal pannello equip già sincronizzato — non serve conoscerla in anticipo né
aggiornarla se cambi zaino, basta che l'equip sia aggiornato con `neq`/`nresync`). Se non hai nulla
in quello slot, `{zaino}` viene sostituito con una stringa vuota. **Nota**: si usa solo l'ultima
parola (non tutta la descrizione) perché passare più parole a comandi come `wear` può confondere il
parser del gioco, che rischia di interpretare parole aggiuntive come una posizione del corpo invece
che come parte del nome dell'oggetto.

**Protezione da doppio scatto**: il gioco spesso manda insieme sia `Hai Fame.` che `Hai sete.`; per
evitare che la macro parta due volte in parallelo (con le due sequenze di comandi che si
accavallano), c'è un "cooldown" di 3 secondi tra un'esecuzione e la successiva.

**Ripetizione**: dentro la macro puoi usare la stessa sintassi `.N comando` della ripetizione
generica per un singolo passo, es. `.5 drink cornu` invia `drink cornu` cinque volte in quel punto
della sequenza.

Esempio reale (fornito dall'utente, per un personaggio con `[18] <sulla schiena> Borsa
Inesauribile dei Korred`):

```
Mirari: rem {zaino}, get cornucopia {zaino}, .5 drink cornu, put cornu {zaino}, wear {zaino}
```

che equivale a: togliersi lo zaino, tirarne fuori la cornucopia, berne cinque volte, rimetterla
dentro e rimettersi lo zaino. **Nota**: solo la parola chiave dello zaino (`{zaino}`) viene derivata
automaticamente — il resto della sequenza (es. il nome dell'oggetto da bere dentro lo zaino, che
varia da personaggio a personaggio) va scritto a mano, perché non è ricavabile da nessun dato che il
pacchetto legge automaticamente dal gioco.

Se non c'è nessuna riga per il personaggio attivo, il pacchetto mostra solo un avviso (nessun errore,
nessun comando inviato) che ti ricorda di configurarla. Dopo aver modificato il file, digita
`nhungermacros` in gioco per ricaricarlo senza riavviare Mudlet.

## Parole chiave per oggetto, condivise tra tutti i personaggi

L'estrazione automatica delle parole chiave di un oggetto (usata per il recupero arma dopo un
disarmo e per il segnaposto `{zaino}` delle macro fame/sete) è solo un'euristica — rimuove articoli
e preposizioni italiane dal nome, ma non sempre il risultato è la parola giusta per il gioco (es.
"Non puoi indossare nulla su un inesauribile." se il gioco interpreta male una parola aggiuntiva). Se
un dato oggetto non funziona bene con l'euristica, o se preferisci semplicemente scrivere tu la
parola giusta una volta per tutte, puoi farlo in:

```
getMudletHomeDir()/nebbie-item-keywords.txt
```

(stessa cartella profilo delle altre configurazioni). Formato, una riga per oggetto:

```
Nome esatto dell'oggetto (come mostrato in eq): parola chiave da usare
```

Esempio:

```
Borsa Inesauribile dei Korred: korred
la Flamberga di Boris: flamberga boris
```

**Vale per tutti i personaggi**: un dato oggetto ha sempre le stesse parole chiave in game, quindi
non serve ripetere la riga per ogni personaggio che possiede quell'oggetto — a differenza del file
delle macro fame/sete (`nebbie-hunger-macros.txt`), che resta invece per personaggio perché la
sequenza di comandi può variare. Se un oggetto non ha una riga qui, si continua a usare l'estrazione
automatica come prima. Dopo aver modificato il file, digita `nitemkeywords` in gioco per ricaricarlo
senza riavviare Mudlet.

## Tasto "? Comandi"

In cima allo schermo, centrato tra i due pannelli laterali, compare sempre un piccolo tasto **"?
Comandi"** (indipendente da `ngui`: resta visibile anche a pannelli nascosti). Cliccandolo si apre
una finestra con l'elenco di tutti i comandi disponibili e una breve descrizione; ricliccando il
tasto (o il link "[chiudi]" dentro la finestra) la si richiude. È l'equivalente pratico di un tasto
personalizzato nell'interfaccia di Mudlet: non è tecnicamente una voce di toolbar nativa (Mudlet non
permette di crearne una in modo affidabile da script, solo dall'editor pacchetti), ma si comporta
allo stesso modo — sempre presente, cliccabile, non serve ricordare un comando.

Il rilevamento del personaggio è **automatico**: appena il prompt del gioco viene ricevuto (dopo
che scrivi un qualsiasi comando), il nome del personaggio attivo viene letto dal prompt stesso
(vedi `DESIGN-OPTIONS.md` D1) e il pannello si aggiorna da solo per quel personaggio. `nchar` serve
solo come override manuale.

## Bug corretto: serviva riavviare Mudlet dopo ogni aggiornamento del pacchetto

**Sintomo segnalato**: dopo aver (re)installato una versione aggiornata del pacchetto senza
riavviare Mudlet, le funzionalità nuove/modificate non si attivavano — serviva sempre un riavvio
completo di Mudlet.

**Causa reale**: la parte del pacchetto che crea i trigger dinamici (`installTriggers()`) aveva un
controllo "una volta per sempre a sessione" che, dopo il primissimo avvio della sessione Lua di
Mudlet, impediva a quella funzione di fare qualsiasi cosa per il resto della sessione — anche se nel
frattempo si reinstallava una versione più recente del pacchetto con trigger nuovi o modificati.
Il codice si aggiornava correttamente (le funzioni vengono ridefinite ad ogni installazione), ma i
trigger che li richiamano restavano quelli vecchi, con eventuali trigger nuovi mai creati affatto.

**Fix**: `installTriggers()` ora è idempotente — ad ogni chiamata smonta prima i trigger dinamici
creati in precedenza e li ricrea da zero — ed è invocata sia dallo script che gira ad ogni
(re)installazione del pacchetto sia da quello legato al normale avvio del profilo, quindi ora una
semplice reinstallazione a caldo del pacchetto è sufficiente per attivare tutte le novità, senza
riavviare Mudlet.

## Bug corretto: pannelli grigi alla prima installazione

**Sintomo segnalato**: dopo l'installazione, le due miniconsole sul bordo destro (equip/spell)
apparivano completamente grigie, senza testo, anche subito dopo l'installazione.

**Causa reale (non il vecchio package `nebbie-play-all`)**: `initGUI()` creava le miniconsole con
`createMiniConsole(...)` ma non assegnava mai loro uno sfondo esplicito né ci scriveva dentro nulla
subito dopo la creazione. Una miniconsole Mudlet appena creata resta con il colore di sfondo di
default del widget Qt (grigio) finché non si chiama `setBackgroundColor(...)` e non si scrive
qualcosa con `cecho`/`clearWindow`. Il primo aggiornamento reale del pannello avveniva solo dopo
`nresync`/rilevamento del prompt, quindi tra l'installazione e il primo comando digitato in gioco
il pannello restava grigio.

**Fix applicato** (`nebbie-complete-dashboard-package-core.lua`, funzione `initGUI`):
- aggiunto `setBackgroundColor("NebbieDashEquip"/"NebbieDashSpells", 15, 15, 15, 255)` subito dopo
  la creazione delle miniconsole;
- aggiunta chiamata a `NebbieDash.refreshDashboard()` alla fine di `initGUI()` (quindi anche dentro
  `boot()`), così il pannello mostra subito il testo placeholder
  (`Nessun personaggio rilevato.` / `(vuoto — esegui neq o nresync)`) invece di restare vuoto.

Il `.mpackage` è stato rigenerato con il fix: `docs/mudlet/nebbie-complete-dashboard-package.mpackage`.

**Se dopo aver reinstallato il pacchetto aggiornato il grigio persiste**, è plausibile un residuo
del vecchio package. Verifica (in ordine):
1. `Package Manager`: assicurati che `nebbie-play-all` (o nomi simili) non sia più nell'elenco.
2. `Editor` (Ctrl+E) → cerca script/alias/trigger con prefisso `Nebbie` diverso da `NebbieDash*`:
   se presenti, sono residui del vecchio package da eliminare a mano.
3. Chiudi completamente Mudlet (non solo disconnetti) e riapri il profilo: i widget creati via Lua
   (`createMiniConsole`, `createLabel`) non sono "salvati" nel profilo, vengono ricreati a ogni
   boot dello script che li possiede — se il vecchio script non gira più, i suoi widget non
   dovrebbero ricomparire dopo un riavvio completo.

## Bug corretto: "una sola barra", pannello non si ridimensiona, font piccolo, slot vuoti nascosti

**Sintomi segnalati** (dopo il fix del bug precedente): a schermo si vedeva una sola barra a
destra invece di due (equip sopra, spell sotto); ridimensionando la finestra di Mudlet il pannello
non si aggiornava; il testo era troppo piccolo; gli slot equip vuoti non comparivano affatto (si
vedevano solo quelli occupati, senza modo di capire cosa mancava da equipaggiare).

**Cause reali, tutte nello stesso file**:
- `positionGUI()` veniva chiamata solo alla creazione iniziale della GUI: non esisteva nessun
  handler per l'evento `sysWindowResizeEvent`, quindi ridimensionare la finestra di Mudlet non
  aveva alcun effetto sul layout del pannello.
- Allo stesso avvio, `getMainWindowSize()` può restituire una dimensione non ancora corretta
  (geometria Qt non assestata nell'istante esatto in cui la GUI viene creata): se questo capitava,
  il calcolo `equipH = h * 0.6` produceva un'altezza sbagliata (es. vicina a 0) per la miniconsole
  equip, che risultava quindi invisibile — dando l'impressione di "una sola barra".
- Il font era fissato a 9pt via codice, senza modo di cambiarlo.
- `refreshDashboard()` stampava solo gli slot equip occupati (`if item then ... end`), saltando
  del tutto quelli vuoti.

**Fix applicati** (`nebbie-complete-dashboard-package-core.lua`):
- aggiunto handler `sysWindowResizeEvent` → `NebbieDash.onWindowResize` → richiama
  `positionGUI()` (con `tempTimer(0, ...)` per dare tempo a Qt di aggiornare la geometria) a ogni
  ridimensionamento della finestra o dei bordi;
- aggiunto un secondo richiamo a `positionGUI()` via `tempTimer(0, ...)` subito dopo la creazione
  iniziale della GUI, per correggere l'eventuale altezza sbagliata calcolata all'avvio;
- font di default alzato da 9 a 11pt, e larghezza pannello di default da 260 a 320px, con due nuovi
  comandi (`nfont`, `nwidth`) per regolarli a piacere;
- il pannello equip ora elenca sempre tutti i 21 slot, marcando `(vuoto)` quelli non occupati,
  invece di ometterli.

`.mpackage` rigenerato con questi fix. Va reinstallato allo stesso modo descritto sopra (rimuovi
la versione precedente, riavvia Mudlet, installa il nuovo file, riconnetti).

## Bug corretto: slot equip nell'ordine sbagliato / etichetta sbagliata (es. "guanti ai piedi")

**Sintomo segnalato**: dopo il fix precedente, lo slot "ai piedi" risultava mancante e lo slot
"davanti agli occhi" risultava vuoto, con un oggetto (i guanti) mostrato sotto l'etichetta "ai
piedi" invece che sotto la sua etichetta reale.

**Causa reale**: la primissima versione del package leggeva SOLO il numero di slot e la
descrizione dell'oggetto da ogni riga di `eq` (es. `[ 8] <ai piedi> Gli stivali...`), scartando il
testo tra `< >` (la posizione reale) e sostituendolo con un'etichetta presa da una tabella statica
indicizzata per numero (`EQ_SLOTS[8] = "ai piedi"`), costruita sull'unico esempio di `eq` visto
finora (dove per coincidenza l'ordine corrispondeva). Il numero di slot da solo **non è un
identificatore affidabile della posizione sul corpo** — può variare, quindi affidarsi a una
tabella statica per numero produce etichette sbagliate non appena l'ordine reale differisce anche
di poco da quell'unico esempio.

**Fix applicato**: la posizione ora viene letta sempre dal testo tra `< >` della riga stessa (mai
da una tabella statica), quindi l'etichetta mostrata è sempre quella reale riportata dal gioco per
quello specifico slot, indipendentemente dal numero. Aggiunto anche un test automatico
("eq anomalo") che verifica esplicitamente questo comportamento con un ordine di slot volutamente
diverso da quello del primo esempio.

**Aggiornamento 1.3.0 — slot vuoti di nuovo visibili, ma senza reintrodurre il bug**: su richiesta
esplicita, il pannello equip mostra di nuovo tutte le 21 posizioni note, marcando "(vuoto)" quelle
non occupate. Questa volta però il confronto è sul **testo della posizione** letto dalla riga `eq`
(es. "ai piedi"), non sul numero di slot del gioco: l'elenco delle 21 posizioni note
(`NebbieDash.EQ_SLOT_ORDER` nel codice) serve solo a sapere QUALI posizioni esistono e in che ordine
mostrarle, mai a decidere quale oggetto va in quale slot per numero — quindi il bug delle etichette
sbagliate (fix 1.0.0/fix 3) non può ripresentarsi. Se il gioco riporta un giorno una posizione non
presente in questo elenco, viene comunque mostrata (non scompare mai un oggetto reale). Un 22° slot
"simbolo del clan" è predisposto ma nascosto di default (`nclanslot on` per attivarlo) perché non
ancora confermato in un `eq` reale.

**Aggiornamento 1.3.3 — numero di riga tra parentesi quadre**: ogni riga del pannello equip mostra
di nuovo un numero tra parentesi quadre (es. `[ 1] <sul dito destro> ...`), per somigliare
visivamente al testo di `eq` sul gioco. Da non confondere con il numero di slot del gioco: è solo la
posizione della riga nel nostro elenco (`EQ_SLOT_ORDER`), sempre nello stesso ordine ad ogni
aggiornamento — non viene mai usato per abbinare un oggetto a una posizione (quello resta il testo
tra `< >`, vedi fix sopra), quindi il bug delle etichette scambiate non può ripresentarsi.

## Bug corretto: descrizioni oggetto troppo lunghe vanno sempre a capo

**Fix applicato**: le descrizioni oggetto nel pannello equip vengono ora troncate a 42 caratteri
(con "…" finale) prima di essere mostrate, per ridurre il word-wrap su un pannello stretto. Il
testo completo resta comunque disponibile digitando `eq` normalmente. Regolabile con `nitemlen`
(vedi tabella comandi sopra); allargare il pannello con `nwidth` riduce ulteriormente il word-wrap
residuo.

## Motore di lancio spell/skill (`c`/`r`/`m`) — 1.15.0

Tre alias Mudlet: `c`, `r`, `m` + argomento. Inviano sempre **`cast`/`recall`/`mind` + apici + bersaglio
esplicito** (il gioco fa l'abbreviazione del nome spell tra apici, vedi `src/spell_parser.cpp`).

| Digitato (PG attivo NomiyaMaki) | Comando al MUD |
|---|---|
| `c heal` | `cast 'heal' NomiyaMaki` |
| `c heal bob` | `cast 'heal' bob` |
| `c word of r` | `cast 'word of r' NomiyaMaki` |
| `r word of recall` | `recall 'word of recall' NomiyaMaki` (se `nclass r`) |

**Regole sintassi `c`/`r`/`m`**:

- **Una parola** o **tre o più parole** (senza bersaglio separato): tutto è il nome spell, bersaglio = PG attivo.
- **Esattamente due parole**: prima = spell, seconda = bersaglio (`c heal bob`).
- **Spell multi-parola su altri**: definisci uno **shortcut** (sotto) e usa `wor bob`, oppure due token se la spell è una sola parola.

Non usiamo più virgola né stacco automatico dell'ultima parola sul nome del tuo PG. Senza PG attivo
(dopo riconnessione, prima del prompt) **non viene inviato nulla** — attendi il prompt o `nchar`.

**`nclass c|r|m`**: salvato **per personaggio** in persistenza (`castPrefix`). Vale per click sul
pannello e per shortcut globali (non per `c`/`r`/`m` digitati a mano, che fissano il prefisso).

Riferimento nomi spell/skill lato server: `MUD-SPELL-SKILL-LIST.md`.

## Shortcut globali (`nebbie-spell-shortcuts.txt`)

File nel profilo Mudlet (creato al primo avvio con esempi `he = heal`, `ts = true sight`):

```
getMudletHomeDir()/nebbie-spell-shortcuts.txt
```

Formato: `shortcut = nome spell` (o `shortcut nome spell`). Sono **globali al profilo**; il
comando cast/recall/mind lo decide `nclass` del PG attivo. Esempi:

- `he` → `cast 'heal' NomiyaMaki`
- `he bob` → `cast 'heal' bob`

Dopo modifiche: `nspellaliasesreload`. Elenco: `nspellaliases`. Non puoi usare come shortcut nomi
riservati (`c`, `r`, `m`, comandi `n*`).

## Pannello spell cliccabili (`nebbie-cast-spells.txt`)

Il pannello **non** elenca più tutte le spell viste un giorno in `attrib`. Mostra solo le righe che
**tu** metti in:

```
getMudletHomeDir()/nebbie-cast-spells.txt
```

Una riga = un nome spell. Metti **solo** ciò che quel personaggio può lanciare **su se stesso** con
un click (es. niente `shield` nel file del mago solo perché un MU te l'ha messo — non potresti
rilanciarla). `attrib`/`nresync` aggiornano solo i **colori/tick** delle spell già in elenco.

Click su una riga → stesso comportamento di `c <spell>` con bersaglio = PG attivo (`cast 'true sight' NomiyaMaki`).

```
nclass c   -- mago/chierico (cast)
nclass r   -- sorcerer (recall)
nclass m   -- psionico (mind)
```

**Colore verde/rosso**: sotto `nspellwarn` tick (default 5) il nome diventa rosso se ancora attiva
con pochi tick; altrimenti verde se `attrib` la conferma attiva, rosso se in elenco ma non attiva.

**Scadenza in tempo reale**: messaggi server noti (sanctuary, armor, aid, true sight, darkness)
spengono subito il verde senza aspettare `nattrib`.

**Rimuovere una voce**: `nforgetspell <nome>` + togli la riga dal file; oppure edita solo il file e
`nspellaliasesreload`.

## Speedwalk (terzo pannello, in basso a destra)

Il pannello aggiunge un terzo riquadro con gli speedwalk, letti da un file di testo che scrivi tu
a mano:

```
getMudletHomeDir()/nebbie-speedwalks.txt
```

(su macOS tipicamente qualcosa come `~/.config/mudlet/profiles/<NomeProfilo>/nebbie-speedwalks.txt`
— alla prima installazione il file viene creato automaticamente con istruzioni ed un esempio
commentato, se non esiste già).

**Formato di ogni riga** (deciso insieme, vedi `Q&A.md` Round 5):

```
(descrizione cliccabile) direzioni separate da virgola
```

oppure, equivalente:

```
direzioni separate da virgola (descrizione cliccabile)
```

Una riga che contiene **solo** `(titolo di sezione)` apre un **gruppo collassabile** nel pannello
Speedwalk (clic su ▼/▶). Le righe percorso sotto restano nella sezione fino al prossimo titolo.
Lo stato aperto/chiuso si salva in `getMudletHomeDir()/nebbie-dash-ui.lua`.

- La parte tra parentesi diventa il testo cliccabile nel pannello.
- Le direzioni si scrivono come le invieresti tu in gioco (es. `n`, `s`, `e`, `w`, `u`, `d`, `ne`,
  `nw`...) — non vengono tradotte, vengono inviate esattamente come scritte.
- Un numero subito prima di una direzione (senza spazi) la ripete quel numero di volte.
- Esempio: `(dalla fontana) u,3w,n,s,2d` — cliccando "dalla fontana" nel pannello vengono inviati,
  in sequenza con una piccola pausa tra l'uno e l'altro: `u`, `w`, `w`, `w`, `n`, `s`, `d`, `d`
  (cioè: su, ovest, ovest, ovest, nord, sud, giù, giù).
- Righe vuote e righe che iniziano con `#` vengono ignorate (puoi usarle come commenti).

Dopo aver modificato il file, digita `nspeedwalks` in gioco per ricaricarlo senza riavviare
Mudlet. Il comando stampa il **percorso completo** del file letto, l'elenco dei percorsi
caricati e, se qualche riga non e' valida, il **numero di riga** e il motivo (righe senza
`(descrizione)` iniziale vengono ignorate e prima non compariva alcun avviso). Modifica sempre
il file sotto `getMudletHomeDir()`, non una copia nel repository Git. La pausa tra un movimento
e il successivo (default 0.35s, per evitare di perdere passi se il gioco impone un lag minimo
tra movimenti) si regola con `nspeeddelay <secondi>`.

**Nota**: gli speedwalk sono globali (non per personaggio) — se ti serve una lista diversa per
personaggio, fammelo sapere.

**Istruzioni con virgole/parole multiple**: un token tra virgole che NON inizia con un numero
viene sempre inviato per intero, così com'è, anche se contiene più parole o spazi. Esempio
confermato e testato: `(paul, da astral) u,n,2w,n,u,enter pool,4n,3w,6s` invia in sequenza `u`,
`n`, `w`, `w`, `n`, `u`, `enter pool` (come comando unico), `n`, `n`, `n`, `n`, `w`, `w`, `w`, `s`,
`s`, `s`, `s`, `s`, `s`. Nota anche che una virgola **dentro le parentesi** della descrizione (es.
"paul, da astral") non crea ambiguità: tutto ciò che sta tra la prima `(` e la prima `)` diventa la
descrizione, indipendentemente da quante virgole contiene.

## Layout: equip a sinistra, spell/speedwalk a destra

Dalla 1.3.0 l'equip occupa da solo il **bordo sinistro**, a tutta altezza. Il bordo destro ospita
"Spell attivi" in alto e "Speedwalk" in basso, separati da una sottile barra grigio-blu (per
regolare quanto spazio va all'uno o all'altro, vedi `nheights` sotto).

## Larghezza automatica dei pannelli

Di default (`nwidth equip auto` / `nwidth right auto`, entrambe attive fin dall'installazione) ogni
colonna si allarga o restringe da sola in base al contenuto più lungo attualmente visibile
(posizione/oggetto per l'equip; nome spell e descrizione+direzioni speedwalk per la destra), così
non c'è più testo che va a capo inutilmente quando ci starebbe su una riga sola, e niente può mai
"uscire" dal bordo dello schermo (la larghezza calcolata non supera mai il 60% della larghezza della
finestra di Mudlet). Se preferisci una larghezza fissa scelta da te, usa `nwidth equip <numero>` o
`nwidth right <numero>` (150–900): disattiva l'automatismo per quella colonna finché non digiti di
nuovo `nwidth <equip|right> auto`. Senza indicare `equip`/`right` il comando agisce sulla colonna
destra (compatibilità con la sintassi precedente). `nlayout` (reset) torna sempre alla modalità
automatica per entrambe.

## Altezza Spell attivi / Speedwalk

La colonna destra è divisa verticalmente tra "Spell attivi" (in alto) e "Speedwalk" (in basso), con
una barra divisoria visibile tra i due. Non essendoci un modo affidabile, nella API Lua di Mudlet,
per intercettare il trascinamento del mouse su quella barra, la regolazione si fa con un comando:
`nheights <percentuale>` imposta quanto della colonna va a "Spell attivi" (10–90, default 40; il
resto va a "Speedwalk"). Esempio: `nheights 60` dà il 60% a "Spell attivi" e il 40% a "Speedwalk".

## Bordo nero a sinistra

Questo package non ha mai usato il bordo sinistro (solo quello destro). Se lo vedevi comunque
comparire, era quasi certamente un residuo lasciato da un package precedente (es.
`nebbie-play-all`): i bordi sono un'impostazione del profilo Mudlet, non di uno script, quindi
disinstallare un package non li azzera da solo. Da questa versione il pannello azzera esplicitamente
il bordo sinistro (`setBorderLeft(0)`) ad ogni avvio, indipendentemente da chi l'avesse impostato in
precedenza. Se dovesse persistere anche dopo l'aggiornamento, prova un riavvio completo di Mudlet
(non solo un reload del profilo): potrebbe trattarsi di un widget creato in una sessione precedente
ancora aperta, che non persiste comunque tra riavvii.
