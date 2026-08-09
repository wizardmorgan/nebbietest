mpackage = [[nebbie-complete-dashboard-package]]
author = [[Nebbie Arcane]]
icon = [[nebbie-dash-icon.png]]
title = [[Nebbie Dashboard — equip, spell attivi e speedwalk per Nebbie Arcane]]
description = [[# Nebbie Dashboard (1.3.0)

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

Nessun comando viene inviato al MUD in automatico: usa `nresync` dopo il
login per sincronizzare equip e spell. Vedi `nfix` se qualcosa sembra
bloccato dopo un aggiornamento.

Documentazione completa (tutti i comandi, formato file speedwalk, changelog):
`docs/mudlet/analysis/USAGE.md` e `docs/mudlet/analysis/CHANGELOG.md` nel
repository del progetto.
]]
version = [[1.3.0]]
