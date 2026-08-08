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

---

(continua...)
