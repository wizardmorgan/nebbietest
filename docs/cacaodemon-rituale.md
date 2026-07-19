# Rituale Cacaodemon — guida alla riscrittura

Documento pensato per builder, staff e chi vuole capire **cosa fa** il nuovo sistema senza dover leggere il codice.

---

## In due parole

Lo spell **cacaodemon** non richiama più un demone fisso da catalogo.  
Evoca una **presenza rituale** (angelo, demone o costrutto, in base all’allineamento del lanciatore), la cui forza dipende da:

1. **Quanto sei potente** (tu e il gruppo nella stanza), con lo stesso tipo di misura usata nelle Dimensioni Effimere  
2. **Che tipo di personaggio sei** (monoclasse caster avvantaggiato rispetto a multiclasse / fighter)  
3. **Che sigillo sacrifichi** (da minore a supremo)

Il risultato è un **alleato ibrido** (tiene i colpi e ne dà), pensato soprattutto per chi gira **da solo** in monoclasse.

---

## Cosa c’era prima (e perché è cambiato)

Nel vecchio impianto tipicamente:

- si usavano parole chiave / livelli fissi (`uno`…`sei` o simili)  
- il demone era spesso una scheda mob “da catalogo”  
- l’equip o non c’era, o non era gestito in modo sicuro  

Problemi tipici emersi nei test:

- sigillo debole e sigillo forte producevano **pet quasi uguali** (troppo legati solo alla “potenza” e poco al sacrificio)  
- il pet era **troppo debole** contro contenuti seri di fascia ~50 (es. custodi tipo Sinuhe), mentre contro guardie di Myst era già “abbastanza”  
- equip scarso o creato solo in memoria → difficile da gestire per gli immortali  
- rischio che pezzi rituali restassero in giro come loot  

La riscrittura punta a: **equilibrio chiaro**, **sigilli che contano**, **equip editabile**, **niente loot residuo**.

---

## Come funziona il rituale (dal punto di vista del giocatore)

### Requisiti

- Deve essere un personaggio con **Chierico, Mago o Stregone** (almeno una di queste classi).  
- Deve tenere **in mano (HOLD)** un **sigillo rituale** di grado sufficiente.  
- Può avere **un solo** essere legato a questo rituale alla volta.  
- Serve mana aggiuntivo in base al “gradino” di potenza raggiunto.

### Cosa succede al lancio

1. Il gioco misura la **potenza** del lanciatore (e del gruppo presente e pronto nella stanza).  
2. Applica un **moltiplicatore di classe** (vedi sotto).  
3. Da quella potenza ricava un **gradino di potenza** (1–6).  
4. Controlla che il sigillo in mano sia **almeno** di quel gradino (o superiore).  
5. Se tutto ok: **consuma il sigillo**, spende il mana extra, fa apparire la presenza.  
6. Se qualcosa fallisce **prima** del successo, il sigillo **non** viene bruciato.

Messaggio tipico al successo: viene indicata potenza canalizzata, gradino e grado del sigillo usato.

### Allineamento → aspetto

| Allineamento del PG | Tema del summon |
|---------------------|-----------------|
| Buono | Presenza “angelica / delle Sfere” |
| Malvagio | Presenza “infernale” |
| Neutro | Costrutto / pietra runica |

Nomi e descrizioni sono **generati** da un lessico, non da una sola scheda fissa.

---

## Potenza: come viene calcolata (in linguaggio semplice)

### Indice di potenza

Si riusa la stessa idea delle **Dimensioni Effimere**:

- per il singolo: un indice basato su equip / livello / profilo del PG  
- in gruppo (stessa stanza, in gruppo, in piedi, non già in combattimento):  
  **70% media del gruppo + 30% del più forte**

Poi l’indice viene “compresso” in un fattore da 0 a 1 (da potenza bassa a potenza molto alta).

### Moltiplicatori di classe (chi beneficia di più)

Solo chi ha CL / MU / SO può lanciare. Tra chi può:

