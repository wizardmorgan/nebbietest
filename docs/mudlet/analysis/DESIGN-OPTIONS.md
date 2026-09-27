# DESIGN OPTIONS — Nebbie Play All (Mudlet), analisi da zero

Stato: **aggiornato con dati reali** ricevuti dall'utente il 2026-08-08 (output `eq` completo e
prompt esatto — vedi `Q&A.md` Round 3, `REQUIREMENTS.md` §5-6). I pattern concreti per prompt ed
`eq` sono ora inclusi nella sezione D2.

Ogni opzione: descrizione, pro, contro, rischio (in particolare rischio di hang, riferito ai
"divieti" osservati nel codice legacy — vedi `LOG.md`), complessità, fonte wiki/codice.

---

## Decisione D1 — Rilevamento cambio personaggio (R1, R2)

Requisito: switch **sequenziale** (un PG alla volta), identificazione dal nome nel prompt.

### D1-A — Trigger dedicato "nome cambiato" derivato dal parser prompt esistente

Ogni volta che il parser del prompt estrae con successo un nome PG, si confronta con
`Nebbie.currentChar` (variabile in memoria). Se diverso (incluso il caso "prima volta dopo
login", cioè `currentChar == nil`), si scatena `onCharacterChanged(oldName, newName)`: si salva
la cache del vecchio PG (se serve persistenza, vedi D3), si carica/inizializza la cache del nuovo,
si aggiorna la dashboard.

- **Pro**: riusa lo stesso trigger di parsing del prompt già necessario per l'HUD (nessun trigger
  aggiuntivo dedicato); zero costo extra su ogni riga.
- **Contro**: dipende dalla robustezza del parser prompt (formato non ancora confermato — gap
  Q&A Round 3). Se il parser fallisce silenziosamente, il cambio personaggio non viene rilevato.
- **Rischio hang**: basso — è un confronto di stringa in memoria, nessuna I/O bloccante.
- **Fonte**: MUDLET-WIKI-NOTES.md §1 (shielding), §4 (multiline se serve blocco multi-riga).

### D1-B — Comando esplicito dell'utente per dichiarare il personaggio (es. `nchar <nome>`)

Il giocatore, dopo il login, digita un comando che dichiara esplicitamente "ora sto giocando
`<nome>`", indipendentemente dal parsing del prompt.

- **Pro**: robusto anche se il parser prompt ha problemi o il formato cambia; comportamento
  esplicito e prevedibile.
- **Contro**: richiede un'azione manuale ad ogni switch — l'utente ha già risposto (Q&A Round 2,
  Q1) che preferisce il rilevamento automatico dal prompt; usare SOLO questa opzione andrebbe
  contro la risposta data.
- **Rischio hang**: nessuno.
- **Uso consigliato**: come **fallback/override manuale** di D1-A, non come meccanismo primario
  (rispetta la risposta utente e aggiunge robustezza).

### D1-C — Rilevamento da messaggio di login/eventi di connessione (`sysConnectionEvent`)

Si intercetta l'evento di (ri)connessione telnet per resettare lo stato e forzare un nuovo
parsing del prompt alla prossima riga utile.

- **Pro**: utile per sapere "quando" è avvenuto un nuovo login (distingue "sto ancora giocando lo
  stesso PG" da "mi sono appena riconnesso"), riducendo falsi positivi di D1-A durante la sessione
  di gioco (es. se il nome comparisse per errore in altre righe non-prompt).
- **Contro**: da solo non identifica IL personaggio (serve comunque D1-A per il nome).
- **Rischio hang**: nessuno (evento nativo Mudlet, non richiede polling).
- **Fonte**: `sysConnectionEvent` è elencato nell'indice degli eventi ufficiali (Manual:Technical
  Manual, sezione 16.6.9) — dettagli parametri non ancora approfonditi in Fase 1 (da fare se
  questa opzione viene scelta).

