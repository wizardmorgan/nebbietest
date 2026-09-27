# LOG — Analisi da zero, Nebbie Play All (Mudlet)

Journal di analisi. Ogni voce: data/ora, azione, fonte, esito, decisione.
Regole di riferimento: `docs/mudlet/AGENT-RULES.txt`, `docs/mudlet/AGENT-PROMPT-ANALISI-ZERO.txt`.

---

## 2026-08-08 21:xx — Fase 0: Setup

- **Azione**: letti per intero `docs/mudlet/AGENT-RULES.txt` e `docs/mudlet/AGENT-PROMPT-ANALISI-ZERO.txt`
  (percorso reale sul Mac dell'utente: `/Users/wizmorgan/Documents/GitHub/istruzioni/`, poi
  confermato presenti anche nel repo su branch `origin/cursor/nebbie-unified-dashboard-55b4`).
- **Nota ambiente**: il workspace Cursor era inizialmente aperto sul repo `mudlet` (client C++
  ufficiale), non su `nebbietest` (repo del server/gioco Nebbie Arcane, dove vive
  `docs/mudlet/` con il pacchetto Mudlet custom). Confermato con l'utente: lavorare nel
  repo `nebbietest`.
- **Azione**: individuato repo locale corretto: `/Users/wizmorgan/Documents/GitHub/nebbietest`.
- **Azione**: creato branch di lavoro `cursor/nebbie-analisi-zero-55b4` a partire da
  `origin/mudlet` (come richiesto da AGENT-PROMPT-ANALISI-ZERO.txt, sezione GIT: "Base: mudlet").
  Verificato che `origin/mudlet` è l'antenato comune (merge-base) del vecchio branch di lavoro
  `origin/cursor/nebbie-unified-dashboard-55b4` — quindi `mudlet` è la base "pulita" pre-iterazione
  precedente.
  - Comando: `git fetch origin mudlet && git checkout -b cursor/nebbie-analisi-zero-55b4 origin/mudlet`
- **Decisione utente esplicita**: lavorare SOLO su questo branch per tutta la durata dello
  sviluppo, senza passare ad altri branch nel corso del lavoro. Il branch `mudlet` serve solo
  come base di partenza (codice client Mudlet + pacchetto precedente per contesto).
- **Nota tecnica**: lo strumento di switch workspace (`move_agent_to_root`) fallisce nell'ambiente
  corrente per un `git` di sistema troppo vecchio (2.21.0, manca `--no-write-fetch-head`,
  introdotto in git 2.29). Non è stata modificata la configurazione git di sistema (vietato da
  regole). Si opera sul repo `nebbietest` tramite i tool di lettura/scrittura file diretti e
  tramite Shell con permessi elevati quando serve `git`.
- **Azione**: letto `AGENTS.md` nella root di `nebbietest` — conferma che riguarda la build del
  **server** C++ (`myst`, Docker/Vagrant, MySQL), separato dal pacchetto Mudlet in `docs/mudlet/`.
- **Azione**: individuato in `origin/cursor/nebbie-unified-dashboard-55b4` l'elenco file legacy
  citati nel prompt (`nebbie-installer-core.lua`, `nebbie-dashboard.lua`,
  `build-nebbie-package.py`, `nebbie-play-all-build/*`, `PACKAGE-GUIDE.md`, `HELP.md`,
  `SPEC-v2.2.8.md`, ecc.). Questi NON sono ancora stati letti in dettaglio: da regola
  (AGENT-PROMPT-ANALISI-ZERO.txt, sezione "CODICE ESISTENTE"), vanno letti DOPO la ricerca sulla
  wiki Mudlet (Fase 1), non prima.
- **Azione**: create cartelle/file `docs/mudlet/analysis/` (questo LOG, Q&A.md, ecc.).
- **Azione**: poste le domande iniziali del template (AGENT-PROMPT-ANALISI-ZERO.txt, sezione
  "DOMANDE INIZIALI") all'utente. Risposte registrate in `Q&A.md`.
- **Esito rilevante**: l'utente ha introdotto un requisito NUOVO non presente nello scope
  originale del prompt: **un solo profilo Mudlet deve permettere di switchare tra più
  personaggi**, ciascuno con proprie skill/spell/prompt differenti. Questo amplia
  significativamente lo scope (multi-character state, non solo multi-panel per un singolo PG).
  Registrato in `REQUIREMENTS.md` come requisito da approfondire con domande di follow-up
  (vedi `Q&A.md`, round 2).
- **Decisione**: NON si procede a leggere in dettaglio il codice legacy né a disegnare soluzioni
  finché non è completata la Fase 1 (wiki Mudlet, read-only) — per rispettare
  AGENT-PROMPT-ANALISI-ZERO.txt (ordine Fase 0 → Fase 1 → Fase 2 → ...).

---

## 2026-08-08 22:xx — Fase 1: Wiki Mudlet (read-only)

- **Azione**: consultate pagine ufficiali wiki.mudlet.org su: Trigger Engine, Best Practices
  (shielding), Regex, Lua Functions (Basics), Scripting (`getLines`/`getLineCount`), UI Functions
  (`createMiniConsole`, `setBorder*`), Mudlet Object Functions (`tempPromptTrigger`,
  `permPromptTrigger`, `isPrompt`), Event Engine (`sysLoadEvent`, `sysInstallPackage`,
  `sysUninstallPackage`), Package Manager, Networking Functions (`downloadFile`), Table Functions
  (`table.save`/`table.load`), Advanced Lua, Miscellaneous Functions (`getMudletHomeDir`).
- **Esito**: sintetizzato in `MUDLET-WIKI-NOTES.md` (10 sezioni, ognuna con URL e implicazioni).
- **Scoperta rilevante #1**: i trigger di tipo **Prompt** (e `tempPromptTrigger`/
  `permPromptTrigger`/`isPrompt`) funzionano SOLO se il server implementa telnet **GA
  (Go-Ahead)** o **EOR**; altrimenti Mudlet mostra "No GA" e questi trigger non sono affidabili.
  Non sappiamo se Nebbie Arcane implementa GA/EOR (dato di codice server, repo `nebbietest/src`,
  non ancora verificato — fuori standard scope Fase 1 che è solo wiki). Non blocca il design se
  si sceglie un approccio che non dipende da GA (vedi Fase 3).
- **Scoperta rilevante #2**: la wiki conferma ufficialmente il pattern "shielding" (trigger
  veloce substring/begin-of-line che scuda una regex figlia) come best practice per ridurre il
  costo di trigger regex "su ogni riga" — quindi i "divieti" del prompt (`.+` catch-all,
  substring su ogni riga) non sono vietati in assoluto dalla wiki, ma vanno usati SOLO se scudati
  correttamente in un chain unico, non come trigger indipendenti multipli.
- **Scoperta rilevante #3**: ambiguità reale (non invenzione) tra la documentazione di `getLines`
  (parametri assoluti) e il commento nel codice sorgente Lua ufficiale (chiavi tabella "relative
  linenumber") — fonte plausibile di bug se non gestita esplicitamente.

## 2026-08-08 22:xx — Lettura codice legacy (DOPO wiki, come da regola)

- **Azione**: letti `docs/mudlet/PACKAGE-GUIDE.md` e `docs/mudlet/SPEC-v2.2.8.md` (repo
  `nebbietest`, branch base `mudlet` = branch di lavoro corrente) per contesto architetturale.
- **Nota discrepanza documentale**: `SPEC-v2.2.8.md` dichiara `Nebbie.version = "2.2.8"`, ma il
  codice reale in questo branch (`nebbie-installer-core.lua`,
  `nebbie-play-all-build/nebbie-install.lua`) ha `Nebbie.version = "2.2.33"`. La SPEC è quindi
  **documentazione non allineata al codice** — da NON usare come fonte di verità per il
  comportamento attuale, solo come contesto storico.
- **Verifiche puntuali nel codice** (grep + lettura mirata di `nebbie-installer-core.lua`):
  - `Nebbie.installPromptHooks()` (riga ~261-278): installa **sia**
    `tempSubstringTrigger(" H:")` **sia** `tempPromptTrigger` (quest'ultimo solo se la funzione
    esiste). Conferma reale (non assunzione) del "divieto" sospettato: substring `" H:"` usata
    per rilevare il prompt. Va rivalutato se scudata correttamente o no nel chain complessivo
    (non ancora analizzato in dettaglio — richiede lettura più estesa se si decide di riusare
    questo codice).
  - `Nebbie.pollPromptFromBuffer()` (righe 184-205): usa `getLines(from, last)` con conversione
    esplicita `rel = abs - from + 1` — **QUESTA istanza specifica gestisce correttamente** la
    differenza indice assoluto/relativo (contrariamente al sospetto generico nel prompt). Non si
    può quindi confermare il bug "getLines indici relativi" su QUESTO branch/questa funzione;
    potrebbe riguardare altre parti del codice non ancora lette, o essere stato introdotto solo
    nelle iterazioni successive (~2.2.48-2.2.55) vissute solo sul branch
    `cursor/nebbie-unified-dashboard-55b4` (non replicato qui).
  - `Nebbie.boot()` (righe 3135-3172) viene chiamato **immediatamente e incondizionatamente**
    all'esecuzione dello script (riga 3174-3179, fuori da qualunque `sysLoadEvent`), e internamente
    chiama `Nebbie.maybeRefreshEqCacheOnBoot()` — **conferma concreta** (non assunzione) del
    "divieto" *"auto eq/attrib e auto download/upgrade al boot"*: essendo uno script XML `perm`,
    Mudlet lo ricompila/esegue ad ogni caricamento del profilo E ad ogni salvataggio nello Script
    Editor (comportamento documentato per `sysLoadEvent` in `MUDLET-WIKI-NOTES.md` §5, che si
    applica per estensione a qualunque script perm eseguito al parse) — coerente con il
    rallentamento al login segnalato dall'utente (Q&A.md, Round 1, Q4) prima di disinstallare il
    package.
  - `Nebbie.guiTimer = tempTimer(1, function() Nebbie.refreshGUI() end, true)` (riga ~2484):
    timer **ricorrente ogni 1 secondo** che richiama un refresh GUI completo, oltre alle chiamate
    dirette a `Nebbie.refreshGUI()` sparse in almeno altri 8 punti del codice (eventi buff, eq,
    ecc.) — conferma concreta del divieto *"refresh UI completo più di ~1 volta / 2-3 secondi"*.
- **Conclusione parziale (da confermare in RECOMMENDATION.md)**: almeno 2 dei "divieti" elencati
  nel prompt sono confermati con evidenza diretta nel codice di QUESTO branch (boot automatico
  con eq/attrib, refresh GUI a 1s); un terzo (substring `" H:"` su ogni riga) è confermato come
  presente ma non ancora valutato se dannoso in pratica (dipende da come è strutturato il resto
  del chain trigger, non ancora letto per intero — file da 3180 righe, lettura completa rimandata
  a dopo l'approvazione dell'utente sul design, per non sprecare tempo se si opta per package
  nuovo). Il quarto sospetto (getLines indici) NON è confermato in questa istanza di codice.
- **Non letto per intero** (rimandato, vedi nota sopra): `nebbie-installer-core.lua` per intero
  (3180 righe), `build-nebbie-package.py` (2000+ righe), `nebbie-play-all-build/nebbie-install.lua`
  generato, `HELP.md`. `nebbie-dashboard.lua` citato nel prompt NON esiste su questo branch —
  esiste solo su `origin/cursor/nebbie-unified-dashboard-55b4` (iterazione successiva, non
  presente nella base `mudlet`); se serve consultarlo va letto da quel branch senza cambiare
  branch di lavoro (es. `git show origin/cursor/nebbie-unified-dashboard-55b4:docs/mudlet/nebbie-dashboard.lua`).

---

## 2026-08-08 22:xx — Fase 2/3/4: Requisiti, opzioni di design, raccomandazione preliminare

- **Azione**: scritto `REQUIREMENTS.md` incrociando risposte utente (Q&A Round 1-2) e vincoli
  wiki/codice. Identificati nuovi gap bloccanti per il pannello equip (priorità R5): formato
  esatto del prompt (discrepanza tra esempio utente e campione nel codice legacy) ed elenco
  completo dei 21 slot equip.
- **Azione**: poste le domande Round 3 all'utente (`Q&A.md`). Risposta: l'utente incollerà
  l'output di `eq` e il prompt esatto in un messaggio successivo (IN ATTESA); confermato che sia
  `eq`/`attrib` che `equipment`/`attribute` funzionano come comandi.
- **Azione**: scritto `DESIGN-OPTIONS.md` a livello architetturale (rilevamento cambio
  personaggio, struttura trigger prompt/eq con shielding, persistenza, package nuovo vs riuso),
  con almeno 2-3 alternative per ciascuna decisione, pro/contro, rischio hang, fonte.
  Deliberatamente NON include pattern regex concreti, che dipendono dai dati Round 3 non ancora
  ricevuti.
- **Azione**: scritto `RECOMMENDATION.md` preliminare: package nuovo minimo (nome proposto
  `nebbie-dash`, da confermare), rilevamento personaggio ibrido (parser prompt + evento
  connessione + comando manuale di sicurezza), shielding ufficiale per i trigger, persistenza su
  disco proposta ma da confermare, scope release 1 limitato a equip + infrastruttura
  multi-personaggio.
- **Esplicitamente NON fatto in questa sessione** (per rispetto di AGENT-RULES.txt §2):
  nessuna riga di codice Lua/XML nuova scritta, nessuna modifica al pacchetto esistente,
  nessuna dichiarazione di problema "risolto".
- **Prossimo passo**: attendere dall'utente (a) output completo `eq`, (b) prompt esatto copiato
  da Mudlet, (c) conferme sui punti aperti in `RECOMMENDATION.md` §2, prima di procedere a
  pattern concreti e a qualunque implementazione.

---

## 2026-08-08 22:24 — Dati reali ricevuti: root cause confermata dei pannelli vuoti

- **Azione**: l'utente ha incollato l'output reale e completo di `eq` (21 slot, personaggio
  NomiyaMaki) e il prompt esatto copiato da Mudlet (`Q&A.md` Round 3).
- **Analisi**: confrontando il prompt reale (`NomiyaMaki H: 747/747 M: 532/532 V: 158/158
  x:-238860738 *:* *:* [[D]] G:3449502 >>`) con il codice `Nebbie.parsePromptPair()`/
  `parsePromptStats()` in `nebbie-installer-core.lua` (righe 121-152, già letto in Fase
  precedente), è stato confermato con certezza (non più sospetto) che:
  1. il parser richiede `H:%d+` (nessuno spazio tollerato dopo `:`), ma il prompt reale ha
     `H: 747` (con spazio) → il parsing di HP/Mana/Move **fallisce sempre**;
  2. il parser cerca `X:` maiuscolo per l'XP, il server manda `x:` minuscolo (case-sensitive in
     Lua) → fallirebbe comunque anche corretto il punto 1.
  Questa è la causa diretta, verificata con evidenza (codice + dato reale, non ipotesi), dei
  "pannelli laterali vuoti con ~89 trigger installati" elencati come sospetto nel prompt
  originale.
