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
   `[NebbieDash] v1.0.0 pronto. Usa nresync dopo il login.`

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
| `nwidth <numero>` | Fissa una larghezza manuale del pannello in pixel (150–900) e **disattiva** l'adattamento automatico. |
| `nwidth auto` | Riattiva la larghezza automatica (default): il pannello si allarga/restringe da solo in base al contenuto più lungo visibile, senza mai superare il 60% della finestra di Mudlet. |
| `nitemlen <numero>` | Cambia quanti caratteri della descrizione oggetto mostrare prima di troncare con "…" (10–300, default 42). Alzalo se preferisci vedere più testo (andrà più facilmente a capo), abbassalo per evitare il più possibile il word-wrap. |
| `nfix` | Reinstalla trigger e GUI senza disinstallare il package (utile se qualcosa sembra "bloccato"). |
| `c <nome>` | Invia `cast '<nome>'` (mago/chierico). Es. `c word of r` → `cast 'word of r'` (il gioco stesso fa il match abbreviato su "word of recall", vedi sotto). |
| `r <nome>` | Invia `recall '<nome>'` (sorcerer). |
| `m <nome>` | Invia `mind '<nome>'` (psionico). |
| `nclass <c\|r\|m>` | Imposta, per il personaggio attivo, quale dei tre comandi viene usato quando clicchi una spell nel pannello per rilanciarla (default `c`/cast). Impostalo una volta per personaggio in base alla sua classe. |
| `nspellwarn <n>` | Sotto quanti tick residui una spell attiva nel pannello viene mostrata in rosso invece che verde (default 5). |
| `nspeedwalks` | Ricarica gli speedwalk dal file di configurazione dopo averlo modificato (vedi sotto), senza riavviare Mudlet. |
| `nspeeddelay <secondi>` | Pausa tra un movimento e il successivo quando esegui uno speedwalk (default 0.35s). |

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

**Nota sugli "slot vuoti"**: la versione precedente elencava sempre tutti gli slot da 1 a 21,
marcando "(vuoto)" quelli non occupati — è proprio questo che ha reso visibile il bug (l'etichetta
sbagliata veniva assegnata a uno slot vuoto "inventato"). Ora il pannello mostra **esattamente e
solo** gli slot che il gioco riporta in `eq`, nel loro ordine reale — non inventiamo più un elenco
fisso di "tutti gli slot possibili", perché non è ancora chiaro se/come il gioco riporti gli slot
liberi. Se vuoi comunque vedere anche gli slot non occupati, serve sapere da dove prendere quella
lista (es. un comando che elenchi *tutte* le posizioni indossabili, occupate o no) — vedi
`Q&A.md` per la domanda aperta su questo punto.

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

## Larghezza automatica del pannello destro

Di default (`nwidth auto`) il pannello si allarga o restringe da solo in base al contenuto più
lungo attualmente visibile (posizione/oggetto equip, nome spell, descrizione+direzioni speedwalk),
così non c'è più testo che va a capo inutilmente quando ci starebbe su una riga sola, e niente può
mai "uscire" dal bordo dello schermo (la larghezza calcolata non supera mai il 60% della larghezza
della finestra di Mudlet). Se preferisci una larghezza fissa scelta da te, usa `nwidth <numero>`
(150–900): disattiva l'automatismo finché non digiti di nuovo `nwidth auto`. `nlayout` (reset) torna
sempre alla modalità automatica.

## Bordo nero a sinistra

Questo package non ha mai usato il bordo sinistro (solo quello destro). Se lo vedevi comunque
comparire, era quasi certamente un residuo lasciato da un package precedente (es.
`nebbie-play-all`): i bordi sono un'impostazione del profilo Mudlet, non di uno script, quindi
disinstallare un package non li azzera da solo. Da questa versione il pannello azzera esplicitamente
il bordo sinistro (`setBorderLeft(0)`) ad ogni avvio, indipendentemente da chi l'avesse impostato in
precedenza. Se dovesse persistere anche dopo l'aggiornamento, prova un riavvio completo di Mudlet
(non solo un reload del profilo): potrebbe trattarsi di un widget creato in una sessione precedente
ancora aperta, che non persiste comunque tra riavvii.