| Profilo | Effetto (indicativo) |
|---------|----------------------|
| Mono Stregone o mono Chierico | Bonus (×1.15) |
| Mono Mago | Neutro (×1.00) |
| Dual senza fighter | Quasi pieno (×0.98) |
| Dual con fighter | Più basso (×0.85) |
| Tri senza fighter | ×0.88 |
| Tri con fighter | ×0.72 |

Obiettivo: **aiutare i monoclasse caster in solitaria**, senza far diventare il pet un secondo tank/DPS da multiclasse già forti.

### Gradino di potenza (1–6)

Dal fattore 0–1 si ottiene un **tier di potenza** da 1 a 6.  
Il sigillo deve essere **di grado ≥ a quel tier**.

Esempio: se la potenza del PG dà tier 3, un sigillo di grado 1–2 **non basta**; ne serve uno da 3 in su.

---

## I sigilli (sacrificio)

Sono oggetti overlay tenuti in **HOLD**:

| Vnum | Nome tipico | Grado |
|------|-------------|-------|
| 98101 | Sigillo rituale minore | 1 |
| 98102 | Sigillo comune | 2 |
| 98103 | Sigillo maggiore | 3 |
| 98104 | Sigillo arcano | 4 |
| 98105 | Sigillo solenne | 5 |
| 98106 | Sigillo rituale **supremo** | 6 |

Marca interna: `value[0] = 98001`, `value[1] = grado 1–6`.

### Cosa fa il grado del sigillo

Non sostituisce la potenza del PG: la **integra**.

- alza un po’ la curva di forza del pet (vita, livello, attacchi, ecc.)  
- decide i **bonus di colpire/danno** (su guanti/braccia e dadi a mani nude):  
  - **monoclasse**: fino a **+5 / +5**  
  - **multiclasse**: fino a **+4 / +4**  
- da grado 5 in su il pet può nascere già con **Santuario**  
- True Sight (e Detect Invis) sono **sempre** attivi sul summon  

Progressione bonus sigillo (indicativa):

- mono: 1 → 2 → 3 → 4 → 5 → 5  
- multi: 1 → 2 → 3 → 3 → 4 → 4  

Gli altri pezzi di equip hanno in genere **+1 / +1**, così il totale resta in una fascia utile e non diventa “dio del mud”.

---

## Quanto è forte il pet? (riferimento di gioco)

Per calibrare non si è usata la guardia di Myst (troppo debole a livello 50).  
Si è analizzato l’intero file mob del mud e si è presa come fascia di riferimento tipica i mob **livello ~45–55** “duri ma normali” (non i casi estremi da shop/guildmaster).

Obiettivo del pet a **sigillo massimo / monoclasse** (ordine di grandezza):

- colpire / danno da equip e corpo intorno alla fascia “alta ma non pazzesca” di quei mob  
- armatura molto buona (verso −80 / −100)  
- qualche centinaio / migliaio di punti ferita (più di molti custodi “medi”, così il chierico può curarlo)  
- circa **4 attacchi**  
- ruolo **ibrido**: non solo wall, non solo DPS  

Esempi usati in discussione: Sinuhe come “duro serio”; la sentinella di Myst come “troppo facile” (non è lo standard).

---

## Equipaggiamento del demone

### Dove sono gli oggetti

Non sono creati “dal nulla” invisibili agli immortali: sono **overlay** in `objects/`:

| Vnum | Pezzo |
|------|--------|
| 98201 | Anello |
| 98202 | Collana |
| 98203 | Corazza |
| 98204 | Elmo |
| 98205 | Schinieri |
| 98206 | Stivali |
| 98207 | Guanti |
| 98208 | Bracciali (braccia) |
| 98209 | Scudo |
| 98210 | Mantello |
| 98211 | Cintura |
| 98212 | Bracciale (polso) |
| 98213 | Orecchino |
| 98214 | Lenti |

L’**arma 98215 non viene più equipaggiata**: il pet combatte **a mani nude** con danno `TYPE_UNDEFINED` (come il monk), così non mappa su taglio/contundente e non è soggetto alle resistenze/immunità di tipo né al check +1…+4 sulle armi.

Il bonus del sigillo (+N/+N, mono max +5/+5) va su **guanti e bracciali**; gli altri pezzi restano a +1/+1. I dadi a mani nude e una quota di hit/dam nativi assorbono quanto prima dava l’arma.