- **Scoperta aggiuntiva**: le descrizioni oggetto in `eq` possono andare a capo su righe di
  continuazione senza numero di slot (word-wrap) — nuovo vincolo per il parser `eq` (M6 in
  REQUIREMENTS.md), non gestito esplicitamente nel parsing legacy (che comunque gestiva solo 3
  slot su 21, non l'intero pannello equip).
- **Azione**: aggiornati `Q&A.md`, `REQUIREMENTS.md` (§5 gap risolti, nuovo §6 M6),
  `DESIGN-OPTIONS.md` (nuova sezione D2-0 con pattern regex concreti per prompt ed `eq`),
  `RECOMMENDATION.md` (stato aggiornato, tabella §2 aggiornata).
- **Non ancora fatto**: nessuna riga di codice del package scritta. Restano da confermare con
  l'utente: persistenza su disco (D3), nome package, scope release 1, nomi comandi (vedi
  `RECOMMENDATION.md` §2) prima di passare a Fase 5 (implementazione).

---

## 2026-08-08 22:40 — Conferme finali utente e Fase 5 (implementazione)

- **Azione**: poste le ultime domande aperte di `RECOMMENDATION.md` §2. Risposte utente:
  persistenza su disco confermata; nome package: **`nebbie-complete-dashboard-package`**
  (preferenza esplicita, sostituisce la proposta `nebbie-dash`); scope release 1: **equip +
  spell/attrib insieme** (non solo equip); approvazione esplicita a procedere con
  l'implementazione.
- **Azione**: scritto `docs/mudlet/nebbie-complete-dashboard-package-core.lua` (namespace Lua
  `NebbieDash`, per non confliggere con `Nebbie` del package legacy) secondo le decisioni
  D1(A+C+B)/D2(pattern concreti D2-0)/D3-B/D4-A documentate.
- **Azione**: scritto `docs/mudlet/build-nebbie-complete-dashboard-package.py` (build script
  minimo, non riusa `build-nebbie-package.py` legacy) e generato
  `docs/mudlet/nebbie-complete-dashboard-package.mpackage` +
  `docs/mudlet/nebbie-complete-dashboard-package-build/` (xml + config.lua).
- **Verifiche eseguite (con evidenza, non dichiarazioni)**:
  - `luac -p` sul core Lua: nessun errore di sintassi.
  - XML generato: validato come ben formato con `xml.etree.ElementTree` (Python).
  - Test offline `docs/mudlet/tests/smoke_test_parsing.lua` (Lua puro, API Mudlet mockate):
    19/19 asserzioni passate usando ESATTAMENTE i dati reali forniti dall'utente (prompt e `eq`
    completo di NomiyaMaki) e l'esempio `attrib` del prompt originale. Copre: parsing prompt,
    rilevamento personaggio, cattura 21/21 slot equip con gestione del word-wrap (M6), cattura
    spell attivi.
- **Esplicitamente NON verificato** (richiede Mudlet reale, non simulabile offline): trigger reali
  (`tempTrigger`/`tempRegexTrigger`/`enableTrigger`/`disableTrigger`), rendering GUI
  (`createMiniConsole`/`setBorderRight`), persistenza reale (`table.save`/`table.load` su
  `getMudletHomeDir()` vero), comportamento su reconnessione reale, formato `attrib` completo
  oltre l'esempio a 2 spell, formato prompt/eq in combattimento. Tutti questi punti sono elencati
  come test manuali da eseguire in `TEST-PLAN.md` — **nessuno viene dichiarato "risolto" o
  "funzionante" senza quell'evidenza**, per rispetto di AGENT-RULES.txt §1.
- **Azione**: scritti `TEST-PLAN.md` (9 test manuali + 1 automatico) e `CHANGELOG.md` (v1.0.0).

## 2026-08-08 23:xx — Feedback post-installazione reale (T1 fallito parzialmente) + fix

- **Segnalazione utente**: dopo aver installato `nebbie-complete-dashboard-package.mpackage` in
  Mudlet reale, le due miniconsole sul bordo destro (equip/spell) apparivano completamente grigie
  e senza testo. L'utente ha anche chiesto istruzioni sull'uso degli alias, mai documentate finora.
- **Ipotesi iniziale dell'utente**: residuo del vecchio package `nebbie-play-all`.
- **Analisi codice**: rivista `initGUI()` in `nebbie-complete-dashboard-package-core.lua`. Trovato
  bug reale, indipendente dal vecchio package: `createMiniConsole(...)` viene chiamata ma non
  segue mai una `setBackgroundColor(...)` né una scrittura (`cecho`); una miniconsole Mudlet
  appena creata resta con lo sfondo di default del widget Qt (grigio) finché non viene disegnata.
  Inoltre `boot()` chiamava `initGUI()` ma mai `refreshDashboard()`, quindi il pannello restava
  vuoto/grigio fino al primo comando digitato in gioco (che innesca il rilevamento del prompt) o al
  primo `nresync` manuale — nell'intervallo tra installazione e quel momento, grigio è esattamente
  il comportamento atteso col bug presente.
- **Fix applicato**: aggiunto `setBackgroundColor` per entrambe le miniconsole subito dopo la
  creazione, e chiamata a `NebbieDash.refreshDashboard()` alla fine di `initGUI()` (quindi anche
  dentro `boot()`), così il pannello mostra da subito un testo placeholder invece di restare vuoto.
- **Verifica**: rieseguito `tests/smoke_test_parsing.lua` dopo la modifica — tutti i 19 assert
  ancora OK (la modifica non tocca la logica di parsing). Rigenerato
  `nebbie-complete-dashboard-package.mpackage` con `build-nebbie-complete-dashboard-package.py`.
- **Azione**: scritto `USAGE.md` con tabella completa degli alias (nessuno documentato prima
  d'ora) e istruzioni di verifica per escludere residui del vecchio package (Package Manager,
  Editor, riavvio completo di Mudlet).
- **Nota**: il fix GUI non è ancora stato validato in Mudlet reale dall'utente (richiede
  reinstallazione del `.mpackage` aggiornato) — resta comunque aperto il test manuale T1/T7 in
  `TEST-PLAN.md`.

## 2026-08-08 23:xx — Secondo giro di feedback reale: layout non responsive, font, slot vuoti

- **Segnalazione utente**: dopo aver reinstallato il `.mpackage` col fix precedente, si vede una
  sola barra a destra (non due), ridimensionare la finestra di Mudlet non ha alcun effetto sul
  pannello, il font è troppo piccolo, e gli slot equip vuoti non compaiono (solo quelli occupati).
- **Analisi codice**: confermato che `positionGUI()` non era mai agganciata a nessun evento di
  resize — mancava un handler per `sysWindowResizeEvent` (verificato su
  https://wiki.mudlet.org/w/Manual:Event_Engine: firma `function(event, x, y)`, x/y = nuove
  dimensioni finestra principale/bordi). Inoltre `getMainWindowSize()` letta nello stesso istante
  della creazione della GUI può restituire una dimensione non ancora corretta (nota già presente
  in MUDLET-WIKI-NOTES.md sulla geometria Qt/autowrap), spiegando l'altezza errata (vicina a 0)
  della miniconsole equip vista come "una sola barra". `refreshDashboard()` inoltre ometteva del
  tutto gli slot equip vuoti (`if item then ... end`, nessun ramo else).
- **Fix applicati**: handler `sysWindowResizeEvent` → `NebbieDash.onWindowResize` che richiama
  `positionGUI()` via `tempTimer(0, ...)`; secondo richiamo a `positionGUI()` via `tempTimer(0,
  ...)` subito dopo la creazione iniziale della GUI per correggere l'altezza calcolata male
  all'avvio; font di default alzato 9→11pt e larghezza pannello 260→320px, con due nuovi comandi
  manuali `nfont <n>` e `nwidth <n>` per regolarli; il pannello equip ora mostra sempre tutti i 21
  slot, marcando esplicitamente `(vuoto)` quelli liberi.
- **Verifica**: `luac -p` OK, rieseguito `tests/smoke_test_parsing.lua` — 19/19 OK (fix riguarda
  solo GUI/layout, non il parsing). Rigenerato `.mpackage`.
- **Azione**: aggiornati `USAGE.md` (nuova sezione + tabella comandi) e `CHANGELOG.md`.
- **Nota**: nessuno di questi fix (resize/font/slot vuoti) è ancora stato validato in Mudlet reale
  — richiede nuova reinstallazione del `.mpackage` da parte dell'utente.

## 2026-08-08 23:xx — Terzo giro di feedback reale: slot equip mislabeled, font ancora a capo

