# REQUIREMENTS — Nebbie Play All (Mudlet), analisi da zero

Fonti: `Q&A.md` (risposte utente), `MUDLET-WIKI-NOTES.md` (vincoli Mudlet), lettura mirata di
`nebbie-installer-core.lua`/`SPEC-v2.2.8.md`/`PACKAGE-GUIDE.md` (vincoli/contesto MUD, vedi
`LOG.md`). Ogni riga è tracciata alla fonte. Nessuna riga è un'invenzione.

---

## 1. Requisiti utente (confermati, Q&A.md)

| ID | Requisito | Fonte | Priorità |
|----|-----------|-------|----------|
| R1 | Un solo profilo Mudlet Mudlet deve poter gestire più personaggi, con switch **sequenziale** (un PG alla volta, disconnessione/riconnessione), non simultaneo. | Q&A Round 2, Q2 | Must-have (nuovo requisito centrale) |
| R2 | Il personaggio attivo si identifica dal **nome nel prompt** (es. `NomiyaMaki H: 747/747 ...`). | Q&A Round 2, Q1 | Must-have |
| R3 | Dati da tenere **separati per personaggio**: equipaggiamento (eq), spell/buff attivi (attrib), config armi/utility per PG. | Q&A Round 2, Q3 | Must-have |
| R4 | Persistenza su disco tra sessioni: **da decidere** in fase di design (nessuna preferenza utente), presentare pro/contro. | Q&A Round 2, Q4 | Da decidere (RECOMMENDATION.md) |
| R5 | **Priorità release 1**: pannello equip funzionante prima di tutto. | Q&A Round 1, Q9 | Must-have (P0) |
| R6 | Package **nuovo** (nome diverso) accettato/preferito se più semplice/solido di riprendere l'esistente. | Q&A Round 1, Q10 | Vincolo di design, non requisito funzionale |
| R7 | Nessun protocollo GMCP sul server: **solo testo/ANSI**. | Q&A Round 1, Q7 | Vincolo tecnico |
| R8 | Nessuna preferenza su visibilità output `eq`/`attrib` in console (gag ammesso). | Q&A Round 1, Q8 | Da decidere in design |
| R9 | Comandi utente: nomi da confermare dopo il design (non bloccante). | Q&A Round 2, Q6 | Da definire in RECOMMENDATION.md |
| R10 | Nome package: da proporre nella RECOMMENDATION. | Q&A Round 2, Q5 | Da definire |

## 2. Requisiti impliciti dal prompt originale (da riconfermare, NON assunti come definitivi)

Questi provenivano da `AGENT-PROMPT-ANALISI-ZERO.txt` come "scope da confermare" — restano
**aperti** finché l'utente non li conferma esplicitamente (nessuno è stato ancora chiesto in
Round 1/2):

| ID | Requisito potenziale | Stato |
|----|----------------------|-------|
| R11 | HUD vitali H/M/V da prompt + info combattimento | Verosimilmente ancora valido (coerente con R5/priorità equip ma HUD non esclusa) — **da confermare** |
| R12 | Buff/debuff da `attrib` | Coerente con R3 (spell attivi per personaggio) — **da confermare come "attivi ora" vs pannello dedicato** |
| R13 | Percorsi speedwalk | **Esplicitamente NON incluso** tra i dati da separare per personaggio (Q&A Round 2, Q3 — opzione non selezionata). Da chiarire se è comunque nello scope come funzione comune a tutti i PG, o del tutto fuori scope release 1. **[APERTO]** |
| R14 | Layout pannelli/UI configurabile | Non selezionato come dato per-personaggio (Q&A Round 2, Q3). Presumibilmente layout comune. **[APERTO, non bloccante]** |
| R15 | Loot automatico, tastierino numerico, alias multi-classe (dal package legacy) | Non menzionati esplicitamente nelle risposte Q&A finora. **Non assumere che siano nello scope della release 1** — R5 dice solo "equip prima di tutto". **[APERTO — chiedere prima di RECOMMENDATION.md finale se vanno incluse o rimandate]** |

## 3. Vincoli tecnici Mudlet (da MUDLET-WIKI-NOTES.md, con citazione)

