# Test Party — 3 PG livello 50 per test in gioco

Strumento per creare automaticamente tre personaggi di livello 50 (Barone), evocarli nella stanza del controllore e pilotarli da **un solo PG** senza aprire tre client separati.

## Requisiti

- Immortale livello **Maestro del Creato (58)** o superiore
- Mud avviato con MySQL (`USE_MYSQL`) per il salvataggio completo
- Opzionale: `--test_mode` / `SetTest on` per login con password `test`

## Comando in-game: `testparty`

| Sottocomando | Sintassi | Descrizione |
|--------------|----------|-------------|
| help | `testparty` | Mostra codici classe e sintassi |
| create | `testparty create <prefisso> <cls1> <cls2> <cls3>` | Crea `prefisso1`, `prefisso2`, `prefisso3` (umano, lv 50, pwd `test`) |
| summon | `testparty summon <prefisso>` | Evoca i 3 PG offline come ghost (senza descriptor), nella tua stanza |
| cmd | `testparty cmd <1\|2\|3\|all> <comando>` | Esegue un comando su uno o tutti i membri |
| dismiss | `testparty dismiss <prefisso>` | Salva inventario (forcerent) e rimuove i ghost |

### Codici classe

| Lettera | Classe |
|---------|--------|
| M | Magico |
| C | Chierico |
| W | Guerriero |
| T | Ladro |
| D | Druido |
| K | Monaco |
| B | Barbaro |
| S | Stregone |
| P | Paladino |
| R | Ranger |
| I | Psi |

Multiclasse: concatena le lettere (`WCT` = Guerriero/Chierico/Ladro). La combinazione deve essere consentita per **umano** (come in creazione normale). Non si possono avere M e S insieme.

## Flusso tipico

```
testparty create lab W MC WCT
testparty summon lab
testparty cmd 1 score
testparty cmd 2 cast 'cura ferite' me
testparty cmd all follow me
testparty cmd 3 kill goblin
testparty dismiss lab
```

Il controllore resta sul proprio PG; i tre membri sono **ghost** (variante di `ghost <nome>`) che lo seguono automaticamente. `testparty cmd` invia comandi al loro interprete — utile per combattimento, spell, movimento (`follow me`, `group`, ecc.).

## Script interattivo (prompt esterno)

```bash
python3 scripts/spawn-test-party.py
```

Chiede prefisso e tre combinazioni classe, poi stampa i comandi da eseguire in mud.

Invio automatico via telnet (mud locale porta 4000):

```bash
python3 scripts/spawn-test-party.py --send --immortal NomeImm --summon
```

## Note tecniche

- I PG creati sono salvati su MySQL (`toon` + `character_*`) e su `mudroot/lib/players/<nome>.dat`
- Password fissa: `test` (comoda con `SetTest on`)
- I ghost non occupano connessioni: un solo client per il controllore
- A fine test usare sempre `testparty dismiss` (equivalente a forcerent sui tre ghost)

## Esempio sessione di test combattimento

```
# 1. Crea tank/healer/multiclasse
testparty create sim W P MC

# 2. Entra con il tuo PG principale, poi evoca
testparty summon sim

# 3. Porta il gruppo nella zona di test
testparty cmd all follow me
goto 12345

# 4. Avvia fight
testparty cmd 1 kill <mob>
testparty cmd 2 cast 'cura ferite' sim1
testparty cmd 3 backstab <mob>

# 5. Pulizia
testparty dismiss sim
```