- **Segnalazione utente**: dopo il secondo fix, il font è più grande ma il testo va comunque a
  capo (non gradito); manca "la finestra con gli speedwalk" (feature del vecchio package, mai
  portata in questo package nuovo, esplicitamente fuori scope in `CHANGELOG.md`); le spell/skill
  non sono cliccabili per rilanciarle (feature mai richiesta/discussa prima d'ora); il conteggio
  slot equip è sbagliato — manca lo slot "ai piedi" e gli oggetti risultano nell'ordine sbagliato,
  con lo slot "davanti agli occhi" vuoto e dei guanti mostrati come "ai piedi".
- **Analisi codice — root cause reale del mislabeling**: `onEqCaptureLine()` leggeva numero di
  slot e descrizione oggetto da ogni riga `eq` (es. `[ 8] <ai piedi> ...`) ma **scartava** il testo
  tra `< >` (la posizione reale), sostituendolo a display-time con un'etichetta presa dalla
  tabella statica `EQ_SLOTS[numero]`, costruita sull'unico esempio di `eq` fornito dall'utente
  (dove l'ordine combaciava per coincidenza). Il numero di slot da solo non è un identificatore
  affidabile della posizione sul corpo — è emerso chiaramente al primo caso reale con ordine
  diverso.
- **Fix applicato**: la posizione ora viene sempre letta dal testo tra `< >` della riga stessa
  (mai da `EQ_SLOTS`), salvata come `{ location = ..., item = ... }` per slot. Aggiunta
  `migrateStore()` per convertire al volo eventuali dati salvati su disco nel vecchio formato
  (stringa semplice). Il pannello ora mostra esattamente e solo gli slot riportati dal gioco, nel
  loro ordine reale — niente più enumerazione fissa "1..21" con placeholder "(vuoto)" inventati
  (che erano proprio ciò che aveva reso visibile il bug). Aggiunto test automatico dedicato
  ("eq anomalo") con un ordine di slot volutamente diverso dal primo esempio, per prevenire
  regressioni future su questo punto.
- **Fix applicato (word-wrap)**: descrizioni oggetto troncate a 42 caratteri (nuovo comando
  `nitemlen` per regolare), per ridurre — non eliminare del tutto, perché alcune descrizioni sono
  comunque più larghe del pannello anche troncate a seconda del font — il numero di righe che
  vanno a capo.
- **NON implementato in questo giro** (richiede conferma esplicita dell'utente, sono feature mai
  discusse prima e/o esplicitamente dichiarate fuori scope): finestra speedwalk, spell/skill
  cliccabili per rilancio, elenco degli slot equip NON occupati (richiede sapere da quale comando
  del gioco recuperare la lista completa delle posizioni indossabili). Vedi domande poste
  all'utente nella stessa risposta di questo turno.
- **Verifica**: `luac -p` OK, `tests/smoke_test_parsing.lua` aggiornato con struttura
  `{location, item}` e nuovo test "eq anomalo" — tutti OK. Rigenerato `.mpackage`.

## 2026-08-08 23:xx — Decisioni su speedwalk/spell cliccabili/slot vuoti + motore quick-cast

- **Domande poste all'utente** (via AskQuestion) sulle 3 feature non implementate nel giro
  precedente: finestra speedwalk, spell cliccabili, elenco slot equip non occupati.
- **Risposta speedwalk**: "progettiamo da zero, dettagli in un prossimo messaggio" — nessuna
  azione ora, in attesa di requisiti.
- **Risposta slot equip non occupati**: "no/non lo so, lascia il pannello com'è" — chiuso, nessuna
  azione richiesta, il pannello resta con i soli slot occupati (comportamento già in essere dal
  fix precedente).
- **Risposta spell cliccabili**: risposta articolata, non un semplice "sì/no". L'utente vuole:
  1. un motore generico di lancio con prefissi a una lettera `c`/`r`/`m` (cast/recall/mind a
     seconda della classe: mago/chierico=cast, sorcerer=recall, psionico=mind), che prenda tutto
     il resto della riga come un unico argomento — es. `c word of r` → `cast 'word of r'`;
  2. l'elenco COMPLETO di spell/skill dal codice del server (repo separato, path locale
     `/Users/wizmorgan/Documents/GitHub/Server`, remote `NebbieArcane/Server` — già visto come
     `upstream` nei remote di `nebbietest`), da cui l'utente sceglierà poi quali alias dedicati
     vuole (non a me deciderlo).
  3. click-to-recast vero e proprio (link cliccabile nel pannello) rimandato: prima serve la
     lista/motore generico, l'utente "darà l'alias" per le spell che gli servono.
- **Verifica codice server**: in `src/spell_parser.cpp`, `ACTION_FUNC(do_cast)` usa
  `old_search_block(argument, 1, qend-1, spells, 0)` per matchare il testo tra apici contro
  l'array `const char* spells[]` — il motore di gioco fa GIÀ da solo il match per abbreviazione
  (conferma diretta nel codice del perché `cast 'word of r'` funziona nel gioco). Questo significa
  che l'engine lato Mudlet non deve fare alcun fuzzy-matching: si limita a incapsulare l'argomento
  tra apici e a inviare il comando giusto.
- **Azione**: estratto l'intero array `spells[]` (300 voci, righe 57-362 di
  `src/spell_parser.cpp`) con uno script Python (nessuna trascrizione manuale, per evitare errori
  di battitura su una lista così lunga) e scritto in
  `docs/mudlet/analysis/MUD-SPELL-SKILL-LIST.md`, con le sezioni già presenti nei commenti del
  codice sorgente (spell base / skill non-magiche / spell da pergamena-pozione-bacchetta) e le
  voci marcate `!...!` (nomi interni, non selezionabili da un giocatore) evidenziate.
- **Azione**: implementato `NebbieDash.cmdQuickCast(prefix, argument)` +
  `NebbieDash.CAST_PREFIX = {c="cast", r="recall", m="mind"}`, alias `^([crm]) (.+)$`.
- **Nota rischio segnalata in USAGE.md**: gli alias a una lettera `c`/`r`/`m` intercettano SEMPRE
  quel prefisso seguito da spazio+testo, anche se nel gioco esistesse un altro comando abbreviato
  con la stessa lettera iniziale — compromesso esplicitamente scelto dall'utente con la sintassi
  richiesta, non una svista.
- **Verifica**: `luac -p` OK, smoke test invariato (non tocca il parsing) — OK. Rigenerato
  `.mpackage`.

## 2026-08-08/09 00:xx — Implementazione speedwalk + spell cliccabili con colore

