# USAGE — nebbie-complete-dashboard-package

Guida rapida ai comandi (alias) del package, scritta dopo il primo test reale dell'utente
(segnalazione barre laterali grigie + richiesta istruzioni alias, 2026-08-08).

## Come installare/aggiornare

1. In Mudlet: `Package Manager` (icona valigetta, o `Giocatore → Gestione pacchetti`).
2. Se `nebbie-complete-dashboard-package` è già installato, disinstallalo prima (bottone `-`),
   poi chiudi e riapri il profilo (i widget grafici creati a runtime — miniconsole/bordo — non
   vengono sempre ripuliti immediatamente dalla sola disinstallazione).
3. Installa (bottone `+`) il file `docs/mudlet/nebbie-complete-dashboard-package.mpackage`
   aggiornato.
4. Riconnetti/ricarica il profilo. Deve comparire in output:
   `[NebbieDash] v1.0.0 pronto. Usa nresync dopo il login.`

## Alias disponibili

Nessun alias invia comandi al MUD in automatico all'avvio (scelta deliberata, vedi
`RECOMMENDATION.md` §3): tutti vanno digitati a mano quando servono.

| Alias | Cosa fa |
|---|---|
| `nresync` | Invia `eq` al MUD, aspetta 1.5s, poi invia `attrib`. Aggiorna la cache equip+spell del personaggio corrente e ridisegna il pannello. **Usalo dopo ogni login/riconnessione.** |
| `neq` | Invia solo `eq` e aggiorna il pannello equip. |
| `nattrib` | Invia solo `attrib` e aggiorna il pannello spell. |
| `nchar <nome>` | Forza manualmente il personaggio attivo (es. `nchar NomiyaMaki`), utile se il rilevamento automatico dal prompt non è ancora scattato (nessun comando ancora digitato in gioco). |
| `ngui` | Mostra/nasconde il pannello laterale (bordo destro). |
| `nlayout` | Ripristina larghezza/posizione di default del pannello (260px, lato destro). |
| `nfix` | Reinstalla trigger e GUI senza disinstallare il package (utile se qualcosa sembra "bloccato"). |

Il rilevamento del personaggio è **automatico**: appena il prompt del gioco viene ricevuto (dopo
che scrivi un qualsiasi comando), il nome del personaggio attivo viene letto dal prompt stesso
(vedi `DESIGN-OPTIONS.md` D1) e il pannello si aggiorna da solo per quel personaggio. `nchar` serve
solo come override manuale.

## Bug corretto: pannelli grigi alla prima installazione

**Sintomo segnalato**: dopo l'installazione, le due miniconsole sul bordo destro (equip/spell)
apparivano completamente grigie, senza testo, anche subito dopo l'installazione.

**Causa reale (non il vecchio package `nebbie-play-all`)**: `initGUI()` creava le miniconsole con
`createMiniConsole(...)` ma non assegnava mai loro uno sfondo esplicito né ci scriveva dentro nulla
subito dopo la creazione. Una miniconsole Mudlet appena creata resta con il colore di sfondo di
default del widget Qt (grigio) finché non si chiama `setBackgroundColor(...)` e non si scrive
qualcosa con `cecho`/`clearWindow`. Il primo aggiornamento reale del pannello avveniva solo dopo
`nresync`/rilevamento del prompt, quindi tra l'installazione e il primo comando digitato in gioco
il pannello restava grigio.

**Fix applicato** (`nebbie-complete-dashboard-package-core.lua`, funzione `initGUI`):
- aggiunto `setBackgroundColor("NebbieDashEquip"/"NebbieDashSpells", 15, 15, 15, 255)` subito dopo
  la creazione delle miniconsole;
- aggiunta chiamata a `NebbieDash.refreshDashboard()` alla fine di `initGUI()` (quindi anche dentro
  `boot()`), così il pannello mostra subito il testo placeholder
  (`Nessun personaggio rilevato.` / `(vuoto — esegui neq o nresync)`) invece di restare vuoto.

Il `.mpackage` è stato rigenerato con il fix: `docs/mudlet/nebbie-complete-dashboard-package.mpackage`.

**Se dopo aver reinstallato il pacchetto aggiornato il grigio persiste**, è plausibile un residuo
del vecchio package. Verifica (in ordine):
1. `Package Manager`: assicurati che `nebbie-play-all` (o nomi simili) non sia più nell'elenco.
2. `Editor` (Ctrl+E) → cerca script/alias/trigger con prefisso `Nebbie` diverso da `NebbieDash*`:
   se presenti, sono residui del vecchio package da eliminare a mano.
3. Chiudi completamente Mudlet (non solo disconnetti) e riapri il profilo: i widget creati via Lua
   (`createMiniConsole`, `createLabel`) non sono "salvati" nel profilo, vengono ricreati a ogni
   boot dello script che li possiede — se il vecchio script non gira più, i suoi widget non
   dovrebbero ricomparire dopo un riavvio completo.
