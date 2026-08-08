-- Nebbie Complete Dashboard Package — core installer logic
--
-- Package Mudlet nuovo e minimo per Nebbie Arcane, nato da un'analisi da zero
-- (vedi docs/mudlet/analysis/). NON e' un patch di nebbie-play-all: e' un package
-- indipendente, pensato per un solo profilo Mudlet condiviso da piu' personaggi con
-- switch sequenziale (un PG alla volta, rilevato dal nome nel prompt).
--
-- Fonti/decisioni documentate in docs/mudlet/analysis/DESIGN-OPTIONS.md (D1..D4) e
-- docs/mudlet/analysis/RECOMMENDATION.md. Pattern prompt/eq basati su dati reali
-- forniti dall'utente (docs/mudlet/analysis/Q&A.md, Round 3).

local PKG_VER = "1.1.0"

if NebbieDash and NebbieDash._loadedVer == PKG_VER and NebbieDash._mainLoaded then
  return
end

NebbieDash = NebbieDash or {}
NebbieDash.version = PKG_VER
NebbieDash._loadedVer = PKG_VER
NebbieDash.package = "nebbie-complete-dashboard-package"

-- ---------------------------------------------------------------------------
-- Tabella slot equip (21 slot) — da REQUIREMENTS.md §5 (M4), output reale `eq`
-- ---------------------------------------------------------------------------
NebbieDash.EQ_SLOTS = {
  [1] = "sul dito destro",
  [2] = "sul dito sinistro",
  [3] = "intorno al collo",
  [4] = "intorno al collo",
  [5] = "sul corpo",
  [6] = "in testa",
  [7] = "sulle gambe",
  [8] = "ai piedi",
  [9] = "sulle mani",
  [10] = "sulle braccia",
  [11] = "come scudo",
  [12] = "intorno al corpo",
  [13] = "intorno alla vita",
  [14] = "al polso destro",
  [15] = "al polso sinistro",
  [16] = "impugnato",
  [17] = "tenuto",
  [18] = "sulla schiena",
  [19] = "all'orecchio destro",
  [20] = "all'orecchio sinistro",
  [21] = "davanti agli occhi",
}