- **Contesto**: pannello confermato funzionante ("ho una barra nera a destra"). Richiesta di
  implementare gli speedwalk nel pannello, con formato dettato dall'utente (vedi Q&A.md Round 5),
  e chiarito perché le spell non erano cliccabili (semplicemente non ancora implementato — non
  c'entrava nulla un presunto meccanismo di scadenza/colore, quello era un secondo suggerimento
  dell'utente su come mostrarle, non un requisito già previsto).
- **Terzo pannello**: aggiunta una terza miniconsole `NebbieDashSpeedwalks`, sotto le altre due sul
  bordo destro. `positionGUI()` ora divide l'altezza in tre proporzioni configurabili
  (`NebbieDash.guiRatios`, default 45/25/30%) invece di due fisse.
- **Speedwalk — file di configurazione**: `getMudletHomeDir()/nebbie-speedwalks.txt`, testo
  semplice scritto a mano dall'utente. Formato concordato: `(descrizione) direzioni,separate,da
  virgola`, con supporto a un numero di ripetizione davanti a una direzione (es. `3w` = ovest tre
  volte). Verificato con l'esempio ESATTO fornito dall'utente ("u,3w,n,s,2d" → 8 passi:
  u,w,w,w,n,s,d,d) in un test automatico dedicato. Se il file non esiste viene creato con
  istruzioni ed un esempio commentato, cosi' l'utente sa subito come compilarlo. Le direzioni
  vengono inviate esattamente come scritte (nessuna traduzione a parola intera: il gioco accetta
  gia' le forme brevi).
- **Speedwalk — esecuzione**: click sulla descrizione (via `cechoLink`) → `runSpeedwalk(index)` →
  invia ogni direzione con una pausa (`NebbieDash.speedwalkDelay`, default 0.35s, regolabile con
  `nspeeddelay`) invece di un unico invio concatenato, per non perdere passi per via del lag di
  movimento del gioco (non confermato quanto lag ci sia realmente — valore di default prudente).
  Comando `nspeedwalks` per ricaricare il file senza riavviare Mudlet.
- **Spell cliccabili**: implementato con `cechoLink()` (verificato su
  https://wiki.mudlet.org/w/Manual:UI_Functions#cechoLink — firma
  `cechoLink([windowName], text, command, hint, true)`), che richiama
  `NebbieDash.cmdQuickCast(prefix, nomeSpell)` al click. Il prefisso (c/r/m) dipende dalla classe
  del personaggio, non deducibile dal nome della spell: aggiunto comando `nclass <c|r|m>` per
  impostarlo una volta per personaggio (persistito), default `c` (cast).
- **Colore verde/rosso**: sotto `NebbieDash.spellWarnTicks` (default 5, regolabile con
  `nspellwarn`) il nome della spell è rosso, altrimenti verde. **Limite dichiarato esplicitamente
  in USAGE.md**: riflette solo il valore letto all'ultimo `nattrib`/`nresync`, NON un conto alla
  rovescia in tempo reale — non conosciamo la durata reale di un tick sul server, quindi non
  inventiamo una stima che potrebbe essere sbagliata.
- **Versione package**: alzata da 1.0.0 a 1.1.0 (sia nel core Lua che nel build script, dove
  servono per il controllo "già caricato in questa sessione" nel wrapper di boot).
- **Verifica**: `luac -p` OK. Aggiunti 8 test automatici dedicati al parsing speedwalk
  (`parseSpeedwalkDirs`, `parseSpeedwalkLine`, righe commento/vuote/malformate ignorate) —
  30/30 test totali OK. Rigenerato `.mpackage`.
- **Non ancora verificato in Mudlet reale**: rendering dei link cliccabili nella miniconsole,
  comportamento reale dello speedwalk in movimento (lag effettivo tra comandi).

---

## 2026-08-09 — Feedback round 6 (post-1.1.0): target spell, larghezza colonna, virgole speedwalk, bordo sinistro

Feedback utente testuale (traduzione dei 4 punti):

1. Le spell cliccabili devono lanciarsi sempre puntate sul personaggio con cui si sta giocando
   (es. da "Spell attivi — NomiyaMaki", il click deve equivalere a bersagliare NomiyaMaki).
2. La larghezza della colonna destra è illeggibile: deve adattarsi alla lunghezza del contenuto
   senza mai far sparire nulla oltre lo schermo, e dovrebbe essere ridimensionabile in autonomia.
3. Dubbio se gli speedwalk gestiscano correttamente istruzioni con virgole/parole multiple tra le
   direzioni, es. `(paul, da astral) u,n,2w,n,u,enter pool,4n,3w,6s`.
4. C'è ancora una "colonna nera" a sinistra: chiesto se serve a qualcosa o va rimossa.

Azioni:

- **Target spell (punto 1)**: verificato in `src/spell_parser.cpp` (repo `Server`,
  `ACTION_FUNC(do_cast)`, riga ~1797-1824) che dopo l'apice di chiusura del nome spell il gioco
  legge il resto della riga come nome del bersaglio (`argument = one_argument(argument, name)`,
  poi cerca `name` tra i personaggi visibili nella stanza). `NebbieDash.cmdQuickCast` ora accetta
  un terzo parametro opzionale `target`; il click da pannello spell lo passa sempre uguale a
  `NebbieDash.currentChar` (il nome mostrato nel titolo "Spell attivi — NomeChar"). Per le spell
  "solo se stessi" il bersaglio esplicito è ridondante ma innocuo (il server lo ignora). Il lancio
  manuale via alias `c`/`r`/`m <nome>` NON viene toccato (nessun target automatico aggiunto lì: se
  l'utente vuole bersagliare qualcun altro digitando a mano, resta libero di scrivere il nome dopo
  la spell come già faceva prima, il motore alias tratta comunque tutto il testo dopo il prefisso
  come un'unica stringa/nome spell — comportamento preesistente e già approvato, non cambiato qui).
- **Larghezza automatica (punto 2)**: aggiunta `NebbieDash.computeContentMaxChars()` che calcola,
  scorrendo i dati correnti (non il testo già scritto nella console, per evitare un doppio giro di
  cecho), quanti caratteri servono per la riga più lunga tra: titoli pannello, posizione/oggetto
  equip (già troncato a `itemMaxLen`), nome spell + tick, descrizione+anteprima direzioni speedwalk
  (nuovo `NebbieDash.speedwalkPreviewMaxLen = 60`, solo per la visualizzazione: l'esecuzione al
  click usa sempre la lista passi completa). `NebbieDash.applyAutoWidth()` converte i caratteri in
  pixel con `calcFontSize(fontSize)` (https://wiki.mudlet.org/w/Manual:UI_Functions#calcFontSize,
  restituisce larghezza/altezza media di un carattere per una dimensione di font data) e clampa il
  risultato tra `autoWidthMin=180` e il 60% di `getMainWindowSize()`, cosi facendo la colonna non
  può mai "sforare" lo schermo. Chiamata a inizio `refreshDashboard()`, prima di riposizionare le 3
  miniconsole. **Ridimensionamento manuale**: il comando `nwidth <numero>` esisteva già (round 5)
  ma restava sovrascritto ad ogni refresh perché l'auto-resize non era ancora implementato; ora
  impostare `nwidth <n>` disattiva esplicitamente la modalità automatica (`NebbieDash.autoWidth =
  false`) cosi la scelta dell'utente non viene più annullata al refresh successivo; `nwidth auto`
  riattiva l'adattamento automatico. `nlayout` (reset totale) torna sempre alla modalità automatica.
- **Virgole/istruzioni multi-parola negli speedwalk (punto 3)**: **nessun bug trovato**. La
  descrizione tra parentesi è già estratta con un pattern non-greedy fino alla prima `)` chiusa
  (`^%((.-)%)%s*(.+)$`), quindi una virgola dentro le parentesi (es. "paul, da astral") non confonde
  il parser. Ogni token separato da virgola che non inizia con un numero (es. "enter pool", che
  contiene uno spazio) non soddisfa il pattern conta+direzione `^(%d+)(%a+)$` e viene quindi inviato
  così com'è, per intero, come singolo passo — esattamente il comportamento desiderato. Aggiunto un
  test dedicato in `smoke_test_parsing.lua` con l'esempio esatto dell'utente
  (`(paul, da astral) u,n,2w,n,u,enter pool,4n,3w,6s` → 20 passi,
  `u,n,w,w,n,u,"enter pool",n,n,n,n,w,w,w,s,s,s,s,s,s`): PASS.
- **Colonna nera a sinistra (punto 4)**: questo package non ha mai chiamato `setBorderLeft` (usa
  solo `setBorderRight`). I bordi in Mudlet sono un'impostazione di profilo persistente, non legata
  a un singolo script: se un package precedente (verosimilmente `nebbie-play-all`, disinstallato
  dall'utente in Fase 0) aveva impostato un bordo sinistro, disinstallare quel package NON lo
  ripristina a 0 automaticamente. Aggiunto `setBorderLeft(0)` esplicito in `initGUI()` per azzerarlo
  in modo difensivo, indipendentemente da chi l'avesse impostato. Se il problema persistesse anche
  dopo l'aggiornamento, è probabile un widget residuo creato in una sessione Mudlet precedente (non
  persistente tra riavvii): richiede un riavvio completo di Mudlet, non solo un `nresync`/reload
  profilo, per essere verificato/escluso.
- **Verifica**: `luac -p` OK. Aggiunto 4° test automatico dedicato (speedwalk con virgola nella
  descrizione + istruzione multi-parola) — 33/33 test totali OK. Versione alzata a 1.2.0.
  Rigenerato `.mpackage`.
- **Non ancora verificato in Mudlet reale**: comportamento effettivo dell'auto-resize a runtime
  (in particolare dopo un ridimensionamento della finestra di Mudlet, dove `getMainWindowSize()`
  potrebbe essere temporaneamente non aggiornato — mitigato dallo stesso pattern `tempTimer(0,...)`
  già usato per `sysWindowResizeEvent`), ed effettiva scomparsa della colonna nera a sinistra.

---

## 2026-08-09 — Feedback round 7 (post-1.2.0): icona/descrizione package, layout equip a sinistra, slot vuoti, slot 22

Feedback utente testuale (traduzione dei punti):

1. L'mpackage installato non ha un'icona nella schermata "Gestione pacchetti" di Mudlet, ne' una
   descrizione interna: va aggiunta, e aggiornata ad ogni release.
2. Manca una barra tra "Spell attivi" e "Speedwalk"; non si riesce a ridimensionare manualmente
   l'altezza delle sotto-colonne.
3. Ora si leggono tutti gli slot ma non segna cosa e' vuoto: va corretto.
4. Per evitare l'affollamento, spostare la colonna equip a sinistra.
5. Preparare uno slot 22 chiamato "simbolo del clan", per ora non visibile.
6. A destra: spell in alto, speedwalk in basso.

Azioni:

- **Icona/descrizione (punto 1)**: verificato nel codice sorgente di Mudlet stesso (workspace
  `mudlet`, non `nebbietest`) come Mudlet legge questi metadati:
  `src/Host.cpp::getPackageConfig()` esegue `config.lua` in una sandbox Lua e registra come
  "packageInfo" ogni variabile globale stringa che definisce; `src/dlgPackageManager.cpp` (righe
  ~513-527) legge da li' `description` (renderizzata come Markdown) e `icon` (cercata nel percorso
  `<nomePackage>/.mudlet/Icon/<icon>` dentro la cartella di destinazione del pacchetto, cioe' la
  radice dello zip). Confermato lo schema concreto confrontando con il pacchetto ufficiale
  `src/packages/echo/` (config.lua con `mpackage/author/icon/title/description/version` + icona
  dentro `.mudlet/Icon/` nello zip). `build-nebbie-complete-dashboard-package.py` ora scrive tutti
  questi campi (nuova funzione `lua_long_string()` per gestire livelli di parentesi lunghe Lua senza
  collisioni) e include l'icona (`docs/mudlet/assets/nebbie-dash-icon.png`, generata) nello zip.
  Verificato che `config.lua` generato e' Lua valido e i campi sono letti correttamente
  (`loadfile` + esecuzione locale). **Promemoria per il futuro**: `PKG_DESCRIPTION` nello script di
  build ha un commento esplicito che ricorda di aggiornarla ad ogni release, dato che l'utente ha
  chiesto proprio questo.
- **Layout equip a sinistra + barra Spell/Speedwalk (punti 2, 4, 6)**: ristrutturato
  `initGUI`/`positionGUI`/`toggleGUI`/`resetLayout`. Equip ora usa `setBorderLeft` da solo, a tutta
  altezza (`NebbieDash.guiWidthEquip`, `NebbieDash.autoWidthEquip`). Spell attivi e Speedwalk
  restano sul bordo destro (`NebbieDash.guiWidthRight`, `NebbieDash.autoWidthRight`), impilati con
  Spell in alto e Speedwalk in basso (come richiesto al punto 6), separati da una `createLabel` di
  4px colorata (`NebbieDashDivider`) usata solo come divisore visivo, non contiene testo. La API Lua
  di Mudlet non espone un modo affidabile per intercettare il trascinamento del mouse su un confine
  tra due miniconsole/bordi (nessuna funzione tipo "onDrag" per bordi/widget nella documentazione
  consultata), quindi il "ridimensionamento manuale" richiesto e' realizzato con un comando invece
  che con il mouse: `nheights <percentuale 10-90>` regola la quota di altezza data a "Spell attivi"
  (il resto va a "Speedwalk"), analogo a come `nwidth` gia' regola le larghezze. Le larghezze
  auto/manuali (round 6) ora sono indipendenti per le due colonne: `computeContentMaxChars()` e'
  stato diviso in `computeEquipMaxChars()`/`computeRightMaxChars()`, `applyAutoWidth()` applica
  entrambe separatamente. `cmdSetWidth` accetta ora un primo argomento opzionale `equip|right`
  (retrocompatibile: senza indicarlo agisce sulla destra, come prima del round 7).
- **Slot vuoti (punto 3)**: aggiunta `NebbieDash.buildEquipRows(data)`, che confronta il **testo**
  della posizione (letto dalla riga `eq`, mai il numero di slot del gioco — la causa del bug fix
  1.0.0/fix 3 era proprio l'uso del numero come chiave) contro l'elenco canonico
  `NebbieDash.EQ_SLOT_ORDER` (le 21 posizioni gia' note, rinominate da `EQ_SLOTS`, che resta come
  alias per compatibilita' con `migrateStore()`). Ogni posizione nota senza un oggetto corrispondente
  viene mostrata come "(vuoto)"; eventuali posizioni riportate dal gioco ma non presenti
  nell'elenco vengono comunque mostrate (mai perse). Gestito anche il caso di etichette duplicate
  (es. le due collane "intorno al collo"): gli oggetti vengono assegnati in ordine di apparizione,
  nessun oggetto perso o duplicato, ma non c'e' modo di sapere con certezza quale dei due slot
  "identici" corrisponda a quale nello specifico. Aggiunti test automatici dedicati
  (`equip rows: ...`) con un personaggio parzialmente equipaggiato (2 slot su 21) per verificare sia
  il conteggio "occupati/vuoti" sia che un eq completo non produca falsi "(vuoto)".
- **Slot 22 "simbolo del clan" (punto 5)**: aggiunto `NebbieDash.EQ_SLOT_CLAN = "simbolo del clan"`,
  escluso di default da `buildEquipRows()` (`NebbieDash.showClanSlot = false`, come richiesto "per
  ora non renderlo visibile"). Nuovo comando `nclanslot <on|off>` per attivarlo quando/se l'utente lo
  vorra' confermare con un `eq` reale.
- **Verifica**: `luac -p` OK. Aggiunti 6 test automatici dedicati (`buildEquipRows`, slot
  parzialmente occupati ed eq completo) — 39/39 test totali OK. Versione alzata a 1.3.0. Rigenerato
  `.mpackage` (ora include anche l'icona, 89.8KB totali contro gli ~11KB delle versioni precedenti).
- **Non ancora verificato in Mudlet reale**: aspetto della barra divisoria e rendering dell'icona
  nella schermata "Gestione pacchetti" (dipende dalla UI reale di Mudlet, non replicabile nel test
  offline), comportamento dell'auto-width indipendente sulle due colonne dopo un ridimensionamento
  della finestra.

---

## 2026-08-09 — Feedback round 8 (post-1.3.0): bersaglio nel lancio manuale c/r/m

Feedback utente: alcuni casi di `c <spell> <bersaglio>` non funzionavano, riportati con log reali:

```
c darkne nom -> Gryffe Olle Gnyffe Snop??? (errore del gioco: sillabe sbagliate)
c dar nom    -> Gryffe Olle Gnyffe Snop???
c heal nom   -> Gryffe Olle Gnyffe Snop???
```

Diagnosi: l'alias `c`/`r`/`m` (design originale, Round 2 fix 4) mette SEMPRE tutto il testo dopo il
prefisso dentro gli apici come un unico nome spell — `c heal nom` diventava `cast 'heal nom'`, non
`cast 'heal' nom`. Il server (`ACTION_FUNC(do_cast)`, `src/spell_parser.cpp`) legge il bersaglio
SOLO come testo dopo l'apice di chiusura (`argument = one_argument(argument, name)`), quindi
`'heal nom'` non e' mai stato un nome spell valido ne' una sintassi con bersaglio. Verificato anche
come il gioco fa il match per abbreviazione (`old_search_block`/`search_block` in
`interpreter.cpp`): e' un semplice confronto per PREFISSO sull'intera stringa (spazi inclusi), non
per parola — motivo per cui non e' possibile determinare in modo affidabile e generale dove finisce
il nome spell e comincia il bersaglio quando entrambi sono scritti senza apici (es. "word of r" e'
un prefisso valido di "word of recall" ESATTAMENTE come "heal" lo sarebbe di un eventuale bersaglio
"heal" — nessuna euristica sulle sole parole può distinguerli con certezza in generale).

Presentate 4 opzioni di sintassi all'utente (automatico su abbreviazione del proprio nome, virgola
esplicita, apici espliciti come fa il gioco, oppure bersaglio solo dal pannello): scelta
**"automatico"**.

Implementato in `NebbieDash.cmdQuickCast()`: se il terzo argomento (`target`, usato dal click sul
pannello Spell attivi) non è passato, l'ultima parola dell'argomento digitato viene confrontata
(prefisso case-insensitive, minimo 2 lettere per evitare falsi positivi su abbreviazioni di 1
lettera come "r" in "word of r") contro il nome del personaggio attivo (`NebbieDash.currentChar`);
se coincide, viene staccata e usata come bersaglio esplicito (il nome COMPLETO del personaggio, non
l'abbreviazione digitata, per evitare ambiguita' con altri personaggi nella stanza con nome simile).
Nessun impatto sul click da pannello (bersaglio gia' esplicito, l'euristica si applica solo quando
`target` è nil) né sul caso storico senza bersaglio.

Limite noto e documentato in USAGE.md: falso positivo raro possibile se un nome personaggio inizia
con le stesse lettere dell'ultima parola di uno spell multi-parola senza bersaglio — accettato
consapevolmente dall'utente scegliendo questa opzione.

**Verifica**: `luac -p` OK. Aggiunti 5 test automatici dedicati con i 3 casi esatti segnalati
dall'utente (`c heal nom`, `c darkne nom`, `c dar nom`) più 2 di non-regressione (`c word of r`
senza bersaglio, click da pannello con bersaglio esplicito invariato) — 44/44 test totali OK.
Versione alzata a 1.3.1. Rigenerato `.mpackage`.

---

## 2026-08-09 — Feedback round 9 (post-1.3.1): bersaglio su un altro personaggio

Feedback utente: l'euristica automatica (round 8) funziona per il proprio personaggio, ma come si fa
a lanciare uno spell su un personaggio DIVERSO da se stessi?

Causa: quel fix era intenzionalmente ristretto al proprio nome per evitare falsi positivi (un
bersaglio arbitrario non verificabile contro nessuna lista nota avrebbe reintrodotto l'ambiguita'
originale con gli spell multi-parola, es. "word of r" avrebbe rischiato di essere letto come spell
"word of" + bersaglio "r").

Soluzione implementata: sintassi esplicita con virgola, che funziona per QUALSIASI bersaglio senza
alcuna ambiguita' (il separatore è inequivocabile, a differenza di un taglio sull'ultima parola):
`c heal, bob` → `cast 'heal' bob`; `r word of recall, bob` → `recall 'word of recall' bob`. La
virgola viene controllata PRIMA dell'euristica sul proprio nome (round 8) e ha sempre precedenza,
anche nel caso limite in cui il bersaglio dopo la virgola sia proprio il personaggio attivo (evita
un bug di interazione tra le due euristiche: se l'euristica sul proprio nome avesse gia' "mangiato"
la parola finale prima del controllo virgola, sarebbe rimasta una virgola residua nel nome spell —
per questo l'ordine dei controlli e' stato invertito rispetto alla prima stesura).

**Verifica**: `luac -p` OK. Aggiunti 3 test automatici dedicati (bersaglio su "bob", spell
multi-parola con virgola, precedenza virgola sul proprio nome) — 47/47 test totali OK. Versione
alzata a 1.3.2. Rigenerato `.mpackage`.

---

## Round 10 — spell che restano rosse, tasto comandi, numero slot equip (2026-08-09)

Feedback utente (3 richieste in un unico messaggio):
1. Dopo aver cliccato uno spell per rilanciarlo (e anche dopo aver eseguito `attrib` manualmente), lo
   spell resta rosso nel pannello invece di tornare verde.
2. Richiesta di un tasto custom nell'interfaccia di Mudlet che mostri una finestra di testo con
   tutti i comandi creati.
3. Richiesta di reintrodurre il numero di riga tra parentesi quadre nel pannello equip, come nel
   testo reale del gioco (fornito nuovo esempio `eq` a conferma, che tra l'altro conferma ancora una
   volta che manca "sulle braccia" tra le posizioni viste finora).

**Punto 1 — analisi**: la logica di sostituzione dati (`finishAttribCapture` sostituisce per intero
`data.spells` con la cattura appena chiusa) e il calcolo del colore (ricalcolato ad ogni
`refreshDashboard()` leggendo `data.spells[].ticks`, non un conto alla rovescia salvato) sono stati
verificati con un nuovo test automatico dedicato (simula un secondo `attrib` con tick piu' alti dopo
un rilancio) e risultano corretti in isolamento. Non essendoci accesso a un'istanza Mudlet reale
collegata al gioco, non è stato possibile riprodurre il sintomo end-to-end. L'ipotesi più probabile,
non confermata (formato completo del blocco `attrib` non ancora verificato al 100%, vedi
REQUIREMENTS.md M5): se una cattura `attrib` non incontra mai una riga vuota o un nuovo prompt
riconosciuti come "fine blocco" (es. per una variante di formato reale diversa da quella vista negli
esempi), resta aperta per sempre e i nuovi tick non vengono mai salvati — coerente col sintomo
("nemmeno dopo attrib").

**Fix difensivo applicato** (non essendo confermata la causa esatta, non si è alterato il parsing
del formato, solo aggiunta una rete di sicurezza): watchdog di inattività (4s, non un timeout fisso
da inizio cattura, per non tagliare a metà una risposta lenta del gioco) su entrambe le catture
eq/attrib. Se non arrivano più righe rilevanti per 4s consecutivi, la cattura si chiude comunque con
quanto raccolto finora, invece di restare bloccata indefinitamente.

**Punto 2 — implementato**: Mudlet non permette di creare/verificare in modo affidabile una vera
voce di toolbar nativa da script (si configura solo dall'editor pacchetti con XML "Action", non
testabile qui senza un'istanza reale) — usata invece una label fluttuante cliccabile ("? Comandi"),
ancorata in cima allo schermo, sempre visibile anche con `ngui` disattivato. Al click apre/chiude una
finestra con l'elenco di tutti i comandi e una breve descrizione (anche da riga di comando con il
nuovo alias `nhelp`).

**Punto 3 — implementato**: ogni riga del pannello equip mostra di nuovo `[NN]` davanti alla
posizione, come richiesto. Per non reintrodurre il bug delle etichette scambiate (fix round
precedente), questo numero è **sempre e solo** la posizione della riga nel nostro elenco fisso
(`EQ_SLOT_ORDER`, stesso ordine ad ogni render), mai il numero di slot riportato dal gioco — quel
numero non è mai stato usato per abbinare oggetti a posizioni e continua a non esserlo.

**Verifica**: `luac -p` OK su tutte le modifiche. Aggiunto test automatico dedicato al punto 1
(risincronizzazione sostituisce, non accumula) — 53/53 test totali OK (verificato con `lua`
standalone, offline). XML del package validato con `xml.dom.minidom`. Versione alzata a 1.3.3.
Rigenerato `.mpackage`. Aggiornati USAGE.md e CHANGELOG.md.

**Nota aperta per l'utente**: se dopo questo fix gli spell continuano a restare rossi, serve un
copia-incolla ESATTO (senza modifiche) dell'output completo di `attrib` dal gioco (dall'intestazione
fino alla riga subito prima del prompt successivo) per capire quale variante di formato il parser
non riconosce ancora — vedi promemoria anche in CHANGELOG.md 1.3.3.

---

## Round 11 — Alias e trigger: proposte di gestione + primo modulo loot/split (2026-08-10)

L'utente conferma che il dashboard è ora soddisfacente e chiede di iniziare a lavorare su alias e
trigger di gioco (esplicitamente lasciati fuori scope nella release 1, vedi REQUIREMENTS.md R15).

**Proposte presentate** (nessuna implementazione prima della scelta dell'utente, per non ripetere
l'errore del vecchio pacchetto — centinaia di alias generati automaticamente, fragile e complesso):
A) file di configurazione per alias semplici (come gli speedwalk); B) stesso principio per trigger
semplici; C) alias/trigger nativi Mudlet creati dall'utente, noi forniamo solo funzioni di supporto;
D) tutto impacchettato nel codice del pacchetto, come i comandi attuali. Raccomandato un ibrido A+D.

**Risposta utente**: approccio ibrido confermato; categoria da affrontare per prima: "combattimento"
(poi chiarito, vedi sotto, essere in realtà loot + split, non attacco/difesa); nessun riutilizzo del
vecchio pacchetto, si riparte da zero come per il resto.

**Chiarimento sulla richiesta reale**: non è "combattimento" in senso stretto (attacco/fuga), ma
raccogliere le monete dal cadavere dopo ogni combattimento e, se in gruppo, dividerle con `split`.

**Ricerca nel codice del server** (`fight.cpp`, `act.comm.cpp`, `interpreter.cpp`) per non inventare
nulla:
- Comandi esistenti confermati: `kill`, `hit`, `flee`, `consider` (combattimento in senso stretto,
  non ancora usati — restano per una fase futura se richiesta), `get`/`take`, `group`, `split`.
- `do_split`: sintassi `split <quantità>`, richiede >=2 membri del gruppo nella stessa stanza,
  altrimenti "Ma cosa vuoi dividere che sei solo." — quindi anche un nostro errore di rilevamento
  gruppo verrebbe comunque rifiutato in modo innocuo dal server, non rischia di regalare oro a
  qualcuno per sbaglio.
- Cadavere di un mostro non-morto (`IsUndead`): nome oggetto `"dust pile bones"`, descrizione "A
  pile of dust and bones is here." — conferma che il "pile of bones" citato dall'utente è reale nel
  codice. Cadavere normale: nome oggetto `"corpo <nome mostro>"` (italiano).

**Testi reali forniti dall'utente** (base esatta delle regex, vedi Q&A.md Round 11 per il dettaglio
completo): sintassi di loot `get all.coin corp`/`get all.coin pile`; riga di successo `C'erano N
monete.`; righe di fallimento `Non vedi nessun corp.`/`Non vedi nessun pile.`; risposta di `group` da
soli (`But you are a member of no group?!`) e in gruppo (`Your group "..." consists of:`).

**Design scelto**: riprendere lo stesso pattern "cattura a trigger temporanei con watchdog di
inattività" già usato per eq/attrib (vedi Round precedente), applicato a un flusso più corto:
1. Nuovo alias `nloot` invia `get all.coin corp` e, mezzo secondo dopo, `get all.coin pile` (uno
   dei due fallirà sempre in modo innocuo con "Non vedi nessun ...", non richiede gestione).
2. Un trigger permanente e leggero (shield su substring fissa `"C'erano"`, stesso principio del
   trigger prompt `" M: "` già presente) intercetta l'importo raccolto, funziona sia che il loot
   parta da `nloot` sia che l'utente digiti i comandi a mano.
3. Se `nautosplit` è attivo (default on, come richiesto — "sempre, subito dopo ogni loot riuscito"),
   invia `group` e arma due trigger temporanei (normalmente disabilitati, stesso principio delle
   catture eq/attrib) che ascoltano rispettivamente la risposta "da soli" e quella "in gruppo";
   quest'ultima fa scattare `split <importo appena raccolto>`. Watchdog di 4s in caso di risposta
   inattesa (stesso meccanismo già introdotto per eq/attrib in questo stesso round).
4. Nuovi comandi manuali: `nautosplit <on|off>` (toggle) e `nsplit <numero>` (split manuale, utile
   anche per test/casi limite).

**Aperto/rimandato**: rilevare automaticamente la FINE del combattimento (per lanciare `nloot` da
solo, così l'utente non deve digitarlo) richiede il testo reale del messaggio di vittoria/morte del
mostro — non ancora fornito, richiesto ma rimandato dall'utente ("later"/deferred nella conversazione
precedente).

**Verifica**: `luac -p` OK su core.lua e sul test. Aggiunti 8 test automatici dedicati (loot
riconosciuto, comando "group" inviato solo con importo valido, comportamento "da soli" vs "in
gruppo", rispetto del flag `nautosplit`, `nsplit` manuale) — 61/61 test totali OK (verificato con
`lua` standalone, offline). XML del package validato con `xml.dom.minidom`. Versione alzata a 1.4.0.
Rigenerato `.mpackage`. Aggiornati USAGE.md, CHANGELOG.md, Q&A.md.

---

## Round 12 — loot automatico alla fine del combattimento (2026-08-10)

L'utente fornisce il testo reale che era rimasto aperto nel Round 11 ("Aperto/rimandato"):

```
Uno Spazzino is dead! R.I.P.
La tua parte di esperienza e' di 1 punti.

