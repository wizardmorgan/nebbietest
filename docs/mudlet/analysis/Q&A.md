# Q&A — Nebbie Play All (Mudlet)

Domande poste all'utente e risposte ricevute. Regola: nessuna assunzione silenziosa
(AGENT-RULES.txt §1-2). Ogni gap non ancora risposto è marcato **[APERTO]**.

---

## Round 1 — Domande iniziali (template AGENT-PROMPT-ANALISI-ZERO.txt)

| # | Domanda | Risposta utente |
|---|---------|------------------|
| 1 | Versione Mudlet esatta (Help → About)? | **4.22.0** |
| 2 | OS e profilo Mudlet di riferimento ("nebbie vero", PG NomiyaMaki)? | Il profilo specifico è indifferente. **Requisito nuovo**: un solo profilo Mudlet deve permettere di switchare tra più personaggi, ciascuno con proprie differenze in skill, spell e prompt. Vedi Round 2. |
| 3 | Package installati ora? | **Nessuno** — l'utente ha disinstallato `nebbie-play-all`. |
| 4 | Mudlet lento al login o solo dopo connessione? | Da quando `nebbie-play-all` è stato disinstallato, **non è più lento**. (Indizio: il rallentamento osservato in precedenza era probabilmente causato dal pacchetto stesso — trigger/refresh — non da Mudlet o dal server di per sé. Da verificare in Fase 1/3, non assumere causa esatta senza analisi del codice legacy + wiki performance trigger.) |
| 5 | Output completo incollato (eq, attrib, prompt)? | Non richiesto esplicitamente in round 1: gli esempi reali forniti nel prompt (prompt, estratto `eq`, estratto `attrib`) sono considerati validi come riferimento minimo. Se servirà altro dettaglio (es. lista completa 21 slot equip, altri formati `attrib`), verrà richiesto in round successivo. |
| 6 | Pannelli equip/spell: vuoti / grigi / ngui aiuta? | **Vuoti** (nessun errore visibile), con `nebbie-play-all` installato in precedenza. |
| 7 | Server espone GMCP? | **No GMCP** — solo testo/ANSI. Confermato dall'utente: nessuna assunzione di protocolli extra da fare in design. |
| 8 | eq/attrib: devono restare visibili in console o è ammesso gag? | **Nessuna preferenza** — decisione delegata a analisi/best practice wiki, da motivare in DESIGN-OPTIONS.md / RECOMMENDATION.md. |
| 9 | Priorità prima release? | **Pannello equip funzionante prima di tutto.** |
| 10 | Accettabile un package NUOVO (nome diverso) se preferibile a patchare l'esistente? | **Sì**, esplicitamente accettato. |

---

## Round 2 — Follow-up sul requisito multi-personaggio (nuovo, non nel prompt originale)

**Motivo**: la risposta alla domanda 2 introduce un requisito che cambia sostanzialmente lo scope
architetturale (stato per-personaggio all'interno di un singolo profilo Mudlet, non solo dashboard
per un singolo PG). Prima di procedere a Fase 2 (Requisiti) e Fase 3 (Design) servono le seguenti
informazioni — **nessuna assunzione verrà fatta senza risposta**:

1. **Come si identifica il personaggio attivo?** Il prompt di gioco contiene il nome PG (es.
   `NomiyaMaki H: 747/747 ...`). È corretto assumere che il nome del personaggio si possa sempre
   leggere dal prompt (o da un messaggio di login), oppure serve un comando/segnale esplicito?
   **[APERTO]**
2. **Cosa significa "switchare tra personaggi" a livello di connessione di gioco?**
   - (a) Un solo personaggio collegato per volta: ti disconnetti dal PG A e ti riconnetti con il
     PG B, sempre nello stesso profilo Mudlet (stessa finestra/sessione Mudlet, connessione
     telnet sequenziale)?
   - (b) Multiplay: più personaggi connessi **contemporaneamente** dentro lo stesso profilo
     Mudlet (es. via comando MUD "link"/secondo login, o funzionalità Mudlet di
     multi-sessione/mini-console per connessione secondaria)?
   **[APERTO — bloccante per il design: (a) e (b) richiedono architetture molto diverse]**
3. **Quali dati vanno tenuti separati per personaggio** (rispetto a dati comuni a tutti i PG dello
   stesso account/utente)? Es.: equip, spell attivi, percorsi speedwalk, config armi/utility,
   layout pannelli. Conferma o correggi l'elenco. **[APERTO]**