Si possono caricare / ispezionare gli overlay (es. `oload 98207`).  
Al rituale il codice **clona** questi modelli, regola i bonus in base al sigillo e li indossa sul pet.

### Regole anti-exploit

- pezzi **non droppabili** in modo utile ai mortali (nodrop / immune allo scrap tipico)  
- se l’arma “cadrebbe” a terra (disarm, ecc.), torna **nell’inventario del demone** e viene **rimessa**  
- alla **morte** del demone (e se il vincolo fallisce all’evocazione) tutto l’equip rituale viene **distrutto**:  
  indossato, in inventario, e anche pezzi eventualmente a terra nella stanza legati a quel pet  

Non devono restare sul cadavere né come loot a terra.

---

## Comportamento in combattimento e vincoli

- Il pet è un **guerriero** alleato (charm), sentinel, non scavenger aggressivo.  
- **Un solo** pet cacaodemon per master.  
- Non viene contato come mob “di Dimensioni Effimere” (non fa scattare logiche boss/DE per sbaglio).  
- True Sight sempre; Santuario dai sigilli alti.

---

## Cosa è stato toccato nel codice (mappa per chi deve manutenere)

Elenco orientativo, senza entrare nel dettaglio riga per riga:

| Area | Ruolo |
|------|--------|
| `spell_power.*` | API riusabile: potenza, gruppo, fattore, moltiplicatori classe, tier |
| `cacaodemon_summon.*` | Identità procedurale, spawn pet, equip da overlay, cleanup, anti-drop |
| `cacaodemon_sacrifice.inc` | Specifica sigilli / mana extra per grado |
| `cacaodemon_summon_lexicon.inc` | Parole per nomi angelici / infernali / costrutti |
| `spells2.cpp` / `magic2.cpp` | Cast, controlli, sacrificio, messaggi |
| `fight.cpp` | Cleanup alla morte; re-equip in combattimento; no scrap dell’equip rituale |
| `handler.cpp` | Se un pezzo rituale sta per andare a terra → inventario + ri-equip |
| `procarea*.cpp` | Il pet non interferisce con conteggi / morti DE |
| Overlay `98101–98106` | Sigilli |
| Overlay `98201–98215` | Equip del summon |
| Help / spell list | Testi aggiornati dove previsto |

Ambiente di test usato in questa fase: istanza **Sirio** (container unico con MySQL + mud, porta **4003**).

---

## Note operative per lo staff

### Test rapido consigliato

1. PG monoclasse CL/SO con sigillo **supremo** (98106) in hold  
2. Lanciare cacaodemon  
3. `stat` sul pet: True Sight; molti pezzi in equipment; arma con bonus alti  
4. Confrontare con lo stesso PG e sigillo **minore**: differenza visibile  
5. Far morire il pet: verificare che **non** restino oggetti 982xx a terra / nel corpse  

### Log del mud (Sirio)

Un solo container (`nebbieserver-sirio`): MySQL e mud insieme.

```text
docker logs -f nebbieserver-sirio
docker exec -it nebbieserver-sirio less /app/alarmud.log
```

### Builder

- nuovi sigilli: stesso schema dei 9810x (`value[0]=98001`, `value[1]=grado`)  
- modificare aspetto/base dell’equip: editare gli overlay 982xx; i bonus di sigillo restano applicati a runtime  

---

## Sintesi finale

Il nuovo cacaodemon è un **patto misurato**:

- la **forza del personaggio** apre il gradino  
- il **sigillo** paga il prezzo e decide quanto l’arma (e il pet) salgono  
- i **monoclasse caster** sono favoriti  
- il pet è un **compagno di fascia alta “normale”** del mud, non una sentinella di Myst e non un boss assurdo  
- l’equip è **reale (overlay)**, **non lootabile**, e **svanisce** con la morte del demone  

Se in playtest qualcosa sfora (troppo debole / troppo forte), si regola soprattutto: curva HP/AC/attacchi, bonus arma per grado, e moltiplicatori di classe — senza dover riscrivere tutto il rituale.
