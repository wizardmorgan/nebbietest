mpackage = [[nebbie-complete-dashboard-package]]
author = [[Nebbie Arcane]]
icon = [[nebbie-dash-icon.png]]
title = [[Nebbie Dashboard — equip, spell attivi e speedwalk per Nebbie Arcane]]
description = [[# Nebbie Dashboard (1.15.11)

Pannello laterale per **Nebbie Arcane**, con supporto multi-personaggio (un
profilo Mudlet, più personaggi, cambio automatico rilevato dal prompt).

- **Equip** (bordo sinistro): tutti gli slot indossati, con posizione ed
  oggetto letti da `eq`; segna anche gli slot liberi noti.
- **Spell attivi** (bordo destro, in alto): elenco **tuo** in
  `nebbie-cast-spells.txt` (solo self-cast che puoi lanciare); colori/tick da
  `attrib`; click rilancia con bersaglio = PG attivo (`nclass` per cast/recall/mind).
- **Shortcut spell globali** (`nebbie-spell-shortcuts.txt`, stile zMUD) +
  **`c`/`r`/`m <spell> [bersaglio]`** con bersaglio sempre esplicito al MUD.
- **Speedwalk** (bordo destro, in basso): percorsi rapidi definiti a mano in
  un file di testo, cliccabili per eseguirli in sequenza.
- Layout ridimensionabile (larghezza automatica o manuale, altezza
  spell/speedwalk regolabile) e persistente tra sessioni.
- Tasto **"? Comandi"** in cima allo schermo: apre/chiude un elenco di tutti
  i comandi disponibili (anche `nhelp`).
- Numero di riga tra parentesi quadre nel pannello equip, come nel testo di
  `eq` sul gioco (non e' pero' il numero di slot del gioco, solo la
  posizione nella nostra lista — vedi `nhelp`/`neq`).
- **Loot + split automatico**: alla fine di ogni combattimento a cui hai
  partecipato, prende da solo le monete dal cadavere (normale o "pile of
  bones", `nloot` anche a mano) e, se sei in gruppo, divide l'importo con
  `split` (disattivabili singolarmente con `nautoloot off`/`nautosplit off`).
- **Rialzarsi e recupero arma automatici**: `stand` da solo dopo una caduta;
  `get`/`wield` da soli dell'arma persa dopo un disarmo (disattivabili con
  `nautostand off`/`nautodisarm off`).
- **Ripetizione comandi**: digita `.4s` per inviare `s` quattro volte (vale
  per qualunque comando, non solo i movimenti).
- **Corretto**: il personaggio attivo si azzera subito alla (ri)connessione,
  invece di restare agganciato al personaggio precedente finché non arriva
  un nuovo prompt — evita di lanciare comandi/spell sul personaggio sbagliato
  appena dopo un cambio personaggio.
- **Corretto**: rilevato un secondo formato di prompt reale (senza spazio
  dopo i due punti, "X:" maiuscolo) che il pacchetto non riconosceva affatto
  — con quel formato la dashboard non rilevava nessun personaggio.
- **Macro fame/sete configurabile** (`nautofeed`, file `nebbie-hunger-
  macros.txt`): alla fame/sete, esegue la sequenza di comandi configurata
  per il personaggio attivo, con la parola chiave dello zaino ("sulla
  schiena") derivata automaticamente (una sola parola, per non confondere
  comandi come `wear`) e un cooldown di 3s per evitare doppie esecuzioni
  quando fame e sete arrivano insieme.
- **Parole chiave per oggetto condivise tra personaggi** (`nitemkeywords`,
  file `nebbie-item-keywords.txt`): puoi fissare tu la parola chiave esatta
  per un dato oggetto (per nome), usata al posto dell'euristica automatica
  per il recupero arma dopo un disarmo e per lo zaino delle macro fame/sete
  — vale per tutti i personaggi, non serve ripeterla.
- **Corretto (importante)**: non serve più riavviare Mudlet dopo aver
  (re)installato una nuova versione del pacchetto — prima, i trigger e le
  funzionalità nuove non venivano attivati finché non si riavviava
  completamente Mudlet.
- **Speedwalk**: sezioni collassabili; formati `(desc) dirs` e `dirs (desc)`; `nspeedwalks` diagnostico.
- **Aggiornamento package**: `npackageupdate` o GMCP `Client.GUI` al login (versione allineata a config.lua).
- **Gestione armi** (pannello "Armi"): click per cambiare — sequenza borsa
  come nebbie-play-all; keyword senza parentesi eq `(alone luminoso)`; `identify`
  fissa la parola chiave canonica.
- **Corretto (bug al primo avvio dopo installazione pulita)**: poteva
  comparire l'errore `attempt to index global 'NebbieDash' (a nil value)`
  perché lo script agganciato a `sysLoadEvent` poteva eseguirsi prima dello
  script principale (ordine non garantito da Mudlet tra i due), chiamando
  `NebbieDash.boot()` quando `NebbieDash` non esisteva ancora.
- **Corretto (bug più grave, causa reale del pannello completamente vuoto
  dopo un riavvio completo di Mudlet)**: lo script principale del pacchetto
  aveva un errore di sintassi Lua nel punto di unione tra il codice e la
  chiamata a `boot()` finale (un a-capo mancante), che ne impediva la
  compilazione: NESSUNA funzione del pacchetto veniva definita, quindi
  nessun comando (incluso `nresync`, `nhelp`, ecc.) funzionava più. Il
  problema era mascherato da tempo dal fatto che le versioni precedenti già
  caricate in memoria da Mudlet continuavano a funzionare fino al primo
  riavvio completo del programma.
- **Batch admin (`nbatch`, solo Sirio connesso)**: esegue in sequenza comandi
  definiti in `nebbie-batch-commands.txt` su righe CSV (`nebbie-batch-items.csv`),
  attende il prompt tra un comando e l'altro, ferma tutto su errore MUD e
  scrive un log completo per ogni nome-toon in `<Toon>-YYYY-MM-DD.txt`.
- **`nbatchverify`**: controlla i log batch rispetto al CSV e ai comandi attesi;
  report in `<Toon>-YYYY-MM-DD.verify.txt`. Script offline:
  `docs/mudlet/tests/verify_batch_log.py`.
- **`nidentbatch`**: `oload $3` poi identify/junk con **`$ed`** = **`ED`+nome-toon** ($1);
  output CSV giornaliero. **`nidentbatch resume`**: salta righe gia' nel CSV di oggi.

Nessun comando viene inviato al MUD in automatico: usa `nresync` dopo il
login per sincronizzare equip e spell. Vedi `nfix` se qualcosa sembra
bloccato dopo un aggiornamento.

Documentazione completa (tutti i comandi, formato file speedwalk, changelog):
`docs/mudlet/analysis/USAGE.md` e `docs/mudlet/analysis/CHANGELOG.md` nel
repository del progetto.
]]
version = [[1.15.11]]
created = [[2026-09-26]]
website = [[https://raw.githubusercontent.com/wizardmorgan/nebbietest/mudlet/docs/mudlet/nebbie-complete-dashboard-package.mpackage]]
