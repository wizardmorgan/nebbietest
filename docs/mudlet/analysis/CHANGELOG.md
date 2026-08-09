# CHANGELOG — nebbie-complete-dashboard-package

## 1.3.0 — 2026-08-09

- **Aggiunto**: icona e descrizione interna del package, visibili in Mudlet nella schermata
  "Gestione pacchetti" (prima mancavano entrambe). Struttura verificata direttamente nel codice
  sorgente di Mudlet (`src/dlgPackageManager.cpp`, `src/packages/echo/config.lua` come esempio
  ufficiale): `config.lua` include ora anche `author`, `icon`, `title`, `description` (markdown),
  oltre a `mpackage`/`version` gia' presenti; l'icona (`assets/nebbie-dash-icon.png`) viene inclusa
  nello zip del pacchetto in `.mudlet/Icon/<nome>`, il percorso che Mudlet si aspetta. **La
  descrizione va aggiornata ad ogni release** (promemoria lasciato nel commento sopra
  `PKG_DESCRIPTION` in `build-nebbie-complete-dashboard-package.py`).
- **Cambiato — layout**: il pannello equip si è spostato sul **bordo sinistro** (a tutta altezza),
  per "sfollare" la colonna destra come richiesto. Sulla destra restano **Spell attivi in alto** e
  **Speedwalk in basso**, ora separati da una barra divisoria visibile (colore grigio-blu, 4px). La
  suddivisione verticale tra Spell attivi e Speedwalk è regolabile con il nuovo comando
  `nheights <percentuale 10-90>` (percentuale riservata a "Spell attivi"). La larghezza automatica
  (introdotta in 1.2.0) ora si applica **separatamente** alle due colonne: `nwidth equip <n>|auto` e
  `nwidth right <n>|auto` (retrocompatibile: `nwidth <n>|auto` senza indicare il lato agisce sulla
  colonna destra, come prima).
- **Fix**: il pannello equip ora marca esplicitamente "(vuoto)" ogni posizione nota (21 slot, elenco
  in `EQ_SLOT_ORDER`) per cui `eq` non riporta alcun oggetto — prima venivano mostrati solo gli slot
  effettivamente occupati. Il confronto è sul **testo della posizione** (es. "ai piedi"), non sul
  numero di slot del gioco (che resta solo un contatore progressivo sugli oggetti indossati, non un
  identificatore di posizione — vedi fix 1.0.0/fix 3), quindi funziona indipendentemente da quanti e
  quali oggetti sono effettivamente indossati.
- **Aggiunto**: predisposto (ma **non visibile di default**, come richiesto) un 22° slot placeholder
  "simbolo del clan", non ancora confermato in un output reale di `eq`. Comando `nclanslot <on|off>`
  per attivarlo quando/se necessario.
- **Versione interna** alzata a 1.3.0.

## 1.2.0 — 2026-08-09

- **Aggiunto**: le spell cliccabili nel pannello "Spell attivi" ora includono sempre il personaggio
  attivo come bersaglio esplicito (es. click su "true sight" con `NomiyaMaki` attivo invia
  `cast 'true sight' NomiyaMaki`, non solo `cast 'true sight'`). Il gioco interpreta tutto ciò che
  segue l'apice di chiusura come nome bersaglio (`ACTION_FUNC(do_cast)`, `src/spell_parser.cpp`
  riga ~1822): per le spell "solo su se stessi" il bersaglio esplicito viene semplicemente ignorato
  dal server, quindi non ha effetti collaterali. Il lancio manuale (`c`/`r`/`m <nome>` digitato)
  resta invariato.
- **Aggiunto**: larghezza automatica del pannello destro (default). Si allarga/restringe da solo in
  base alla riga più lunga attualmente mostrata (posizione/oggetto equip, nome spell, descrizione+
  direzioni speedwalk), senza mai superare il 60% della larghezza della finestra di Mudlet — niente
  più testo tagliato "a schermo pieno" né testo che va a capo inutilmente quando il contenuto
  entrerebbe su una riga sola. Comando `nwidth <numero>` continua a permettere una larghezza fissa
  manuale come prima; `nwidth auto` torna alla modalità automatica.