Una sentinella is dead! R.I.P.
La tua parte di esperienza e' di 1047 punti.

Un Ubriacone is dead! R.I.P.
La tua parte di esperienza e' di 0 punti.
```

**Decisione di design**: usare come segnale la riga `"La tua parte di esperienza e' di N punti."`
(shield su substring fissa "La tua parte di esperienza", stesso principio degli altri trigger a riga
singola) invece di `"X is dead! R.I.P."`, perche' quest'ultima si vedrebbe anche per uccisioni a cui
non hai contribuito (es. un altro giocatore/gruppo che uccide qualcosa nella tua stessa stanza),
mentre la riga sull'esperienza compare solo quando hai effettivamente partecipato — anche con 0
punti, quindi il pattern non richiede N>0.

**Implementazione**: nuovo trigger permanente `onCombatEndLine()` che, se `nautoloot` e' attivo
(default **on**), chiama la stessa `cmdLoot()` gia' usata dall'alias manuale `nloot` (nessuna
duplicazione di logica). Nuovo comando `nautoloot <on|off>` per disattivarlo separatamente da
`nautosplit` (i due restano indipendenti: puoi per esempio voler raccogliere da solo ma non
dividere, o viceversa).

**Verifica**: `luac -p` OK. Aggiunti 4 test automatici dedicati (loot scattato dalla riga esperienza,
anche con 0 punti, nessuna azione dalla sola riga "is dead!", rispetto del flag `nautoloot`) —
65/65 test totali OK. XML validato. Versione alzata a 1.4.1. Rigenerato `.mpackage`. Aggiornati
USAGE.md, CHANGELOG.md, Q&A.md.

**Stato attuale del modulo loot/split**: con questo fix il flusso e' ora **interamente automatico**
dal punto di vista dell'utente (nessun comando manuale richiesto dopo un combattimento), salvo
disattivazione esplicita con `nautoloot off`/`nautosplit off`.

---

## Round 13 — due bug + rialzarsi/recupero arma/ripetizione comandi (2026-08-10)

**Bug 1 (character switch stale)**: l'utente segnala che cambiando personaggio, lanciare uno spell
su se stesso finiva sul personaggio PRECEDENTE. Analisi del codice (`setCurrentCharacter`/
`onPromptLine`): `NebbieDash.currentChar` viene aggiornato solo quando arriva un prompt valido, e un
prompt arriva solo DOPO che il gioco risponde a un comando — quindi tra una riconnessione con un
nuovo personaggio e il primo comando digitato (incluso un click su uno spell nel pannello, che
potrebbe ancora mostrare i dati del vecchio personaggio se il pannello non si e' ancora aggiornato),
`currentChar` restava silenziosamente quello vecchio.

**Fix applicato**: `onConnectionEvent()` ora azzera subito `NebbieDash.currentChar` (e ridisegna il
pannello, che mostrera' "nessun personaggio rilevato" finche' non arriva un prompt fresco) invece di
limitarsi a impostare un flag interno. Cosi' un'azione fatta nella finestra "morta" tra riconnessione
e primo prompt fallisce in modo sicuro e visibile (nessun bersaglio aggiunto dall'euristica sul nome,
vedi test dedicato) invece di colpire silenziosamente il personaggio sbagliato.

**Bug 2 (split senza gruppo)**: l'utente segnala uno split scattato durante un combattimento in
solitaria. Causa non confermata con certezza (richiesto un log reale della sequenza, non ancora
fornito dall'utente) — l'ipotesi piu' probabile e' che qualche testo di gioco non correlato
contenesse per caso la sottostringa "Your group " usata come trigger, dato che i due controlli
gruppo (`_groupSoloTrig`/`_groupHeaderTrig`) usavano `tempTrigger` a substring libera (non ancorata a
inizio riga). **Fix difensivo applicato** (in attesa di conferma della causa esatta): entrambi i
trigger sono ora `tempRegexTrigger` ancorati a inizio riga (`^But you are a member of no group` e
`^Your group "` — con la virgoletta di apertura inclusa per essere ancora piu' specifici), costo
trascurabile perche' restano disabilitati tranne il breve intervallo del controllo dopo un loot.

