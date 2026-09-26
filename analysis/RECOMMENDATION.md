# RECOMMENDATION — Nebbie Play All (Mudlet), analisi da zero

**Stato: bozza con dati reali, ANCORA NON APPROVATA.** I dati bloccanti richiesti in `Q&A.md`
Round 3 (output reale di `eq`, prompt esatto) sono stati ricevuti il 2026-08-08 e hanno permesso
di individuare la **causa concreta e verificata** dei "pannelli vuoti": il parser del prompt nel
codice legacy (`nebbie-installer-core.lua`) usa pattern Lua che richiedono l'assenza di spazio
dopo i due punti (`H:%d+`), mentre il prompt reale del server ha uno spazio (`H: 747/747`) — il
parser fallisce quindi SEMPRE con l'output reale attuale, oltre a cercare `X:` maiuscolo dove il
server manda `x:` minuscolo. Questo documento propone ora anche i pattern concreti risultanti
(vedi `DESIGN-OPTIONS.md` §D2-0), ma **resta da approvare esplicitamente** prima di scrivere
codice definitivo (regola AGENT-RULES.txt §2), in particolare sui punti in §2 sotto.

---

## 1. Sintesi della raccomandazione

Per la **release 1** (priorità dichiarata: pannello equip funzionante, R5):

1. **Package NUOVO**, minimo (D4-A in `DESIGN-OPTIONS.md`), non un patch del
   `nebbie-play-all` esistente. Motivazione: il requisito R1 (un profilo, più personaggi con
   switch sequenziale) è un cambiamento di modello architetturale rispetto al design legacy
   ("un profilo = un personaggio", dato di fatto da `SPEC-v2.2.8.md` §6), e almeno due dei
   "divieti" elencati nel prompt originale sono confermati con evidenza diretta nel codice
   legacy attuale (boot automatico incondizionato con `maybeRefreshEqCacheOnBoot()`, refresh GUI
   ricorrente ogni 1 secondo — vedi `LOG.md`). Ripartire minimi riduce il rischio di ereditare
   questi comportamenti.
2. **Nome package proposto**: `nebbie-dash` (alternativa: `nebbie-multichar`). Motivazione: nome
   diverso da `nebbie-play-all` (per evitare confusione/conflitti con l'eventuale reinstallazione
   futura del vecchio package, ed è esplicitamente permesso da R6), breve, riflette lo scope reale
   (dashboard equip/spell multi-personaggio) senza promettere le funzionalità "play all"
   (alias/loot/tastierino) che sono fuori scope per ora. **Proposta aperta a preferenza
   dell'utente** (Q&A Round 2, Q5: "proponi tu").
3. **Rilevamento personaggio (D1)**: combinazione D1-A (dal parser prompt) + D1-C
   (evento di connessione come reset di stato), con D1-B (comando manuale esplicito, es. `nchar`)
   come override/debug — coerente con la risposta utente che vuole rilevamento automatico dal
   prompt (Q&A Round 2, Q1) ma con una via di sicurezza se il parser fallisse.
4. **Trigger prompt/eq (D2)**: shielding ufficiale (D2-A) come meccanismo primario garantito
   indipendentemente da GA/EOR, con hook opzionale `tempPromptTrigger` (D2-B) se disponibile,
   esattamente come già fa (correttamente, su questo punto) il codice legacy. Cattura `eq` con
   trigger multiline delimitato (D2-C) invece di poll di scrollback a tempo.
5. **Persistenza (D3)**: **proposta preliminare = D3-B (persistenza su disco)**, perché il
   requisito R1 implica che l'utente cambierà personaggio più volte nella stessa sessione Mudlet
   e a distanza di sessioni diverse; avere subito uno stato "ultimo noto" per personaggio anche
   prima di rifare `eq`/`attrib` sembra più utile dell'alternativa (solo memoria). **Da confermare
   esplicitamente con l'utente** (Q&A Round 2, Q4 non aveva preferenza) prima di implementare,
   perché è una scelta con trade-off reali (complessità I/O vs comodità), non un dettaglio tecnico
   neutro.
6. **Scope release 1**: SOLO pannello equip (R5) + infrastruttura multi-personaggio (R1-R3) +
   comando diagnostico minimo. Spell/attrib (R11/R12), loot, alias multiclasse, tastierino
   restano espliciti come "release 2+" salvo diversa indicazione — **da confermare** (REQUIREMENTS
   R15, aperto).

---

## 2. Cosa NON è ancora deciso (richiede risposta utente prima di procedere)

