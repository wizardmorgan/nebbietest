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

## Round 4 — Feedback post-installazione: speedwalk / spell cliccabili / slot vuoti

Poste dopo la terza reinstallazione reale del pacchetto (bug slot mislabeled + word-wrap).

- **Q1 (finestra speedwalk)**: riusare la fonte dati del vecchio package o progettare da zero?
  **R**: "progettiamo da zero" — dettagli forniti in un messaggio successivo (non ancora arrivati
  al momento di scrivere questa voce).
- **Q2 (spell cliccabili)**: che comando usare per rilanciare una spell dal pannello?
  **R**: dipende dalla classe — sorcerer usa `recall '<nome>'`, psionico usa `mind '<nome>'`
  (o la skill psionica), mago/chierico usano `cast '<nome>'`. Richiesta di estrarre la lista
  completa di spell/skill dal codice del server (repo separato, "nebbietest ha upstream
  NebbieArcane/Server"), NON di decidere io quali assegnare come alias — quello lo decide
  l'utente in un secondo momento, eventualmente da un file di configurazione. Richiesto anche un
  "motore generico" con prefissi a una lettera `c`/`r`/`m` che prendano tutto il resto della riga
  come un'unica stringa argomento, es. `c word of r` → `cast 'word of recall'` (nota: verificato
  nel codice server che il motore di gioco fa già da solo il match per abbreviazione, quindi in
  realtà l'output esatto inviato è `cast 'word of r'`, non serve espanderlo a mano lato Mudlet).
- **Q3 (slot equip non occupati)**: c'è un comando per elencare tutte le posizioni indossabili
  anche vuote? **R**: "no/non lo so, lascia il pannello così com'è" — chiuso, nessuna azione.

## Round 5 — Speedwalk (formato) + perché le spell non erano cliccabili

- **Conferma positiva**: "ho una barra nera a destra" — il fix del pannello grigio ha funzionato.
- **Speedwalk**: l'utente scriverà lui stesso il file di configurazione. Formato dato
  dall'utente: `(descrizione)` tra parentesi diventa una label cliccabile, seguita da direzioni
  separate da virgola; un numero prima di una direzione la ripete N volte. Esempio esatto
  dell'utente: `u,3w,n,s,2d` = up, west, west, west, north, south, down, down. Implementato
  esattamente così (vedi `USAGE.md`), con file `nebbie-speedwalks.txt` in `getMudletHomeDir()`.
- **Domanda posta dall'agente**: le spell non erano cliccabili semplicemente perché non ancora
  implementato (deferred nel round precedente in attesa del motore c/r/m, ora pronto) — non per un
  meccanismo di scadenza/colore mancante. L'utente ha comunque chiesto se convenga far scadere e
  cambiare colore (verde→rosso) le spell in prossimità della scadenza: implementato come soglia
  configurabile sui tick noti all'ultima sincronizzazione (non un countdown live, vedi `USAGE.md`
  per il perché — servirebbe sapere quanti secondi reali dura un tick sul server, informazione non
  ancora fornita).

**Domanda aperta, non bloccante**: se in futuro si vuole un countdown in tempo reale (che scende
da solo senza dover rifare `nattrib`), serve sapere quanti secondi reali dura un tick sul server.

## Regola di avanzamento

- Le domande **bloccanti** (1, 2, 3, 4 del Round 2) devono avere risposta prima di scrivere
  `DESIGN-OPTIONS.md` con opzioni concrete per la gestione multi-personaggio, perché (a) vs (b)
  del punto 2 cambia la scelta tecnica alla radice (trigger/eventi per singola sessione vs
  gestione di più `Host`/connessioni Mudlet in parallelo).
- Nel frattempo si procede con la Fase 1 (ricerca wiki Mudlet, read-only, indipendente dalle
  risposte) e con la lettura del codice legacy per contesto.

## Round 11 — Alias e trigger: gestione generale + primo modulo (loot/split) (2026-08-10)

**Contesto**: dopo che il dashboard (equip/spell/speedwalk) è stato dichiarato soddisfacente
dall'utente, si apre una nuova fase: alias e trigger di gioco (esplicitamente fuori scope nella
release 1, vedi REQUIREMENTS.md R15).

**Domande su come gestire alias/trigger in generale**:
- Q: quale approccio? → A: **ibrido** — file di configurazione per alias/trigger semplici (come gli
  speedwalk) + codice del pacchetto per logica complessa.
- Q: quali categorie per prime? → A: **combattimento** (poi chiarito essere loot/split, non
  attacco/fuga).
- Q: riusare gli alias del vecchio pacchetto (`nebbie-play-all`)? → A: **no, da zero**, solo ciò che
  serve davvero, coerente con l'approccio già seguito per il resto del pacchetto.

**Domande sul modulo loot/split (prima richiesta concreta)**: l'utente vuole raccogliere le monete
dal cadavere dopo ogni combattimento e, se in gruppo, dividerle automaticamente con `split`.

