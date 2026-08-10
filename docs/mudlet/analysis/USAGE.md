# USAGE — nebbie-complete-dashboard-package

Guida rapida ai comandi (alias) del package, scritta dopo il primo test reale dell'utente
(segnalazione barre laterali grigie + richiesta istruzioni alias, 2026-08-08).

## Come installare/aggiornare

1. In Mudlet: `Package Manager` (icona valigetta, o `Giocatore → Gestione pacchetti`).
2. Se `nebbie-complete-dashboard-package` è già installato, disinstallalo prima (bottone `-`),
   poi chiudi e riapri il profilo (i widget grafici creati a runtime — miniconsole/bordo — non
   vengono sempre ripuliti immediatamente dalla sola disinstallazione).
3. Installa (bottone `+`) il file `docs/mudlet/nebbie-complete-dashboard-package.mpackage`
   aggiornato.
4. Riconnetti/ricarica il profilo. Deve comparire in output:
   `[NebbieDash] v1.3.0 pronto. Usa nresync dopo il login.`

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
| `nclanslot <on\|off>` | Mostra/nasconde il 22° slot equip placeholder "simbolo del clan" (nascosto di default, non ancora confermato in un `eq` reale). |
| `nitemlen <numero>` | Cambia quanti caratteri della descrizione oggetto mostrare prima di troncare con "…" (10–300, default 42). Alzalo se preferisci vedere più testo (andrà più facilmente a capo), abbassalo per evitare il più possibile il word-wrap. |
| `nfix` | Reinstalla trigger e GUI senza disinstallare il package (utile se qualcosa sembra "bloccato"). |
| `c <nome>[, bersaglio]` | Invia `cast '<nome>'` (mago/chierico). Con `, bersaglio` esplicito o con l'ultima parola che abbrevia il tuo personaggio, aggiunge il bersaglio (vedi sotto). Es. `c word of r` → `cast 'word of r'`. |
| `r <nome>[, bersaglio]` | Come sopra ma `recall` (sorcerer). |
| `m <nome>[, bersaglio]` | Come sopra ma `mind` (psionico). |
| `nclass <c\|r\|m>` | Imposta, per il personaggio attivo, quale dei tre comandi viene usato quando clicchi una spell nel pannello per rilanciarla (default `c`/cast). Impostalo una volta per personaggio in base alla sua classe. |
| `nspellwarn <n>` | Sotto quanti tick residui una spell attiva nel pannello viene mostrata in rosso invece che verde (default 5). |
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

## Loot e split automatico