| ID | Vincolo | Fonte |
|----|---------|-------|
| V1 | Mudlet 4.22.0 confermato: tutte le API usabili nel design (trigger, `tempPromptTrigger`, `createMiniConsole`, `setBorder*`, `table.save`/`load`, eventi) sono disponibili in questa versione. | MUDLET-WIKI-NOTES.md §10 |
| V2 | Trigger di tipo Prompt / `tempPromptTrigger` richiedono GA/EOR telnet — **non verificato se il server Nebbie Arcane li implementa**. | MUDLET-WIKI-NOTES.md §2 |
| V3 | Regex trigger non scudate su ogni riga sono la best-practice sconsigliata dalla wiki stessa (costo CPU); serve shielding con substring/begin-of-line. | MUDLET-WIKI-NOTES.md §1 |
| V4 | `getLines(from,to)`: parametri assoluti, chiavi tabella relative all'intervallo — gestire esplicitamente la conversione. | MUDLET-WIKI-NOTES.md §3 |
| V5 | `sysLoadEvent`/script perm si rieseguono ad ogni caricamento profilo (e ad ogni salvataggio in editor) — logica di boot che invia comandi al MUD va resa esplicita/manuale, non automatica silenziosa. | MUDLET-WIKI-NOTES.md §5, confermato empiricamente nel codice legacy (LOG.md) |
| V6 | Persistenza dati: `table.save`/`table.load` su `getMudletHomeDir()` (cartella del **profilo corrente**), non nella cartella di installazione Mudlet. | MUDLET-WIKI-NOTES.md §9 |
| V7 | Un `.mpackage` è uno zip con `config.lua` + XML root + asset opzionali; il modo "ufficiale" di generarlo è il Package Exporter integrato, non la generazione manuale di XML (come fa `build-nebbie-package.py`). | MUDLET-WIKI-NOTES.md §7 |

## 4. Vincoli/contesto dal codice e dai documenti del MUD (da rivalidare, non da fidarsi ciecamente)

| ID | Osservazione | Fonte | Affidabilità |
|----|--------------|-------|--------------|
| M1 | Formato prompt reale: `NomiyaMaki H: 747/747 M: 532/532 V: 158/158 x:-238860738 *:* *:* [[TD]] G:3449613 >>` | Esempio utente in AGENT-PROMPT-ANALISI-ZERO.txt | Alta (dato utente reale) |
| M2 | Formato prompt alternativo nel codice legacy: `Mirari H:652/652 M:532/532 V:265/265 X:280457721 - */* - *-* - [[------Tm---]] - G:49287175 >>` (nota: SENZA spazio dopo `H:`, con `X:` maiuscolo, separatori `-` invece di spazi) | `nebbie-installer-core.lua` riga 242 (funzione `testPromptParse`) | Media — è un campione di TEST nel codice legacy, non necessariamente il formato attuale del server. **Discrepanza con M1** (spazio dopo `H:` presente in M1, assente in M2) da chiarire con l'utente prima di scrivere qualunque regex nuova. |
| M3 | Comando MUD corretto per equip è `eq` (non `equipment`/`inv`), per spell attivi è `attrib` (non `attribute`) | AGENT-PROMPT-ANALISI-ZERO.txt, righe 62 e 83 | Alta (dato utente esplicito) — **nota**: il codice legacy (`PACKAGE-GUIDE.md`/`SPEC-v2.2.8.md`) usa invece `equipment`/`attribute` in più punti. **Discrepanza da chiarire**: il server accetta entrambe le forme (abbreviazioni) o solo quella indicata dall'utente? **[APERTO]** |
| M4 | Slot equip osservati: `[ 16] <impugnato>`, `[ 17] <tenuto>`, `[ 18] <sulla schiena>` (numerazione fino ad almeno 18, prompt menziona "21 slot o subset — chiedere") | AGENT-PROMPT-ANALISI-ZERO.txt righe 71-75, 55 | Alta per l'estratto, ma **elenco completo dei 21 slot non ancora fornito** — **[APERTO, bloccante per R5/P0]** |
| M5 | Formato `attrib`: blocco "Spells attivi:" con righe `Spell : 'nome' - N` (N presumibilmente durata in tick) | AGENT-PROMPT-ANALISI-ZERO.txt righe 77-82 | Alta per l'estratto, formato completo (altre sezioni di `attrib`, es. eventuali debuff) non fornito — **[APERTO, non bloccante per P0 equip]** |

## 5. Gap bloccanti per procedere a DESIGN-OPTIONS.md dettagliato su equip (R5/P0) — RISOLTI

