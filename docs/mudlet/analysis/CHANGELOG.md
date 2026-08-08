# CHANGELOG — nebbie-complete-dashboard-package

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
