# TEST PLAN — nebbie-complete-dashboard-package v1.0.0

Regola (AGENT-RULES.txt §1): nessuna dichiarazione di "risolto" senza evidenza. I test automatici
coprono solo la logica pura di parsing (fuori Mudlet). I test manuali sotto vanno eseguiti
dall'utente IN GIOCO e i risultati (output/screenshot) vanno riportati prima di considerare
chiuso qualunque punto.

---

## 1. Test automatico offline (logica di parsing, già eseguito in questa sessione)

**File**: `docs/mudlet/tests/smoke_test_parsing.lua`
**Comando**: `lua docs/mudlet/tests/smoke_test_parsing.lua` (richiede `lua` 5.x nel PATH; verificato
con Lua 5.4 via Homebrew — Mudlet usa Lua 5.1 embedded, ma la sintassi usata nel core non usa
funzionalità specifiche di 5.2+, verificato anche con `luac -p` che non segnala errori).

**Esito registrato in questa sessione (2026-08-08)**: 19/19 asserzioni passate, usando
ESATTAMENTE i dati reali forniti dall'utente (prompt e output `eq` completo di NomiyaMaki,
`Q&A.md` Round 3) e l'esempio `attrib` fornito in `AGENT-PROMPT-ANALISI-ZERO.txt`. Copre:
parsing prompt (nome, HP/Mana/Move, campo x, oro, codici buff), rilevamento personaggio,
cattura completa dei 21 slot equip incluso il word-wrap (M6), cattura spell attivi.

**Limite esplicito**: questo test NON verifica trigger reali, GUI, `enableTrigger`/
`disableTrigger`, `table.save`/`table.load` reali, `setBorderRight`/`createMiniConsole` reali —
tutte le API Mudlet sono mockate (stub vuoti). Verifica SOLO che le funzioni di parsing pure
producano il risultato atteso sui dati reali noti. I punti sotto vanno verificati in Mudlet vero.

---

## 2. Test manuali richiesti in Mudlet (da eseguire dall'utente)

Per ciascun test: passi, atteso, e uno spazio per l'osservato (l'utente compila dopo l'esecuzione).

### T1 — Installazione pulita

1. Disinstallare `nebbie-play-all` se ancora presente (Package Manager, Alt+O).
2. Installare `docs/mudlet/nebbie-complete-dashboard-package.mpackage` (Alt+O → Install).
3. **Atteso**: messaggio in console `[NebbieDash] v1.0.0 pronto. Usa nresync dopo il login.`
   Nessun hang, nessun invio automatico di comandi al MUD.
4. **Osservato**: _da compilare_

### T2 — Nessun comando automatico al login/reload

1. Con il package installato, riconnettersi al MUD (o salvare/ricaricare uno script nell'editor,
   per simulare un reload dello script perm).
2. **Atteso**: nessun `eq`/`attrib` inviato automaticamente al server (nessuna riga aggiuntiva nel
   log del server/nessun output eq/attrib non richiesto in console).
3. **Osservato**: _da compilare_

### T3 — Rilevamento personaggio dal prompt

1. Loggare con un personaggio (es. NomiyaMaki) e digitare un comando qualsiasi per generare un
   prompt.
2. **Atteso**: in console appare `[NebbieDash] Personaggio attivo: NomiyaMaki`.
3. **Osservato**: _da compilare_

### T4 — Sync equip (`nresync` o `neq`)

1. Digitare `nresync` (o `neq`).
2. **Atteso**: dopo l'invio di `eq` al server, il pannello destro ("Equip — NomiyaMaki") mostra
   tutti gli slot con oggetti equipaggiati, incluse le descrizioni andate a capo (es. slot 5, 7,
   9, 10, 12, 19 nell'esempio reale) concatenate correttamente in un'unica riga per slot.
3. **Osservato**: _da compilare_

### T5 — Sync spell (`nattrib`)

1. Digitare `nattrib`.
2. **Atteso**: pannello "Spell attivi" popolato con nome+tick per ogni spell attivo, oppure
   messaggio "(nessuno...)" se non ce ne sono.
3. **Osservato**: _da compilare — NOTA: il formato completo del blocco `attrib` non è stato
   verificato oltre l'esempio con 2 spell fornito nel prompt originale; se il blocco reale ha
   sezioni aggiuntive (debuff, intestazioni diverse) il parser attuale potrebbe non gestirle —
   segnalare l'output completo se il test fallisce._

### T6 — Switch personaggio sequenziale

1. Disconnettersi e riconnettersi con un secondo personaggio (nome diverso).
2. Digitare un comando per generare un prompt.
3. **Atteso**: `[NebbieDash] Personaggio attivo: <NuovoNome>`; il pannello equip/spell si svuota
   (o mostra "(vuoto)") finché non si esegue `nresync` per il nuovo personaggio; i dati del primo
   personaggio restano salvati (verificabile tornando al primo PG: dopo un nuovo prompt, se la
   persistenza su disco è attiva, il pannello dovrebbe ripopolarsi con l'ULTIMA cache nota per
   quel nome, anche prima di rifare `eq`).
4. **Osservato**: _da compilare_

### T7 — Persistenza su riavvio Mudlet

1. Dopo aver eseguito `nresync` per un personaggio, chiudere e riaprire Mudlet (stesso profilo).
2. Rifare login con lo stesso personaggio, generare un prompt.
3. **Atteso**: il pannello equip/spell si ripopola con l'ultima cache salvata (file
   `getMudletHomeDir()/nebbie-complete-dashboard-package-chars.lua` nel profilo), senza dover
   rifare `eq`/`attrib` (anche se un resync resta raccomandato per dati aggiornati).
4. **Osservato**: _da compilare_

### T8 — `ngui` / `nlayout` / `nfix`

1. `ngui` due volte: nasconde poi mostra il pannello.
2. `nlayout`: ripristina larghezza/posizione di default.
3. `nfix`: reinstalla trigger senza duplicati né errori Lua in console.
4. **Osservato**: _da compilare_

### T9 — Nessun hang percepito

1. Giocare normalmente per alcuni minuti con traffico di gioco tipico.
2. **Atteso**: nessun rallentamento percepito (confronto soggettivo con l'esperienza "senza
   nebbie-play-all" riportata dall'utente in Q&A.md Round 1, Q4).
3. **Osservato**: _da compilare_

---

## 3. Criteri di chiusura

Questo pacchetto NON va considerato "pronto"/"risolto" finché almeno T1, T3, T4, T6 non sono
stati eseguiti dall'utente con esito positivo riportato esplicitamente (screenshot, copia/incolla
output, o conferma testuale dettagliata) — per rispetto di AGENT-RULES.txt §1 ("Dichiarare che un
problema è risolto senza test documentato o evidenza dell'utente" è vietato).
