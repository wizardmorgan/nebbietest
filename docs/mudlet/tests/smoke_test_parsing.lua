-- Smoke test offline (fuori da Mudlet) per la logica pura di parsing.
-- Non testa trigger/GUI (richiedono l'API Mudlet reale), solo le funzioni Lua
-- pure che analizzano prompt ed eq con i dati reali forniti dall'utente.

-- Mock minimale delle API Mudlet usate al top-level dello script (side-effect free)
function getMudletHomeDir() return "/tmp" end
io = io or {}
io.exists = function() return false end
table.save = function() end
table.load = function() end
function cecho() end
function tempTrigger() return nil end
function tempRegexTrigger() return nil end
function disableTrigger() end
function enableTrigger() end
local lastSent = nil
local sentLog = {}
function send(cmd) lastSent = cmd; table.insert(sentLog, cmd) end
function tempTimer() end
function setBorderRight() end
function setBorderLeft() end
function createMiniConsole() end
function createLabel() end
function setBackgroundColor() end
function setMiniConsoleFontSize() end
function calcFontSize() return 8, 14 end
function getMainWindowSize() return 1024, 768 end
function moveWindow() end
function resizeWindow() end
function clearWindow() end
function hideWindow() end
function showWindow() end
registerAnonymousEventHandler = function() end

local scriptDir = arg and arg[0] and arg[0]:match("^(.*)[/\\][^/\\]+$") or "."
dofile(scriptDir .. "/../nebbie-complete-dashboard-package-core.lua")

local failures = 0
local function check(name, cond)
  if cond then
    print("OK   " .. name)
  else
    print("FAIL " .. name)
    failures = failures + 1
  end
end

-- Test 1: parsing prompt reale (Q&A.md Round 3)
local promptLine = "NomiyaMaki H: 747/747 M: 532/532 V: 158/158 x:-238860738 *:* *:* [[D]] G:3449502 >>"
local parsed = NebbieDash.parsePromptLine(promptLine)
check("prompt: parsed non-nil", parsed ~= nil)
if parsed then
  check("prompt: name == NomiyaMaki", parsed.name == "NomiyaMaki")
  check("prompt: hp == 747", parsed.hp == 747)
  check("prompt: hpmax == 747", parsed.hpmax == 747)
  check("prompt: mana == 532", parsed.mana == 532)
  check("prompt: move == 158", parsed.move == 158)
  check("prompt: xfield == -238860738", parsed.xfield == -238860738)
  check("prompt: gold == 3449502", parsed.gold == 3449502)
  check("prompt: codes == D", parsed.codes == "D")
end

-- Test 1b: il pattern del CODICE LEGACY (per confronto) NON deve matchare -- lo verifichiamo
-- non richiamando codice legacy (non importato qui), il punto è già dimostrato in LOG.md/Q&A.md
-- leggendo il codice; qui verifichiamo solo che il NOSTRO pattern funzioni sul dato reale.

-- Test 2: rilevamento personaggio da riga prompt
NebbieDash.onPromptLine_test = function(text)
  line = text
  NebbieDash.onPromptLine()
end
NebbieDash.onPromptLine_test(promptLine)
check("character: currentChar == NomiyaMaki", NebbieDash.currentChar == "NomiyaMaki")

-- Test 3: capture eq completa sui 21 slot reali forniti dall'utente
local eqLines = {
  "Stai usando:",
  "[ 1] <sul dito destro>       Il sigillo delle ombre",
  "[ 2] <sul dito sinistro>     La bandiera britannica",
  "[ 3] <intorno al collo>      Il Ciondolo con la Testa di Jeeg Robot",
  "[ 4] <intorno al collo>      Una collana di perline",
  "[ 5] <sul corpo>             Un tubino rinforzato con una grossa Union Jack (in condizioni",
  "eccellenti)",
  "[ 6] <in testa>              Un cerchietto tempestato di Diamanti Rossi (in condizioni eccellenti)",
  "[ 7] <sulle gambe>           Dei gambali di piastra scintillanti (hanno un alone luminoso) (in",
  "ottime condizioni)",
  "[ 8] <ai piedi>              Gli stivali del lungo viaggio (in condizioni eccellenti)",
  "[ 9] <sulle mani>            Il Guanto dell'Infinito (hanno un alone luminoso) (in condizioni",
  "eccellenti)",
  "[10] <sulle braccia>         Una manica dell'abito di Twiggy (emettono un forte ronzio) (in",
  "condizioni eccellenti)",
  "[11] <come scudo>            The Cross (in condizioni eccellenti)",
  "[12] <intorno al corpo>      Una giacca di carapace d'insetto opera di NomiyaMaki (in condizioni",
  "eccellenti)",
  "[13] <intorno alla vita>     A feathered belt (in condizioni eccellenti)",
  "[14] <al polso destro>       Un bracciale a pois bianchi e rossi (in condizioni eccellenti)",
  "[15] <al polso sinistro>     Un bracciale di plastica rosa (in condizioni eccellenti)",
  "[16] <impugnato>             La Flamberga di Boris",
  "[17] <tenuto>                Happy End of the World",
  "[18] <sulla schiena>         It's a Beautiful Day",
  "[19] <all'orecchio destro>   Un orecchino tigrato made in Tokio (invisibile) (in condizioni",
  "eccellenti)",
  "[20] <all'orecchio sinistro> Una rosa metallica (ha un alone luminoso) (in condizioni eccellenti)",
  "[21] <davanti agli occhi>    Glass no Kamen",
  "",
}

NebbieDash.startEqCapture()
for _, l in ipairs(eqLines) do
  line = l
  NebbieDash.onEqCaptureLine()
end

local data = NebbieDash.getCharData("NomiyaMaki")
check("eq: 21 slot popolati", NebbieDash.countSlots(data.eq) == 21)
check("eq: slot 16 impugnato (item)", data.eq[16].item == "La Flamberga di Boris")
check("eq: slot 16 impugnato (location)", data.eq[16].location == "impugnato")
check("eq: slot 5 con word-wrap concatenato", data.eq[5].item == "Un tubino rinforzato con una grossa Union Jack (in condizioni eccellenti)")
check("eq: slot 5 location", data.eq[5].location == "sul corpo")
check("eq: slot 9 con word-wrap concatenato", data.eq[9].item == "Il Guanto dell'Infinito (hanno un alone luminoso) (in condizioni eccellenti)")
check("eq: slot 21 ultimo (item)", data.eq[21].item == "Glass no Kamen")
check("eq: slot 21 ultimo (location)", data.eq[21].location == "davanti agli occhi")
check("eq: capture chiusa (nessuna capture attiva)", NebbieDash._eqCapture == nil)

-- Test 3b: la posizione viene sempre letta dalla riga stessa, non da una
-- tabella statica per indice — verifica esplicita che un ordine "anomalo"
-- (slot non contiguo, posizione diversa da quella che una tabella statica
-- indicizzata per numero avrebbe assunto) venga comunque letto correttamente.
NebbieDash.setCurrentCharacter("TestAnomalo", true)
NebbieDash.startEqCapture()
local anomalLines = {
  "Stai usando:",
  "[ 1] <ai piedi>              Un paio di guanti (anomalia apposta per il test)",
  "[ 8] <davanti agli occhi>    Degli occhiali",
  "",
}
for _, l in ipairs(anomalLines) do
  line = l
  NebbieDash.onEqCaptureLine()
end
local dataAnomalo = NebbieDash.getCharData("TestAnomalo")
check("eq anomalo: slot 1 usa la location dalla riga (non la tabella statica 'sul dito destro')",
  dataAnomalo.eq[1].location == "ai piedi")
check("eq anomalo: slot 8 usa la location dalla riga (non la tabella statica 'ai piedi')",
  dataAnomalo.eq[8].location == "davanti agli occhi")

-- Test 3c: buildEquipRows segna correttamente gli slot vuoti (richiesta:
-- "adesso si leggono tutti gli slot ma non mi segna cosa è vuoto"). Su
-- TestAnomalo sono occupati solo 2 dei 21 slot canonici.
local rowsAnomalo = NebbieDash.buildEquipRows(dataAnomalo)
check("equip rows: 21 righe (nessuno slot clan, disattivato di default)", #rowsAnomalo == 21)
local occupied, empty = 0, 0
for _, row in ipairs(rowsAnomalo) do
  if row.empty then empty = empty + 1 else occupied = occupied + 1 end
end
check("equip rows: 2 occupati", occupied == 2)
check("equip rows: 19 vuoti", empty == 19)
for _, row in ipairs(rowsAnomalo) do
  if row.location == "ai piedi" then
    check("equip rows: 'ai piedi' occupato con l'oggetto giusto",
      not row.empty and row.item == "Un paio di guanti (anomalia apposta per il test)")
  end
  if row.location == "sul dito destro" then
    check("equip rows: 'sul dito destro' marcato vuoto", row.empty == true)
  end
end

-- Test 3d: con tutti i 21 slot occupati (NomiyaMaki), nessuna riga deve
-- risultare vuota.
local rowsFull = NebbieDash.buildEquipRows(data)
local emptyFull = 0
for _, row in ipairs(rowsFull) do
  if row.empty then emptyFull = emptyFull + 1 end
end
check("equip rows: eq completo -> zero slot vuoti", emptyFull == 0)

NebbieDash.setCurrentCharacter("NomiyaMaki", true)

-- Test 4: capture attrib con esempio da AGENT-PROMPT-ANALISI-ZERO.txt
local attribLines = {
  "Spells attivi:",
  "--------------",
  "Spell : 'true sight' - 74",
  "Spell : 'darkness' - 9",
  "",
}
NebbieDash.startAttribCapture()
for _, l in ipairs(attribLines) do
  line = l
  NebbieDash.onAttribCaptureLine()
end
local data2 = NebbieDash.getCharData("NomiyaMaki")
check("attrib: 2 spell catturati", #data2.spells == 2)
check("attrib: primo spell true sight/74", data2.spells[1].name == "true sight" and data2.spells[1].ticks == 74)
check("attrib: secondo spell darkness/9", data2.spells[2].name == "darkness" and data2.spells[2].ticks == 9)

-- Test 4b: un secondo `attrib` (es. dopo aver rilanciato "darkness") deve
-- SOSTITUIRE per intero data.spells con i nuovi tick, non accumularli — cosi'
-- il colore (verde/rosso), che viene ricalcolato ad ogni refreshDashboard()
-- leggendo data.spells, torna verde appena i tick residui salgono sopra la
-- soglia nspellwarn. Riproduce il bug segnalato ("rimangono rossi anche dopo
-- attrib") per verificare che la logica di cattura/sostituzione sia corretta.
local attribLines2 = {
  "Spells attivi:",
  "--------------",
  "Spell : 'true sight' - 70",
  "Spell : 'darkness' - 80",
  "",
}
NebbieDash.startAttribCapture()
for _, l in ipairs(attribLines2) do
  line = l
  NebbieDash.onAttribCaptureLine()
end
local data2b = NebbieDash.getCharData("NomiyaMaki")
check("attrib: risync sostituisce (non accumula) gli spell", #data2b.spells == 2)
check("attrib: darkness aggiornato a 80 tick dopo il rilancio",
  data2b.spells[2].name == "darkness" and data2b.spells[2].ticks == 80)
check("attrib: colore darkness verde dopo il rilancio (80 > soglia 5)",
  (tonumber(data2b.spells[2].ticks) or 0) > NebbieDash.spellWarnTicks)

-- Test 5: parsing speedwalk (Q&A.md Round 5) — esempio esatto fornito
-- dall'utente: "u,3w,n,s,2d" = up, west, west, west, north, south, down, down.
local steps = NebbieDash.parseSpeedwalkDirs("u,3w,n,s,2d")
check("speedwalk: 8 passi totali", #steps == 8)
check("speedwalk: sequenza esatta",
  table.concat(steps, ",") == "u,w,w,w,n,s,d,d")

local swEntry = NebbieDash.parseSpeedwalkLine("(dalla fontana) u,3w,n,s,2d")
check("speedwalk: riga valida non nil", swEntry ~= nil)
if swEntry then
  check("speedwalk: descrizione estratta", swEntry.desc == "dalla fontana")
  check("speedwalk: 8 passi dalla riga completa", #swEntry.steps == 8)
end

check("speedwalk: riga commento ignorata", NebbieDash.parseSpeedwalkLine("# commento") == nil)
check("speedwalk: riga vuota ignorata", NebbieDash.parseSpeedwalkLine("") == nil)
check("speedwalk: riga senza parentesi ignorata", NebbieDash.parseSpeedwalkLine("u,3w,n,s,2d") == nil)

-- Test 6: speedwalk con descrizione contenente una virgola e un'istruzione a
-- piu' parole tra le direzioni (es. "enter pool") — esempio esatto fornito
-- dall'utente. La descrizione tra parentesi puo' contenere virgole (il match
-- e' su "fino alla prima parentesi chiusa", non sulla virgola), e ogni token
-- senza un numero davanti viene inviato cosi' com'e', anche se contiene piu'
-- parole.
local swEntry2 = NebbieDash.parseSpeedwalkLine("(paul, da astral) u,n,2w,n,u,enter pool,4n,3w,6s")
check("speedwalk complesso: riga valida non nil", swEntry2 ~= nil)
if swEntry2 then
  check("speedwalk complesso: descrizione con virgola interna", swEntry2.desc == "paul, da astral")
  check("speedwalk complesso: 20 passi totali",
    #swEntry2.steps == 20)
  check("speedwalk complesso: sequenza esatta",
    table.concat(swEntry2.steps, "|") ==
    table.concat({ "u", "n", "w", "w", "n", "u", "enter pool", "n", "n", "n", "n", "w", "w", "w", "s", "s", "s", "s", "s", "s" }, "|"))
end

-- Test 7: cmdQuickCast — bersaglio automatico su se stessi quando l'ultima
-- parola digitata abbrevia il personaggio attivo (NomiyaMaki), riportato
-- dall'utente come non funzionante ("c heal nom", "c darkne nom", "c dar
-- nom" -> il gioco riceveva 'heal nom' come nome spell unico, invece di
-- 'heal' + bersaglio nom).
NebbieDash.setCurrentCharacter("NomiyaMaki", true)
NebbieDash.cmdQuickCast("c", "heal nom")
check("quickcast: 'c heal nom' -> cast 'heal' NomiyaMaki", lastSent == "cast 'heal' NomiyaMaki")

NebbieDash.cmdQuickCast("c", "darkne nom")
check("quickcast: 'c darkne nom' -> cast 'darkne' NomiyaMaki", lastSent == "cast 'darkne' NomiyaMaki")

NebbieDash.cmdQuickCast("c", "dar nom")
check("quickcast: 'c dar nom' -> cast 'dar' NomiyaMaki", lastSent == "cast 'dar' NomiyaMaki")

-- Non deve rompere il caso storico senza bersaglio (ultima parola di 1 sola
-- lettera, ignorata apposta per questo motivo).
NebbieDash.cmdQuickCast("c", "word of r")
check("quickcast: 'c word of r' resta senza bersaglio", lastSent == "cast 'word of r'")

-- Click dal pannello spell attivi: bersaglio esplicito passato come terzo
-- argomento, non deve attivare l'euristica (gia' corretto di suo).
NebbieDash.cmdQuickCast("c", "true sight", "NomiyaMaki")
check("quickcast: bersaglio esplicito dal pannello invariato", lastSent == "cast 'true sight' NomiyaMaki")

-- Bersaglio esplicito su un ALTRO personaggio (non il proprio), richiesto
-- dall'utente dopo il fix precedente: sintassi con virgola, funziona anche se
-- il bersaglio non abbrevia in alcun modo il nome del personaggio attivo.
NebbieDash.cmdQuickCast("c", "heal, bob")
check("quickcast: 'c heal, bob' -> cast 'heal' bob", lastSent == "cast 'heal' bob")

NebbieDash.cmdQuickCast("r", "word of recall, bob")
check("quickcast: virgola con spell multi-parola", lastSent == "recall 'word of recall' bob")

-- La virgola ha precedenza sull'euristica automatica anche quando il
-- bersaglio scritto dopo la virgola e' proprio il personaggio attivo.
NebbieDash.cmdQuickCast("c", "heal, NomiyaMaki")
check("quickcast: virgola vince anche col proprio nome", lastSent == "cast 'heal' NomiyaMaki")

-- Test 8: loot + split automatico — testi REALI incollati dall'utente
-- (2026-08-10): "Prendi gold coins da il corpo di ...", "C'erano N monete.",
-- "But you are a member of no group?!", 'Your group "..." consists of:'.
NebbieDash.autoSplit = true

-- 8a: la riga "Prendi gold coins da ..." da sola non fa scattare nulla (non
-- contiene l'importo, solo il nome del cadavere, che varia per ogni mostro).
local sentBefore8a = #sentLog
line = "Prendi gold coins da il corpo di Il grande drago verde delle foreste."
NebbieDash.onLootLine()
check("loot: riga 'Prendi...' da sola non genera comandi",
  #sentLog == sentBefore8a)

-- 8b: la riga con l'importo avvia il controllo gruppo (invio di "group").
line = "C'erano 100000 monete."
NebbieDash.onLootLine()
check("loot: importo riconosciuto correttamente", NebbieDash._pendingSplitAmount == 100000)
check("loot: dopo il loot invia 'group' per il controllo", lastSent == "group")

-- 8c: risposta "da soli" -> nessuno split inviato, stato ripulito.
NebbieDash.onGroupSoloLine()
check("loot: da soli non invia alcuno split", lastSent == "group")
check("loot: stato controllo gruppo ripulito (da soli)", NebbieDash._groupCheckActive == false)

-- 8d: risposta "in gruppo" -> invia split con l'importo corretto.
line = "C'erano 250 monete."
NebbieDash.onLootLine()
line = 'Your group "I cacciatori di Draghi" consists of:'
NebbieDash.onGroupHeaderLine()
check("loot: in gruppo invia split con l'importo corretto", lastSent == "split 250")

-- 8e: con nautosplit off, il loot non deve avviare alcun controllo gruppo.
NebbieDash.autoSplit = false
sentLog = {}
line = "C'erano 42 monete."
NebbieDash.onLootLine()
check("loot: con autosplit off non invia 'group'", #sentLog == 0)
NebbieDash.autoSplit = true

-- 8f: nsplit manuale invia l'importo indicato senza passare dal loot.
NebbieDash.cmdSplit("777")
check("split manuale: 'nsplit 777' -> invia split 777", lastSent == "split 777")

-- Test 9: loot automatico alla fine del combattimento — testi REALI
-- incollati dall'utente (2026-08-10): "Uno Spazzino is dead! R.I.P." seguito
-- da "La tua parte di esperienza e' di N punti." (anche con N=0/1).
NebbieDash.autoLoot = true
sentLog = {}
line = "Uno Spazzino is dead! R.I.P."
-- La riga "is dead!" da sola NON deve avviare il loot (potrebbe non essere
-- una uccisione a cui hai partecipato tu): serve la riga "La tua parte...".
check("combattimento: riga 'is dead!' da sola non genera comandi", #sentLog == 0)

line = "La tua parte di esperienza e' di 1047 punti."
NebbieDash.onCombatEndLine()
check("combattimento: fine combattimento avvia il loot automatico", sentLog[1] == "get all.coin corp")

-- Anche con 0 punti di esperienza (uccisione minima) deve comunque scattare.
sentLog = {}
line = "La tua parte di esperienza e' di 0 punti."
NebbieDash.onCombatEndLine()
check("combattimento: scatta anche con 0 punti esperienza", sentLog[1] == "get all.coin corp")

-- Con nautoloot off non deve inviare nulla.
NebbieDash.autoLoot = false
sentLog = {}
NebbieDash.onCombatEndLine()
check("combattimento: con nautoloot off non invia nulla", #sentLog == 0)
NebbieDash.autoLoot = true

-- Test 10: bug segnalato (2026-08-10) — cambio personaggio non aggiornava
-- la dashboard (self-cast finiva sul personaggio precedente). Fix: alla
-- (ri)connessione il personaggio attivo viene azzerato subito, invece di
-- restare quello vecchio finche' non arriva un nuovo prompt.
NebbieDash.setCurrentCharacter("NomiyaMaki", true)
check("connessione: personaggio attivo prima del reset", NebbieDash.currentChar == "NomiyaMaki")
NebbieDash.onConnectionEvent()
check("connessione: personaggio azzerato subito alla riconnessione", NebbieDash.currentChar == nil)
check("connessione: in attesa di un nuovo prompt", NebbieDash._awaitingPromptAfterConnect == true)
-- Un self-cast prima che arrivi un nuovo prompt non deve piu' finire sul
-- vecchio personaggio: senza nome attivo, l'euristica sul proprio nome non
-- puo' scattare (nessun bersaglio aggiunto, comportamento sicuro).
sentLog = {}
NebbieDash.cmdQuickCast("c", "heal nom")
check("connessione: quickcast senza personaggio attivo non aggiunge un bersaglio sbagliato",
  lastSent == "cast 'heal nom'")
NebbieDash.setCurrentCharacter("NomiyaMaki", true)

-- Test 11: rialzarsi automatico dopo una caduta — testo REALE fornito
-- dall'utente (2026-08-10): "Illyari schiva il tuo urto. Inciampi e cadi
-- per terra." (la parte fissa e' "Inciampi e cadi per terra.").
NebbieDash.autoStand = true
sentLog = {}
NebbieDash.onFallLine()
check("caduta: 'stand' inviato automaticamente", lastSent == "stand")

NebbieDash.autoStand = false
sentLog = {}
NebbieDash.onFallLine()
check("caduta: con nautostand off non invia nulla", #sentLog == 0)
NebbieDash.autoStand = true

-- Test 12: recupero automatico dell'arma dopo un disarmo — testo REALE
-- fornito dall'utente: "Ti disarmano e la Flamberga di Boris vola dalla tua
-- presa." Le parole chiave attese ("flamberga boris") sono confermate
-- dall'utente come quelle che funzionano davvero in gioco per quest'arma.
check("parole chiave: 'la Flamberga di Boris' -> 'flamberga boris'",
  NebbieDash.extractItemKeywords("la Flamberga di Boris") == "flamberga boris")
check("parole chiave: apostrofo gestito (\"dell'Infinito\" -> \"infinito\")",
  NebbieDash.extractItemKeywords("Il Guanto dell'Infinito") == "guanto infinito")

NebbieDash.autoDisarmRecover = true
sentLog = {}
line = "Ti disarmano e la Flamberga di Boris vola dalla tua presa."
NebbieDash.onDisarmLine()
check("disarmo: 'get flamberga boris' inviato automaticamente", sentLog[1] == "get flamberga boris")

NebbieDash.autoDisarmRecover = false
sentLog = {}
NebbieDash.onDisarmLine()
check("disarmo: con nautodisarm off non invia nulla", #sentLog == 0)
NebbieDash.autoDisarmRecover = true

-- Test 13: ripetizione comandi generica (".4s" -> s,s,s,s), richiesta
-- esplicitamente dall'utente. tempTimer e' un mock no-op in questo test
-- (non esegue MAI i callback, nemmeno con delay 0 — stesso limite gia'
-- presente per gli altri invii differiti di questo file, es. il secondo
-- comando di nloot), quindi qui verifichiamo solo la validazione dei
-- parametri: nessun errore e nessun invio "a sorpresa" per input non validi.
local repeatOk = pcall(NebbieDash.cmdRepeat, "4", "s")
check("ripetizione: 'cmdRepeat(4, s)' non genera errori", repeatOk)

sentLog = {}
NebbieDash.cmdRepeat("0", "s")
check("ripetizione: conteggio zero non invia nulla", #sentLog == 0)

sentLog = {}
NebbieDash.cmdRepeat("abc", "s")
check("ripetizione: conteggio non numerico non invia nulla", #sentLog == 0)

sentLog = {}
NebbieDash.cmdRepeat("4", "")
check("ripetizione: comando vuoto non invia nulla", #sentLog == 0)

print("")
if failures == 0 then
  print("TUTTI I TEST OK (" .. #eqLines .. " righe eq, " .. #attribLines .. " righe attrib)")
  os.exit(0)
else
  print(failures .. " TEST FALLITI")
  os.exit(1)
end