- **Fix**: azzerato esplicitamente il bordo sinistro (`setBorderLeft(0)`) alla creazione della GUI.
  I bordi sono un'impostazione di profilo, non di uno script: un vecchio package (es.
  `nebbie-play-all`) può averlo impostato in passato e disinstallarlo non lo resetta da solo —
  causa più probabile della "colonna nera a sinistra" segnalata senza che questo package l'abbia
  mai richiesta. Se dovesse persistere dopo l'aggiornamento, riavviare del tutto Mudlet (non solo
  ricaricare il profilo) per eliminare eventuali widget residui creati in sessione da script ormai
  rimossi.
- **Verificato** (nessun fix necessario): il parsing degli speedwalk già gestiva correttamente sia
  descrizioni con virgole interne (es. `(paul, da astral)`, il testo tra parentesi viene preso per
  intero fino alla prima `)` chiusa, la virgola interna non confonde il parser) sia istruzioni
  multi-parola tra le direzioni (es. `enter pool`, inviata così com'è perché non inizia con un
  numero). Aggiunto test automatico dedicato con l'esempio esatto fornito
  (`docs/mudlet/tests/smoke_test_parsing.lua`).
- **Versione interna** alzata a 1.2.0.

## 1.1.0 — 2026-08-09

- **Aggiunto**: terzo pannello "Speedwalk" (bordo destro, sotto equip/spell). Legge
  `getMudletHomeDir()/nebbie-speedwalks.txt` (creato automaticamente con istruzioni se mancante),
  un file di testo che l'utente compila a mano nel formato `(descrizione) direzioni,separate,da
  virgola` (con supporto a ripetizioni tipo `3w`). Click sulla descrizione = invio automatico
  della sequenza, con una pausa configurabile (`nspeeddelay`) tra un movimento e l'altro. Comando
  `nspeedwalks` per ricaricare il file senza riavviare Mudlet.
- **Aggiunto**: le spell nel pannello "Spell attivi" sono ora cliccabili per rilanciarle (usano il
  motore `c`/`r`/`m` già presente). Comando `nclass <c|r|m>` per impostare, per personaggio, quale
  dei tre comandi usare (default `cast`). Nome della spell mostrato in rosso sotto una soglia di
  tick configurabile (`nspellwarn`, default 5) invece che verde — riflette il valore all'ultima
  sincronizzazione, non un conto alla rovescia in tempo reale (non conosciamo la durata di un tick
  sul server).
- **Versione interna** alzata a 1.1.0.

## 1.0.0 (fix 4) — 2026-08-08

- **Aggiunto**: motore generico di lancio spell/skill/potere psionico — alias `c <nome>`
  (`cast '<nome>'`, mago/chierico), `r <nome>` (`recall '<nome>'`, sorcerer), `m <nome>`
  (`mind '<nome>'`, psionico). Nessun fuzzy-matching lato Mudlet: il motore di gioco fa già il
  match per abbreviazione (verificato in `src/spell_parser.cpp`, `do_cast`/`old_search_block`).
- **Aggiunto**: `docs/mudlet/analysis/MUD-SPELL-SKILL-LIST.md`, elenco completo (300 voci) di
  spell/skill/poteri estratto dal codice sorgente del server (`spells[]` in
  `src/spell_parser.cpp`), come riferimento per scegliere eventuali alias dedicati più corti.
- **Non incluso** (in attesa di requisiti dall'utente): finestra speedwalk, alias dedicati per
  spell specifiche, click-to-recast vero e proprio nel pannello.

## 1.0.0 (fix 3) — 2026-08-08

- **Fix importante**: etichette slot equip sbagliate (es. oggetto mostrato come "ai piedi" quando
  in realtà occupava un'altra posizione). Causa: la posizione veniva presa da una tabella statica
  indicizzata per numero di slot invece che dal testo reale della riga `eq`. Ora la posizione è
  sempre letta dalla riga stessa. Vedi `LOG.md`/`USAGE.md`.
- **Cambiato**: il pannello equip mostra ora esattamente gli slot riportati dal gioco (niente più
  enumerazione fissa 1–21 con "(vuoto)" inventati — era proprio questo a rendere visibile il bug).
- **Aggiunto**: comando `nitemlen <n>` per troncare le descrizioni oggetto (default 42 caratteri)
  e ridurre il word-wrap nel pannello stretto.
- **Non incluso** (richiede conferma utente, mai discusso prima/esplicitamente fuori scope):
  finestra speedwalk, spell/skill cliccabili per rilancio, elenco slot equip non occupati.

## 1.0.0 (fix 2) — 2026-08-08

- **Fix**: il pannello non si ridimensionava mai dopo la creazione iniziale (mancava un handler
  per `sysWindowResizeEvent`), causando anche una miniconsole a altezza ~0 all'avvio ("una sola
  barra" a schermo). Vedi `LOG.md`.
- **Aggiunto**: comandi `nfont <n>` e `nwidth <n>` per regolare font (default alzato 9→11pt) e
  larghezza (default alzata 260→320px) del pannello.
- **Cambiato**: il pannello equip mostra ora sempre tutti i 21 slot, marcando `(vuoto)` quelli
  liberi, invece di ometterli.

## 1.0.0 (fix) — 2026-08-08

- **Fix**: pannelli equip/spell grigi/vuoti subito dopo l'installazione (prima di qualunque
  `nresync`/rilevamento prompt). Causa: miniconsole create senza sfondo esplicito né refresh
  iniziale. Vedi `LOG.md` (voce "Feedback post-installazione reale") e `USAGE.md`.
- **Aggiunto**: `USAGE.md` con la tabella completa degli alias e istruzioni di verifica per
  escludere residui del vecchio package.

## 1.0.0 — 2026-08-08

Prima release. Package **nuovo**, indipendente da `nebbie-play-all` (non un patch/fork).

**Perché un package nuovo e non un aggiornamento di `nebbie-play-all`**: vedi
`docs/mudlet/analysis/RECOMMENDATION.md` §3 — evidenza diretta nel codice legacy di boot
automatico incondizionato con invio implicito di comandi al MUD, refresh GUI ricorrente ogni 1
secondo, e un modello dati "un profilo Mudlet = un personaggio" incompatibile con il nuovo
requisito multi-personaggio.

### Aggiunto

- Rilevamento del personaggio attivo dal prompt di gioco (nome + HP/Mana/Move), con gestione
  esplicita del formato reale del server (spazio dopo `H:`/`M:`/`V:`, campo `x:` minuscolo) —
  root cause dei "pannelli vuoti" del package precedente, confermata con evidenza (vedi
  `docs/mudlet/analysis/LOG.md`, voce 2026-08-08 22:24).
- Cache equip/spell/config armi separata per personaggio, con switch sequenziale (un PG alla
  volta) rilevato automaticamente dal prompt, più comando manuale `nchar <nome>` come override.
- Persistenza su disco tra sessioni Mudlet (`table.save`/`table.load` in
  `getMudletHomeDir()/nebbie-complete-dashboard-package-chars.lua`), come da conferma esplicita
  dell'utente.
- Pannello dashboard su bordo destro (`setBorderRight` + 2 miniconsole: equip e spell attivi).
- Parsing completo dei 21 slot equip da `eq`, incluso il caso di descrizioni oggetto che vanno a
  capo (word-wrap) su righe di continuazione senza numero di slot.
- Parsing spell attivi da `attrib` (formato base: `Spell : 'nome' - N`).
- Comandi: `nfix`, `neq`, `nattrib`, `nresync`, `ngui`, `nlayout`, `nchar <nome>`.

### Deliberatamente NON incluso in questa release (fuori scope, vedi REQUIREMENTS.md)

- Alias multiclasse, loot automatico, tastierino numerico, HUD HP/Mana/Move a barre (presenti nel
  package legacy `nebbie-play-all`, non riportati qui — possono essere aggiunti in una release
  successiva se richiesto, eventualmente riusando SOLO i dati generati dal sorgente C++ del
  server, non l'installer legacy).
- Invio automatico di `eq`/`attrib` al boot/login (esplicitamente evitato per rispettare il
  divieto confermato nel codice legacy).
- Gestione del formato prompt/eq durante il combattimento (non ancora osservato/fornito).

### Note tecniche

- Namespace Lua: `NebbieDash` (diverso da `Nebbie` usato da `nebbie-play-all`, per evitare
  qualunque conflitto se entrambi i package fossero installati per errore).
- Nessuna riga di codice/trigger del package legacy è stata riusata.