Alla fine di ogni combattimento a cui partecipi (riconosciuto dal messaggio del gioco "La tua parte
di esperienza è di N punti.", anche con N=0), se `nautoloot` è attivo (default sì) il pacchetto
prende da solo le monete dal cadavere presente — che tu abbia contribuito con l'ultimo colpo o meno,
qualsiasi cosa ti dia una quota di esperienza. Appena il gioco conferma il bottino (`C'erano N
monete.`), se `nautosplit` è attivo (default sì) e sei in gruppo, invia da solo `split N` con
l'importo appena raccolto — verificando prima che tu sia in gruppo leggendo l'output del comando
`group`. Se non sei in gruppo, il bottino resta semplicemente tuo, senza inviare nulla.

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

## Motore generico di lancio spell/skill (`c`/`r`/`m`)

Aggiunto su richiesta esplicita (comando esatto specificato dall'utente): tre alias a una lettera,
`c <nome>`, `r <nome>`, `m <nome>`, che inviano rispettivamente `cast '<nome>'`, `recall '<nome>'`,
`mind '<nome>'`. Non facciamo nessun fuzzy-matching lato Mudlet: il motore di gioco stesso
(`ACTION_FUNC(do_cast)` in `src/spell_parser.cpp` sul repo server) fa già il match per
abbreviazione contro l'elenco completo dei nomi (`old_search_block`), quindi `c word of r` diventa
`cast 'word of r'` e il gioco lo risolve da solo in "word of recall".

L'elenco completo di tutti i nomi conosciuti dal motore di gioco (spell, skill, poteri psionici —
non filtrato per classe) è in `MUD-SPELL-SKILL-LIST.md`, estratto direttamente dal codice sorgente
del server (non inventato). Serve come riferimento per scegliere quali nomi assegnare a eventuali
alias dedicati più corti (feature non ancora implementata, in attesa che l'utente indichi quali
voci gli servono e con quale sintassi — vedi `Q&A.md`).

**Bersaglio manuale — su un ALTRO personaggio (1.3.2)**: usa una virgola per separare nome spell e
bersaglio in modo inequivocabile, qualunque sia il bersaglio: `c heal, bob` → `cast 'heal' bob`.
Funziona anche con nomi spell multi-parola: `r word of recall, bob` → `recall 'word of recall' bob`.
La virgola ha sempre la precedenza su tutto il resto.

**Bersaglio manuale — su se stessi (1.3.1)**: senza virgola, se l'ultima parola digitata è
un'abbreviazione plausibile (almeno 2 lettere, prefisso case-insensitive) del personaggio attivo,
viene staccata automaticamente e usata come bersaglio esplicito. Esempio con `NomiyaMaki` attivo:
`c heal nom` → `cast 'heal' NomiyaMaki` (non `cast 'heal nom'`, che il gioco non riconosce). Senza
questa parola finale il comportamento resta quello di sempre: tutto il testo è il nome spell (es.
`c word of r` → `cast 'word of r'`, nessun bersaglio). **Limite noto**: se il nome del personaggio
inizia con le stesse lettere dell'ultima parola di uno spell multi-parola che NON deve avere
bersaglio, questa viene comunque staccata (falso positivo raro, accettato consapevolmente — usa la
virgola per evitarlo del tutto, oppure segnalalo se capita spesso).

**Attenzione — possibile collisione**: `c`, `r`, `m` seguiti da uno spazio e altro testo ora
vengono intercettati SEMPRE da questo alias, anche se nel gioco esistessero altri comandi che
iniziano per caso con la stessa lettera (es. abbreviazioni di comandi diversi da "cast"/"recall"/
"mind" che prendono un argomento). Se noti che un comando che usavi prima con quella lettera ha
smesso di funzionare come previsto, segnalalo: è il compromesso esplicitamente scelto con la
sintassi richiesta.

## Spell attivi cliccabili (rilancio con un click)

Ogni spell nel pannello "Spell attivi" è ora un link cliccabile: cliccandoci sopra la rilancia
usando il comando impostato con `nclass` per quel personaggio (default `cast`, cioè come se
avessi digitato `c <nome spell>`), **puntata sempre sul personaggio attivo** (quello mostrato nel
titolo del pannello, es. "Spell attivi — NomiyaMaki"): il click su "true sight" invia
`cast 'true sight' NomiyaMaki`, non solo `cast 'true sight'`. Il gioco interpreta tutto ciò che
segue l'apice di chiusura come nome del bersaglio (`ACTION_FUNC(do_cast)`,
`src/spell_parser.cpp`); per le spell "solo su se stessi" indicare comunque il proprio nome non ha
alcun effetto negativo, il server lo ignora semplicemente. Imposta la classe giusta una volta per
personaggio:

```
nclass c   -- mago/chierico (cast)
nclass r   -- sorcerer (recall)
nclass m   -- psionico (mind)
```

**Colore verde/rosso**: sotto `nspellwarn` tick (default 5) il nome della spell diventa rosso,
altrimenti resta verde. Nota importante: questo riflette il numero di tick letto **all'ultima
sincronizzazione** (`nattrib`/`nresync`), non è un conto alla rovescia in tempo reale — il pannello
non sa quanti secondi dura un tick sul server, quindi non può stimare da solo quanto manca alla
scadenza tra un `nattrib` e l'altro. Se vuoi un conto alla rovescia live, serve sapere quanti
secondi reali dura un tick lato server.

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

- La parte tra parentesi diventa il testo cliccabile nel pannello.
- Le direzioni si scrivono come le invieresti tu in gioco (es. `n`, `s`, `e`, `w`, `u`, `d`, `ne`,
  `nw`...) — non vengono tradotte, vengono inviate esattamente come scritte.
- Un numero subito prima di una direzione (senza spazi) la ripete quel numero di volte.
- Esempio: `(dalla fontana) u,3w,n,s,2d` — cliccando "dalla fontana" nel pannello vengono inviati,
  in sequenza con una piccola pausa tra l'uno e l'altro: `u`, `w`, `w`, `w`, `n`, `s`, `d`, `d`
  (cioè: su, ovest, ovest, ovest, nord, sud, giù, giù).
- Righe vuote e righe che iniziano con `#` vengono ignorate (puoi usarle come commenti).

Dopo aver modificato il file, digita `nspeedwalks` in gioco per ricaricarlo senza riavviare
Mudlet. La pausa tra un movimento e il successivo (default 0.35s, per evitare di perdere passi se
il gioco impone un lag minimo tra movimenti) si regola con `nspeeddelay <secondi>`.

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
