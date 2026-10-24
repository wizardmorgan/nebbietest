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
| **EQ riferimento PI** | Blend mediana/armonica pesato per livello dei mortali online | Comando `world`, staff `powerindex` |
| **Fattore EQ** | Moltiplicatore soft-cap dal riferimento mondo (asintoto 4.0) | Comando `world`, staff `powerindex` |
| **Power Index (PI)** | Indicatore **neutro** riusabile per spell, skill, mob procedurali, ecc. | Staff `powerindex`; consumatori (es. cacaodemon) |
| **PI cacaodemon** | Variante del PI con blend mondo + caster | Calcolo interno al rituale; staff `powerindex` |

**Importante:** le tre metriche EQ (storico rent, online, personale) **non sono la stessa cosa** e possono divergere molto — soprattutto dopo un riavvio del server o con pochi PG connessi.

---

## Power Index (modulo generico)

File: `src/power_index.hpp`, `src/power_index.cpp`

### Scopo

Fornire un indicatore **neutro e riusabile** per calibrare dinamicamente spell, skill, mob
generati proceduralmente o qualsiasi meccanica che benefici di variabilità legata al contesto
di gioco. Non è necessariamente un malus: il cacaodemon, ad esempio, evoca servitori **più utili**
quando il PI è alto (endgame impegnativo) e resta accessibile a livelli più bassi con mob
modesti; il costo mana leggermente superiore compensa in parte il vantaggio.

Oggi il **primo consumatore** è il cacaodemon; altri sistemi possono chiamare le stesse API.

### Campione EQ online

Ad ogni richiesta (nessun timer in background):

1. Si scorre `character_list`.
2. Si includono solo **PG mortali** (`!IS_NPC`, `!IS_IMMORTAL`) con `GetCharBonusIndex > 0`.
3. Per ogni PG si calcola un **peso** `clamp(sqrt(livello_max/40), 0.25, 1.0)`.
4. Si derivano:
   - **EQ aritmetico pesato** (display informativo)
   - **Mediana pesata** dell'equipment index
   - **Media armonica pesata** (dà più voce ai PG con EQ basso nel campione)
5. **EQ riferimento** = `0.6 × mediana + 0.4 × armonica`.
6. Con **≤ 2 PG** online, il riferimento viene stabilizzato verso `AverageEqIndex(-1)` (media rent dal boot), senza escludere i connessi dal campione.
7. Se nessuno rientra: fallback `EQ_riferimento = 1`.

Gli **immortali** non entrano nel campione.

### Fattore EQ mondo (soft cap)

```
raw     = EQ_riferimento / ANCHOR        (ANCHOR = 3000)
eq_factor = 1 + (MAX - 1) × raw / (1 + raw)     (MAX = 4.0, floor 1.0)
```

- Crescita **continua** oltre l'endgame attuale: non satura tutti al mismo valore come il vecchio `clamp(EQ/100, 1, 3)`.
- Con EQ riferimento ≈ 6000 il fattore è ~3.0, non 4.0; resta margine se l'economia cresce ancora.

### Fattore EQ caster (relativo al mondo)

```
ratio = tuo_EQ / EQ_riferimento
caster_factor = 1 + (MAX - 1) × ratio / (1 + ratio)
```

Misura quanto il **tuo** equip è sopra/sotto il contesto online, non un valore assoluto `/100`.

### Formula PI generica

```
PI = livello_incantesimo × scala × eq_factor_mondo
```

| Parametro | Significato |
|-----------|-------------|
| `livello_incantesimo` | Livello effettivo del cast |
| `scala` | Moltiplicatore libero (tier cacaodemon 1–6, numero bersagli, ecc.) |
| `eq_factor_mondo` | Solo pressione mondo (EQ riferimento) |

### API codice

```cpp
PowerIndexWorldEq power_index_world_snapshot();
float power_index_eq_factor_from_reference(float eq_reference);
float power_index_caster_eq_factor(float caster_eq, float world_eq_reference);
float compute_power_index(int spell_level, int scale, const PowerIndexWorldEq* world = nullptr);
```

`power_index_eq_factor_from_avg()` resta come alias di compatibilità.

Passare `world` evita un secondo scan della `character_list` se si calcolano più PI nello stesso tick.

### Comando staff `powerindex`

- **Accesso:** immortali livello 52+ (`IMMORTALE`).
- **Sintassi:** `powerindex [<livello>] [<scala>]`
- **Senza argomenti:** snapshot del mondo + tabella PI generico e cacaodemon per scale 1–6 a livello 40 + mana cacaodemon grado 6.
- **Con livello e scala:** PI singolo generico e PI cacaodemon per quella coppia.

#### Voci mostrate da `powerindex`

| Voce | Cosa significa |
|------|----------------|
| **EQ medio aritmetico** | Media pesata per livello (informativa) |
| **EQ riferimento PI** | 60% mediana + 40% armonica (pesate); stabilizzata con rent se ≤2 PG |
| **Mediana / armonica** | Componenti del riferimento |
| **Fattore EQ mondo** | Soft cap su EQ riferimento (anchor 3000, max 4.0) |
| **Fattore EQ caster** | Rapporto tuo_EQ / EQ_riferimento, stessa curva |
| **Fattore EQ cacaodemon** | 70% mondo + 30% caster |
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
fattore_cacaodemon = clamp(0.7 × fattore_mondo + 0.3 × fattore_caster_relativo, 1.0, 4.0)
PI_cacaodemon = livello_cast × magnitudine × fattore_cacaodemon
```

Il PI alimenta statistiche del servitore (HP bonus, hitroll, damroll): più alto il contesto,
più utile il mob in endgame; con fattore basso resta un alleato modesto per i non-endgame.
```
mana = round(50 × fattore_cacaodemon × (1 + 0.15 × (grado − 1)))
```

Il fattore dipende dalla **pressione mondo** (70%) e dalla **potenza personale relativa** (30%).

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

## Riepilogo bilanciamento

1. **Soft cap a 4.0** con anchor 3000 — il fattore continua a crescere oltre l'endgame attuale senza saturare tutti allo stesso valore.
2. **EQ riferimento robusto** — mediana + armonica pesate per livello; i PG con EQ basso pesano di più che con la sola media aritmetica.
3. **Stabilizzazione campione sottile** — con ≤2 PG online si miscela la media rent storica, senza escludere i connessi.
4. **Fattore caster relativo** — il blend cacaodemon distingue chi è sopra/sotto il contesto, non solo il mondo globale.
5. **Esclusione immortali** dal campione mondo.
6. **PI neutro riusabile** — stesse API per spell, mob procedurali, skill future; il cacaodemon è un consumatore che **potenzia** il servitore, non un malus generalizzato.
7. **Mana e offerta dinamici** — costo leggermente superiore al normale come compensazione parziale.

Queste regole sono implementate nel codice; l’help giocatore (`help cacaodemon`) le descrive in linguaggio narrativo **senza formule**, mentre questo documento le espone in forma tecnica per staff e sviluppo.
