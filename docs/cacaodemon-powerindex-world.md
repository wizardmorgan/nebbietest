# Cacaodemon, Power Index e comando `world`

Documento di riferimento sullo stato attuale del branch `test-integrazione-docker-nebbie`
(dopo l’estrazione del modulo `power_index`, l’integrazione in `world`, il bilanciamento
del cacaodemon e l’aggiornamento degli help).

---

## Panoramica

| Concetto | A cosa serve | Chi lo vede |
|----------|--------------|-------------|
| **Equipment index** (`GetCharBonusIndex`) | Punteggio numerico della qualità dell’equip indossato da un PG | Motore di gioco (calcoli interni) |
| **EQ medio storico (rent)** (`AverageEqIndex`) | Media cumulativa campionata al login/rent, in memoria dal boot | Comando `world` |
| **EQ medio online** | Media dell’equipment index dei PG mortali connessi con EQ > 0 | Comando `world`, staff `powerindex` |
| **Fattore EQ** | Moltiplicatore derivato dall’EQ medio (min 1.0, max 3.0) | Comando `world`, staff `powerindex` |
| **Power Index (PI)** | Indicatore generico di “potenza” di uno spell | Staff `powerindex`; usato dal cacaodemon |
| **PI cacaodemon** | Variante del PI con blend mondo + caster | Calcolo interno al rituale; staff `powerindex` |

**Importante:** le tre metriche EQ (storico rent, online, personale) **non sono la stessa cosa** e possono divergere molto — soprattutto dopo un riavvio del server o con pochi PG connessi.

---

## Power Index (modulo generico)

File: `src/power_index.hpp`, `src/power_index.cpp`

### Scopo

Fornire un indicatore riutilizzabile per incantesimi che devono scalare con il “livello di equip” del mondo online, senza legarsi al solo cacaodemon. Oggi il **primo consumatore** è il cacaodemon; altri spell futuri possono chiamare le stesse API.

### Campione EQ online

Ad ogni richiesta (nessun timer in background):

1. Si scorre la lista dei personaggi connessi (`character_list`).
2. Si includono solo i **PG mortali** (`!IS_NPC`, `!IS_IMMORTAL`) con `GetCharBonusIndex > 0`.
3. Si calcola la media aritmetica del loro equipment index.
4. Se nessuno rientra nel campione: `EQ_medio = 1` (valore di fallback).

Gli **immortali/staff non entrano** nel campione, per evitare che toon di test gonfino il mondo.

### Fattore EQ (generico)

```
eq_factor = clamp(EQ_medio / 100, 1.0, 3.0)
```

- **Pavimento 1.0:** con EQ medio ≤ 100 (o mondo vuoto) il moltiplicatore resta 1.
- **Tetto 3.0:** anche con EQ medio molto alto (es. 1900+) il fattore non supera 3.

### Formula PI generica

```
PI = livello_incantesimo × scala × eq_factor
```

| Parametro | Significato |
|-----------|-------------|
| `livello_incantesimo` | Livello effettivo del cast (classe magica usata) |
| `scala` | Moltiplicatore scelto dallo spell (per cacaodemon = magnitudine 1–6) |
| `eq_factor` | Solo dal mondo online (senza blend col caster) |

### API codice

```cpp
PowerIndexWorldEq power_index_world_snapshot();
float power_index_eq_factor_from_avg(float eq_avg);
float compute_power_index(int spell_level, int scale, const PowerIndexWorldEq* world = nullptr);
```

Passare `world` evita un secondo scan della `character_list` se si calcolano più PI nello stesso tick.

### Comando staff `powerindex`

- **Accesso:** immortali livello 52+ (`IMMORTALE`).
- **Sintassi:** `powerindex [<livello>] [<scala>]`
- **Senza argomenti:** snapshot del mondo + tabella PI generico e cacaodemon per scale 1–6 a livello 40 + mana cacaodemon grado 6.
- **Con livello e scala:** PI singolo generico e PI cacaodemon per quella coppia.

#### Voci mostrate da `powerindex`

| Voce | Cosa significa |
|------|----------------|
| **EQ medio online (PG mortali…)** | Media equipment index dei mortali connessi con EQ > 0 |
| **(N PG)** | Quanti PG entrano nel campione |
| **Fattore EQ mondo (cap 3.0)** | `clamp(EQ_medio/100, 1, 3)` — usato dal PI generico |
| **Fattore EQ caster (cap 3.0)** | `clamp(tuo_EQ/100, 1, 3)` — solo il tuo equip |
| **Fattore EQ cacaodemon (70% mondo + 30% caster)** | Blend usato dal rituale cacaodemon |
| **Il tuo equipment index** | `GetCharBonusIndex` del PG che lancia il comando |
| **Valore medio storico (rent)** | `AverageEqIndex(-1)` — **non** entra nel PI |
| **PG mortali nel calcolo** | Elenco nome + equipment index di chi pesa sulla media online |
| **Power index generico** | `livello × scala × fattore mondo` |
| **Power index cacaodemon** | `livello × scala × fattore blend cacaodemon` |
| **Mana cacaodemon (grado 6)** | Anteprima costo mana per patto al grado massimo |