4. **Persistenza**: i dati per personaggio (cache equip/spell/config) devono sopravvivere alla
   chiusura di Mudlet (salvataggio su disco tra sessioni), o basta che vivano in memoria per la
   sessione corrente e vengano ricostruiti da `eq`/`attrib` ad ogni connessione? **[APERTO]**
5. **Nome del nuovo package**: hai una preferenza, o lascio una proposta motivata in
   `RECOMMENDATION.md`? **[APERTO — non bloccante, si può proporre]**
6. **Comandi utente**: vanno bene i nomi proposti nel prompt originale (`neq`, `nattrib`,
   `nresync`, `ngui`, `nlayout`, `nfix`), aggiungendo un comando per lo switch personaggio (es.
   `nchar <nome>`), o preferisci altro? **[APERTO — non bloccante]**

---

## Round 2 — Risposte ricevute

| # | Domanda | Risposta utente |
|---|---------|------------------|
| 1 | Nome PG identificabile dal prompt? | **Sì**, il nome nel prompt è affidabile per identificare il PG attivo. |
| 2 | Sequenziale o simultaneo? | **Sequenziale**: un PG alla volta, disconnessione/riconnessione nello stesso profilo Mudlet (NON multiplay/doppio login). Questo semplifica molto il design: un solo `Host`/connessione telnet attiva per volta, stato "personaggio corrente" che cambia a login/riconnessione. |
| 3 | Dati da separare per personaggio | **Equipaggiamento (eq)**, **spell/buff attivi (attrib)**, **config armi/utility per PG**. (Percorsi speedwalk e layout pannelli: NON selezionati esplicitamente — trattarli come comuni/condivisi salvo diversa indicazione futura. Non assumere altrimenti.) |
| 4 | Persistenza su disco? | **Nessuna preferenza** — decisione delegata all'analisi (pro/contro in DESIGN-OPTIONS.md / RECOMMENDATION.md). |
| 5 | Nome package | **Da proporre** in RECOMMENDATION.md (motivato). |
| 6 | Nomi comandi | **Da decidere dopo aver visto il design** (non bloccante ora). |

**Conseguenza per il design**: essendo lo switch personaggio **sequenziale** (un login alla
volta sulla stessa connessione), il problema si riduce a: (1) rilevare in modo affidabile il
nome del PG attivo dal prompt ad ogni (ri)connessione/login, (2) tenere una cache per-personaggio
(chiave = nome PG) di eq/spell/config armi, caricata quando quel nome compare nel prompt, (3)
decidere se questa cache vive solo in memoria di sessione o su disco tra riavvii di Mudlet — punto
ancora aperto, da trattare come alternative in DESIGN-OPTIONS.md piuttosto che assunzione.

---

## Round 3 — Gap bloccanti per il pannello Equip (R5/P0, da REQUIREMENTS.md §5)

| # | Domanda | Risposta utente |
|---|---------|------------------|
| 1 | Elenco completo/output reale di `eq` (21 slot) | **RICEVUTO** (2026-08-08 22:24) — vedi sotto, trascritto integralmente in `REQUIREMENTS.md` §4 (M4). |
| 2 | Formato esatto del prompt (spazio dopo `H:`? maiuscole X?) | **RICEVUTO** — `NomiyaMaki H: 747/747 M: 532/532 V: 158/158 x:-238860738 *:* *:* [[D]] G:3449502 >>` |
| 3 | `eq`/`attrib` vs `equipment`/`attribute` | **Entrambe le forme funzionano** (corta e lunga). |