-- ---------------------------------------------------------------------------
-- Persistenza per personaggio (D3-B, confermata dall'utente)
-- ---------------------------------------------------------------------------
NebbieDash.persistEnabled = true

function NebbieDash.storePath()
  local home = (type(getMudletHomeDir) == "function" and getMudletHomeDir()) or "."
  return home .. "/nebbie-complete-dashboard-package-chars.lua"
end

function NebbieDash.loadStore()
  NebbieDash.chars = NebbieDash.chars or {}
  local path = NebbieDash.storePath()
  if type(io.exists) == "function" and io.exists(path) then
    pcall(function() table.load(path, NebbieDash.chars) end)
  end
  NebbieDash.migrateStore()
end

-- Versioni precedenti salvavano data.eq[slot] come stringa (solo item, niente
-- posizione). Converte al volo il formato vecchio { [slot] = "testo" } nel
-- nuovo { [slot] = { location = ..., item = ... } } senza perdere dati salvati
-- su disco da installazioni precedenti del package.
function NebbieDash.migrateStore()
  for _, data in pairs(NebbieDash.chars or {}) do
    if type(data.eq) == "table" then
      for slot, entry in pairs(data.eq) do
        if type(entry) == "string" then
          data.eq[slot] = { location = NebbieDash.EQ_SLOTS[slot] or "?", item = entry }
        end
      end
    end
  end
end

function NebbieDash.saveStore()
  if not NebbieDash.persistEnabled then return end
  pcall(function() table.save(NebbieDash.storePath(), NebbieDash.chars) end)
end

function NebbieDash.getCharData(name)
  NebbieDash.chars = NebbieDash.chars or {}
  if not NebbieDash.chars[name] then
    NebbieDash.chars[name] = { eq = {}, spells = {}, weaponConfig = {}, lastSeen = nil }
  end
  return NebbieDash.chars[name]
end

-- ---------------------------------------------------------------------------
-- Rilevamento personaggio attivo (D1-A + D1-C + D1-B override manuale)
-- ---------------------------------------------------------------------------
function NebbieDash.setCurrentCharacter(name, manual)
  if not name or name == "" then return end
  if NebbieDash.currentChar == name then
    NebbieDash.getCharData(name).lastSeen = os.time()
    return
  end
  NebbieDash.currentChar = name
  local data = NebbieDash.getCharData(name)
  data.lastSeen = os.time()
  NebbieDash.saveStore()
  NebbieDash.refreshDashboard()
  if type(raiseEvent) == "function" then
    pcall(raiseEvent, "nebbieDashCharacterChanged", name, manual and true or false)
  end
  cecho("<cyan>[NebbieDash] Personaggio attivo: <yellow>" .. name .. "\n")
end

function NebbieDash.onConnectionEvent()
  -- Reset difensivo: alla (ri)connessione non sappiamo ancora con certezza chi sia
  -- collegato finche' non arriva un prompt valido (D1-C, MUDLET-WIKI-NOTES.md §5-6).
  NebbieDash._awaitingPromptAfterConnect = true
end

-- ---------------------------------------------------------------------------
-- Parsing prompt (D2-0) — pattern Lua, NON quelli del codice legacy (bug noto:
-- il codice legacy richiede "H:%d+" senza spazio e "X:" maiuscolo; il prompt
-- reale ha "H: %d+" con spazio e "x:" minuscolo — vedi Q&A.md Round 3).
-- ---------------------------------------------------------------------------
function NebbieDash.parsePromptLine(text)
  if not text or text == "" then return nil end
  local name, hp, hpmax, mana, manamax, move, movemax, xfield =
    text:match("^(%S+)%s+H:%s*(%d+)/(%d+)%s+M:%s*(%d+)/(%d+)%s+V:%s*(%d+)/(%d+)%s+[Xx]:%s*(%-?%d+)")
  if not name then return nil end
  local gold = text:match("[Gg]:(%d+)")
  local codes = text:match("%[%[([^%]]*)%]%]")
  return {
    name = name,
    hp = tonumber(hp), hpmax = tonumber(hpmax),
    mana = tonumber(mana), manamax = tonumber(manamax),
    move = tonumber(move), movemax = tonumber(movemax),
    xfield = tonumber(xfield),
    gold = gold and tonumber(gold) or nil,
    codes = codes,
  }
end

function NebbieDash.onPromptLine()
  local text = line
  if (not text or text == "") and type(getCurrentLine) == "function" then
    text = getCurrentLine()
  end
  local parsed = NebbieDash.parsePromptLine(text or "")
  if not parsed then return end
  NebbieDash.stats = parsed
  NebbieDash.setCurrentCharacter(parsed.name, false)
  NebbieDash._awaitingPromptAfterConnect = false
  NebbieDash.updateVitalsDisplay()
end

-- ---------------------------------------------------------------------------
-- Capture "eq" (D2-C / D2-0) — state machine attivata/disattivata con
-- enableTrigger()/disableTrigger() invece di un trigger multiline con margine
-- fisso, per gestire un numero variabile di righe (incluso il word-wrap, M6).
-- ---------------------------------------------------------------------------
function NebbieDash.startEqCapture()
  NebbieDash._eqCapture = { slots = {}, lastSlot = nil }
  if NebbieDash._eqLineTrig then
    pcall(enableTrigger, NebbieDash._eqLineTrig)
  end
end

function NebbieDash.finishEqCapture()
  local cap = NebbieDash._eqCapture
  NebbieDash._eqCapture = nil
  if NebbieDash._eqLineTrig then
    pcall(disableTrigger, NebbieDash._eqLineTrig)
  end
  if not cap then return end
  local name = NebbieDash.currentChar
  if not name then return end
  local data = NebbieDash.getCharData(name)
  data.eq = cap.slots
  data.eqUpdated = os.time()
  NebbieDash.saveStore()
  NebbieDash.refreshDashboard()
  cecho("<green>[NebbieDash] Equip aggiornato (" .. tostring(NebbieDash.countSlots(cap.slots)) .. "/21 slot).\n")
end

function NebbieDash.countSlots(slots)
  local n = 0
  for _ in pairs(slots or {}) do n = n + 1 end
  return n
end

-- Trigger "sempre presente" ma disabilitato salvo durante la cattura: costo
-- nullo sulle righe normali di gioco (i trigger disabilitati non vengono
-- valutati — vedi MUDLET-WIKI-NOTES.md §1, principio di shielding/locking).
function NebbieDash.onEqCaptureLine()
  local cap = NebbieDash._eqCapture
  if not cap then return end
  local text = line
  if (not text or text == "") and type(getCurrentLine) == "function" then
    text = getCurrentLine()
  end
  text = text or ""

  if NebbieDash.parsePromptLine(text) or text:match("^>>%s*$") then
    NebbieDash.finishEqCapture()
    return
  end

  -- La posizione (es. "ai piedi") viene letta dalla riga stessa, MAI da una
  -- tabella statica: il numero di slot da solo non e' un identificatore
  -- affidabile della posizione sul corpo (varia in base a cosa il PG ha
  -- effettivamente indosso in quel momento) — bug osservato: con la vecchia
  -- tabella statica EQ_SLOTS uno slot "spostato" faceva comparire l'oggetto
  -- sotto l'etichetta sbagliata (es. stivali mostrati come "ai piedi" quando
  -- invece occupavano un altro indice, lasciando "davanti agli occhi" vuoto).
  local slot, location, item = text:match("^%[%s*(%d+)%]%s+<([^>]+)>%s*(.+)$")
  if slot then
    slot = tonumber(slot)
    cap.slots[slot] = { location = location:match("^%s*(.-)%s*$"), item = item:match("^%s*(.-)%s*$") }
    cap.lastSlot = slot
    return
  end

  if text:match("^%s*$") then
    NebbieDash.finishEqCapture()
    return
  end

  -- Riga di continuazione (word-wrap, M6): concatenata all'ultimo slot letto.
  if cap.lastSlot and cap.slots[cap.lastSlot] then
    local entry = cap.slots[cap.lastSlot]
    entry.item = entry.item .. " " .. text:match("^%s*(.-)%s*$")
  end