Help staff: `wizhelp powerindex` (`pages/wizhelptbl`).

---

## Cacaodemon — funzionamento attuale

File principali: `src/proc_cacaodemon.cpp`, `src/spells2.cpp` (`cast_cacaodemon`), `src/magic2.cpp` (`spell_cacaodemon`), `src/spell_parser.cpp` (mana dinamico).

Help giocatore: `help cacaodemon` (`pages/helptbl`).

### Requisiti di base

| Aspetto | Valore |
|---------|--------|
| Classi | Mage 30, Cleric 29, Sorcerer 30 |
| Mana base | 50 (poi scalato — vedi sotto) |
| Durata servizio | Charm legato al carisma (`follow_time`) |
| Interdetto | Dove vale `NoSummon` / zone anti-evocazione |

### Lancio del rituale

**Sintassi:** `cast 'cacaodemon' <one|two|…|six>` (anche italiano o cifre 1–6).

1. **Grado del patto (1–6)** — determina template mob (vnum 20–25), offerta richiesta e magnitudine nelle formule.
2. **Offerta** — oggetto rituale specifico per grado (vnum 39990–39995). Deve essere **quella giusta per il grado** **e** **impugnata o in mano** al cast. Se manca una delle due condizioni, il rituale non evoca nulla.
3. **Mana** — controllato e scalato **prima** del cast in `do_cast` (vedi costo dinamico).
4. **Allineamento** — chi non è già fuori dalle regole comuni può perdere allineamento; consumo totale o parziale dell’offerta.

### Costo mana dinamico

```
fattore_cacaodemon = clamp(0.7 × fattore_mondo + 0.3 × fattore_caster, 1.0, 3.0)
mana = round(50 × fattore_cacaodemon × (1 + 0.15 × (grado − 1)))
```

| Grado | fattore 1.0 | fattore 3.0 (cap) |
|-------|-------------|-----------------|
| 1 | 50 | 150 |
| 6 | 87 | 262 |

Il fattore dipende dall’equip **medio dei mortali online** (70%) e dal **tuo** equip (30%). Gli immortali non pesano sul 70% “mondo”.

### Offerta rituale

| Caso | Comportamento |
|------|----------------|
| **Consumo normale** | L’offerta brucia del tutto al successo |
| **Chierico malvagio >40** | Può logorare l’offerta invece di distruggerla subito |
| **Valore minimo riuso** | `round(200 × fattore_cacaodemon)` — cresce con l’equip del mondo/caster |
| **Logoramento per cast** | Il valore dell’oggetto viene diviso per `max(2, 1 + fattore_cacaodemon)` — più equip “caro” in gioco, più in fretta si consuma |

### PI e statistiche del servitore evocato

Al momento dell’apparizione, `proc_modify_cacaodemon` **riscrive** il mob appena creato (non è una creatura fissa presa tal quale dal database mob):

```
PI_cacaodemon = livello_cast × magnitudine × fattore_cacaodemon
```

| Stat | Formula / regola |
|------|------------------|
| **Livello finale** | `clamp(livello_cast + magnitudine×2, 1, 60)` |
| **HP base** | `livello_finale×15 + magnitudine×50` |
| **HP bonus** | `HP_base × (PI / 500)` |
| **AC** | `10 − livello_finale/2 − magnitudine×3` |
| **Dadi danno** | `#dadi = max(2, livello_finale/10)`, `lato = 6 + magnitudine/2` |
| **Hitroll / Damroll** | `magnitudine×2 + PI/50` |
| **Sanctuary** | Magnitudine ≥ 4 |
| **Fireshield** | Magnitudine = 6 |

**Aspetto e testi:** scelti a caso tra pool diversi per allineamento del caster (buono / neutro / malvagio) e fascia di magnitudine (1–2, 3–4, 5–6). Nome, descrizioni brevi/lunghe/dettaglio cambiano a ogni evocazione.

**Comportamento in combattimento** (`spec_cacaodemon`):

- **Buono:** cure / protezione al master
- **Neutro:** colpo sismico ad area (esclusi master e gruppo)
- **Malvagio:** drain HP e veleno sul bersaglio

### Dopo l’evocazione

1. La creatura appare in stanza, non è più aggressiva verso l’ambiente, tende a restare ferma (`ACT_SENTINEL`).
2. Se non hai troppi follower, viene ammaliata e ti segue per un tempo legato al carisma.
3. **Bodyguard automatico** (`cacaodemon_assign_bodyguard`):
   - Protegge **sempre** l’evocatore.
   - Se il servitore ha livello **≤ 49**, estende la guardia del corpo a **tutto il gruppo** attivo.
   - Se livello **> 49**, guardia solo sul master.
4. **Ordine `vigila`** (o `guardia`, `proteggi`, `bodyguard` senza altro target): ripristina la protezione; `order followers vigila` su tutti i cacaodemon in stanza.

Log di check: `proc_cacaodemon: Modificata creatura liv X, Mag Y, HP Z, … (PI …)`.

---

## Comando `world` — cosa è cambiato

### Prima (una sola riga EQ)

