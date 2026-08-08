# CHANGELOG — nebbie-complete-dashboard-package

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