Risolti il 2026-08-08 con dati reali forniti dall'utente (vedi `Q&A.md` Round 3):

1. **M4 — RISOLTO**: elenco completo dei 21 slot ricevuto (output reale `eq` di NomiyaMaki),
   trascritto in `Q&A.md` Round 3. Tabella slot→etichetta:

   | # | Etichetta | # | Etichetta | # | Etichetta |
   |---|-----------|---|-----------|---|-----------|
   | 1 | sul dito destro | 8 | ai piedi | 15 | al polso sinistro |
   | 2 | sul dito sinistro | 9 | sulle mani | 16 | impugnato |
   | 3 | intorno al collo | 10 | sulle braccia | 17 | tenuto |
   | 4 | intorno al collo | 11 | come scudo | 18 | sulla schiena |
   | 5 | sul corpo | 12 | intorno al corpo | 19 | all'orecchio destro |
   | 6 | in testa | 13 | intorno alla vita | 20 | all'orecchio sinistro |
   | 7 | sulle gambe | 14 | al polso destro | 21 | davanti agli occhi |

   Nota: gli slot 3 e 4 condividono la stessa etichetta "intorno al collo" (2 slot collana) — il
   numero resta la chiave univoca, non l'etichetta.
2. **M3 — RISOLTO**: confermato dall'utente (Q&A Round 3, Q3) che sia `eq`/`attrib` sia
   `equipment`/`attribute` funzionano.
3. **M2 vs M1 — RISOLTO**: il formato REALE è quello di M1, con una precisazione ulteriore
   emersa dal dato reale: `NomiyaMaki H: 747/747 M: 532/532 V: 158/158 x:-238860738 *:* *:*
   [[D]] G:3449502 >>` — **spazio dopo i due punti** per H/M/V, **`x:` minuscolo** per il campo
   che nel codice legacy si chiama XP (maiuscolo), placeholder combattimento `*:* *:*` a riposo
   (formato in combattimento non ancora visto, non necessario per P0). Il campione nel codice
   legacy (M2) risulta quindi **non rappresentativo del formato attuale del server** — e infatti,
   verificato leggendo `Nebbie.parsePromptPair()`/`parsePromptStats()`, il parser legacy
   **fallisce sempre** su input reale per questo motivo (vedi `Q&A.md` Round 3 per il dettaglio
   riga-per-riga — root cause dei "pannelli vuoti" confermata, non più solo sospettata).
4. **V2 (GA/EOR)**: resta non verificato ma **non bloccante** (design scelto non dipende da GA,
   vedi DESIGN-OPTIONS.md D2-A/D2-B).

## 6. Nuova osservazione dai dati reali (M6) — word-wrap nel testo oggetti eq

**M6**: le descrizioni degli oggetti in `eq` possono andare a capo su una riga di continuazione
priva di numero di slot (es. slot `[ 5]`: "Un tubino rinforzato con una grossa Union Jack (in
condizioni" + riga successiva "eccellenti)"). Qualunque parser riga-per-riga deve accumulare le
righe di continuazione (righe che non iniziano con `[nn]`) al testo dello slot precedente, fino
alla riga vuota finale o al prompt successivo. Fonte: dato reale utente, Q&A.md Round 3.

## 6. Criteri di successo (da AGENT-PROMPT-ANALISI-ZERO.txt, da confermare/adattare a R1-R10)

1. Profilo Mudlet fluido al login (no hang multi-secondo) — **causa root plausibile già
   identificata con evidenza di codice** (LOG.md: boot automatico + refresh 1s), non solo
   ipotesi.
2. Comando equivalente a `nfix`: setup senza errore versione, versione coerente (single source of
   truth per la versione — vedi V7 e "divieto" doppia versione).
3. Pannello equip popolato con gli slot documentati (bloccato da gap M4).
4. Pannello spell (`attrib`) popolato (bloccato in parte da gap M5, meno prioritario di equip
   per R5).
5. Comando di resync (`nresync` o equivalente) completa senza freeze.
6. **Nuovo criterio da R1**: cambiare personaggio (disconnessione/riconnessione nello stesso
   profilo) aggiorna correttamente cache equip/spell/config armi al nuovo nome PG rilevato dal
   prompt, senza mischiare dati tra personaggi diversi.
7. Documentazione completa per manutenzione futura (questo stesso set di file).