In coda all’output compariva:

```
Valore medio dell'eq in gioco        : 145.000000
```

- Una sola metrica, etichetta generica “eq in gioco”.
- Precisione a 6 decimali.
- In realtà quella riga leggeva già `AverageEqIndex(-1)` (media in memoria campionata al login), **non** l’EQ medio dei PG online.

### Adesso (blocco EQ / PI)

Le righe **non immortali** in coda includono sempre:

```
Valore medio EQ storico (rent)     : …
EQ medio online (PG mortali)       : …  (N PG con equip index > 0)
Fattore EQ mondo (cap 3.0)       : …
```

Gli **immortali** (livello ≥ `IMMORTALE`) vedono in più:

```
PI di riferimento (liv.40, scala 1): …  (wizhelp powerindex)
```

Le righe immortali già presenti prima (flags di sistema, connessioni dalla partenza, zone init) **non sono cambiate** — restano visibili solo agli immortali.

### Significato di ogni voce EQ/PI in `world`

| Voce | Cosa misura | Come si aggiorna | Usata da |
|------|-------------|------------------|----------|
| **Valore medio EQ storico (rent)** | Media cumulativa dell’equipment index al **login** (`load_char_objs`) | Si azzera a ogni **boot** di `myst`; conta solo campioni con EQ ≥ 100 | XP (`gain_corretto` usa l’EQ del singolo PG, non questa media); display informativo |
| **EQ medio online (PG mortali)** | Media `GetCharBonusIndex` dei **mortali connessi adesso** con EQ > 0 | Ricalcolata **on demand** a ogni `world` / cast / powerindex | Base del fattore EQ mondo |
| **(N PG con equip index > 0)** | Quanti mortali entrano nella media online | Idem | Diagnostica: con N=1–2 la media è molto volatile |
| **Fattore EQ mondo (cap 3.0)** | `clamp(EQ_medio_online / 100, 1, 3)` | Derivato dalla riga precedente | PI generico; componente 70% del cacaodemon |
| **PI di riferimento (liv.40, scala 1)** | `40 × 1 × fattore_EQ_mondo` — esempio numerico | Solo display | Staff: capire l’ordine di grandezza del PI generico **senza** magnitudine cacaodemon |

### Cosa **non** mostra `world` (ma esiste)

- Il **fattore blend cacaodemon** (70% mondo + 30% caster) → solo in `powerindex` staff.
- Il **costo mana** del cacaodemon → calcolato al cast.
- L’**elenco dei PG** nel campione → solo in `powerindex` staff.

---

## Relazione tra le metriche (esempio pratico)

Scenario tipico dopo **riavvio** con 2 PG mortali high-EQ (~1900) connessi:

| Metrica | Valore indicativo | Perché |
|---------|-------------------|--------|
| EQ storico (rent) | Parte da 0, poi ~1900 dopo i login | Media cumulativa **da boot**, pochi campioni |
| EQ medio online | ~1900 | Media dei 2 PG **adesso** |
| Fattore EQ mondo | **3.0** (cap) | 1900/100 >> 3, limitato dal tetto |
| PI cacaodemon (liv 30, mag 6) | 30×6×3 = **540** | Con blend al cap, se caster e mondo sono entrambi alti |

Stesso server **prima del riavvio**, con 1 solo login a EQ 145:

| Metrica | Valore |
|---------|--------|
| EQ storico (rent) | ~145 |
| EQ medio online | dipende da chi è connesso **in quel momento** |

Il salto da 145 a 1902 osservato in test non era un cambio di formula sulla riga “storica”, ma **restart + campione online diverso**.

---

## File e help di riferimento

| Contenuto | Percorso |
|-----------|----------|
| Modulo PI generico | `src/power_index.hpp`, `src/power_index.cpp` |
| Logica cacaodemon | `src/proc_cacaodemon.hpp`, `src/proc_cacaodemon.cpp` |
| Cast / offerta | `src/spells2.cpp`, `src/magic2.cpp` |
| Mana dinamico | `src/spell_parser.cpp` |
| Comandi `world` / `powerindex` | `src/act.info.cpp` |
| Help giocatore cacaodemon | `pages/helptbl` → `help cacaodemon` |
| Help staff powerindex | `pages/wizhelptbl` → `wizhelp powerindex` |
| Runtime help (copia locale) | `mudroot/lib/helptbl`, `mudroot/lib/wizhelptbl` |

---

## Riepilogo bilanciamento (introdotto per evitare outlier)

1. **Cap fattore EQ a 3.0** — nessun moltiplicatore illimitato da twink online.
2. **Esclusione immortali** dal campione mondo.
3. **Blend 70/30 mondo/caster** — il PI del cacaodemon dipende anche da chi lancia, non solo dagli altri online.
4. **Mana e offerta dinamici** — costo cresce con il fattore EQ; offerta chierico malvagio si logora più in fretta e richiede valore minimo più alto.

Queste regole sono implementate nel codice; l’help giocatore (`help cacaodemon`) le descrive in linguaggio narrativo **senza formule**, mentre questo documento le espone in forma tecnica per staff e sviluppo.