**Nuova funzionalita' — ripetizione comandi generica**: richiesto un modo per Mudlet di interpretare
`.4s` come l'invio di "s" quattro volte, utilizzabile per QUALSIASI comando (non solo movimenti).
Implementato come nuovo alias con regex `^\.(\d+)\s*(.+)$` (accetta sia `.4s` che `.4 s`) che chiama
`NebbieDash.cmdRepeat(count, cmd)`, riusando la stessa pausa configurabile gia' usata per gli
speedwalk (`NebbieDash.speedwalkDelay`) per non intasare la coda comandi del gioco. Limite di
sicurezza a 99 ripetizioni per un refuso tipo `.400s`.

**Nuovi trigger di combattimento "minimi"** (l'utente chiarisce di volere solo questi due, non un
sistema di combattimento completo):
1. **Rialzarsi da terra**: testo reale `"Illyari schiva il tuo urto. Inciampi e cadi per terra."` —
   shield su substring fissa `"Inciampi e cadi per terra."`, invia `stand`. L'utente precisa che
   questo e' solo UNO dei possibili messaggi di caduta: eventuali altri testi andranno aggiunti solo
   quando forniti (non inventati per analogia).
2. **Recupero arma dopo disarmo**: testo reale `"Ti disarmano e la Flamberga di Boris vola dalla tua
   presa."` — il nome dell'arma viene catturato DIRETTAMENTE da questa riga (non dal pannello equip,
   che potrebbe essere disallineato), poi ripulito dagli articoli/preposizioni italiane con una
   nuova funzione `NebbieDash.extractItemKeywords()` per ottenere le parole chiave con cui il gioco
   identifica l'oggetto — confermato dall'utente che "la Flamberga di Boris" → "flamberga boris"
   sono le parole che funzionano davvero in gioco per quest'arma. Segue `get <parole chiave>` e,
   mezzo secondo dopo, `wield <parole chiave>` (comando confermato nel codice del server,
   `interpreter.cpp`, per lo slot "impugnato").

Entrambi i nuovi trigger sono disattivabili singolarmente (`nautostand off`/`nautodisarm off`,
default **on** per entrambi).

**Verifica**: `luac -p` OK su core.lua e sul test. Aggiunti 15 test automatici dedicati (reset
personaggio alla riconnessione, quickcast sicuro senza personaggio attivo, rialzarsi automatico,
estrazione parole chiave da un nome oggetto incluso il caso con apostrofo, recupero arma dopo
disarmo, validazione della ripetizione comandi) — 79/79 test totali OK (verificato con `lua`
standalone, offline). XML del package validato con `xml.dom.minidom` (regex dell'alias di
ripetizione verificata testualmente nell'XML generato). Versione alzata a 1.5.0. Rigenerato
`.mpackage`. Aggiornati USAGE.md, CHANGELOG.md, Q&A.md.

**Nota aperta per l'utente**: per confermare (o escludere) la causa esatta del Bug 2, se lo split
indesiderato si ripresenta anche dopo questo fix difensivo, serve il log reale della sequenza
(cosa hai digitato, cosa ha risposto il gioco a `group`, e il messaggio di split che hai visto).

---

## Round 15 (2026-08-10): bug "nessun personaggio rilevato" + macro fame/sete

**Segnalazione utente**: "la dashboard non sta rilevando alcun personaggio", con il prompt reale
incollato:

```
Mirari H:655/655 M:533/533 V:271/271 X:284016936 - */* - *-* - [[------T----]] - G:38267520 >>
```

**Causa individuata**: questo e' un SECONDO formato di prompt reale, diverso da quello confermato in
Round 3 (`NomiyaMaki H: 747/747 M: 532/532 ... x:-238860738 *:* *:* [[D]] G:3449502 >>`). Le
differenze: nessuno spazio dopo i due punti (`M:533/533` invece di `M: 532/532`), `X:` maiuscolo, e
separatori aggiuntivi `" - "` tra i campi (invece di `*:* *:*`). Verificando `parsePromptLine()` con
questo testo, la regex di parsing gestiva GIA' correttamente entrambi i formati (spazio opzionale
`%s*`, `[Xx]` case-insensitive) — il problema era altrove: lo "shield" del trigger che chiama
`onPromptLine()` era la sottostringa fissa `" M: "` (con lo spazio finale), che non compare MAI nel
secondo formato (`"M:533/533"`, senza spazio dopo i due punti). Risultato: per un personaggio con
questo formato di prompt, `onPromptLine()` non veniva MAI chiamata, quindi nessun personaggio veniva
mai rilevato per l'intera sessione — esattamente il sintomo segnalato.

