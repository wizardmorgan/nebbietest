# Note dalla Wiki Mudlet ufficiale (Fase 1 — read-only)

Fonte primaria: https://wiki.mudlet.org/ — consultata il 2026-08-08.
Versione Mudlet target confermata dall'utente: **4.22.0** (vedi `Q&A.md`, Round 1, Q1).
Ogni API citata sotto è verificata compatibile con 4.22.0 (indicato "Available in Mudlet X.Y+"
quando la pagina lo specifica; se X.Y ≤ 4.22 è compatibile).

Per ogni voce: nome/API, URL wiki, versione minima Mudlet, implicazioni per il design Nebbie.

---

## 1. Trigger — tipi, costo prestazionale, "shielding"

**URL**: https://wiki.mudlet.org/w/Manual:Trigger_Engine, https://wiki.mudlet.org/w/Manual:Best_Practices

- Tipi di pattern: Substring, Perl Regex, Start of Line (begin-of-line), Exact Match, Lua
  Function, Line Spacer, Color Trigger, **Prompt**.
- **Costo relativo per riga non-matchata** (dal forum ufficiale, benchmark citati dalla wiki
  Best Practices): Begin-of-line / Exact Match sono i più veloci; Substring poco più lento;
  **Perl Regex è il tipo più lento** (a parità di altre condizioni); i trigger Lua-function sono
  ancora più costosi perché eseguono codice Lua ad ogni riga.
- **Best practice ufficiale — "shielding"**: una regex costosa va sempre preceduta ("scudata")
  da un trigger più veloce (substring o begin-of-line) che filtra la maggior parte delle righe;
  la regex gira solo sulle righe già filtrate dal trigger scudo (trigger annidato/chain, oppure
  trigger multiline/AND con line-delta 0 + lettura da `multimatches` invece di `matches`).
  Benchmark citati: **regex non scudata può costare fino al 50% di CPU in più** rispetto alla
  versione scudata, su 100k trigger.
- **Implicazione per Nebbie**: i "DIVIETI" elencati in AGENT-PROMPT-ANALISI-ZERO.txt
  (regex `.+` catch-all, substring `" H:"/" M:"/" V:"/" X:"` su OGNI riga) sono in linea con
  quanto la wiki stessa sconsiglia se usati SENZA scudo — ma non sono vietati in assoluto dalla
  wiki: un substring-trigger scudo su un frammento fisso del prompt (es. il nome del personaggio,
  se stabile) seguito da regex figlia è il pattern ufficiale raccomandato. Il problema del
  pacchetto precedente (da rivalidare leggendo il codice) è probabile che non fosse la substring
  in sé ma l'assenza di scudo + uso su multipli trigger indipendenti anziché un chain unico.

---

## 2. Trigger di tipo "Prompt" — requisito Telnet GA/EOR

**URL**: https://wiki.mudlet.org/w/Manual:Trigger_Engine (sezione "Prompt"),
https://wiki.mudlet.org/w/Manual:Mudlet_Object_Functions (sezioni `tempPromptTrigger`,
`permPromptTrigger`, `isPrompt`)

- Il trigger di tipo **Prompt** e le funzioni **`tempPromptTrigger()`** (3.6+),
  **`permPromptTrigger()`** e **`isPrompt()`** funzionano SOLO se il server MUD implementa il
  telnet **GO-AHEAD (GA)** oppure **End-Of-Record (EOR)**.
- Se il server non implementa GA/EOR, Mudlet mostra **"No GA"** in basso a destra nella barra di
  stato (indicatore `N:` senza numero) e i trigger di tipo Prompt **non scattano in modo
  affidabile** (secondo le note ufficiali: "If the trigger is not working, check that the N:
  bottom-right has a number").
- **Implicazione per Nebbie — GAP BLOCCANTE non ancora verificato**: non sappiamo se il server
  Nebbie Arcane invia GA/EOR. Questo è un dato di **codice server** (repo `nebbietest`, `src/`)
  o verificabile empiricamente in game (guardando l'indicatore `N:` in basso a destra in Mudlet).
  **Non si può assumere né in un senso né nell'altro** (regola AGENT-RULES.txt §1). Registrato
  come domanda aperta in `Q&A.md` Round 3 / `REQUIREMENTS.md`.
  Se GA non è disponibile, il trigger "Prompt" ufficiale NON è utilizzabile e la rilevazione del
  prompt deve basarsi su pattern testuali (regex/substring scudata) sulla riga stessa — che è
  l'approccio che il pacchetto precedente sembra aver usato (probabilmente proprio perché GA non
  è disponibile — da confermare, non assumere).

---

## 3. `getLines` / `getLineCount` — indicizzazione e limiti buffer

**URL**: https://wiki.mudlet.org/w/Manual:Scripting (sezione su `moveCursor`/`getLineCount`/
`getLines`), codice sorgente commentato in
https://github.com/Mudlet/Mudlet/blob/master/src/mudlet-lua/lua/CoreMudlet.lua

