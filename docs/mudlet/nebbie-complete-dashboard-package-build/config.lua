mpackage = [[nebbie-complete-dashboard-package]]
author = [[Nebbie Arcane]]
icon = [[nebbie-dash-icon.png]]
title = [[Nebbie Dashboard — equip, spell attivi e speedwalk per Nebbie Arcane]]
description = [[# Nebbie Dashboard (1.6.1)

Pannello laterale per **Nebbie Arcane**, con supporto multi-personaggio (un
profilo Mudlet, più personaggi, cambio automatico rilevato dal prompt).

- **Equip** (bordo sinistro): tutti gli slot indossati, con posizione ed
  oggetto letti da `eq`; segna anche gli slot liberi noti.
- **Spell attivi** (bordo destro, in alto): spell/buff letti da `attrib`,
  cliccabili per rilanciarli sul personaggio corrente (`cast`/`recall`/`mind`
  a seconda della classe, vedi `nclass`).
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

Nessun comando viene inviato al MUD in automatico: usa `nresync` dopo il
login per sincronizzare equip e spell. Vedi `nfix` se qualcosa sembra
bloccato dopo un aggiornamento.

Documentazione completa (tutti i comandi, formato file speedwalk, changelog):
`docs/mudlet/analysis/USAGE.md` e `docs/mudlet/analysis/CHANGELOG.md` nel
repository del progetto.
]]
version = [[1.6.1]]
