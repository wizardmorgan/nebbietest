# CHANGELOG — nebbie-complete-dashboard-package

## 1.6.1 — 2026-08-10

- **Corretto (bug in gioco confermato dai log)**: la macro fame/sete poteva partire **due volte in
  parallelo**, perché il gioco spesso manda insieme sia `Hai Fame.` che `Hai sete.` (una riga
  ciascuna), e ognuna delle due faceva scattare il proprio trigger indipendentemente. Le due
  sequenze accavallate causavano fallimenti a catena (es. il secondo `rem` falliva con "Non lo stai
  usando." perché il primo aveva già tolto lo zaino un istante prima). Corretto con un cooldown di 3
  secondi tra un'esecuzione della macro e la successiva.
- **Corretto (bug in gioco confermato dai log)**: il segnaposto `{zaino}` veniva sostituito con
  **tutte** le parole chiave estratte dal nome dell'oggetto (es. "borsa inesauribile korred"), ma
  passare più parole a `wear` confondeva il parser del gioco, che interpretava la parola aggiuntiva
  come una posizione del corpo invece che come parte del nome dell'oggetto (risposta osservata: "Non
  puoi indossare nulla su un inesauribile."). Corretto usando solo **l'ultima** parola chiave (es.
  "korred"), come nell'esempio originale fornito dall'utente.
- **Versione interna** alzata a 1.6.1.

## 1.6.0 — 2026-08-10

- **Corretto (bug importante)**: "la dashboard non sta rilevando alcun personaggio". Causa: esiste
  almeno un secondo formato di prompt reale (personaggio `Mirari`, es. `Mirari H:655/655 M:533/533
  V:271/271 X:284016936 - */* - *-* - [[------T----]] - G:38267520 >>`), **senza spazio dopo i due
  punti** e con `X:` maiuscolo — diverso dal primo formato confermato (`NomiyaMaki H: 747/747 M:
  532/532 ... x:-238860738 *:* *:* [[D]] G:3449502 >>`, con lo spazio). Il parsing del prompt
  gestiva già entrambi i formati, ma lo "shield" del trigger che lo attiva cercava la sottostringa
  fissa `" M: "` (con lo spazio finale), che non compare mai nel secondo formato: il trigger non
  scattava **mai** per quel formato, quindi nessun personaggio veniva mai rilevato per l'intera
  sessione. Corretto restringendo lo shield a `" M:"` (senza lo spazio finale), che matcha entrambi i
  formati; il parsing preciso resta comunque affidato alla regex completa, quindi non si rischiano
  falsi positivi.