- `getLineCount()`: ritorna il numero assoluto dell'ultima riga nel buffer del console (main o
  miniconsole).
- `getLines(from, to)`: **usa numeri di riga ASSOLUTI** per `from` e `to` (non relativi alla
  posizione corrente) — la pagina Manual:Scripting lo dice esplicitamente: *"Note: This function
  uses absolute line numbers, not relative ones like in moveCursor()"*.
- **Attenzione — ambiguità documentata nella wiki stessa**: il commento nel codice sorgente Lua
  (`CoreMudlet.lua`, usato anche per generare la doc) descrive il valore di ritorno come
  `Lua_table[relative_linenumber, content]` (chiavi "relative"), mentre il testo della pagina
  manuale dice che l'input è assoluto. Questa è una fonte di confusione reale, non un'invenzione:
  **le CHIAVI della tabella restituita partono da 1 in poi in base al numero di righe richieste
  (quindi "relative" all'intervallo estratto)**, mentre i PARAMETRI `from`/`to` sono assoluti.
  Confondere questi due concetti (trattare le chiavi della tabella come se fossero numeri di riga
  assoluti) è un bug plausibile e concreto, coerente con quanto segnalato come sospetto nel
  pacchetto precedente ("getLines: indici relativi 1..n, filtri assoluti errati").
- Non è documentato un limite esplicito superiore al buffer dello scrollback; la dimensione è
  configurabile per profilo (impostazioni generali, "Display" → command/scrollback lines) mediante
  `getConsoleBufferSize()` / `setConsoleBufferSize()` (Manual:Mudlet_Object_Functions).
- **Implicazione per Nebbie**: se il design userà scan di scrollback via `getLines`, va sempre
  usato `getLineCount()` per calcolare gli indici assoluti correnti PRIMA di ogni chiamata (il
  buffer cresce continuamente), e va gestita esplicitamente la differenza tra indice assoluto
  richiesto e chiave relativa restituita.

---

## 4. Trigger multiline / prompt-delimited capture

**URL**: https://wiki.mudlet.org/w/Manual:Trigger_Engine (sezione "Multi-Line Triggers and
Multi-Condition Triggers")

- I trigger multiline/AND richiedono che TUTTE le condizioni della lista matchino entro un
  margine di righe (delta) definito, in ordine. Utile per catturare blocchi delimitati (es.
  "Stai usando:" ... righe slot ... riga vuota o prompt successivo) senza fare scan manuale dello
  scrollback.
- I capture group di trigger multiline vanno letti da `multimatches[n][m]`, NON da `matches[]`
  (fonte comune di bug quando si scudano regex con AND trigger — vedi anche §1).

---

## 5. Eventi di sistema (`sysLoadEvent`, `sysInstallPackage`, `sysUninstallPackage`, `sysConnectionEvent`)

**URL**: https://wiki.mudlet.org/w/Manual:Event_Engine

- **`sysLoadEvent`**: sparato dopo che Mudlet ha finito di caricare il profilo (script, package,
  moduli installati). È il punto ufficiale per inizializzazioni "una tantum" all'avvio profilo.
  Nota importante della wiki: gli script vengono ricompilati/eseguiti anche ad ogni salvataggio
  nell'editor, quindi agganciare la logica di init A `sysLoadEvent` (anziché eseguirla nel corpo
  dello script) evita ri-esecuzioni indesiderate durante lo sviluppo.
  Dal **4.20.0+** riceve un argomento booleano che indica se l'evento arriva da un nuovo
  caricamento profilo o da una chiamata a `resetProfile()`.
- **`sysInstallPackage` / `sysUninstallPackage`**: sparati rispettivamente subito dopo
  l'installazione e subito prima della rimozione di un package, con nome (e filename per
  install) come argomenti. Disponibili da Mudlet 3.1+.