Testi REALI forniti dall'utente (copiati dal gioco, base per i trigger — nessuna regex inventata):
1. Comando di loot: sintassi Diku `get all.coin corp` (cadavere normale) o `get all.coin pile`
   ("pile of bones" di un non-morto, vedi `fight.cpp`/`IsUndead`).
2. Risposta di successo (due righe): `Prendi gold coins da il corpo di Il grande drago verde delle
   foreste.` seguita da `C'erano 100000 monete.`
3. Risposta di fallimento: `Non vedi nessun corp.` / `Non vedi nessun pile.`
4. `group` da soli: `But you are a member of no group?!`
5. `group` in gruppo:
   ```
   Your group "I cacciatori di Draghi" consists of:
       NomiyaMaki      (Head of group) HP:100% MANA:100% MV:100%
       Grendel                         HP:100% MANA:98% MV:100%
   ```
- Q: il loot deve funzionare solo su "pile of bones" o su qualsiasi cadavere? → A: **qualsiasi
  cadavere**.
- Q: quando scatta lo split? → A: **sempre**, subito dopo ogni loot riuscito, se in gruppo
  (automatico, disattivabile).
- Q: come si rileva il gruppo? → A: leggendo l'output del comando **`group`**.

**Aperto/rimandato**: rilevamento automatico della fine del combattimento (per lanciare `nloot` da
solo senza che l'utente lo digiti) — servirà il testo reale del messaggio di vittoria/morte del
mostro, non ancora fornito.

**Implementazione**: vedi LOG.md Round 11 e CHANGELOG.md 1.4.0 per i dettagli tecnici (nuovi comandi
`nloot`/`nautosplit`/`nsplit`).

## Round 12 — testo reale di fine combattimento → loot automatico (2026-08-10)

L'utente fornisce il testo reale mancante dal Round 11 (rilevamento automatico fine combattimento):

```
Uno Spazzino is dead! R.I.P.
La tua parte di esperienza e' di 1 punti.

Una sentinella is dead! R.I.P.
La tua parte di esperienza e' di 1047 punti.

Un Ubriacone is dead! R.I.P.
La tua parte di esperienza e' di 0 punti.
```

**Osservazione**: la riga "La tua parte di esperienza e' di N punti." (anche con N=0) compare solo
quando hai effettivamente partecipato/contribuito a quel combattimento — a differenza di "X is dead!
R.I.P." che potrebbe comparire anche per uccisioni altrui non tue. Usata quindi come segnale per
`nloot` automatico invece della riga "is dead!".

**Implementazione**: vedi LOG.md Round 12 e CHANGELOG.md 1.4.1 (nuovo comando `nautoloot`).

## Round 13 — due bug segnalati + nuove richieste (2026-08-10)

**Bug 1 — cambio personaggio non aggiornava la dashboard**: l'utente segnala che dopo aver cambiato
personaggio, lanciare uno spell su se stesso falliva perché la dashboard aveva ancora memorizzato il
vecchio personaggio. Causa: `currentChar` veniva aggiornato solo alla ricezione di un nuovo prompt,
che arriva solo DOPO aver inviato un comando — quindi un self-cast fatto subito dopo il cambio
personaggio (prima di qualunque altro comando) usava ancora il nome del personaggio precedente,
senza alcun avviso. Fix: alla (ri)connessione il personaggio attivo viene azzerato subito (pannello
mostra "nessun personaggio rilevato" finché non arriva un prompt fresco), vedi LOG.md Round 13.

**Bug 2 — split scattato senza essere in gruppo**: l'utente segnala che durante un combattimento in
solitaria lo split è comunque scattato. Causa non confermata con certezza (serve un log reale per
esserne sicuri — richiesto ma non ancora fornito); come misura difensiva i due trigger di verifica
gruppo sono stati resi più specifici (ancorati a inizio riga con la virgoletta di apertura per "Your
group \"", invece di un semplice "contiene la sottostringa Your group ") per ridurre il rischio che
del testo di gioco non correlato faccia scattare un falso positivo.

**Richiesta**: interpretare `.4s` (o `.N<comando>`) come l'invio ripetuto N volte dello stesso
comando, utilizzabile per qualsiasi comando non solo i movimenti. Implementato come nuovo alias
generico (vedi LOG.md Round 13).

**Richiesta — trigger di combattimento "minimi"**: l'utente chiarisce che per ora gli servono solo
due trigger, non un sistema di combattimento completo:
1. Rialzarsi da terra dopo una caduta. Testo reale fornito: `"Illyari schiva il tuo urto. Inciampi e
   cadi per terra."` (parte fissa: `"Inciampi e cadi per terra."`; l'utente precisa che questo è SOLO
   UNO dei possibili messaggi di caduta — altri andranno aggiunti quando forniti).
2. Recuperare l'arma dopo un disarmo. Testo reale fornito: `"Ti disarmano e la Flamberga di Boris
   vola dalla tua presa."`, dove "la Flamberga di Boris" è l'oggetto nello slot `[16] <impugnato>` e
   risponde alle parole chiave `"flamberga boris"` in gioco (confermato dall'utente) — l'utente
   chiede esplicitamente un modo per derivare le parole chiave automaticamente, perché cambiano da
   arma ad arma.

**Implementazione di entrambi**: vedi LOG.md Round 13 e CHANGELOG.md 1.5.0 (nuovi comandi
`nautostand`, `nautodisarm`, alias generico `.N<comando>`).

## Round 14 — Gestione armi: pannello + tipo di danno (2026-08-10)

**Richiesta**: un sotto-pannello sotto l'Equip con l'elenco delle armi possedute, il tipo di danno
(slash/blunt/pierce) e la possibilità di cambiare arma con un click (`rem`/`put`/`get`/`wield`).

**Dettagli confermati dall'utente** (scelta multipla + testo libero):
- La lista si popola da sola quando si impugna un'arma.
- Il tipo di danno va rilevato con un comando separato (l'utente ha scelto `identify`, non
  inventato dall'agente).
- `rem <keyword>` è adatto a rimuovere un'arma (già confermato nel Round 13 per il disarmo).
- La lista delle armi deve essere persistente per personaggio (come equip/spell).
- Il messaggio di wield si presume `"Impugni <nome arma>."` (risposta a scelta multipla
  "generic_wield", **non un copia-incolla letterale** — da correggere se il testo reale in gioco
  fosse diverso).

**Dato bloccante fornito** (output REALE di `identify`, richiesto esplicitamente perché mancante):

```
Pronunci le parole, 'identify'.
La conoscenza ti pervade:
Oggetto: 'spada elf slayer', Tipo di Oggetto WEAPON
L'oggetto e': HUM METAL MAGIC ANTI-GOOD ANTI-MAGE ARTIFACT EDIT
Peso: 12, Valore: 5000, Costo di rent: 7500
Dado di danno: '3d5'
Tipo di danno: 'SLASH'
Caratteristiche:
    Ti puo' dare : HIT-N-DAM by 4
    ...
Vieni sopraffatto da un'ondata di stanchezza.
```

Da questo testo: `identify` non viene mai inviato in automatico dal pacchetto (costa una "ondata di
stanchezza"), resta un comando eseguito dall'utente di propria iniziativa; il pacchetto si limita ad
ascoltare le due righe `Oggetto: '...', Tipo di Oggetto WEAPON` e `Tipo di danno: '...'`.

**Implementazione**: vedi LOG.md "Gestione armi (v1.8.0)" e CHANGELOG.md 1.8.0 (nuovo pannello
"Armi", nuovo comando `nleftheights`).

## Round 15 — Spell residue, split in solitaria, scadenza in tempo reale (2026-08-10)

**Segnalazioni**:
1. "ho switchato da mirari a nomiyamaki ma la dashboard mi ha mantenuto le spell che non posso
   lanciare (mirror images, shield)".
2. "lo split è di nuovo partito mentre ero solo" (fornito un log reale della sessione, incluso un
   testo di fine combattimento MAI visto prima: "La tua esperienza e' aumentata di N punti.", diverso
   da "La tua parte di esperienza e' di N punti." già gestito).
3. Testi reali per far scadere le spell subito (invece di aspettare `attrib`):
   - "Non ti senti piu' cosi' invulnerabile." (sanc)
   - "Perdi la tua armatura Divina." (armor)
   - "Perdi l'aiuto Divino." (aid)
   - "L'alone d'argento nei tuoi occhi scompare." (true sight)
   - "Il globo di oscurita' che ti avvolgeva scompare." (darkness)
   - esplicitamente ESCLUSO: "Senti i tuoi movimenti accellerare rapidamente." (scadenza di
     "slowness", un debuff subito dal personaggio, non un buff lanciato da lui — l'utente lo precisa
     esplicitamente).

**Decisioni prese**: per il punto 1, non esistendo un elenco spell-per-classe confermato (non
inventabile senza violare AGENT-RULES), la soluzione è un comando manuale di pulizia
(`nforgetspell`) invece di un filtro automatico per classe. Per il punto 2, il log fornito non
mostra uno split effettivamente inviato in quella sequenza specifica, ma ha permesso di individuare
una vera race condition nel codice (vedi LOG.md) risolta accumulando gli importi di loot quasi
simultanei in un solo controllo gruppo. Per il punto 3, implementati solo i 5 testi forniti,
nessuno inventato.

**Implementazione**: vedi LOG.md "Spell residue, split in solitaria, scadenza in tempo reale
(v1.9.0)" e CHANGELOG.md 1.9.0.