| # | Domanda | Impatto se non risolta |
|---|---------|-------------------------|
| 1 | ~~Output completo di `eq` e prompt esatto~~ | **RISOLTO** (Q&A Round 3) — pattern concreti in DESIGN-OPTIONS.md §D2-0 |
| 2 | Persistenza su disco (D3-B) sì/no — proposta sopra, ma non confermata | Cambia la struttura dati e il comando `nfix`/init; da confermare prima di scrivere codice |
| 3 | Nome package definitivo (`nebbie-dash` proposto) | Impatta nome file, `config.lua`, comandi di diagnosi (`nlist` etc. se ripresi) |
| 4 | Scope release 1: solo equip, o anche spell/attrib da subito? (R11/R12/R15) | Cambia l'estensione del lavoro di implementazione |
| 5 | Nomi comandi utente definitivi (`neq`, `nattrib`, `nresync`, `ngui`, `nlayout`, `nfix`, più un comando per lo switch manuale personaggio) — Q&A Round 2 Q6 rimandata "dopo il design" | Non bloccante tecnicamente, ma va fissata prima di scrivere l'installer |
| 6 | GA/EOR disponibile sul server? (V2, non bloccante per il design scelto, ma utile sapere) | Nessun impatto sulla release 1 (D2-A funziona comunque); utile solo per capire se attivare l'hook D2-B |
| 7 | Il sostring-shield `" M: "` proposto per il prompt va validato su altri campioni (es. durante il combattimento, con nomi PG diversi/più corti, con oggetti equipaggiati diversi) prima di fissarlo definitivamente — un solo campione "a riposo" potrebbe non coprire tutti i casi (es. formato mob/tank quando `*:* *:*` diventa nomi reali) | Rischio di falsi negativi in combattimento se il formato cambia in modi non ancora visti |

## 3. Perché NON si propone di riprendere `nebbie-play-all` così com'è

Con evidenza diretta dal codice (non assunzione, vedi `LOG.md`):

- `Nebbie.boot()` viene eseguito **incondizionatamente** al parse dello script (non dietro
  `sysLoadEvent`), e richiama `Nebbie.maybeRefreshEqCacheOnBoot()` — comportamento vietato
  esplicitamente nel prompt originale ("auto eq/attrib... al boot") e osservato causare
  rallentamenti (coerente con la testimonianza utente: il profilo è tornato fluido dopo la
  disinstallazione).
- Refresh GUI programmato ogni 1 secondo (`tempTimer(1, ..., true)`) oltre a refresh
  event-driven sparsi in almeno 8 altri punti — vietato esplicitamente ("refresh UI completo più
  di ~1 volta / 2-3 secondi").
- Il modello dati assume un personaggio per profilo (`SPEC-v2.2.8.md` §6) — in diretto contrasto
  con il requisito R1.
- Un aspetto NON confermato come problematico in questa istanza di codice: lo shielding del
  prompt (`tempSubstringTrigger(" H:")` + `tempPromptTrigger` come hook aggiuntivo) sembra già
  seguire correttamente il pattern raccomandato dalla wiki — quindi **non tutti** i "divieti"
  sospettati nel prompt originale risultano confermati; questo viene riportato per completezza e
  onestà d'analisi, non per minimizzare gli altri problemi reali trovati.

Questo non significa che il lavoro pregresso sia da buttare: gli **alias e i dati generati
automaticamente dal sorgente C++** (`nebbie-spells-reference.txt`, le tabelle di
wear-off/abbreviazioni in `build-nebbie-package.py`) restano un asset riusabile in una fase
successiva, indipendente dai problemi dell'installer runtime.

---

## 4. Decisioni finali confermate dall'utente (2026-08-08)

| Punto | Decisione finale |
|-------|-------------------|
| Persistenza | **Su disco** (D3-B), `table.save`/`table.load` per personaggio |
| Nome package | **`nebbie-complete-dashboard-package`** (preferenza esplicita utente) |
| Scope release 1 | **Equip + spell/attrib insieme** (non solo equip) |
| Approvazione implementazione | **Sì, procedere** |

## 5. Stato implementazione

Implementato in questa sessione (Fase 5):

- `docs/mudlet/nebbie-complete-dashboard-package-core.lua` — logica principale (namespace
  `NebbieDash`).
- `docs/mudlet/build-nebbie-complete-dashboard-package.py` — build script.
- `docs/mudlet/nebbie-complete-dashboard-package.mpackage` — package installabile (generato).
- `docs/mudlet/tests/smoke_test_parsing.lua` — test automatico offline (19/19 passati sui dati
  reali forniti dall'utente).
- `docs/mudlet/analysis/TEST-PLAN.md` — 9 test manuali da eseguire IN MUDLET dall'utente prima di
  considerare qualunque punto "risolto" (AGENT-RULES.txt §1).
- `docs/mudlet/analysis/CHANGELOG.md` — v1.0.0.

**Non ancora fatto, in attesa dell'utente**: esecuzione dei test manuali T1-T9 in Mudlet reale e
riporto dell'esito. Nessuna funzionalità di questo pacchetto va considerata verificata finché
questi test non sono stati eseguiti e l'esito riportato esplicitamente.

---

*Documento aggiornato al termine della Fase 5 (implementazione iniziale). Resta aperta la verifica
in Mudlet reale da parte dell'utente.*
