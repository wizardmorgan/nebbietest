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
function send() end
function tempTimer() end
function setBorderRight() end
function createMiniConsole() end
function setMiniConsoleFontSize() end
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

print("")
if failures == 0 then
  print("TUTTI I TEST OK (" .. #eqLines .. " righe eq, " .. #attribLines .. " righe attrib)")
  os.exit(0)
else
  print(failures .. " TEST FALLITI")
  os.exit(1)
end