**Fix applicato**: shield ristretto a `" M:"` (senza lo spazio finale), che matcha entrambi i
formati. Nessun rischio di falsi positivi aggiuntivi: lo shield serve solo a decidere QUANDO provare
il parsing preciso (che resta la regex completa in `parsePromptLine()`, che ritorna `nil` se la riga
non e' davvero un prompt).

**Seconda richiesta (nuova funzionalita')**: macro configurabile per fame/sete, con testi reali
forniti dall'utente per il trigger (`"Hai Fame."` / `"Hai sete."`) e per l'oggetto coinvolto (`"[18]
<sulla schiena> Borsa Inesauribile dei Korred"`). L'utente chiede esplicitamente che la parola chiave
dello zaino venga derivata automaticamente (come già fatto per il recupero arma dopo disarmo), ma
che il resto della sequenza (es. `"rem korred, get cornucopia korred, .5 drink cornu, put cornu
korred, wear korred"`) possa variare "a seconda del personaggio" — quindi non e' derivabile
automaticamente nella sua interezza (il nome dell'oggetto da bere dentro lo zaino non ha nessuna
relazione meccanica col nome dello zaino).

**Decisione di design** (nessuna domanda necessaria, coerente con le decisioni precedenti su
speedwalk/file di configurazione): stesso principio degli speedwalk — un file di testo scritto
dall'utente (`nebbie-hunger-macros.txt`, stessa cartella profilo), una riga per personaggio
(`NomePersonaggio: comando1, comando2, ...`), con un segnaposto `{zaino}` sostituito automaticamente
dalla parola chiave dell'oggetto nello slot equip `"sulla schiena"` (stessa funzione
`extractItemKeywords()` già usata per il recupero arma). Dentro la macro si può usare la stessa
sintassi `.N comando` della ripetizione generica per un singolo passo (nuova funzione
`NebbieDash.expandMacroSteps()`, che interpreta questa sintassi via script senza passare dall'alias
di Mudlet, che intercetta solo l'input digitato dall'utente). Comando `nautofeed <on|off>` (default
**on**) e `nhungermacros` per ricaricare il file.

**Verifica**: `luac -p` OK su core.lua. Aggiunti 22 test automatici dedicati (parsing del secondo
formato di prompt, rilevamento del personaggio "Mirari" tramite il trigger corretto, estrazione
parole chiave dello zaino, espansione dei passi `.N`, sostituzione del segnaposto `{zaino}`, casi
senza macro configurata e con `nautofeed off`) — 97/97 test totali OK (verificato con `lua`
standalone, offline). Versione alzata a 1.6.0. Rigenerato `.mpackage`. Aggiornati USAGE.md,
CHANGELOG.md.

---

## Round 16 (2026-08-10): "il trigger non funziona" — analisi log reali dalla macro fame/sete

**Segnalazione utente**: incollato il log completo del gioco dopo l'attivazione della macro
fame/sete (v1.6.0). Sintomi nel log: `"Smetti di usare Borsa Inesauribile dei Korred."` (il primo
`rem` riesce), seguito da `"Non lo stai usando."` (un SECONDO `rem` che fallisce perché il primo ha
già tolto lo zaino), poi `"Borsa Inesauribile dei Korred non contiene nessun cornucopia."` **due
volte identiche**, poi una serie di `"Non hai nulla del genere con te!"`/`"Non hai nessun cornu."`,
poi `"Non puoi indossare nulla su un inesauribile."` **due volte identiche**.

**Causa 1 (confermata dal pattern duplicato)**: nel log, `Hai Fame.` e `Hai sete.` arrivano come due
righe separate nello stesso blocco di output (il gioco controlla fame e sete insieme). Essendo due
trigger DISTINTI (nessun prefisso comune utile come shield unico), entrambi scattavano e chiamavano
`onHungerThirstLine()` → `runHungerMacro()` **indipendentemente**, avviando la stessa sequenza di 9
comandi (via `tempTimer`) **due volte in parallelo**, con gli stessi ritardi (0, 0.35s, 0.7s, ...).
Le due sequenze si accavallavano: il secondo `rem` arrivava dopo che il primo aveva già tolto lo
zaino (→ "Non lo stai usando."), e così via per `get`/`wear`, spiegando esattamente ogni messaggio
duplicato visto nel log.

**Fix**: aggiunto un cooldown (`NebbieDash.hungerMacroCooldownSec = 3`) tra un'esecuzione della
macro e la successiva — la seconda chiamata (stesso secondo, `os.time()`) viene silenziosamente
ignorata.

**Causa 2 (bug distinto, non duplicazione)**: l'ultimo comando (`wear {zaino}`) falliva con `"Non
puoi indossare nulla su un inesauribile."` — un messaggio che tratta "inesauribile" (una delle parole
non-stopword estratte dal nome completo "Borsa Inesauribile dei Korred") come se fosse una posizione
del corpo, non parte del nome dell'oggetto. La causa e' che `{zaino}` veniva sostituito con TUTTE le
parole chiave estratte ("borsa inesauribile korred"), non con una sola: passare più parole a `wear`
confonde il parser del gioco. Da notare che l'esempio ORIGINALE fornito dall'utente usava sempre una
singola parola ("korred"), non la frase estratta completa — coerente col fix.

**Fix**: nuova funzione `NebbieDash.lastKeyword()` che prende solo l'ultima parola della frase
estratta; usata per la sostituzione di `{zaino}` (non tocca `extractItemKeywords()` usata per il
recupero arma dopo disarmo, dove 2 parole sono già confermate funzionanti dall'utente).

**Nota per l'utente (non un bug del pacchetto)**: nel log, `"Borsa Inesauribile dei Korred non
contiene nessun cornucopia."` indica che l'oggetto dentro lo zaino non si chiama davvero
"cornucopia" per questo personaggio — l'esempio originale (`cornucopia`/`cornu`) era solo
illustrativo. Serve controllare il nome REALE dell'oggetto dentro lo zaino (es. guardando dentro con
un comando apposito) e aggiornare `nebbie-hunger-macros.txt` di conseguenza, poi `nhungermacros` per
ricaricare.

**Verifica**: `luac -p` OK. Aggiunti 4 test dedicati (estrazione a singola parola, sostituzione
corretta, cooldown). 101/101 test totali OK (offline, `lua` standalone). Versione alzata a 1.6.1.
Rigenerato `.mpackage`. Aggiornati USAGE.md, CHANGELOG.md.

---

## Round 17 (2026-08-10): keyword condivise, fix reinstall, spell conosciute persistenti

**Tre richieste dell'utente** in risposta al fix precedente:

1. "l'oggetto da cui prendere la cornucopia potrà cambiare, non sono sicuro sia una buona idea
   prendere solo l'ultima parola. e se assegnassimo delle key predefinite per oggetto in modo da
   condividerle con tutti i personaggi?"
2. "è possibile fare in modo che non vada rilanciato tutte le volte mudlet ogni volta che carico un
   nuovo package?"
3. "possiamo anche fare in modo che le spell che mi lancio rimangano inattive in rosso quando entro
   con il personaggio relativo e che si sincronizzino quando esguo attrib?" (con esempio dettagliato
   del comportamento desiderato per due personaggi diversi).