end

-- ---------------------------------------------------------------------------
-- Capture "attrib" (Spell attivi) — stessa tecnica enable/disable di sopra.
-- Formato base confermato da esempio utente: "Spell : 'nome' - N"
-- (AGENT-PROMPT-ANALISI-ZERO.txt righe 77-82). Formato completo del blocco
-- (es. eventuali sezioni debuff) NON ancora confermato — vedi REQUIREMENTS.md
-- M5, aperto/non bloccante per la release 1.
-- ---------------------------------------------------------------------------
function NebbieDash.startAttribCapture()
  NebbieDash._attribCapture = { spells = {} }
  if NebbieDash._attribLineTrig then
    pcall(enableTrigger, NebbieDash._attribLineTrig)
  end
end

function NebbieDash.finishAttribCapture()
  local cap = NebbieDash._attribCapture
  NebbieDash._attribCapture = nil
  if NebbieDash._attribLineTrig then
    pcall(disableTrigger, NebbieDash._attribLineTrig)
  end
  if not cap then return end
  local name = NebbieDash.currentChar
  if not name then return end
  local data = NebbieDash.getCharData(name)
  data.spells = cap.spells
  data.spellsUpdated = os.time()
  NebbieDash.saveStore()
  NebbieDash.refreshDashboard()
  cecho("<green>[NebbieDash] Spell attivi aggiornati (" .. tostring(#cap.spells) .. ").\n")
end

function NebbieDash.onAttribCaptureLine()
  local cap = NebbieDash._attribCapture
  if not cap then return end
  local text = line
  if (not text or text == "") and type(getCurrentLine) == "function" then
    text = getCurrentLine()
  end
  text = text or ""

  if NebbieDash.parsePromptLine(text) or text:match("^>>%s*$") then
    NebbieDash.finishAttribCapture()
    return
  end

  local spellName, ticks = text:match("Spell%s*:%s*'([^']+)'%s*%-%s*(%d+)")
  if spellName then
    table.insert(cap.spells, { name = spellName, ticks = tonumber(ticks) })
    return
  end

  if cap._started and text:match("^%s*$") then
    NebbieDash.finishAttribCapture()
    return
  end
  if text:match("Spells attivi") then
    cap._started = true
  end
end

-- ---------------------------------------------------------------------------
-- Comandi manuali (nessun invio automatico eq/attrib al boot — vedi
-- MUDLET-WIKI-NOTES.md §5-6 e RECOMMENDATION.md §3)
-- ---------------------------------------------------------------------------
function NebbieDash.cmdResyncEq()
  NebbieDash.startEqCapture()
  send("eq", false)
end

function NebbieDash.cmdResyncAttrib()
  NebbieDash.startAttribCapture()
  send("attrib", false)
end

function NebbieDash.cmdResyncAll()
  NebbieDash.cmdResyncEq()
  tempTimer(1.5, function() NebbieDash.cmdResyncAttrib() end)
end

-- ---------------------------------------------------------------------------
-- Motore generico di lancio spell/skill/potere psionico (c/r/m + argomento)
-- Fonte: src/spell_parser.cpp del server (ACTION_FUNC(do_cast)) usa
-- old_search_block(argument, 1, qend-1, spells, 0) per matchare il nome tra
-- apici anche abbreviato (es. 'word of r' -> "word of recall"): il motore di
-- gioco fa gia' da solo il fuzzy-match, qui ci limitiamo a incapsulare
-- l'argomento tra apici singoli e a inviare il comando giusto per prefisso.
-- Confermato dall'utente: mago/chierico usano "cast", sorcerer "recall",
-- psionico "mind". Vedi docs/mudlet/analysis/MUD-SPELL-SKILL-LIST.md.
-- ---------------------------------------------------------------------------
NebbieDash.CAST_PREFIX = { c = "cast", r = "recall", m = "mind" }

function NebbieDash.cmdQuickCast(prefix, argument)
  local cmdWord = NebbieDash.CAST_PREFIX[(prefix or ""):lower()]
  if not cmdWord then return end
  argument = (argument or ""):match("^%s*(.-)%s*$")
  if argument == "" then
    cecho("<orange>[NebbieDash] Uso: " .. prefix .. " <nome spell/skill, anche abbreviato>\n")
    return
  end
  send(cmdWord .. " '" .. argument .. "'", false)
end

-- ---------------------------------------------------------------------------
-- Speedwalk (file di configurazione scritto a mano dall'utente — vedi
-- Q&A.md Round 5). Formato per riga, deciso in accordo con l'utente:
--   (descrizione cliccabile) direzioni separate da virgola
-- Una direzione puo' avere un numero davanti per ripeterla N volte, es.
-- "u,3w,n,s,2d" = up, west, west, west, north, south, down, down. Righe
-- vuote o che iniziano con # sono ignorate. Le direzioni vengono inviate
-- cosi' come scritte (es. "u", "w", "n"...): NON le traduciamo in parole
-- intere, perche' il gioco stesso accetta le forme brevi come comandi di
-- movimento.
-- ---------------------------------------------------------------------------
NebbieDash.speedwalks = {}
-- Pausa (in secondi) tra un movimento e il successivo quando si esegue uno
-- speedwalk: un invio istantaneo di tutte le direzioni una via l'altra
-- rischia di perdere passi se il gioco impone un tempo minimo (\"lag\") tra
-- un movimento e l'altro. Regolabile con nspeeddelay se serve un valore
-- diverso.
NebbieDash.speedwalkDelay = 0.35

function NebbieDash.speedwalkPath()
  local home = (type(getMudletHomeDir) == "function" and getMudletHomeDir()) or "."
  return home .. "/nebbie-speedwalks.txt"
end

function NebbieDash.ensureSpeedwalkFile()
  local path = NebbieDash.speedwalkPath()
  if type(io.exists) == "function" and io.exists(path) then return end
  local f = io.open(path, "w")
  if not f then return end
  f:write(
    "# File di configurazione speedwalk — nebbie-complete-dashboard-package\n" ..
    "#\n" ..
    "# Una riga per speedwalk, formato:\n" ..
    "#   (descrizione cliccabile) direzioni separate da virgola\n" ..
    "#\n" ..
    "# Le direzioni si scrivono come le invieresti tu in gioco (es. n, s, e, w,\n" ..
    "# u, d, ne, nw, se, sw...). Se vuoi ripetere la stessa direzione piu' volte\n" ..
    "# di fila, metti il numero di ripetizioni subito prima, senza spazi.\n" ..
    "#\n" ..
    "# Esempio (spiegato): \"u,3w,n,s,2d\" significa: up, west, west, west,\n" ..
    "# north, south, down, down.\n" ..
    "#\n" ..
    "# Le righe che iniziano con # e le righe vuote vengono ignorate.\n" ..
    "# Dopo aver modificato questo file, digita 'nspeedwalks' in gioco per\n" ..
    "# ricaricarlo senza dover riavviare Mudlet.\n" ..
    "#\n" ..
    "# Esempio (rimuovi il # iniziale per attivarlo):\n" ..
    "# (dalla fontana) u,3w,n,s,2d\n"
  )
  f:close()
end

function NebbieDash.parseSpeedwalkDirs(dirString)
  local steps = {}
  for rawToken in (dirString or ""):gmatch("[^,]+") do
    local token = rawToken:match("^%s*(.-)%s*$")
    if token ~= "" then
      local count, dir = token:match("^(%d+)(%a+)$")
      if not dir then
        dir = token
        count = 1
      end
      count = tonumber(count) or 1
      for _ = 1, count do
        table.insert(steps, dir)
      end
    end
  end
  return steps
end

function NebbieDash.parseSpeedwalkLine(rawLine)
  local line2 = rawLine:match("^%s*(.-)%s*$")
  if line2 == "" or line2:sub(1, 1) == "#" then return nil end
  local desc, dirString = line2:match("^%((.-)%)%s*(.+)$")
  if not desc then return nil end
  local steps = NebbieDash.parseSpeedwalkDirs(dirString)
  if #steps == 0 then return nil end
  return { desc = desc, dirString = dirString:match("^%s*(.-)%s*$"), steps = steps }
end

function NebbieDash.loadSpeedwalks()
  NebbieDash.ensureSpeedwalkFile()
  NebbieDash.speedwalks = {}
  local path = NebbieDash.speedwalkPath()
  local f = io.open(path, "r")
  if not f then return end
  for rawLine in f:lines() do
    local entry = NebbieDash.parseSpeedwalkLine(rawLine)
    if entry then table.insert(NebbieDash.speedwalks, entry) end
  end
  f:close()
end

function NebbieDash.cmdReloadSpeedwalks()
  NebbieDash.loadSpeedwalks()
  NebbieDash.refreshDashboard()
  cecho("<green>[NebbieDash] Speedwalk ricaricati (" .. #NebbieDash.speedwalks .. ") da " .. NebbieDash.speedwalkPath() .. "\n")
end

function NebbieDash.cmdSetSpeedDelay(str)
  local delay = tonumber(str)
  if not delay or delay < 0 or delay > 10 then
    cecho("<orange>[NebbieDash] Uso: nspeeddelay <secondi tra 0 e 10> (attuale: " .. NebbieDash.speedwalkDelay .. ")\n")
    return
  end
  NebbieDash.speedwalkDelay = delay
  cecho("<green>[NebbieDash] Pausa tra i movimenti impostata a " .. delay .. "s.\n")
end

-- Invia le direzioni di uno speedwalk una alla volta, con una pausa tra
-- l'una e l'altra (vedi NebbieDash.speedwalkDelay) invece di un unico invio
-- concatenato, per non rischiare di perdere passi per via del lag di
-- movimento del gioco.
function NebbieDash.runSpeedwalk(index)
  local entry = NebbieDash.speedwalks[index]
  if not entry then return end
  for i, dir in ipairs(entry.steps) do
    tempTimer(NebbieDash.speedwalkDelay * (i - 1), function() send(dir, false) end)
  end
end

function NebbieDash.cmdShowEq()
  local name = NebbieDash.currentChar
  if not name then
    cecho("<orange>[NebbieDash] Nessun personaggio rilevato ancora. Digita un comando in gioco, poi riprova.\n")
    return
  end
  local data = NebbieDash.getCharData(name)
  if not data.eqUpdated then
    cecho("<orange>[NebbieDash] Nessuna cache equip per " .. name .. " — esegui <yellow>nresync<orange> o <yellow>neq<orange>.\n")
  end
  NebbieDash.cmdResyncEq()
end

function NebbieDash.cmdShowAttrib()
  local name = NebbieDash.currentChar
  if not name then
    cecho("<orange>[NebbieDash] Nessun personaggio rilevato ancora. Digita un comando in gioco, poi riprova.\n")
    return
  end
  NebbieDash.cmdResyncAttrib()
end

function NebbieDash.cmdSetCharacter(name)
  if not name or name == "" then
    cecho("<orange>[NebbieDash] Uso: nchar NomePersonaggio\n")
    return
  end
  NebbieDash.setCurrentCharacter(name, true)
end

-- Comando di lancio da usare quando si clicca una spell attiva nel pannello
-- (vedi refreshDashboard): dipende dalla classe del personaggio corrente
-- (mago/chierico -> cast, sorcerer -> recall, psionico -> mind), non e'
-- deducibile dal nome della spell stesso, quindi va impostato una volta per
-- personaggio. Default "c" (cast) finche' non specificato.
function NebbieDash.cmdSetClass(prefix)
  prefix = (prefix or ""):lower():match("^%s*(.-)%s*$")
  if not NebbieDash.CAST_PREFIX[prefix] then
    cecho("<orange>[NebbieDash] Uso: nclass <c|r|m> (cast/recall/mind)\n")
    return
  end
  local name = NebbieDash.currentChar
  if not name then
    cecho("<orange>[NebbieDash] Nessun personaggio rilevato ancora.\n")
    return
  end
  NebbieDash.getCharData(name).castPrefix = prefix
  NebbieDash.saveStore()
  NebbieDash.refreshDashboard()
  cecho("<green>[NebbieDash] Comando di rilancio per " .. name .. " impostato su '" .. prefix .. "' (" .. NebbieDash.CAST_PREFIX[prefix] .. ").\n")
end

-- ---------------------------------------------------------------------------
-- Dashboard (miniconsole su bordo destro — MUDLET-WIKI-NOTES.md §6)
-- ---------------------------------------------------------------------------
NebbieDash.guiWidth = 320
NebbieDash.fontSize = 11
-- Le descrizioni oggetto sono spesso lunghe (es. "Un tubino rinforzato con
-- una grossa Union Jack (in condizioni eccellenti)") e vanno quasi sempre a
-- capo in un pannello laterale stretto; le tronchiamo per un colpo d'occhio
-- piu' pulito (il testo completo resta comunque visibile con `eq` normale).
NebbieDash.itemMaxLen = 42
-- Soglia (in tick) sotto la quale una spell attiva viene mostrata in rosso
-- invece che verde, per segnalare che sta per scadere. NOTA: riflette solo
-- il valore letto all'ultimo `nattrib`/`nresync`, NON un conto alla rovescia
-- in tempo reale — non conosciamo quanti secondi dura un tick sul server, e
-- senza quell'informazione non possiamo stimare il tempo residuo reale.
NebbieDash.spellWarnTicks = 5

function NebbieDash.truncate(s, maxLen)
  if not s or #s <= maxLen then return s end
  return s:sub(1, math.max(1, maxLen - 1)) .. "…"
end

function NebbieDash.guiVisible()
  return NebbieDash._guiCreated == true and NebbieDash._guiHidden ~= true
end

-- Proporzioni verticali dei 3 pannelli (devono sommare a 1.0).
NebbieDash.guiRatios = { equip = 0.45, spells = 0.25, speedwalk = 0.30 }
NebbieDash.GUI_WINDOWS = { "NebbieDashEquip", "NebbieDashSpells", "NebbieDashSpeedwalks" }

function NebbieDash.initGUI()
  if NebbieDash._guiCreated then return end
  setBorderRight(NebbieDash.guiWidth)
  for _, win in ipairs(NebbieDash.GUI_WINDOWS) do
    createMiniConsole(win, 0, 0, NebbieDash.guiWidth, 0)
    setMiniConsoleFontSize(win, NebbieDash.fontSize)
    -- Una miniconsole appena creata ha uno sfondo di default (grigio, widget
    -- Qt non ancora disegnato) finche' non le si assegna esplicitamente un
    -- colore e non ci si scrive dentro almeno una volta: senza questo il
    -- pannello resta grigio anche a install riuscita (bug osservato, vedi
    -- docs/mudlet/analysis/LOG.md).
    setBackgroundColor(win, 15, 15, 15, 255)
  end
  NebbieDash._guiCreated = true
  NebbieDash.positionGUI()
  NebbieDash.refreshDashboard()
  -- getMainWindowSize() puo' non essere ancora affidabile nello stesso istante
  -- in cui la GUI viene creata (geometria Qt non ancora assestata all'avvio
  -- del profilo): riesegui il posizionamento un istante dopo per evitare che
  -- un pannello resti a altezza 0 (visto come "una sola barra" a schermo).
  tempTimer(0, [[NebbieDash.positionGUI()]])
end

function NebbieDash.positionGUI()
  if not NebbieDash._guiCreated then return end
  local w, h = getMainWindowSize()
  w = w or 800
  h = h or 600
  local x = math.max(0, w - NebbieDash.guiWidth)
  local equipH = math.floor(h * NebbieDash.guiRatios.equip)
  local spellsH = math.floor(h * NebbieDash.guiRatios.spells)
  local speedwalkH = h - equipH - spellsH
  moveWindow("NebbieDashEquip", x, 0)
  resizeWindow("NebbieDashEquip", NebbieDash.guiWidth, equipH)
  moveWindow("NebbieDashSpells", x, equipH)
  resizeWindow("NebbieDashSpells", NebbieDash.guiWidth, spellsH)
  moveWindow("NebbieDashSpeedwalks", x, equipH + spellsH)
  resizeWindow("NebbieDashSpeedwalks", NebbieDash.guiWidth, speedwalkH)
end

function NebbieDash.toggleGUI()
  if not NebbieDash._guiCreated then
    NebbieDash.initGUI()
    NebbieDash._guiHidden = false
  else
    NebbieDash._guiHidden = not NebbieDash._guiHidden
    if NebbieDash._guiHidden then
      for _, win in ipairs(NebbieDash.GUI_WINDOWS) do hideWindow(win) end
      setBorderRight(0)
    else
      for _, win in ipairs(NebbieDash.GUI_WINDOWS) do showWindow(win) end
      setBorderRight(NebbieDash.guiWidth)
      NebbieDash.positionGUI()
    end
  end
  NebbieDash.refreshDashboard()
end

function NebbieDash.resetLayout()
  NebbieDash.guiWidth = 320
  NebbieDash.fontSize = 11
  NebbieDash.guiRatios = { equip = 0.45, spells = 0.25, speedwalk = 0.30 }
  if NebbieDash._guiCreated then
    setBorderRight(NebbieDash.guiWidth)
    for _, win in ipairs(NebbieDash.GUI_WINDOWS) do
      setMiniConsoleFontSize(win, NebbieDash.fontSize)
    end
    NebbieDash.positionGUI()
  end
end

function NebbieDash.cmdSetFont(sizeStr)
  local size = tonumber(sizeStr)
  if not size or size < 6 or size > 24 then
    cecho("<orange>[NebbieDash] Uso: nfont <numero tra 6 e 24> (attuale: " .. NebbieDash.fontSize .. ")\n")
    return
  end
  NebbieDash.fontSize = size
  if NebbieDash._guiCreated then
    for _, win in ipairs(NebbieDash.GUI_WINDOWS) do
      setMiniConsoleFontSize(win, size)
    end
  end
  cecho("<green>[NebbieDash] Font pannello impostato a " .. size .. ".\n")
end

function NebbieDash.cmdSetWidth(widthStr)
  local width = tonumber(widthStr)
  if not width or width < 150 or width > 900 then
    cecho("<orange>[NebbieDash] Uso: nwidth <numero tra 150 e 900> (attuale: " .. NebbieDash.guiWidth .. ")\n")
    return
  end
  NebbieDash.guiWidth = width
  if NebbieDash._guiCreated then
    setBorderRight(width)
    NebbieDash.positionGUI()
  end
  cecho("<green>[NebbieDash] Larghezza pannello impostata a " .. width .. ".\n")
end

function NebbieDash.cmdSetItemLen(lenStr)
  local len = tonumber(lenStr)
  if not len or len < 10 or len > 300 then
    cecho("<orange>[NebbieDash] Uso: nitemlen <numero tra 10 e 300> (attuale: " .. NebbieDash.itemMaxLen .. ")\n")
    return
  end
  NebbieDash.itemMaxLen = len
  NebbieDash.refreshDashboard()
  cecho("<green>[NebbieDash] Lunghezza max descrizione oggetto impostata a " .. len .. ".\n")
end

function NebbieDash.cmdSetSpellWarn(ticksStr)
  local ticks = tonumber(ticksStr)
  if not ticks or ticks < 0 or ticks > 999 then
    cecho("<orange>[NebbieDash] Uso: nspellwarn <numero tra 0 e 999> (attuale: " .. NebbieDash.spellWarnTicks .. ")\n")
    return
  end
  NebbieDash.spellWarnTicks = ticks
  NebbieDash.refreshDashboard()
  cecho("<green>[NebbieDash] Soglia colore rosso spell impostata a " .. ticks .. " tick.\n")
end

function NebbieDash.refreshDashboard()
  if not NebbieDash._guiCreated or NebbieDash._guiHidden then return end
  NebbieDash.refreshSpeedwalkPanel()
  local name = NebbieDash.currentChar
  clearWindow("NebbieDashEquip")
  clearWindow("NebbieDashSpells")
  if not name then
    cecho("NebbieDashEquip", "<grey>Nessun personaggio rilevato.\n")
    cecho("NebbieDashSpells", "<grey>Nessun personaggio rilevato.\n")
    return
  end
  local data = NebbieDash.getCharData(name)

  cecho("NebbieDashEquip", "<cyan><b>Equip — " .. name .. "</b>\n")
  if not (data.eqUpdated) then
    cecho("NebbieDashEquip", "<grey>(mai sincronizzato — esegui <yellow>neq<grey> o <yellow>nresync<grey>)\n")
  end
  -- NOTA: mostriamo esattamente gli slot riportati dal gioco (numero +
  -- posizione letti dalla riga stessa), nell'ordine in cui il gioco li
  -- numera. NON inventiamo una lista fissa di "tutti gli slot possibili":
  -- il numero da solo non e' un identificatore affidabile della posizione
  -- (bug osservato — vedi LOG.md, "conteggio slot sbagliato"). Se serve
  -- anche l'elenco degli slot NON occupati, va chiesto all'utente da dove
  -- prenderlo (il gioco potrebbe non riportarli affatto in `eq`).
  local slots = data.eq or {}
  local indices = {}
  for i in pairs(slots) do table.insert(indices, i) end
  table.sort(indices)
  if #indices == 0 then
    cecho("NebbieDashEquip", "<grey>(nessun oggetto — esegui <yellow>neq<grey> o <yellow>nresync<grey>)\n")
  end
  for _, i in ipairs(indices) do
    local entry = slots[i]
    local location = (entry and entry.location) or "?"
    local item = NebbieDash.truncate((entry and entry.item) or "?", NebbieDash.itemMaxLen)
    cecho("NebbieDashEquip", string.format("<grey>[%2d] <white>%s\n     <green>%s\n", i, location, item))
  end

  cecho("NebbieDashSpells", "<cyan><b>Spell attivi — " .. name .. "</b>\n")
  if data.spells and #data.spells > 0 then
    local prefix = data.castPrefix or "c"
    for _, s in ipairs(data.spells) do
      -- Cliccabile per rilanciare: usa il comando (cast/recall/mind) impostato
      -- per questo personaggio con `nclass` (default "cast"). Colore
      -- verde/rosso in base ai tick residui ALL'ULTIMA SINCRONIZZAZIONE (non
      -- e' un conto alla rovescia in tempo reale, vedi nota su spellWarnTicks).
      local ticks = tonumber(s.ticks) or 0
      local color = ticks <= NebbieDash.spellWarnTicks and "<red>" or "<green>"
      cechoLink("NebbieDashSpells", color .. s.name,
        string.format("NebbieDash.cmdQuickCast(%q, %q)", prefix, s.name),
        "Clicca per rilanciare: " .. s.name, true)
      cecho("NebbieDashSpells", string.format(" %s%s tick\n", color, tostring(s.ticks)))
    end
  else
    cecho("NebbieDashSpells", "<grey>(nessuno — esegui <yellow>nattrib<grey> o <yellow>nresync<grey>)\n")
  end
end

function NebbieDash.refreshSpeedwalkPanel()
  if not NebbieDash._guiCreated or NebbieDash._guiHidden then return end
  clearWindow("NebbieDashSpeedwalks")
  cecho("NebbieDashSpeedwalks", "<cyan><b>Speedwalk</b>\n")
  if #NebbieDash.speedwalks == 0 then
    cecho("NebbieDashSpeedwalks",
      "<grey>(nessuno — scrivili in " .. NebbieDash.speedwalkPath() .. " poi digita <yellow>nspeedwalks<grey>)\n")
    return
  end
  for i, entry in ipairs(NebbieDash.speedwalks) do
    cechoLink("NebbieDashSpeedwalks", "<cyan>" .. entry.desc,
      string.format("NebbieDash.runSpeedwalk(%d)", i),
      "Clicca per andare: " .. entry.desc .. " (" .. entry.dirString .. ")", true)
    cecho("NebbieDashSpeedwalks", string.format(" <grey>%s\n", entry.dirString))
  end
end

function NebbieDash.updateVitalsDisplay()
  -- Placeholder minimo: la release 1 si concentra su equip/spell (R5/R11-R12);
  -- una vera barra HP/Mana/Move e' rimandata a una fase successiva (fuori dal
  -- gap risolto ora) e va progettata separatamente se richiesta.
end

-- ---------------------------------------------------------------------------
-- Installazione trigger (una volta sola per boot)
-- ---------------------------------------------------------------------------
function NebbieDash.installTriggers()
  if NebbieDash._triggersInstalled then return end
  NebbieDash._promptTrig = tempTrigger(" M: ", [[NebbieDash.onPromptLine()]])
  NebbieDash._eqOpenTrig = tempTrigger("Stai usando:", [[NebbieDash.startEqCapture()]])
  NebbieDash._attribOpenTrig = tempTrigger("Spells attivi", [[NebbieDash.startAttribCapture()]])
  NebbieDash._eqLineTrig = tempRegexTrigger("^", [[NebbieDash.onEqCaptureLine()]])
  NebbieDash._attribLineTrig = tempRegexTrigger("^", [[NebbieDash.onAttribCaptureLine()]])
  if NebbieDash._eqLineTrig then pcall(disableTrigger, NebbieDash._eqLineTrig) end
  if NebbieDash._attribLineTrig then pcall(disableTrigger, NebbieDash._attribLineTrig) end
  if type(registerAnonymousEventHandler) == "function" then
    registerAnonymousEventHandler("sysConnectionEvent", "NebbieDash.onConnectionEvent")
    registerAnonymousEventHandler("sysWindowResizeEvent", "NebbieDash.onWindowResize")
  end
  NebbieDash._triggersInstalled = true
end

-- Ridisegna il pannello quando la finestra principale (o i bordi) cambiano
-- dimensione — senza questo handler positionGUI() viene chiamata solo alla
-- creazione iniziale e il layout resta "congelato" a qualunque dimensione
-- avesse la finestra in quel momento (bug osservato: ridimensionare Mudlet
-- non aggiornava i pannelli). tempTimer(0, ...) perche' la geometria di Qt
-- non e' ancora aggiornata nello stesso istante dell'evento (vedi
-- MUDLET-WIKI-NOTES.md, nota su autowrap/resize).
function NebbieDash.onWindowResize(_, _, _)
  tempTimer(0, [[NebbieDash.positionGUI()]])
end

-- ---------------------------------------------------------------------------
-- Boot (agganciato a sysLoadEvent — NON eseguito incondizionatamente al parse
-- dello script, a differenza del codice legacy — vedi LOG.md/RECOMMENDATION.md)
-- ---------------------------------------------------------------------------
function NebbieDash.boot()
  NebbieDash.loadStore()
  NebbieDash.loadSpeedwalks()
  NebbieDash.installTriggers()
  NebbieDash.initGUI()
  NebbieDash._mainLoaded = true
  cecho("<green>[NebbieDash] v" .. NebbieDash.version .. " pronto. Usa <yellow>nresync<green> dopo il login.\n")
end

function NebbieDash.runFix()
  NebbieDash._triggersInstalled = false
  NebbieDash.boot()
  cecho("<green>[NebbieDash] nfix completato.\n")
end