- **Implicazione per Nebbie**: il "divieto" elencato nel prompt ("auto eq/attrib e auto
  download/upgrade al boot") è coerente con l'uso solitamente scorretto di `sysLoadEvent` per
  inviare comandi al MUD in automatico — se il profilo si ricarica spesso (es. editing script),
  ogni reload manderebbe di nuovo `eq`/`attrib` al server. Da trattare con cautela nel design:
  se serve un boot-sync, va reso esplicito/manuale (comando utente) piuttosto che automatico su
  `sysLoadEvent`, salvo diversa decisione motivata e approvata dall'utente.

---

## 6. Mini console e bordi laterali (dashboard L/R)

**URL**: https://wiki.mudlet.org/w/Manual:UI_Functions (sezioni `createMiniConsole`,
`setBorderLeft`, `setBorderRight`, `setBorderSizes`, `setBorderColor`)

- **`createMiniConsole([userwindow], name, x, y, width, height)`**: crea una finestra di testo
  colorato indipendente dal main; supporta `clearWindow()`/`moveCursor()`/`cecho()`/`echo()` per
  quella finestra. Parametro `userwindow` opzionale disponibile da **Mudlet 4.6.1+** (compatibile
  con 4.22.0). **Nota ufficiale su cambio profilo**: quando si passa da un profilo all'altro con
  miniconsole ad autowrap attive, il testo può apparire tagliato a destra finché Qt non
  ricalcola la geometria del widget — soluzione raccomandata dalla wiki: rimandare i calcoli
  dipendenti dalla larghezza con `tempTimer(0, function() ... end)`.
  **Implicazione diretta per Nebbie**: nel nostro caso lo "switch personaggio" è sequenziale
  entro lo STESSO profilo (non switch tra profili Mudlet diversi), quindi questo problema
  specifico probabilmente non si applica direttamente — ma il pattern "defer con `tempTimer(0,
  ...)` dopo un cambio di stato" resta rilevante per qualunque refresh dashboard dopo un evento
  di login/reconnect.
- **`setBorderLeft(size)` / `setBorderRight(size)` / `setBorderSizes(top, right, bottom, left)`**
  (4.0+): riservano una fascia di pixel del MAIN window in cui il testo di gioco non scorre più,
  lasciando spazio per elementi grafici propri (es. dashboard permanente L/R). Alternativa
  concettuale a miniconsole "flottanti" sovrapposte: qui il testo di gioco stesso si restringe.
- **Alternativa**: Geyser (framework Lua di layout ad alto livello sopra le funzioni UI native,
  vedi https://wiki.mudlet.org/w/Manual:Geyser) — package Geyser semplifica creazione/gestione di
  container, ma introduce una dipendenza aggiuntiva da valutare in DESIGN-OPTIONS.md.

---

## 7. Ciclo di vita dei Package Mudlet (.mpackage)

**URL**: https://wiki.mudlet.org/w/Manual:Package_Manager, thread forum ufficiali citati (Mudlet
Packages)

- Un `.mpackage` è un file **ZIP rinominato** che DEVE contenere, nella root dell'archivio:
  1. un file **`config.lua`** con (attualmente) solo il nome del package come stringa Lua
     (`name = "MioPackage"`);
  2. un file **XML** con lo stesso nome del package, contenente tutti gli elementi Mudlet
     (alias, trigger, timer, script, keybinding, bottoni/toolbar);
  3. opzionalmente altri file (immagini, suoni, font) in una struttura di cartelle a piacere —
     dichiarati nella sezione Assets se referenziati da script (altrimenti funzionano solo in
     locale e non per chi installa il package altrove).
- All'installazione, il contenuto del package viene estratto in
  `getMudletHomeDir() .. "/" .. packageName` (accessibile dagli script per referenziare i propri
  asset).
- Il modo "ufficiale" supportato per creare un package è il **Package Exporter** integrato
  (menu Toolbox), che genera l'XML automaticamente; costruire l'XML a mano (come sembra fare
  `build-nebbie-package.py`, da leggere in dettaglio nella fase "codice legacy") è possibile ma
  non è il percorso raccomandato dalla wiki — comporta il rischio di XML non conforme allo schema
  interno di Mudlet (una possibile causa, da verificare col codice, dei problemi di sync/versione
  osservati in precedenza).

---

## 8. Download e auto-update (`downloadFile`, eventi correlati)

**URL**: https://wiki.mudlet.org/w/Manual:Networking_Functions, Manual:Event_Engine
(`sysDownloadDone`, `sysDownloadError`, `sysDownloadFileProgress`)

- `downloadFile(saveto, url)` è **asincrono**: non blocca lo script, bisogna gestire il
  completamento tramite l'evento `sysDownloadDone` (argomenti: percorso file, dimensione,
  risposta HTTP) o l'errore tramite `sysDownloadError`.
- **Implicazione per Nebbie**: qualunque logica di "self-update" del package (menzionata nei
  "divieti": *"forceUpgrade/download automatico al login senza consenso"*) che non gestisca
  correttamente l'asincronia (es. assume che il file esista subito dopo la chiamata a
  `downloadFile`) è strutturalmente fragile — coerente con il sintomo "hang" segnalato. Da
  verificare puntualmente nel codice legacy, non da assumere come causa certa.

---

## 9. Persistenza dati per personaggio (`table.save` / `table.load`)

**URL**: https://wiki.mudlet.org/w/Manual:Table_Functions, Manual:Advanced_Lua,
Manual:Miscellaneous_Functions (`getMudletHomeDir`)

- `table.save(location, table)` / `table.load(location, table)` serializzano/deserializzano
  tabelle Lua su file. Pattern raccomandato: salvare sotto `getMudletHomeDir()` (cartella dati
  del **profilo corrente**, NON la cartella di installazione di Mudlet — un errore comune
  segnalato più volte nei forum ufficiali causa perdita dati con profili multipli).
- Pattern di init raccomandato: `mytable = mytable or {}` poi `if io.exists(path) then
  table.load(path, mytable) end`, tipicamente agganciato a `sysLoadEvent`; salvataggio ad ogni
  modifica rilevante o su `sysExitEvent`.
- **Implicazione diretta per il requisito multi-personaggio (Q&A.md Round 2)**: `table.save`/
  `table.load` con una tabella chiave = nome personaggio (es.
  `nebbieChars["NomiyaMaki"] = { eq = {...}, spells = {...}, weaponConfig = {...} }`) è il
  meccanismo standard per la persistenza su disco tra sessioni, SE l'utente conferma di volerla
  (`Q&A.md` Round 2, domanda 4: risposta "nessuna preferenza" — quindi da presentare come
  opzione con pro/contro in `DESIGN-OPTIONS.md`, non da assumere).

---

## 10. Versione Mudlet 4.22.0 — note di compatibilità

- Tutte le API citate sopra sono disponibili in Mudlet 4.22.0 (le versioni minime indicate dalla
  wiki — 3.1+, 3.6+, 4.0+, 4.6.1+, 4.11+, 4.20.0+ — sono tutte ≤ 4.22.0).
- Mudlet 4.22.0 è una release della serie 4.x (pre Mudlet 5, che ha introdotto un refactor
  significativo di alcune parti di UI/Lua). Non è stata trovata, nella ricerca svolta, alcuna nota
  di deprecazione che riguardi le funzioni sopra elencate nella serie 4.x. Se in futuro si
  aggiornasse a Mudlet 5.x andrebbe fatta una verifica di compatibilità dedicata (fuori scope
  ora, dato che l'utente ha confermato 4.22.0).

---

## Fonti consultate (elenco URL)

- https://wiki.mudlet.org/w/Manual:Introduction
- https://wiki.mudlet.org/w/Manual:Trigger_Engine
- https://wiki.mudlet.org/w/Manual:Best_Practices
- https://wiki.mudlet.org/w/Regex
- https://wiki.mudlet.org/w/Manual:Lua_Functions
- https://wiki.mudlet.org/w/Manual:Lua_Functions_Basics
- https://wiki.mudlet.org/w/Manual:Scripting
- https://wiki.mudlet.org/w/Manual:UI_Functions
- https://wiki.mudlet.org/w/Manual:Mudlet_Object_Functions
- https://wiki.mudlet.org/w/Manual:Event_Engine
- https://wiki.mudlet.org/w/Manual:Technical_Manual/en
- https://wiki.mudlet.org/w/Manual:Package_Manager
- https://wiki.mudlet.org/w/Manual:Networking_Functions
- https://wiki.mudlet.org/w/Manual:Table_Functions
- https://wiki.mudlet.org/w/Manual:Advanced_Lua
- https://wiki.mudlet.org/w/Manual:Miscellaneous_Functions
- https://github.com/Mudlet/Mudlet/blob/master/src/mudlet-lua/lua/CoreMudlet.lua (codice sorgente
  ufficiale citato per chiarire l'ambiguità di `getLines`, non "codice legacy Nebbie")
- Forum ufficiale Mudlet (benchmark trigger shielding): https://forums.mudlet.org/viewtopic.php?f=12&t=1441 ,
  https://forums.mudlet.org/viewtopic.php?t=22836