- **Aggiunto**: macro configurabile per fame/sete (`nautofeed <on|off>`, default **on**). Scatta sui
  testi reali `Hai Fame.` / `Hai sete.` ed esegue la sequenza di comandi scritta dall'utente nel file
  `nebbie-hunger-macros.txt` (una riga per personaggio, formato `NomePersonaggio: comando1, comando2,
  ...`), con il segnaposto `{zaino}` sostituito automaticamente dalla parola chiave dell'oggetto nello
  slot equip "sulla schiena" (letta dal pannello equip già sincronizzato, senza bisogno di conoscerla
  in anticipo). Dentro la macro si può usare la stessa sintassi `.N comando` della ripetizione
  generica (es. `.5 drink cornu`). Comando `nhungermacros` per ricaricare il file senza riavviare
  Mudlet. Il resto della sequenza (es. il nome dell'oggetto da bere dentro lo zaino) resta specifico
  del personaggio e va scritto a mano nel file, come richiesto esplicitamente dall'utente.
- **Versione interna** alzata a 1.6.0.

## 1.5.0 — 2026-08-10

- **Corretto**: il personaggio attivo si azzera subito alla (ri)connessione, invece di restare
  agganciato al personaggio precedente finché non arriva un nuovo prompt. Prima di questo fix, uno
  spell lanciato su se stessi (o un click nel pannello) subito dopo un cambio personaggio poteva
  colpire ancora il personaggio precedente, senza alcun avviso.
- **Corretto (difensivo)**: i due trigger di verifica gruppo (usati dallo split automatico) sono ora
  ancorati a inizio riga invece di semplici sottostringhe libere, per ridurre il rischio che del
  testo di gioco non correlato faccia scattare uno split senza essere davvero in gruppo (bug
  segnalato; causa esatta non ancora confermata con un log reale — se si ripresenta, serve quel log).
- **Aggiunto**: rialzarsi automatico (`stand`) dopo una caduta, riconosciuta dal testo `Inciampi e
  cadi per terra.`. Disattivabile con `nautostand off` (default **on**). Nota: copre solo questo
  specifico messaggio di caduta — se ce ne sono altri andranno aggiunti quando forniti.
- **Aggiunto**: recupero automatico dell'arma dopo un disarmo (`Ti disarmano e ... vola dalla tua
  presa.`): le parole chiave dell'arma vengono derivate automaticamente dal nome catturato nel
  messaggio stesso (ripulito da articoli/preposizioni italiane), poi `get`/`wield` automatici.
  Disattivabile con `nautodisarm off` (default **on**).
- **Aggiunto**: ripetizione generica di un comando col prefisso `.N`, es. `.4s` invia `s` quattro
  volte (funziona con qualsiasi comando, non solo i movimenti).
- **Versione interna** alzata a 1.5.0.

## 1.4.1 — 2026-08-10

- **Aggiunto**: loot **completamente automatico** alla fine di ogni combattimento a cui hai
  partecipato (non serve più digitare `nloot` a mano). Riconosciuto dal testo reale del gioco `La
  tua parte di esperienza e' di N punti.` (anche con N=0), che compare solo quando hai
  effettivamente contribuito al combattimento — a differenza di `X is dead! R.I.P.`, che potrebbe
  comparire anche per uccisioni non tue nella stessa stanza.
- **Aggiunto**: nuovo comando `nautoloot <on|off>` (default **on**), indipendente da `nautosplit`:
  puoi disattivare separatamente il loot automatico e/o lo split automatico.
- **Versione interna** alzata a 1.4.1.

## 1.4.0 — 2026-08-10

- **Aggiunto**: primo modulo di automazione di gioco (oltre a equip/spell/speedwalk): **loot +
  split automatico**.
  - `nloot`: prende le monete dal cadavere presente, sia normale (`get all.coin corp`) sia "pile of
    bones" di un non-morto (`get all.coin pile`) — prova entrambe le sintassi, una delle due fallirà
    sempre in modo innocuo se non applicabile.
  - Dopo un loot riuscito (riconosciuto dalla riga `C'erano N monete.`, sia se avviato con `nloot`
    sia digitato a mano), se sei in gruppo (verificato leggendo l'output di `group`) invia
    automaticamente `split N` con l'importo appena raccolto. Disattivabile con `nautosplit off`
    (default: **on**).
  - Nuovo comando `nsplit <numero>` per uno split manuale (senza passare dal loot).
- **Aggiunto (difensivo)**: stesso watchdog di inattività già introdotto in 1.3.3 per eq/attrib,
  applicato anche al controllo del gruppo dopo un loot: se `group` non risponde in modo riconosciuto
  entro pochi secondi, il controllo si annulla da solo (nessuno split "in sospeso" per sempre).
- **Nota**: rilevare automaticamente la fine di un combattimento (per lanciare `nloot` da solo senza
  doverlo digitare) resta aperto — serve il testo reale del messaggio di vittoria/morte del mostro,
  non ancora fornito (vedi Q&A.md Round 11).
- **Versione interna** alzata a 1.4.0.

## 1.3.3 — 2026-08-09

- **Aggiunto**: numero di riga tra parentesi quadre nel pannello equip (es. `[ 1] <sul dito
  destro> ...`), per somigliare visivamente al testo di `eq` sul gioco (richiesta esplicita: "mi
  piaceva come avevi messo prima il numero dello slot"). **Attenzione**: è solo la posizione della
  riga nella nostra lista, NON il numero di slot che riporta il gioco — quel numero resta
  inaffidabile come identificatore di posizione (vedi bug corretto in 1.3.0/1.2.0) e non è mai usato
  per decidere quale oggetto va in quale riga.
- **Aggiunto**: tasto **"? Comandi"** fluttuante in cima allo schermo (sempre visibile, anche con
  `ngui` disattivato). Cliccandolo si apre/chiude una finestra con l'elenco di tutti i comandi
  disponibili e una breve descrizione di ciascuno. Nuovo alias `nhelp` per aprirla/chiuderla anche
  da riga di comando. Nota tecnica: Mudlet non permette di creare/verificare da script una vera voce
  di toolbar nativa in modo affidabile (si configura solo via editor pacchetti), quindi si usa una
  label cliccabile ancorata allo schermo, che si comporta come un pulsante a tutti gli effetti.
- **Corretto (difensivo)**: aggiunto un "watchdog" di inattività (4s) alle catture di `eq`/`attrib`.
  Se il gioco manda un blocco che il parser non riconosce come "finito" (riga vuota o nuovo prompt
  non rilevati, es. per una variante di formato non ancora vista), la cattura ora si chiude comunque
  da sola dopo qualche secondo di silenzio, invece di restare bloccata per sempre. Questo è il
  sospetto principale per il bug segnalato "gli spell attivi rimangono rossi anche dopo `attrib`":
  se la cattura precedente non si era mai chiusa, i nuovi tick (e quindi il colore, che viene
  ricalcolato ad ogni aggiornamento del pannello) non venivano mai salvati. La logica di
  sostituzione dei dati è stata verificata via test automatico (vedi
  `docs/mudlet/tests/smoke_test_parsing.lua`, test "attrib: risync sostituisce") ed è corretta di
  per sé: se il problema persiste dopo questo fix, serve un esempio reale copiato dal gioco del
  blocco `attrib` completo (header, righe spell, riga finale) per capire quale variante di formato
  non viene ancora riconosciuta.
- **Versione interna** alzata a 1.3.3.

## 1.3.2 — 2026-08-09

- **Aggiunto**: sintassi esplicita con virgola per lanciare uno spell su un bersaglio QUALSIASI (non
  solo il proprio personaggio, come nel fix 1.3.1) da riga di comando: `c heal, bob` → `cast 'heal'
  bob`. Funziona anche con nomi spell multi-parola (`r word of recall, bob` → `recall 'word of
  recall' bob`) e ha precedenza sull'euristica automatica sul proprio nome introdotta in 1.3.1 (se
  scrivi la virgola, il bersaglio è sempre quello dopo la virgola). Senza virgola il comportamento
  resta quello di 1.3.1 (bersaglio automatico solo se l'ultima parola abbrevia il proprio nome,
  altrimenti tutto il testo è il nome spell).
- **Versione interna** alzata a 1.3.2.

## 1.3.1 — 2026-08-09

- **Fix**: il lancio manuale `c`/`r`/`m <nome> <bersaglio>` non funzionava quando il bersaglio era
  scritto come ultima parola (es. `c heal nom`, `c darkne nom`): l'intero testo veniva inviato come
  UN SOLO nome spell (`cast 'heal nom'`), che il gioco non riconosce, invece di separare nome e
  bersaglio (`cast 'heal' nom`, sintassi richiesta dal server — vedi `do_cast` in
  `src/spell_parser.cpp`). Ora, se l'ultima parola digitata è un'abbreviazione plausibile (prefisso,
  almeno 2 lettere) del personaggio attivo, viene staccata e usata come bersaglio esplicito
  automaticamente; il click dal pannello "Spell attivi" (che passa già un bersaglio esplicito) non
  è interessato dal cambiamento. Il caso storico senza bersaglio (es. `c word of r`) continua a
  funzionare invariato.
- **Versione interna** alzata a 1.3.1.

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