**Fix 1 — parole chiave per oggetto condivise**: nuovo file `nebbie-item-keywords.txt` (una riga
per oggetto per NOME, non per personaggio — un dato oggetto ha sempre le stesse parole chiave in
game). Nuova funzione `NebbieDash.resolveItemKeywords()`, punto unico usato sia dal recupero arma
dopo disarmo sia dallo zaino delle macro fame/sete: se l'oggetto ha una riga nel file, si usa quella
per intero (l'utente sa che funziona); altrimenti si ricade sull'euristica automatica (con
`lastKeyword()` applicato solo in questo secondo caso, per il motivo gia' spiegato nel Round 16).
Comando `nitemkeywords` per ricaricare.

**Fix 2 — causa reale del "serve riavviare Mudlet"**: analizzando l'architettura di boot del
pacchetto (due Script XML: uno "core" senza event handler che si esegue AD OGNI caricamento/
installazione, e uno "boot" agganciato a `sysLoadEvent` che chiama `NebbieDash.boot()`), si e'
scoperto che `NebbieDash.boot()` veniva chiamato SOLO dallo script legato a `sysLoadEvent` — che
non rifira affatto durante una semplice reinstallazione del pacchetto a meta' sessione (scatta solo
al vero avvio/caricamento del profilo). Il codice (definizioni di funzione) si aggiornava comunque
ad ogni reinstallazione (perche' lo script "core" lo esegue sempre), ma `boot()` — che chiama
`installTriggers()` per creare/aggiornare i trigger dinamici — non veniva mai richiamato senza un
riavvio completo. In piu', anche quando richiamato manualmente (es. con `nfix`), `installTriggers()`
aveva un secondo guard "una volta per sempre a sessione" (`_triggersInstalled`) che bloccava
comunque qualunque nuova registrazione dopo il primissimo avvio.

**Fix applicato**: (a) `NebbieDash.boot()` viene ora chiamato ANCHE alla fine dello script "core"
(quindi ad ogni [re]installazione del pacchetto, non solo al vero avvio del profilo); (b)
`installTriggers()`/nuova `teardownTriggers()` sono ora idempotenti — ad ogni chiamata smontano
(`killTrigger`) gli eventuali trigger dinamici di un boot precedente e li ricreano da zero; (c)
`boot()` stesso ha un piccolo dedupe temporale (2s) solo per evitare un doppio messaggio "pronto" se
per caso venisse chiamato due volte nello stesso istante (es. al vero avvio di Mudlet, se sia lo
script "core" sia l'evento `sysLoadEvent` scattano nello stesso momento).

**Fix 3 — spell "conosciute" persistenti**: nuovo campo persistente `data.knownSpellOrder` (elenco
CUMULATIVO, mai sostituito, di tutti i nomi di spell mai visti attivi per un personaggio) separato
da `data.activeSpells` (mappa nome -> tick, SOLO le spell confermate attive dall'ultimo `attrib`).
`finishAttribCapture()` ora aggiunge eventuali nomi nuovi a `knownSpellOrder` e sostituisce per
intero `activeSpells`; il pannello itera su `knownSpellOrder` (sempre visibile/cliccabile) e colora
in verde solo le voci presenti in `activeSpells` (sopra la soglia `nspellwarn`), rosso tutte le
altre (comprese quelle mai confermate o scadute). `setCurrentCharacter()` azzera `activeSpells` ad
ogni cambio di personaggio EFFETTIVO (non su refresh ripetuti dello stesso personaggio), cosi' al
rientro su un personaggio le sue spell conosciute appaiono tutte rosse finche' non si rilancia
`attrib` — esattamente il comportamento descritto dall'utente per Mirari e NomiyaMaki. Aggiunta
`migrateStore()` per costruire `knownSpellOrder`/`activeSpells` dai vecchi `data.spells` salvati da
installazioni precedenti, senza perdere dati.

**Verifica**: `luac -p` OK. Aggiunti/aggiornati test dedicati (override di parole chiave con
precedenza sull'euristica, idempotenza di `installTriggers()`/`teardownTriggers()`/`boot()`, elenco
spell cumulativo che non sparisce, azzeramento dello stato attivo al cambio personaggio) — 120/120
test totali OK (offline, `lua` standalone). Versione alzata a 1.7.0. Rigenerato `.mpackage`
(validato anche l'XML generato con `xml.dom.minidom`, confermando 2 Script e la chiamata a
`NebbieDash.boot()` presente in entrambi). Aggiornati USAGE.md, CHANGELOG.md.

---

## 2026-08-10 — Gestione armi (v1.8.0)

**Richiesta utente**: pannello con elenco delle armi possedute (impugnate almeno una volta), col
tipo di danno (slash/blunt/pierce), cliccabile per cambiare arma con la sequenza
`rem`/`put`/`get`/`wield`. Dato bloccante richiesto e fornito dall'utente: output REALE di
`identify` su un'arma —

```
Pronunci le parole, 'identify'.
La conoscenza ti pervade:
Oggetto: 'spada elf slayer', Tipo di Oggetto WEAPON
...
Dado di danno: '3d5'
Tipo di danno: 'SLASH'
Caratteristiche: ...
```

**Decisioni prese** (nessuna inventata senza base):
- L'individuazione dell'arma impugnata (per il wield) usa il messaggio "Impugni <nome arma>."
  confermato dall'utente tramite risposta a scelta multipla (non un copia-incolla letterale — se in
  gioco il testo risultasse diverso andrà corretto).
- `identify` NON viene mai inviato in automatico dal pacchetto: costa una "ondata di stanchezza" (si
  presume mana/energia), quindi resta un comando che l'utente esegue di propria iniziativa quando
  vuole conoscere il tipo di danno di un'arma. Il pacchetto si limita ad "ascoltare" le due righe di
  risposta (`Oggetto: '...', Tipo di Oggetto WEAPON` e `Tipo di danno: '...'`) con due trigger a
  riga singola che si passano il dato tra una riga e l'altra (stesso principio degli altri trigger a
  riga singola del pacchetto, niente capture multi-riga con inizio/fine essendo bastano due righe
  fisse).
- La keyword "euristica" derivata dal nome mostrato al wield e quella "canonica" riportata da
  `identify` raramente coincidono parola per parola (es. "Spada degli Elfi Assassina" al wield vs
  "spada elf slayer" da identify): il matching tra le due usa una euristica per PAROLA IN COMUNE
  (`keywordsOverlap`), non l'uguaglianza esatta — se `identify` la aggiorna, la keyword "canonica" da
  identify sostituisce quella euristica (piu' affidabile, viene dal gioco stesso).
- Il cambio arma con un click riusa lo stesso zaino ("sulla schiena") e lo stesso criterio
  override/euristica delle altre automazioni (`nitemkeywords`, vedi sopra): nessuna nuova sorgente di
  keyword introdotta, un solo file di override condiviso per tutto il pacchetto.
- Layout: nuovo pannello "Armi" nella colonna sinistra, SOTTO l'Equip (richiesto esplicitamente),
  con divisore e proporzione regolabile (`nleftheights`), stesso pattern gia' usato per
  Spell/Speedwalk a destra (`nheights`).

**Verifica**: `luac -p` OK. Aggiunti test dedicati (wield popola la lista, identify aggiorna/crea
un'entry, identify su oggetto non-WEAPON ignorato, `keywordsOverlap`, `cmdSwapWeapon` sui casi
limite) — 131/131 test totali OK (offline, `lua` standalone). Versione alzata a 1.8.0. Rigenerato
`.mpackage` (XML validato con `xml.dom.minidom`, `config.lua` validato con `luac -p`). Aggiornati
USAGE.md, CHANGELOG.md.

---

## 2026-08-10 — Bug al primo avvio dopo installazione pulita (v1.8.1)

**Segnalazione utente**: al primo avvio dopo un'installazione pulita del pacchetto (disinstalla +
riavvia Mudlet + installa, esattamente il flusso di test suggerito per il pannello Armi), compare
l'errore:

```
[NebbieDash] errore boot: [string "Script: nebbie-complete-dashboard-package -..."]:1: attempt to index global 'NebbieDash' (a nil value)
```

**Analisi**: il messaggio riporta `:1:` (errore alla riga 1 del chunk) — la riga 1 del chunk "core"
(molto più lungo) non potrebbe mai generare questo errore così presto; il chunk che INIZIA con
`local ok, err = pcall(function() NebbieDash.boot() end)` alla riga 1 è invece lo script "boot",
agganciato a `sysLoadEvent` e composto SOLO da `boot_call` (vedi `build-nebbie-complete-dashboard-
package.py`). Questo conferma che lo script "boot" si è eseguito PRIMA che lo script "core" avesse
anche solo definito la tabella globale `NebbieDash` (`NebbieDash = NebbieDash or {}`, riga 18 di
`nebbie-complete-dashboard-package-core.lua`) — Mudlet non garantisce l'ordine di esecuzione tra due
`<Script>` distinti nello stesso file XML del pacchetto all'installazione/caricamento iniziale (il
nome "boot" precede alfabeticamente "core", ordinamento sospetto ma non confermato con certezza
assoluta — la causa esatta dell'ordine non è documentata pubblicamente da Mudlet, il fix però non
dipende dal conoscerla). Il bug esisteva già dalla 1.7.0 (che ha introdotto lo script "boot"
separato) ma non era mai stato notato perché i test precedenti reinstallavano il pacchetto SENZA
riavviare Mudlet, mantenendo `NebbieDash` già definita in memoria da un caricamento precedente della
sessione.

**Fix applicato**: aggiunta una guardia `if type(NebbieDash) ~= "table" then return end` in testa a
`boot_call` (usato identico in entrambi gli script). All'avvio iniziale, se lo script "boot" si
esegue per primo, si limita a non fare nulla (nessun errore) — il vero `boot()` arriva comunque
dalla chiamata identica appesa in fondo allo script "core", che nello stesso chunk ha già definito
`NebbieDash` prima di quel punto. Per i successivi eventi `sysLoadEvent` reali durante la sessione
(riconnessioni), `NebbieDash` esiste sempre già a quel punto, quindi la ridondanza difensiva
originale resta intatta.

**Verifica**: estratto lo script "boot" isolato dall'XML generato ed eseguito con `NebbieDash` non
definito (`lua /tmp/boot_only.lua`) — nessun errore, confermando il fix. `luac -p` OK, XML validato
con `xml.dom.minidom`, 131/131 test offline OK (nessun test nuovo necessario: il bug era
nell'orchestrazione tra i due `<Script>` del pacchetto, non nella logica Lua testata offline).
Versione alzata a 1.8.1. Aggiornato CHANGELOG.md.

---

## 2026-08-10 — Causa REALE: errore di sintassi Lua nel build script (v1.8.2)

**Segnalazione utente**: dopo il fix precedente (v1.8.1, guardia sull'ordine "boot"/"core"), l'utente
riporta un sintomo ancora peggiore: "non appare nulla e non funziona nemmeno nresync. non compare
nemmeno l'help" — nessun errore visibile stavolta, ma nessuna funzionalità del pacchetto attiva.

**Analisi**: la guardia introdotta in v1.8.1 era corretta ma insufficiente: nascondeva l'ERRORE
visibile senza risolvere la causa di fondo. Per riprodurre il problema fedelmente, ho estratto il
testo ESATTO dei due `<script>` dal file XML generato (non il file `core.lua` isolato, che da solo
compila benissimo) e li ho eseguiti con `lua` standalone e i mock usati dal test offline. Risultato:

```
core ok=	false	core_extracted.lua:2161: unexpected symbol near '\'
```

Riga 2161 del testo REALMENTE spedito nel pacchetto conteneva:

```
end
\n\nif type(NebbieDash) ~= "table" then
```

cioè il testo letterale a 4 caratteri `\n\n` (backslash, n, backslash, n) subito dopo `end`, SENZA
alcun vero a-capo — non un errore di battitura recente, ma un bug preesistente in
`build-nebbie-complete-dashboard-package.py` (riga che unisce `core_code` e `boot_call`):
nell'f-string Python `core_code + "\\n\\n" + boot_call`, la sequenza `"\\n\\n"` è Python per "due
backslash letterali seguiti da n", non per "due a-capo" (che in Python si scrive `"\n\n"`, un solo
backslash). Introdotto insieme all'unione core+boot_call in v1.7.0 (fix "non serve riavviare
Mudlet"), il bug rendeva lo script principale del pacchetto NON COMPILABILE fin da allora — ma
restava invisibile perché ogni test successivo (incluso quello dell'utente) aveva sempre riutilizzato
una sessione Mudlet già avviata prima, con il codice di una versione precedente (valida) ancora in
memoria; la guardia della v1.8.1, aggiungendo un `return` silenzioso allo script "boot" quando
`NebbieDash` non esiste, ha eliminato l'errore visibile ma ha anche smascherato il vero problema:
con `core` che non compila affatto, `NebbieDash` non viene MAI definita, quindi ANCHE la guardia di
"boot" restituisce silenziosamente senza fare nulla — nessun errore, nessuna funzionalità, esattamente
il sintomo segnalato.

**Fix applicato**: corretto il separatore da `"\\n\\n"` a `"\n\n"` in
`build-nebbie-complete-dashboard-package.py`. Aggiunta anche una validazione PERMANENTE anti-
regressione: una nuova funzione `validate_lua_syntax()` esegue `luac -p` sul testo ESATTO di
ciascuno dei due `<script>` prima di scrivere qualunque file, interrompendo la build (nessun
`.mpackage` aggiornato) se non è Lua valido — questo controllo NON esisteva prima (la build
validava solo `core.lua` isolato con un comando manuale separato, mai il testo realmente unito che
finisce nel pacchetto), motivo per cui il bug non era mai stato notato in due release.

**Verifica**: `validate_lua_syntax()` testato contro una ricostruzione del bug originale (rileva
correttamente l'errore e interrompe la build). Ricostruito il pacchetto: `luac -p` OK su entrambi gli
script estratti dall'XML generato, XML validato con `xml.dom.minidom`, 131/131 test offline OK,
simulazione end-to-end (script "boot" eseguito PRIMA di "core", il caso peggiore) con mock completi
dell'API Mudlet: nessun errore, `NebbieDash._guiCreated == true`, `NebbieDash._mainLoaded == true`,
messaggio "pronto" mostrato correttamente. Versione alzata a 1.8.2. Aggiornato CHANGELOG.md.

---

## 2026-08-10 — Spell residue, split in solitaria, scadenza in tempo reale (v1.9.0)

**Segnalazioni utente**:
1. Passando da Mirari a NomiyaMaki, restano visibili spell (mirror images, shield) che NomiyaMaki
   non può lanciare.
2. Lo split è ripartito mentre l'utente era da solo (fornito un log reale della sessione).
3. Richiesta: far diventare rosse le spell SUBITO al messaggio di scadenza reale (non solo al
   prossimo `attrib`), con 5 testi reali forniti; esplicitamente ESCLUSA la scadenza di "slowness"
   (debuff, non un buff nostro).

**Analisi bug 1 (spell residue)**: `data.knownSpellOrder` è per-personaggio (chiave = nome), non
c'è contaminazione tra personaggi nel codice attuale — la causa più probabile è dato RESIDUO salvato
su disco da PRIMA del fix del cambio-personaggio (Round 13), quando un self-cast poteva essere
attribuito al personaggio sbagliato per un istante. Con l'elenco "conosciuto" ora persistente
(v1.7.0), quel dato errato non viene mai più rimosso automaticamente. Non esistendo un elenco
spell-per-classe confermato (inventarlo violerebbe AGENT-RULES), la soluzione è un comando manuale
di pulizia: `nforgetspell <nome>`, che rimuove una voce specifica dall'elenco conosciuto E da quello
attivo del personaggio corrente.

**Analisi bug 2 (split in solitaria)**: il log fornito dall'utente non mostra uno split
effettivamente inviato in quella sequenza specifica (il "group" automatico dopo `get all gwy`
riceve correttamente "But you are a member of no group?!" e non invia nulla) — MA rivela una vera
race condition nel codice: `startSplitFlow()` sovrascriveva incondizionatamente
`_pendingSplitAmount`/incrementava `_groupCheckGen` ad ogni loot, mentre `onGroupSoloLine()`/
`onGroupHeaderLine()` non verificavano MAI a quale generazione appartenesse la risposta "group"
arrivata — solo il watchdog controllava la generazione. Con più uccisioni ravvicinate (es. da un
incantesimo ad area, come "chain lightning" nel log fornito, che colpisce 3 mostri in un colpo) che
innescano ciascuna il proprio loot automatico, due controlli gruppo sovrapposti potevano
"incrociarsi": la risposta del PRIMO controllo (magari da solo) chiudeva anche il SECONDO controllo
(magari in gruppo, con un importo diverso), inviando o non inviando uno split in base al controllo
sbagliato. **Fix**: se un controllo gruppo è già attivo, un nuovo loot si limita ad ACCUMULARE il
proprio importo in quello in corso, senza avviare un secondo controllo — un solo `group`, un solo
split (con la somma totale) quando arriva la risposta.

**Bug collaterale trovato durante l'analisi**: il log fornito dall'utente mostra il testo REALE di
fine combattimento per un'uccisione in solitaria — "La tua esperienza e' aumentata di N punti." —
diverso dal formato già gestito ("La tua parte di esperienza e' di N punti.", quota di gruppo).
L'autoloot NON scattava affatto con questa frase. Aggiunto un secondo trigger con questo shield.

**Implementazione bug 3 (scadenza in tempo reale)**: nuova tabella `SPELL_EXPIRY_PATTERNS` con i 5
testi REALI forniti dall'utente (sanctuary/armor/aid/true sight/darkness) e un trigger dedicato per
ciascuno; alla ricezione disattivano immediatamente la spell corrispondente in `activeSpells` (quindi
il pannello la mostra rossa da subito), senza aspettare `attrib`. "Senti i tuoi movimenti
accellerare rapidamente." (scadenza di "slowness") esclusa come richiesto: è un debuff subito dal
personaggio, non un buff lanciato da lui, semanticamente diverso dagli altri 5.

**Verifica**: `luac -p` OK, XML validato, `validate_lua_syntax()` del build script passata senza
errori, 150/150 test offline OK (19 nuovi: race condition split, secondo formato fine combattimento,
`nforgetspell`, 5 pattern di scadenza spell), simulazione end-to-end (script "boot" prima di "core")
OK. Versione alzata a 1.9.0. Aggiornati USAGE.md, CHANGELOG.md.

---

(continua...)