**Raccomandazione preliminare (da confermare in RECOMMENDATION.md)**: combinare **D1-A + D1-C**
come meccanismo primario, con **D1-B** come comando manuale di sicurezza/debug (coerente con
comandi tipo `nfix`/`ndiagnose` già presenti nel package legacy per scenari "qualcosa non torna").

---

## Decisione D2 — Struttura dei trigger per `eq` e prompt (evitare i "divieti" osservati)

Requisito: evitare regex/substring catch-all non scudate su ogni riga (vedi LOG.md — confermato
nel codice legacy: `tempSubstringTrigger(" H:")` + refresh 1s).

### D2-0 — Pattern concreti sbloccati dai dati reali (Q&A.md Round 3)

Prompt reale: `NomiyaMaki H: 747/747 M: 532/532 V: 158/158 x:-238860738 *:* *:* [[D]] G:3449502 >>`

- **Sostring-shield proposto**: `" M: "` (poco frequente nel testo di gioco normale italiano,
  breve, presente solo sui prompt insieme a `V:` — da validare su più campioni in game, es.
  durante il combattimento, prima di darlo per definitivo).
- **Regex figlia proposta** (Perl regex Mudlet, capture group tra parentesi):
  `^(\S+) H: (\d+)/(\d+) M: (\d+)/(\d+) V: (\d+)/(\d+) x:(-?\d+)`
  — nota lo **spazio dopo i due punti** per H/M/V (assente nel codice legacy, causa root del bug
  osservato) e la **`x` minuscola** per il campo dopo V. Cattura: nome PG, HP cur/max, mana
  cur/max, move cur/max, campo x (con segno, può essere negativo come nell'esempio).
- **Nome personaggio per D1**: `matches[2]` di questa regex (primo capture group) — usato sia per
  il rilevamento cambio personaggio (D1-A) sia per l'HUD.
- Campo `[[D]]`/gold/combattimento: pattern aggiuntivi opzionali, non necessari per P0 (equip);
  da definire quando servirà l'HUD combattimento — **non inventare ora il formato mob/tank in
  combattimento**, non ancora osservato.

Eq reale: blocco che inizia con `Stai usando:` e righe `[ N] <etichetta>       Testo oggetto`,
con possibile continuazione del testo oggetto su riga successiva priva di `[N]` (M6).

- **Trigger apertura**: substring esatta `Stai usando:` (già usata correttamente anche nel codice
  legacy come parte delle condizioni, riutilizzabile).
- **Pattern riga slot**: `^\[\s*(\d+)\]\s+<([^>]+)>\s+(.+)$` — cattura numero slot, etichetta,
  testo oggetto (fino a fine riga, che può essere solo una parte se continua sotto).
- **Continuazione**: se una riga NON matcha il pattern sopra e NON è vuota e NON è il prompt
  successivo (rilevabile con la stessa regex prompt di D2-0), va concatenata (con uno spazio) al
  testo dell'ultimo slot numerato letto.
- **Chiusura blocco**: riga vuota oppure comparsa del prompt successivo (rilevato con la regex
  prompt sopra) — usare quest'ultimo come rete di sicurezza per non restare "aperti"
  indefinitamente (mitiga il rischio hang di D2-C generico, ora concretizzato).
- Implementabile sia come trigger multiline/AND (D2-C) sia come piccola state machine Lua
  (variabile `Nebbie.eqCapture = {open=true, slots={}}` aggiornata riga per riga da un trigger
  Lua-function unico attivo solo quando `eqCapture.open == true`) — quest'ultima opzione evita il
  costo di un trigger multiline con margine di righe elevato (il numero di righe del blocco eq
  varia con quanti oggetti sono equipaggiati e quante righe di word-wrap producono) e si spegne
  da sola in stato "chiuso" per il resto del tempo (nessun costo su righe normali di gioco).

### D2-A — Trigger "gate" a singolo punto d'ingresso per il prompt (chain/shielding ufficiale)

Un solo trigger scudo (begin-of-line o substring su un frammento stabile e raro nella riga, es.
qualcosa presente SOLO nel prompt e non nel testo di gioco normale — da determinare quando avremo
il formato esatto) apre un chain; la regex di estrazione dei campi gira SOLO sulle righe che
hanno già superato lo scudo.

- **Pro**: è il pattern esplicitamente raccomandato dalla wiki (MUDLET-WIKI-NOTES.md §1); un solo
  punto di manutenzione per il rilevamento del prompt.
- **Contro**: se il "frammento stabile" scelto per lo scudo non è davvero unico al prompt (falsi
  positivi/negativi), l'intero meccanismo fallisce — da validare con l'output reale (Round 3).
- **Rischio hang**: basso, se scudato correttamente.

### D2-B — Trigger di tipo "Prompt" nativo (`tempPromptTrigger`) come canale primario, con fallback D2-A

Se il server implementa GA/EOR (da verificare — vedi REQUIREMENTS.md V2, non bloccante), si può
usare il trigger nativo "Prompt" che è progettato esattamente per questo scopo e non richiede
pattern-matching testuale sul contenuto del prompt per sapere "questa riga è un prompt" (lo sa
già dal protocollo telnet).

- **Pro**: zero rischio di falsi positivi/negativi sul "è un prompt sì/no"; è l'approccio
  "ufficiale" per questo caso d'uso secondo la wiki.
- **Contro**: **non utilizzabile se il server non implementa GA/EOR** — condizione non verificata.
  Se usato come UNICO meccanismo e GA non è disponibile, il pannello resterebbe vuoto (probabile
  causa reale dei "pannelli vuoti" segnalati con il codice legacy, che infatti lo usa solo come
  hook aggiuntivo opzionale, non come unico meccanismo — scelta corretta secondo la wiki).
- **Rischio hang**: nessuno (è un trigger nativo, non polling).
- **Fonte**: MUDLET-WIKI-NOTES.md §2.

**Raccomandazione preliminare**: **D2-A come meccanismo primario garantito** (funziona a
prescindere da GA), **D2-B aggiunto come hook opzionale** se `tempPromptTrigger` è disponibile
E il test (`Nebbie.testPromptParse`-style, già presente nel codice legacy) conferma che scatta
correttamente — esattamente il pattern già usato nel codice legacy per questo punto specifico
(unico "divieto" della lista che, alla lettura, risulta già mitigato correttamente nel codice
attuale: vedi LOG.md, `installPromptHooks`).

### D2-C — Cattura `eq` con trigger multiline delimitato (inizio="Stai usando:"/fine=prompt successivo o riga vuota)

Per l'elenco degli slot equip, usare un trigger multiline/AND che si "apre" sulla riga di
intestazione (es. "Stai usando:") e si "chiude" dopo N righe o al prossimo prompt, accumulando le
righe in una tabella, invece di fare polling dello scrollback con `getLines` a tempo (che nel
codice legacy è usato come FALLBACK, non meccanismo primario, per il solo prompt — per `eq` non
ancora verificato come sia strutturato, essendo rimandata la lettura completa del file).

- **Pro**: non richiede timeout arbitrari né poll di buffer; cattura deterministica del blocco.
- **Contro**: se il numero di slot è variabile (dipende da quanti oggetti sono equipaggiati) serve
  gestire la fine del blocco in modo robusto (riga vuota? prompt? conteggio fisso di 21 righe se
  il server stampa sempre tutti gli slot anche vuoti — da confermare con l'output reale, Round 3).
- **Rischio hang**: basso se la condizione di chiusura è ben definita; rischio di "blocco aperto
  indefinitamente" se la condizione di fine non scatta mai (mitigabile con un timeout di sicurezza
  come rete, non come meccanismo primario).
- **Fonte**: MUDLET-WIKI-NOTES.md §4.

---

## Decisione D3 — Persistenza dati per personaggio (R4, aperta per scelta utente)

### D3-A — Solo in memoria di sessione (nessun salvataggio su disco)

La cache equip/spell/config armi per il personaggio attivo vive in una tabella Lua in RAM;
ricostruita da `eq`/`attrib` ogni volta che serve (su richiesta esplicita o al cambio
personaggio).

- **Pro**: massima semplicità; zero rischio di file corrotti/obsoleti tra sessioni; zero problemi
  di "quale versione dei dati è la più recente" quando il personaggio cambia equip fuori sessione
  Mudlet (es. da un altro client).
- **Contro**: ogni riavvio di Mudlet o cambio personaggio richiede un nuovo comando `eq`/`attrib`
  per ripopolare i pannelli (nessun dato "istantaneo" alla riconnessione).
- **Rischio hang**: nessuno.

### D3-B — Persistenza su disco con `table.save`/`table.load`, chiave = nome personaggio

Una tabella unica (es. `NebbieChars["NomiyaMaki"] = {eq=..., spells=..., weaponConfig=...}`)
salvata in `getMudletHomeDir() .. "/nebbie-chars.lua"` (path del PROFILO corrente, per evitare
l'errore comune segnalato nei forum ufficiali di salvare nella cartella di installazione — vedi
MUDLET-WIKI-NOTES.md §9). Caricata a `sysLoadEvent`, salvata ad ogni modifica rilevante.

- **Pro**: alla riapertura di Mudlet/riconnessione con lo stesso personaggio, il pannello può
  mostrare l'ultimo stato noto immediatamente, in attesa di un resync; utile se l'utente vuole
  vedere "cosa avevo equipaggiato" anche prima di rifare `eq`.
- **Contro**: introduce lo stesso rischio "dati vecchi/disallineati" osservato in altri contesti
  se non si invalida bene la cache quando il personaggio effettivo ha cambiato equip fuori
  sincronia; aggiunge complessità (gestione file, migrazioni di formato se lo schema cambia).
- **Rischio hang**: basso (I/O locale sincrono ma piccolo), MA attenzione a non salvare troppo
  spesso/su ogni singola riga (stesso principio del "refresh 1s" da evitare per la GUI, applicato
  qui all'I/O su disco).
- **Fonte**: MUDLET-WIKI-NOTES.md §9.

**Nota**: questa decisione resta esplicitamente **aperta** (Q&A.md Round 2, risposta "nessuna
preferenza") — va presentata come scelta finale in `RECOMMENDATION.md` con una raccomandazione
motivata, non decisa qui unilateralmente.

---

## Decisione D4 — Package nuovo vs riuso/patch del codice legacy (R6)

### D4-A — Package NUOVO, minimo, scritto da zero seguendo i pattern D1/D2/D3 sopra

Si riparte da un file installer minimo che implementa solo: rilevamento personaggio (D1),
parsing prompt scudato (D2-A/B), parsing `eq` (D2-C), cache per personaggio (D3), pannello equip
(R5/P0). Le altre funzionalità del package legacy (loot automatico, alias multiclasse, tastierino,
buff/debuff estesi) sono **fuori scope della release 1** salvo diversa indicazione (vedi
REQUIREMENTS.md R15, aperto).

- **Pro**: nessun rischio di ereditare i comportamenti concretamente confermati come problematici
  (boot automatico incondizionato, refresh 1s, doppia versione) perché non si riusa quel codice;
  base di codice piccola e comprensibile; più facile da testare passo-passo (coerente con R5:
  equip prima di tutto, poi si estende).
- **Contro**: si perde immediatamente tutto il lavoro già fatto su alias multiclasse/loot/buff
  (centinaia di alias/trigger già generati e documentati in `PACKAGE-GUIDE.md`); se in futuro
  servono quelle funzionalità, vanno riportate/riscritte (non necessariamente da zero: si può
  valutare un riuso SELETTIVO dei dati generati automaticamente da `build-nebbie-package.py`
  dal sorgente C++ del server, che è un asset via via valido indipendentemente dai bug
  dell'installer).
- **Rischio hang**: minimo, per costruzione (i pattern pericolosi non vengono introdotti).
- **Complessità**: bassa per la release 1 (P0 equip), crescente se si vogliono re-includere le
  altre funzionalità in release successive.

### D4-B — Riuso del codice legacy con patch mirate ai problemi confermati

Si parte da `nebbie-installer-core.lua` (v2.2.33, in questo branch base) e si corregge
puntualmente: gating del boot dietro `sysLoadEvent`/comando esplicito invece di esecuzione
incondizionata, riduzione frequenza refresh GUI, verifica/hardening dello shielding sul prompt,
eventuale introduzione della logica multi-personaggio (D1/D3) come aggiunta.

- **Pro**: preserva ~185 alias e ~85 trigger già scritti, testati e documentati (multiclasse,
  loot, tastierino, buff/debuff estesi con 35+ pattern di wear-off allineati al sorgente C++ del
  server) — un lavoro sostanziale da non buttare se non necessario.
- **Contro**: il file è grande (3180 righe) e non ancora letto per intero in questa analisi (per
  rispetto del tempo, rimandato a dopo l'approvazione dell'utente); il rischio di bug residui non
  ancora scoperti (es. l'ambiguità `getLines` non confermata ma nemmeno esclusa altrove nel file)
  resta più alto rispetto a scrivere da zero una base minima; introdurre il requisito NUOVO
  multi-personaggio (R1, non previsto nel design originale del codice legacy, che assume "un
  profilo = un personaggio", vedi `SPEC-v2.2.8.md` §6 "Multi-personaggio: un profilo Mudlet per
  PG") richiede comunque una modifica strutturale non banale, non un semplice patch.
- **Rischio hang**: medio — dipende dalla qualità della lettura/patch completa del file, non
  ancora fatta.
- **Complessità**: medio-alta per la modifica strutturale R1; bassa per il resto (già scritto).

**Osservazione chiave (non assunzione, dato di fatto da SPEC-v2.2.8.md §6)**: il codice legacy è
stato progettato esplicitamente per il modello "un profilo Mudlet = un personaggio", con la
classe salvata per-profilo. Il requisito R1 (un profilo, più personaggi con switch sequenziale)
è quindi un cambiamento di modello architetturale, non un dettaglio incrementale — questo pesa a
favore di D4-A per la parte "gestione multi-personaggio", indipendentemente da cosa si decida per
il resto delle funzionalità (alias/loot/ecc., che potrebbero comunque essere riusate come dati
generati, non come installer).

---

## Riepilogo comparativo

| Decisione | Opzione consigliata (preliminare) | Bloccata da |
|-----------|-----------------------------------|-------------|
| D1 (rilevamento personaggio) | D1-A + D1-C, con D1-B come override manuale | Formato prompt (Round 3) per l'estrazione robusta del nome |
| D2 (trigger prompt/eq) | D2-A primario + D2-B hook opzionale; D2-C per `eq` | Formato prompt ed `eq` reali (Round 3) |
| D3 (persistenza) | Aperta — da presentare in RECOMMENDATION.md con pro/contro finali | Nessun blocco tecnico, solo preferenza utente |
| D4 (nuovo vs riuso) | D4-A per il core multi-personaggio + pannello equip (P0); valutare riuso SELETTIVO dei dati generati (spell/skill da sorgente C++) per funzionalità future | Conferma utente su scope release 1 (R15, aperto) |

Nessuna di queste raccomandazioni preliminari è definitiva: la scelta finale motivata, con i
pro/contro pesati esplicitamente rispetto ai requisiti R1-R10, va in `RECOMMENDATION.md` — da
presentare per approvazione esplicita prima di qualunque implementazione massiccia (regola
AGENT-RULES.txt §2).