**Dati ricevuti — output reale `eq` (personaggio NomiyaMaki, copiato dall'utente, 2026-08-08)**:

```
NomiyaMaki H: 747/747 M: 532/532 V: 158/158 x:-238860738 *:* *:* [[D]] G:3449502 >>
eq
Stai usando:
[ 1] <sul dito destro>       Il sigillo delle ombre
[ 2] <sul dito sinistro>     La bandiera britannica
[ 3] <intorno al collo>      Il Ciondolo con la Testa di Jeeg Robot
[ 4] <intorno al collo>      Una collana di perline
[ 5] <sul corpo>             Un tubino rinforzato con una grossa Union Jack (in condizioni
eccellenti)
[ 6] <in testa>              Un cerchietto tempestato di Diamanti Rossi (in condizioni eccellenti)
[ 7] <sulle gambe>           Dei gambali di piastra scintillanti (hanno un alone luminoso) (in
ottime condizioni)
[ 8] <ai piedi>              Gli stivali del lungo viaggio (in condizioni eccellenti)
[ 9] <sulle mani>            Il Guanto dell'Infinito (hanno un alone luminoso) (in condizioni
eccellenti)
[10] <sulle braccia>         Una manica dell'abito di Twiggy (emettono un forte ronzio) (in
condizioni eccellenti)
[11] <come scudo>            The Cross (in condizioni eccellenti)
[12] <intorno al corpo>      Una giacca di carapace d'insetto opera di NomiyaMaki (in condizioni
eccellenti)
[13] <intorno alla vita>     A feathered belt (in condizioni eccellenti)
[14] <al polso destro>       Un bracciale a pois bianchi e rossi (in condizioni eccellenti)
[15] <al polso sinistro>     Un bracciale di plastica rosa (in condizioni eccellenti)
[16] <impugnato>             La Flamberga di Boris
[17] <tenuto>                Happy End of the World
[18] <sulla schiena>         It's a Beautiful Day
[19] <all'orecchio destro>   Un orecchino tigrato made in Tokio (invisibile) (in condizioni
eccellenti)
[20] <all'orecchio sinistro> Una rosa metallica (ha un alone luminoso) (in condizioni eccellenti)
[21] <davanti agli occhi>    Glass no Kamen

NomiyaMaki H: 747/747 M: 532/532 V: 158/158 x:-238860738 *:* *:* [[D]] G:3449502 >>
```

**Osservazioni concrete tratte da questo dato reale (non assunzioni)**:

1. **Root cause confermata dei "pannelli vuoti" con il codice legacy**: il prompt reale ha uno
   **spazio dopo il carattere `:`** (`H: 747/747`), mentre `Nebbie.parsePromptPair()` in
   `nebbie-installer-core.lua` (righe 121-131) usa i pattern Lua `letter..":(%d+)/(%d+)"` e
   `letter.."(%d+)/(%d+)"` — **nessuno dei due tollera uno spazio dopo i due punti**. Con
   l'output reale, `H:%d+` non matcha mai (`:` seguito da spazio, non da cifra) → `parsePromptPair`
   ritorna sempre `nil` → `parsePromptStats` fallisce sempre ("mancano H/M/V/X") → l'HUD non si
   popola mai. Questo è un bug concreto, verificato leggendo il codice E confrontandolo col dato
   reale, non un'ipotesi.
2. **Bug concreto aggiuntivo**: il campo XP nel prompt reale è **`x:` minuscolo** (es.
   `x:-238860738`), ma il parser cerca solo `X:(%d+)` / `X(%d+)` **maiuscolo** — i pattern Lua
   sono case-sensitive, quindi anche questo campo non verrebbe mai estratto con l'output reale
   attuale (a prescindere dal problema n.1, che fallisce comunque prima).
3. **Formato più semplice del previsto per gli slot combattimento**: nel prompt reale a riposo si
   vede `*:* *:*` (due placeholder) invece del formato con trattini `- */* - *-*` assunto nel
   codice legacy/SPEC — probabile che il formato con nomi mob/tank compaia solo IN combattimento;
   non ancora confermato che aspetto abbia (fuori scope per P0 equip, da chiedere se/quando serve
   l'HUD di combattimento).
4. **Il testo degli oggetti equip può andare a capo (word-wrap) senza numero di slot**: es. lo
   slot `[ 5]` continua con `eccellenti)` su una riga separata, senza `[nn]` davanti. Un parser
   riga-per-riga ingenuo (un trigger per riga che matcha solo `^\[%d+\]`) perderebbe il testo
   proseguito e/o lo scambierebbe per una riga senza slot. Va gestito accumulando la continuazione
   alla voce dello slot precedente finché non arriva la riga vuota finale o il prompt successivo.
5. **Slot 21 confermati**, con etichette testuali (non solo numeriche) — utile per costruire la
   tabella `EQ_SLOTS` del nuovo package (numero → etichetta italiana).

**Nota**: queste osservazioni SBLOCCANO la scrittura di pattern concreti in
`DESIGN-OPTIONS.md`/`RECOMMENDATION.md` per il parsing di prompt ed `eq` (release 1 / R5).

---

## Regola di avanzamento

- Le domande **bloccanti** (1, 2, 3, 4 del Round 2) devono avere risposta prima di scrivere
  `DESIGN-OPTIONS.md` con opzioni concrete per la gestione multi-personaggio, perché (a) vs (b)
  del punto 2 cambia la scelta tecnica alla radice (trigger/eventi per singola sessione vs
  gestione di più `Host`/connessioni Mudlet in parallelo).
- Nel frattempo si procede con la Fase 1 (ricerca wiki Mudlet, read-only, indipendente dalle
  risposte) e con la lettura del codice legacy per contesto.
