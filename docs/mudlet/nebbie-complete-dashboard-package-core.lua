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

local PKG_VER = "1.15.10"
local PKG_MPACKAGE_URL =
  "https://raw.githubusercontent.com/wizardmorgan/nebbietest/mudlet/docs/mudlet/nebbie-complete-dashboard-package.mpackage"

local _prevPkgVer = NebbieDash and NebbieDash._loadedVer
if NebbieDash and _prevPkgVer == PKG_VER and NebbieDash._mainLoaded then
  return
end
if NebbieDash and _prevPkgVer and _prevPkgVer ~= PKG_VER then
  NebbieDash._mainLoaded = false
  NebbieDash._lastBootTime = nil
end

NebbieDash = NebbieDash or {}
NebbieDash.version = PKG_VER
NebbieDash._loadedVer = PKG_VER
NebbieDash._upgradeFromVer = (_prevPkgVer and _prevPkgVer ~= PKG_VER) and _prevPkgVer or nil
NebbieDash.package = "nebbie-complete-dashboard-package"

-- ---------------------------------------------------------------------------
-- Elenco canonico delle posizioni indossabili note (21, da REQUIREMENTS.md
-- §5/M4, output reale `eq`), in un ordine di visualizzazione fisso. Usato per
-- mostrare anche gli slot NON occupati ("(vuoto)") — l'occupazione si decide
-- confrontando il TESTO della posizione con quello letto dalla riga `eq`
-- reale (mai il numero di slot del gioco, che e' solo un contatore
-- progressivo sugli oggetti indossati, non un identificatore di posizione:
-- vedi bug corretto in LOG.md, "conteggio slot sbagliato").
-- NebbieDash.EQ_SLOTS e' un alias mantenuto per compatibilita' con
-- migrateStore() (dati salvati da versioni precedenti, indicizzati per
-- numero, mai per etichetta).
-- ---------------------------------------------------------------------------
NebbieDash.EQ_SLOT_ORDER = {
  "sul dito destro",
  "sul dito sinistro",
  "intorno al collo",
  "intorno al collo",
  "sul corpo",
  "in testa",
  "sulle gambe",
  "ai piedi",
  "sulle mani",
  "sulle braccia",
  "come scudo",
  "intorno al corpo",
  "intorno alla vita",
  "al polso destro",
  "al polso sinistro",
  "impugnato",
  "tenuto",
  "sulla schiena",
  "all'orecchio destro",
  "all'orecchio sinistro",
  "davanti agli occhi",
}
NebbieDash.EQ_SLOTS = NebbieDash.EQ_SLOT_ORDER
-- Slot aggiuntivo indicato dall'utente ma non ancora osservato/confermato in
-- un output reale di `eq`: tenuto nascosto di default (nclanslot per
-- attivarlo) per non mostrare "(vuoto)" su una posizione che potrebbe non
-- esistere per tutti i personaggi/classi.
NebbieDash.EQ_SLOT_CLAN = "simbolo del clan"
NebbieDash.showClanSlot = false

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
    -- Versioni precedenti (< 1.7.0) salvavano solo data.spells (lista delle
    -- spell attive all'ultima sincronizzazione, sostituita ad ogni attrib).
    -- Costruisce da questa il nuovo elenco cumulativo/persistente
    -- (knownSpellOrder) e lo stato attivo separato (activeSpells), senza
    -- perdere le spell gia' note da installazioni precedenti.
    if type(data.spells) == "table" and not data.knownSpellOrder then
      data.knownSpellOrder = {}
      data.activeSpells = {}
      for _, s in ipairs(data.spells) do
        if s.name then
          table.insert(data.knownSpellOrder, s.name)
          data.activeSpells[s.name] = s.ticks
        end
      end
    end
    if type(data.weapons) ~= "table" then
      data.weapons = {}
    end
  end
end

function NebbieDash.saveStore()
  if not NebbieDash.persistEnabled then return end
  pcall(function() table.save(NebbieDash.storePath(), NebbieDash.chars) end)
end

function NebbieDash.uiStorePath()
  local home = (type(getMudletHomeDir) == "function" and getMudletHomeDir()) or "."
  return home .. "/nebbie-dash-ui.lua"
end

function NebbieDash.loadUiStore()
  NebbieDash.uiState = NebbieDash.uiState or { speedwalkSectionCollapsed = {} }
  local path = NebbieDash.uiStorePath()
  if type(io.exists) == "function" and io.exists(path) then
    pcall(function() table.load(path, NebbieDash.uiState) end)
  end
  NebbieDash.uiState.speedwalkSectionCollapsed = NebbieDash.uiState.speedwalkSectionCollapsed or {}
  local gr = NebbieDash.uiState.guiRatios
  if type(gr) == "table" and type(gr.spells) == "number" then
    NebbieDash.guiRatios = NebbieDash.guiRatios or {}
    NebbieDash.guiRatios.spells = math.max(0.1, math.min(0.9, gr.spells))
  end
  if type(gr) == "table" and type(gr.equip) == "number" then
    NebbieDash.guiRatios = NebbieDash.guiRatios or {}
    NebbieDash.guiRatios.equip = math.max(0.1, math.min(0.9, gr.equip))
  end
end

function NebbieDash.persistGuiRatios()
  NebbieDash.uiState = NebbieDash.uiState or {}
  NebbieDash.uiState.guiRatios = {
    spells = NebbieDash.guiRatios and NebbieDash.guiRatios.spells,
    equip = NebbieDash.guiRatios and NebbieDash.guiRatios.equip,
  }
  NebbieDash.saveUiStore()
end

function NebbieDash.saveUiStore()
  if not NebbieDash.persistEnabled then return end
  pcall(function() table.save(NebbieDash.uiStorePath(), NebbieDash.uiState or {}) end)
end

function NebbieDash.isSpeedwalkSectionCollapsed(sectionKey)
  local t = (NebbieDash.uiState and NebbieDash.uiState.speedwalkSectionCollapsed) or {}
  return t[sectionKey] == true
end

function NebbieDash.toggleSpeedwalkSection(itemIndex)
  local item = (NebbieDash.speedwalkItems or {})[itemIndex]
  if not item or item.kind ~= "section" then return end
  NebbieDash.uiState = NebbieDash.uiState or { speedwalkSectionCollapsed = {} }
  NebbieDash.uiState.speedwalkSectionCollapsed[item.key] =
    not NebbieDash.isSpeedwalkSectionCollapsed(item.key)
  NebbieDash.saveUiStore()
  NebbieDash.refreshSpeedwalkPanel()
end

function NebbieDash.getCharData(name)
  NebbieDash.chars = NebbieDash.chars or {}
  if not NebbieDash.chars[name] then
    NebbieDash.chars[name] = { eq = {}, knownSpellOrder = {}, activeSpells = {}, weapons = {}, lastSeen = nil }
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
  -- Ogni volta che si (ri)diventa questo personaggio, le spell "conosciute"
  -- tornano tutte rosse (non confermate) finche' non si rilancia `attrib`:
  -- richiesto esplicitamente dall'utente, per non fidarsi di uno stato
  -- attivo potenzialmente vecchio dopo un cambio di personaggio (le durate
  -- residue mostrate prima non erano un conto alla rovescia in tempo
  -- reale, quindi diventerebbero presto inattendibili).
  data.activeSpells = {}
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
  -- IMPORTANTE (bug segnalato dall'utente): prima di questo fix, `currentChar`
  -- restava impostato al PERSONAGGIO PRECEDENTE finche' non arrivava un nuovo
  -- prompt — e un prompt arriva solo DOPO che invii un comando al gioco. Se
  -- lanciavi uno spell su te stesso (o cliccavi qualcosa nel pannello) subito
  -- dopo esserti riconnesso con un personaggio diverso, ma PRIMA di inviare
  -- un qualsiasi altro comando, il bersaglio/i dati usati erano ancora quelli
  -- del vecchio personaggio, senza alcun avviso. Ora invece il pannello
  -- mostra chiaramente "nessun personaggio rilevato" finche' non arriva un
  -- prompt fresco, cosi' non si rischia piu' di agire sul personaggio
  -- sbagliato senza accorgersene.
  NebbieDash.currentChar = nil
  NebbieDash._awaitingPromptAfterConnect = true
  NebbieDash.refreshDashboard()
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

-- Prompt immortale/builder (es. Sirio): "Sirio R1000 [On//60]>>" — confermato
-- dall'utente 2026-09-21. Il trigger " M:" non matcha mai questo formato, quindi
-- nbatch (che attendeva onPromptLine) andava in timeout anche con prompt visibile.
function NebbieDash.parseImmortalPromptLine(text)
  if not text or text == "" then return nil end
  local name = text:match("^(%S+)%s+R%d+%s+%[[^%]]+%]%s*>>%s*$")
  if not name then return nil end
  return { name = name, immortal = true }
end

function NebbieDash.isAnyPromptLine(text)
  return NebbieDash.parsePromptLine(text) or NebbieDash.parseImmortalPromptLine(text)
      or (text and text:match("^>>%s*$") and { name = NebbieDash.currentChar or "?" })
end

function NebbieDash.onPromptLine()
  local text = line
  if (not text or text == "") and type(getCurrentLine) == "function" then
    text = getCurrentLine()
  end
  local parsed = NebbieDash.parsePromptLine(text or "")
  if not parsed then
    parsed = NebbieDash.parseImmortalPromptLine(text or "")
  end
  if not parsed then return end
  NebbieDash.stats = parsed
  NebbieDash.setCurrentCharacter(parsed.name, false)
  NebbieDash._awaitingPromptAfterConnect = false
  NebbieDash.updateVitalsDisplay()
  if NebbieDash._batch and NebbieDash._batch.active and NebbieDash._batch.awaitingOutput then
    NebbieDash.onBatchPrompt(text)
  end
end

-- ---------------------------------------------------------------------------
-- Capture "eq" (D2-C / D2-0) — state machine attivata/disattivata con
-- enableTrigger()/disableTrigger() invece di un trigger multiline con margine
-- fisso, per gestire un numero variabile di righe (incluso il word-wrap, M6).
-- ---------------------------------------------------------------------------
-- Timeout di sicurezza (secondi) per chiudere una cattura eq/attrib rimasta
-- "aperta" (nessuna riga vuota/prompt riconosciuta dopo l'ultima riga utile:
-- puo' succedere se il formato reale del blocco di gioco ha una variante non
-- prevista). Senza questo timeout una cattura bloccata resterebbe attiva per
-- sempre e i dati non verrebbero MAI aggiornati anche rilanciando eq/attrib
-- (bug segnalato: "gli spell rimangono rossi anche dopo attrib").
NebbieDash.captureTimeoutSec = 4

-- Watchdog "a inattivita'": ad ogni riga rilevante (vedi onEqCaptureLine)
-- cap.activity viene incrementato; se allo scadere del timeout non e'
-- cambiato da quando e' stato programmato, la cattura viene chiusa. Se
-- invece sono arrivate altre righe nel frattempo, si riprogramma un altro
-- giro: cosi' una risposta lenta del gioco non taglia la cattura a meta',
-- ma una cattura davvero bloccata si chiude comunque entro pochi secondi
-- dall'ultima riga ricevuta.
function NebbieDash.armEqWatchdog(gen)
  tempTimer(NebbieDash.captureTimeoutSec, function()
    local cap = NebbieDash._eqCapture
    if not cap or NebbieDash._eqCaptureGen ~= gen then return end
    if cap.activity ~= cap.watchedActivity then
      cap.watchedActivity = cap.activity
      NebbieDash.armEqWatchdog(gen)
    else
      NebbieDash.finishEqCapture()
    end
  end)
end

function NebbieDash.startEqCapture()
  NebbieDash._eqCaptureGen = (NebbieDash._eqCaptureGen or 0) + 1
  local gen = NebbieDash._eqCaptureGen
  NebbieDash._eqCapture = { slots = {}, lastSlot = nil, activity = 0, watchedActivity = 0 }
  if NebbieDash._eqLineTrig then
    pcall(enableTrigger, NebbieDash._eqLineTrig)
  end
  NebbieDash.armEqWatchdog(gen)
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
  cap.activity = cap.activity + 1
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
-- Stesso watchdog "a inattivita'" usato per la cattura eq — vedi
-- armEqWatchdog() per la spiegazione. Necessario anche qui: e' la causa piu'
-- probabile del bug "gli spell rimangono rossi anche dopo attrib" se il
-- formato reale del blocco finale (riga vuota/prompt) ha una variante non
-- prevista dal parser (formato non ancora confermato al 100%, vedi
-- REQUIREMENTS.md M5): senza watchdog la cattura resterebbe aperta per
-- sempre e data.spells non verrebbe mai sostituito.
function NebbieDash.armAttribWatchdog(gen)
  tempTimer(NebbieDash.captureTimeoutSec, function()
    local cap = NebbieDash._attribCapture
    if not cap or NebbieDash._attribCaptureGen ~= gen then return end
    if cap.activity ~= cap.watchedActivity then
      cap.watchedActivity = cap.activity
      NebbieDash.armAttribWatchdog(gen)
    else
      NebbieDash.finishAttribCapture()
    end
  end)
end

function NebbieDash.startAttribCapture()
  NebbieDash._attribCaptureGen = (NebbieDash._attribCaptureGen or 0) + 1
  local gen = NebbieDash._attribCaptureGen
  NebbieDash._attribCapture = { spells = {}, activity = 0, watchedActivity = 0 }
  if NebbieDash._attribLineTrig then
    pcall(enableTrigger, NebbieDash._attribLineTrig)
  end
  NebbieDash.armAttribWatchdog(gen)
end

-- Elenco spell "conosciute" per un personaggio (2026-08-10): a differenza
-- di prima (dove attrib SOSTITUIVA data.spells, facendo sparire dal
-- pannello qualunque spell non piu' attiva), ora si mantiene un elenco
-- CUMULATIVO e persistente di tutti i nomi di spell mai visti attivi per
-- quel personaggio (data.knownSpellOrder), cosi' restano sempre visibili e
-- cliccabili per rilanciarle, anche da spente. Lo stato "attivo ora" resta
-- separato (data.activeSpells, nome -> tick) e viene AZZERATO ogni volta
-- che si cambia personaggio (vedi setCurrentCharacter), cosi' al rientro su
-- un personaggio tutte le sue spell conosciute appaiono rosse finche' non
-- si rilancia `attrib` per confermare quali sono davvero ancora attive.
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
  data.knownSpellOrder = data.knownSpellOrder or {}
  local known = {}
  for _, n in ipairs(data.knownSpellOrder) do known[n] = true end
  local activeMap = {}
  for _, s in ipairs(cap.spells) do
    activeMap[s.name] = s.ticks
    if not known[s.name] then
      table.insert(data.knownSpellOrder, s.name)
      known[s.name] = true
    end
  end
  data.activeSpells = activeMap
  data.spellsUpdated = os.time()
  NebbieDash.saveStore()
  NebbieDash.refreshDashboard()
  cecho("<green>[NebbieDash] Spell attivi aggiornati (" .. tostring(#cap.spells) .. " attive, " ..
    tostring(#data.knownSpellOrder) .. " conosciute in totale).\n")
end

function NebbieDash.onAttribCaptureLine()
  local cap = NebbieDash._attribCapture
  if not cap then return end
  cap.activity = cap.activity + 1
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
NebbieDash.spellShortcuts = {}
NebbieDash.castSpellPanelList = {}
NebbieDash._spellShortcutTrigs = {}

-- Alias riservati (comandi Nebbie + prefissi c/r/m): non usabili come shortcut spell.
NebbieDash.SHORTCUT_RESERVED = {
  c = true, r = true, m = true,
  nhelp = true, nfix = true, neq = true, nattrib = true, nresync = true, ngui = true,
  nlayout = true, nchar = true, nclass = true, nfont = true, nwidth = true, nitemlen = true,
  nspellwarn = true, nspeedwalks = true, nspeeddelay = true, nheights = true, nleftheights = true,
  nclanslot = true, nloot = true, nautoloot = true, nautosplit = true, nsplit = true,
  nautostand = true, nautodisarm = true, nautofeed = true, nhungermacros = true, nitemkeywords = true,
  nforgetspell = true, nbatch = true, nbatchreload = true, nbatchverify = true,
  nidentbatch = true, nidentbatchreload = true, nspellaliases = true, nspellaliasesreload = true,
  npackageupdate = true,
}

function NebbieDash.spellShortcutsPath()
  local home = (type(getMudletHomeDir) == "function" and getMudletHomeDir()) or "."
  return home .. "/nebbie-spell-shortcuts.txt"
end

function NebbieDash.castSpellsPath()
  local home = (type(getMudletHomeDir) == "function" and getMudletHomeDir()) or "."
  return home .. "/nebbie-cast-spells.txt"
end

function NebbieDash.ensureSpellShortcutsFile()
  local path = NebbieDash.spellShortcutsPath()
  if type(io.exists) == "function" and io.exists(path) then return end
  local f = io.open(path, "w")
  if not f then return end
  f:write(
    "# Shortcut globali profilo — stile zMUD: digiti 'he bob' -> cast 'heal' bob\n" ..
    "# Il comando (cast/recall/mind) viene da nclass del personaggio attivo.\n" ..
    "# Formato: shortcut = nome spell completo (abbreviazione lato server ok nel gioco)\n" ..
    "# Dopo modifiche: nspellaliasesreload\n" ..
    "#\n" ..
    "he = heal\n" ..
    "ts = true sight\n"
  )
  f:close()
end

function NebbieDash.ensureCastSpellsFile()
  local path = NebbieDash.castSpellsPath()
  if type(io.exists) == "function" and io.exists(path) then return end
  local f = io.open(path, "w")
  if not f then return end
  f:write(
    "# Spell cliccabili nel pannello (solo quelle che TU puoi lanciare su te stesso).\n" ..
    "# Una riga = un nome spell (come in identify/attrib). NON mettere buff altrui\n" ..
    "# (es. shield da MU se non sei chierico). Dopo modifiche: nspellaliasesreload\n" ..
    "#\n" ..
    "heal\n" ..
    "true sight\n"
  )
  f:close()
end

function NebbieDash.parseSpellShortcutLine(line2)
  local key, spell = line2:match("^(%S+)%s*=%s*(.+)$")
  if key and spell then
    key = key:match("^%s*(.-)%s*$")
    spell = spell:match("^%s*(.-)%s*$")
    return key, spell
  end
  key, spell = line2:match("^(%S+)%s+(.+)$")
  if key and spell then
    return key:match("^%s*(.-)%s*$"), spell:match("^%s*(.-)%s*$")
  end
  return nil, nil
end

function NebbieDash.loadSpellCastConfig()
  NebbieDash.ensureSpellShortcutsFile()
  NebbieDash.ensureCastSpellsFile()
  NebbieDash.spellShortcuts = {}
  local path = NebbieDash.spellShortcutsPath()
  local f = io.open(path, "r")
  if f then
    for rawLine in f:lines() do
      local line2 = rawLine:match("^%s*(.-)%s*$")
      if line2 ~= "" and line2:sub(1, 1) ~= "#" then
        local key, spell = NebbieDash.parseSpellShortcutLine(line2)
        if key and spell and key ~= "" and spell ~= "" then
          local lk = key:lower()
          if NebbieDash.SHORTCUT_RESERVED[lk] then
            cecho("<orange>[NebbieDash] Shortcut ignorato (riservato): " .. key .. "\n")
          else
            NebbieDash.spellShortcuts[lk] = { key = key, spell = spell }
          end
        end
      end
    end
    f:close()
  end

  NebbieDash.castSpellPanelList = {}
  local panelPath = NebbieDash.castSpellsPath()
  local pf = io.open(panelPath, "r")
  if pf then
    for rawLine in pf:lines() do
      local line2 = rawLine:match("^%s*(.-)%s*$")
      if line2 ~= "" and line2:sub(1, 1) ~= "#" and not line2:find("=") then
        table.insert(NebbieDash.castSpellPanelList, line2)
      end
    end
    pf:close()
  end
end

function NebbieDash.getCastPrefixForCharacter(charName)
  if not charName then return "c" end
  return NebbieDash.getCharData(charName).castPrefix or "c"
end

-- Invia sempre con bersaglio esplicito (PG attivo se omesso). cast/recall/mind
-- da nclass del personaggio attivo (persistente per PG).
function NebbieDash.sendCastSpell(spellName, target, prefixOverride)
  spellName = (spellName or ""):match("^%s*(.-)%s*$")
  if spellName == "" then return false end
  local charName = NebbieDash.currentChar
  if not charName then
    cecho("<orange>[NebbieDash] Nessun personaggio attivo — attendi il prompt o usa nchar.\n")
    return false
  end
  target = (target or ""):match("^%s*(.-)%s*$")
  if target == "" then
    target = charName
  end
  local prefix = prefixOverride or NebbieDash.getCastPrefixForCharacter(charName)
  local cmdWord = NebbieDash.CAST_PREFIX[prefix]
  if not cmdWord then return false end
  send(cmdWord .. " '" .. spellName .. "' " .. target, false)
  return true
end

-- c/r/m <spell> [bersaglio] — bersaglio con spazio; se omesso = PG attivo.
-- Con esattamente DUE parole totali: prima=spell, seconda=bersaglio (es. c heal bob).
-- Con una parola o tre+ parole: tutto il testo e' il nome spell, bersaglio=PG attivo
-- (per multi-parola + altri usa shortcut: wor bob).
function NebbieDash.parseQuickCastArgument(argument)
  argument = (argument or ""):match("^%s*(.-)%s*$") or ""
  if argument == "" then return nil, nil end
  if argument:match("%S+%s+%S+%s+") then
    return argument, nil
  end
  local w1, w2 = argument:match("^(%S+)%s+(%S+)$")
  if w1 and w2 then
    return w1, w2
  end
  return argument, nil
end

function NebbieDash.cmdQuickCast(prefix, argument, target)
  local cmdWord = NebbieDash.CAST_PREFIX[(prefix or ""):lower()]
  if not cmdWord then return end
  argument = (argument or ""):match("^%s*(.-)%s*$")
  if argument == "" then
    cecho("<orange>[NebbieDash] Uso: " .. prefix .. " <spell> [bersaglio] — bersaglio default: PG attivo\n")
    return
  end
  if not target then
    local spellPart, targetPart = NebbieDash.parseQuickCastArgument(argument)
    argument = spellPart
    target = targetPart
  end
  NebbieDash.sendCastSpell(argument, target, (prefix or ""):lower())
end

function NebbieDash.cmdSpellShortcut(shortcutKey, targetArg)
  local lk = (shortcutKey or ""):lower()
  local entry = NebbieDash.spellShortcuts[lk]
  if not entry then return end
  NebbieDash.sendCastSpell(entry.spell, targetArg, nil)
end

function NebbieDash.regexEscapePattern(s)
  return (s or ""):gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end

function NebbieDash.teardownSpellShortcutTriggers()
  for _, id in ipairs(NebbieDash._spellShortcutTrigs or {}) do
    if id then pcall(function() killTrigger(id) end) end
  end
  NebbieDash._spellShortcutTrigs = {}
end

function NebbieDash.installSpellShortcutTriggers()
  NebbieDash.teardownSpellShortcutTriggers()
  if type(tempRegexTrigger) ~= "function" then return end
  for lk, entry in pairs(NebbieDash.spellShortcuts or {}) do
    local esc = NebbieDash.regexEscapePattern(entry.key)
    local id1 = tempRegexTrigger("^" .. esc .. "$",
      string.format([[NebbieDash.cmdSpellShortcut(%q)]], lk))
    local id2 = tempRegexTrigger("^" .. esc .. "%s+(.+)$",
      string.format([[NebbieDash.cmdSpellShortcut(%q, matches[2])]], lk))
    table.insert(NebbieDash._spellShortcutTrigs, id1)
    table.insert(NebbieDash._spellShortcutTrigs, id2)
  end
end

function NebbieDash.cmdListSpellAliases()
  cecho("<cyan><b>Shortcut spell (globali)</b> — file: " .. NebbieDash.spellShortcutsPath() .. "\n")
  local n = 0
  for _, entry in pairs(NebbieDash.spellShortcuts or {}) do
    n = n + 1
    cecho(string.format("<yellow>%-12s<white> -> %s\n", entry.key, entry.spell))
  end
  if n == 0 then
    cecho("<grey>(nessuno — aggiungi righe tipo 'he = heal' nel file)\n")
  end
  cecho("<cyan><b>Spell pannello (self-cast)</b> — file: " .. NebbieDash.castSpellsPath() .. "\n")
  if #(NebbieDash.castSpellPanelList or {}) == 0 then
    cecho("<grey>(nessuna — una spell per riga nel file)\n")
  else
    for _, spell in ipairs(NebbieDash.castSpellPanelList) do
      cecho("<white>  " .. spell .. "\n")
    end
  end
  local name = NebbieDash.currentChar
  if name then
    local p = NebbieDash.getCastPrefixForCharacter(name)
    cecho("<grey>nclass per " .. name .. ": <yellow>" .. p ..
      "<grey> (" .. NebbieDash.CAST_PREFIX[p] .. ")\n")
  end
end

function NebbieDash.cmdReloadSpellAliases()
  NebbieDash.loadSpellCastConfig()
  NebbieDash.installSpellShortcutTriggers()
  NebbieDash.refreshDashboard()
  cecho("<green>[NebbieDash] Shortcut/pannello spell ricaricati: " ..
    tostring((function()
      local c = 0
      for _ in pairs(NebbieDash.spellShortcuts) do c = c + 1 end
      return c
    end)()) .. " shortcut, " .. #NebbieDash.castSpellPanelList .. " nel pannello.\n")
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
NebbieDash.speedwalkItems = {}
-- speedwalk: un invio istantaneo di tutte le direzioni una via l'altra
-- rischia di perdere passi se il gioco impone un tempo minimo (\"lag\") tra
-- un movimento e l'altro. Regolabile con nspeeddelay se serve un valore
-- diverso.
NebbieDash.speedwalkDelay = 0.35
NebbieDash.weaponSwapDelay = 0.5
NebbieDash._weaponSwapBusy = false

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
    "# Una riga per speedwalk, formato (due varianti):\n" ..
    "#   (descrizione cliccabile) direzioni separate da virgola\n" ..
    "#   direzioni separate da virgola (descrizione cliccabile)\n" ..
    "# Sezione collassabile nel pannello (obbligatorio il prefisso >>):\n" ..
    "#   (>> titolo sezione)\n" ..
    "# Le righe percorso sotto restano in quella sezione fino alla prossima (>> ...).\n" ..
    "# Nota opzionale: stessa riga dopo le direzioni \"... (testo nota)\" oppure riga\n" ..
    "# separata con sole parentesi \"(testo nota)\" (NON usare >> sulle note).\n" ..
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

function NebbieDash.stripUtf8Bom(s)
  if not s or #s < 3 then return s end
  if s:byte(1) == 0xEF and s:byte(2) == 0xBB and s:byte(3) == 0xBF then
    return s:sub(4)
  end
  return s
end

function NebbieDash.isSpeedwalkDirToken(part)
  part = (part or ""):match("^%s*(.-)%s*$"):lower()
  if part == "" then return false end
  local dirs = {
    n = true, ne = true, nw = true, s = true, se = true, sw = true,
    e = true, w = true, u = true, d = true,
  }
  local _, rest = part:match("^(%d+)(.+)$")
  if rest then part = rest end
  return dirs[part] == true
end

function NebbieDash.isSpeedwalkSectionMarkerLine(line2)
  return line2 and line2:match("^%(%s*>%s*>") ~= nil and line2:match("^%(.+%)$") ~= nil
end

function NebbieDash.parseSpeedwalkSectionLine(rawLine)
  local line2 = NebbieDash.stripUtf8Bom(rawLine):match("^%s*(.-)%s*$")
  if line2 == "" or line2:sub(1, 1) == "#" then return nil end
  local title = line2:match("^%(%s*>%s*>%s*(.-)%)$")
  if not title then return nil end
  title = title:match("^%s*(.-)%s*$")
  if title == "" then return nil end
  return { kind = "section", title = title, key = title }
end

function NebbieDash.parseSpeedwalkParenNoteLine(rawLine)
  local line2 = NebbieDash.stripUtf8Bom(rawLine):match("^%s*(.-)%s*$")
  if line2 == "" or line2:sub(1, 1) == "#" then return nil end
  if NebbieDash.isSpeedwalkSectionMarkerLine(line2) then return nil end
  local note = line2:match("^%((.-)%)$")
  if not note then return nil end
  note = note:match("^%s*(.-)%s*$")
  if note == "" then return nil end
  return note
end

function NebbieDash.splitSpeedwalkTrailingNote(dirPart)
  dirPart = (dirPart or ""):match("^%s*(.-)%s*$")
  if dirPart == "" then return dirPart, nil end
  local body, note = dirPart:match("^(.-)%s+%(([^)]*)%)$")
  if not body or not note then return dirPart, nil end
  body = body:match("^%s*(.-)%s*$")
  local norm = NebbieDash.normalizeSpeedwalkDirString(body)
  if #NebbieDash.parseSpeedwalkDirs(norm) > 0 then
    return body, note:match("^%s*(.-)%s*$")
  end
  return dirPart, nil
end

function NebbieDash.parseSpeedwalkLine(rawLine)
  local line2 = NebbieDash.stripUtf8Bom(rawLine):match("^%s*(.-)%s*$")
  if line2 == "" or line2:sub(1, 1) == "#" then return nil end
  if NebbieDash.isSpeedwalkSectionMarkerLine(line2) then return nil end
  local note = nil
  local desc, dirString = line2:match("^%((.-)%)%s+(.+)$")
  if desc then
    dirString, note = NebbieDash.splitSpeedwalkTrailingNote(dirString)
  else
    dirString, desc = line2:match("^(.+)%s+%((.-)%)$")
    if desc and dirString and not line2:match("^%(") then
      note = nil
    end
  end
  if not desc or not dirString then return nil end
  dirString = NebbieDash.normalizeSpeedwalkDirString(dirString)
  local steps = NebbieDash.parseSpeedwalkDirs(dirString)
  if #steps == 0 then return nil end
  return {
    desc = desc:match("^%s*(.-)%s*$"),
    dirString = dirString,
    steps = steps,
    note = note,
  }
end

function NebbieDash.normalizeSpeedwalkDirString(dirString)
  local tokens = {}
  for rawChunk in (dirString or ""):gmatch("[^,]+") do
    local chunk = rawChunk:match("^%s*(.-)%s*$")
    if chunk ~= "" then
      if chunk:find("%s") then
        local parts = {}
        for part in chunk:gmatch("%S+") do table.insert(parts, part) end
        local allShortDirs = #parts > 1
        for _, part in ipairs(parts) do
          if not NebbieDash.isSpeedwalkDirToken(part) then
            allShortDirs = false
            break
          end
        end
        if allShortDirs then
          for _, part in ipairs(parts) do table.insert(tokens, part) end
        else
          table.insert(tokens, chunk)
        end
      else
        table.insert(tokens, chunk)
      end
    end
  end
  return table.concat(tokens, ",")
end

-- Motivo umano se una riga non vuota/commento non e' diventata uno speedwalk (per nspeedwalks).
function NebbieDash.speedwalkLineSkipReason(rawLine)
  local line2 = NebbieDash.stripUtf8Bom(rawLine or ""):match("^%s*(.-)%s*$")
  if line2 == "" or line2:sub(1, 1) == "#" then return nil end
  if NebbieDash.parseSpeedwalkSectionLine(rawLine) then return nil end
  if NebbieDash.parseSpeedwalkParenNoteLine(rawLine) then return nil end
  local desc, dirString = line2:match("^%((.-)%)%s+(.+)$")
  if desc then
    dirString = NebbieDash.splitSpeedwalkTrailingNote(dirString)
  elseif not line2:match("^%(") then
    dirString, desc = line2:match("^(.+)%s+%((.-)%)$")
  end
  if not desc or not dirString then
    return "formato: (descrizione) dir1,dir2,... oppure dir1,dir2,... (descrizione)"
  end
  dirString = NebbieDash.normalizeSpeedwalkDirString(dirString)
  if #NebbieDash.parseSpeedwalkDirs(dirString) == 0 then
    return "nessuna direzione valida (usa virgole tra i passi, es. u,n,2w,n)"
  end
  return nil
end

function NebbieDash.loadSpeedwalks()
  NebbieDash.ensureSpeedwalkFile()
  NebbieDash.speedwalks = {}
  NebbieDash.speedwalkItems = {}
  NebbieDash.speedwalkLoadSkipped = {}
  local path = NebbieDash.speedwalkPath()
  local f = io.open(path, "r")
  if not f then
    NebbieDash.speedwalkLoadOpenFailed = true
    return false
  end
  NebbieDash.speedwalkLoadOpenFailed = false
  local lineNum = 0
  local currentSectionKey = nil
  for rawLine in f:lines() do
    lineNum = lineNum + 1
    local parenNote = NebbieDash.parseSpeedwalkParenNoteLine(rawLine)
    if parenNote then
      local last = NebbieDash.speedwalkItems[#NebbieDash.speedwalkItems]
      if last and last.kind == "walk" then
        last.note = last.note and (last.note .. " " .. parenNote) or parenNote
      end
    else
      local section = NebbieDash.parseSpeedwalkSectionLine(rawLine)
      if section then
        currentSectionKey = section.key
        table.insert(NebbieDash.speedwalkItems, section)
      else
        local entry = NebbieDash.parseSpeedwalkLine(rawLine)
        if entry then
          entry.kind = "walk"
          entry.walkIndex = #NebbieDash.speedwalks + 1
          entry.sectionKey = currentSectionKey
          table.insert(NebbieDash.speedwalks, {
            desc = entry.desc,
            dirString = entry.dirString,
            steps = entry.steps,
            note = entry.note,
          })
          table.insert(NebbieDash.speedwalkItems, entry)
        else
          local reason = NebbieDash.speedwalkLineSkipReason(rawLine)
          if reason then
            table.insert(NebbieDash.speedwalkLoadSkipped, {
              line = lineNum,
              reason = reason,
              preview = NebbieDash.truncate(rawLine:match("^%s*(.-)%s*$"), 72),
            })
          end
        end
      end
    end
  end
  f:close()
  return true
end

function NebbieDash.cmdReloadSpeedwalks()
  local path = NebbieDash.speedwalkPath()
  local ok = NebbieDash.loadSpeedwalks()
  NebbieDash.refreshDashboard()
  if not ok then
    cecho("<red>[NebbieDash] Impossibile leggere " .. path .. " — controlla permessi o percorso.\n")
    cecho("<grey>Il file va editato nel profilo Mudlet (getMudletHomeDir()), non nella cartella del repo.\n")
    return
  end
  cecho("<green>[NebbieDash] Speedwalk ricaricati: " .. #NebbieDash.speedwalks .. " — " .. path .. "\n")
  for _, item in ipairs(NebbieDash.speedwalkItems or {}) do
    if item.kind == "section" then
      cecho("<grey>  [sezione] <yellow>" .. item.title .. "\n")
    elseif item.kind == "walk" then
      cecho("<grey>    <cyan>" .. item.desc .. "<grey> (" .. #item.steps .. " passi)\n")
    end
  end
  local skipped = NebbieDash.speedwalkLoadSkipped or {}
  if #skipped > 0 then
    cecho("<orange>[NebbieDash] " .. #skipped .. " riga/e ignorata/e (non contano nel pannello):\n")
    for _, item in ipairs(skipped) do
      cecho("<orange>  riga " .. item.line .. ": " .. item.reason .. " — " .. item.preview .. "\n")
    end
  end
  if #NebbieDash.speedwalks == 0 and #skipped == 0 then
    cecho("<grey>Aggiungi righe attive (non commentate) tipo: (nome percorso) u,3w,n,s\n")
  end
end

-- Reinstalla/aggiorna il package dal branch mudlet su GitHub (stesso URL usato da GMCP Client.GUI).
-- Mudlet Package Manager mostra la versione da config.lua nel .mpackage: va rigenerato ad ogni release.
function NebbieDash.cmdPackageUpdate()
  local url = PKG_MPACKAGE_URL
  cecho("<yellow>[NebbieDash] Aggiornamento package da GitHub (branch mudlet)...\n")
  cecho("<grey>" .. url .. "\n")
  if type(installPackage) ~= "function" then
    cecho("<red>installPackage non disponibile — scarica il .mpackage a mano da GitHub.\n")
    return
  end
  local ok, err = pcall(installPackage, url)
  if not ok then
    cecho("<red>installPackage fallito: " .. tostring(err) .. "\n")
    return
  end
  cecho("<green>Download avviato. Al termine controlla Package Manager (versione = " ..
    NebbieDash.version .. ") o digita <yellow>nfix<green>.\n")
end

-- Ripetizione generica di un comando digitato direttamente al prompt, es.
-- ".4s" invia "s" quattro volte (equivalente a scrivere "s" e premere invio
-- 4 volte), con la stessa pausa tra un invio e l'altro gia' usata per gli
-- speedwalk (NebbieDash.speedwalkDelay) — stesso motivo: non perdere passi
-- per lag di movimento. Funziona con qualunque comando, non solo direzioni
-- (es. ".3 kill goblin"). Limite massimo di sicurezza a 99 ripetizioni per
-- evitare di intasare la coda comandi per un refuso (es. ".400s").
function NebbieDash.cmdRepeat(countStr, cmdStr)
  local count = tonumber(countStr)
  cmdStr = (cmdStr or ""):match("^%s*(.-)%s*$")
  if not count or count < 1 or cmdStr == "" then return end
  if count > 99 then
    cecho("<orange>[NebbieDash] Troppe ripetizioni richieste (" .. count .. "), limitate a 99.\n")
    count = 99
  end
  for i = 1, count do
    tempTimer(NebbieDash.speedwalkDelay * (i - 1), function() send(cmdStr, false) end)
  end
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
-- Larghezza dei due bordi (equip a sinistra, spell+speedwalk a destra),
-- ciascuna con la propria modalita' auto/manuale — vedi autoWidthEquip /
-- autoWidthRight piu' sotto.
NebbieDash.guiWidthEquip = 260
NebbieDash.guiWidthRight = 320
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
-- Analogo a itemMaxLen ma per l'anteprima delle direzioni nel pannello
-- speedwalk (il comando eseguito al click usa comunque la lista completa,
-- solo l'anteprima a schermo viene troncata).
NebbieDash.speedwalkPreviewMaxLen = 80
NebbieDash.speedwalkNoteMaxLen = 80
-- Limite caratteri per l'auto-larghezza colonna destra (evita che liste speedwalk
-- lunghe mangino tutta la finestra principale).
NebbieDash.autoWidthRightMaxChars = 44
-- Larghezza automatica (default per entrambe le colonne): ogni pannello si
-- allarga/restringe da solo in base al contenuto piu' lungo attualmente
-- visibile, cosi' non "sparisce" niente oltre il bordo dello schermo.
-- `nwidth equip|right <numero>` disattiva l'automatismo per quella colonna
-- e fissa una larghezza manuale; `nwidth equip|right auto` lo riattiva.
NebbieDash.autoWidthEquip = true
NebbieDash.autoWidthRight = true
NebbieDash.autoWidthMin = 180

function NebbieDash.truncate(s, maxLen)
  if not s or #s <= maxLen then return s end
  return s:sub(1, math.max(1, maxLen - 1)) .. "…"
end

-- A capo morbido per miniconsole (prefere spazi prima del limite).
function NebbieDash.wrapPanelText(s, maxLen)
  maxLen = maxLen or 80
  local lines = {}
  local rest = (s or ""):match("^%s*(.-)%s*$")
  while rest and #rest > maxLen do
    local chunk = rest:sub(1, maxLen)
    local breakAt = chunk:reverse():find(" ", 1, true)
    if breakAt and breakAt <= 24 then
      local cut = maxLen - breakAt + 1
      table.insert(lines, rest:sub(1, cut):match("^%s*(.-)%s*$"))
      rest = rest:sub(cut + 1):match("^%s*(.-)%s*$")
    else
      table.insert(lines, chunk)
      rest = rest:sub(maxLen + 1):match("^%s*(.-)%s*$")
    end
  end
  if rest and rest ~= "" then table.insert(lines, rest) end
  return lines
end

-- Costruisce l'elenco di righe da mostrare nel pannello equip: una riga per
-- ogni posizione nota in EQ_SLOT_ORDER (piu' EQ_SLOT_CLAN se showClanSlot),
-- marcata come vuota se nessun oggetto catturato da `eq` ha una posizione
-- corrispondente. Il confronto e' sul TESTO della posizione, case-insensitive
-- (mai sul numero di slot del gioco — vedi nota su EQ_SLOT_ORDER). Se due
-- posizioni condividono la stessa etichetta (es. le due collane), gli
-- oggetti catturati vengono assegnati in ordine di apparizione: non c'e' modo
-- di sapere quale dei due slot "identici" corrisponda a quale, ma nessun
-- oggetto viene perso o duplicato.
function NebbieDash.buildEquipRows(data)
  local pool = {}
  for _, entry in pairs(data.eq or {}) do
    local key = ((entry and entry.location) or "?"):lower():match("^%s*(.-)%s*$")
    pool[key] = pool[key] or {}
    table.insert(pool[key], entry)
  end
  local positions = {}
  for _, label in ipairs(NebbieDash.EQ_SLOT_ORDER) do table.insert(positions, label) end
  if NebbieDash.showClanSlot then table.insert(positions, NebbieDash.EQ_SLOT_CLAN) end

  local rows = {}
  for _, label in ipairs(positions) do
    local bucket = pool[label:lower()]
    local matched = bucket and table.remove(bucket, 1)
    table.insert(rows, { location = label, item = matched and matched.item or nil, empty = not matched })
  end
  -- Posizioni riportate dal gioco ma non presenti nell'elenco canonico sopra
  -- (mai osservate finora): mostrate comunque, per non nascondere dati reali.
  for _, bucket in pairs(pool) do
    for _, entry in ipairs(bucket) do
      table.insert(rows, { location = entry.location, item = entry.item, empty = false, unknown = true })
    end
  end
  return rows
end

function NebbieDash.guiVisible()
  return NebbieDash._guiCreated == true and NebbieDash._guiHidden ~= true
end

-- Proporzione verticale della colonna destra tra Spell attivi (in alto) e
-- Speedwalk (in basso, il resto). Analogamente, "equip" e' la proporzione
-- della colonna sinistra tra Equip (in alto) e Armi (in basso, il resto) —
-- richiesta esplicita dell'utente (2026-08-10): "devo avere sotto l'equip
-- una lista di armi".
NebbieDash.guiRatios = { spells = 0.62, equip = 0.6 }
-- Altezza (px) delle barre divisorie visibili tra Spell attivi/Speedwalk e
-- tra Equip/Armi.
NebbieDash.dividerPx = 4
-- Le 4 miniconsole con testo (font/ricaricamento contenuto). Le barre
-- divisorie sono elementi separati (nessun testo, solo colore) — vedi
-- ALL_GUI_ELEMENTS per mostra/nascondi che deve includerle.
NebbieDash.GUI_WINDOWS = { "NebbieDashEquip", "NebbieDashWeapons", "NebbieDashSpells", "NebbieDashSpeedwalks" }
NebbieDash.ALL_GUI_ELEMENTS = {
  "NebbieDashEquip", "NebbieDashWeapons", "NebbieDashSpells", "NebbieDashSpeedwalks",
  "NebbieDashDivider", "NebbieDashDividerLeft",
}

function NebbieDash.initGUI()
  if NebbieDash._guiCreated then return end
  setBorderLeft(NebbieDash.guiWidthEquip)
  setBorderRight(NebbieDash.guiWidthRight)
  createMiniConsole("NebbieDashEquip", 0, 0, NebbieDash.guiWidthEquip, 0)
  createMiniConsole("NebbieDashWeapons", 0, 0, NebbieDash.guiWidthEquip, 0)
  createMiniConsole("NebbieDashSpells", 0, 0, NebbieDash.guiWidthRight, 0)
  createMiniConsole("NebbieDashSpeedwalks", 0, 0, NebbieDash.guiWidthRight, 0)
  if type(enableScrollBar) == "function" then
    enableScrollBar("NebbieDashSpeedwalks", true)
  end
  -- Barre divisorie (richiesta esplicita: "manca una barra tra gli spell
  -- attivi e gli speedwalk", stesso principio applicato ora anche tra Equip
  -- e Armi). Sono label, non miniconsole: servono solo a marcare
  -- visivamente il confine tra due pannelli, non contengono testo.
  createLabel("NebbieDashDivider", 0, 0, NebbieDash.guiWidthRight, NebbieDash.dividerPx, 1)
  createLabel("NebbieDashDividerLeft", 0, 0, NebbieDash.guiWidthEquip, NebbieDash.dividerPx, 1)
  for _, win in ipairs(NebbieDash.GUI_WINDOWS) do
    setMiniConsoleFontSize(win, NebbieDash.fontSize)
    -- Una miniconsole appena creata ha uno sfondo di default (grigio, widget
    -- Qt non ancora disegnato) finche' non le si assegna esplicitamente un
    -- colore e non ci si scrive dentro almeno una volta: senza questo il
    -- pannello resta grigio anche a install riuscita (bug osservato, vedi
    -- docs/mudlet/analysis/LOG.md).
    setBackgroundColor(win, 15, 15, 15, 255)
  end
  setBackgroundColor("NebbieDashDivider", 90, 90, 100, 255)
  setBackgroundColor("NebbieDashDividerLeft", 90, 90, 100, 255)
  NebbieDash._guiCreated = true
  NebbieDash.positionGUI()
  NebbieDash.refreshDashboard()
  -- getMainWindowSize() puo' non essere ancora affidabile nello stesso istante
  -- in cui la GUI viene creata (geometria Qt non ancora assestata all'avvio
  -- del profilo): riesegui il posizionamento un istante dopo per evitare che
  -- un pannello resti a altezza 0 (visto come "una sola barra" a schermo).
  tempTimer(0, [[NebbieDash.positionGUI()]])
end

-- Calcola quanti caratteri servono per mostrare senza andare a capo tutto il
-- contenuto del pannello equip (colonna sinistra): titolo + una riga per ogni
-- posizione nota (occupata o "(vuoto)").
function NebbieDash.computeEquipMaxChars(data)
  local maxChars = 20
  local name = NebbieDash.currentChar
  if name then
    maxChars = math.max(maxChars, #("Equip — " .. name))
    maxChars = math.max(maxChars, #("Armi — " .. name))
  end
  if data and data.eqUpdated then
    for _, row in ipairs(NebbieDash.buildEquipRows(data)) do
      if row.empty then
        maxChars = math.max(maxChars, #row.location + 14) -- "[NN] " + " (vuoto)"
      else
        local item = NebbieDash.truncate(row.item or "?", NebbieDash.itemMaxLen)
        maxChars = math.max(maxChars, #row.location + 5, #item + 5)
      end
    end
  end
  if data then
    for _, w in ipairs(data.weapons or {}) do
      local label = NebbieDash.truncate(w.displayName or w.keyword or "?", NebbieDash.itemMaxLen)
      maxChars = math.max(maxChars, #label + #(" -- " .. (w.type or "?")))
    end
  end
  return maxChars
end

-- Come sopra ma per la colonna destra (Spell attivi + Speedwalk insieme,
-- condividono la stessa larghezza di bordo).
function NebbieDash.computeRightMaxChars(data)
  local maxChars = 20
  local name = NebbieDash.currentChar
  if name then
    maxChars = math.max(maxChars, #("Spell attivi — " .. name))
  end
  if data then
    for _, spellName in ipairs(NebbieDash.castSpellPanelList or {}) do
      maxChars = math.max(maxChars, #(spellName or "") + #(" -- tick"))
    end
  end
  for _, item in ipairs(NebbieDash.speedwalkItems or {}) do
    if item.kind == "section" then
      maxChars = math.max(maxChars, #item.title + 3)
    elseif item.kind == "walk" then
      local preview = NebbieDash.truncate(item.dirString, NebbieDash.speedwalkPreviewMaxLen)
      maxChars = math.max(maxChars, #item.desc + 1 + #preview)
    end
  end
  if not NebbieDash.speedwalkItems or #NebbieDash.speedwalkItems == 0 then
    for _, entry in ipairs(NebbieDash.speedwalks) do
      local preview = NebbieDash.truncate(entry.dirString, NebbieDash.speedwalkPreviewMaxLen)
      maxChars = math.max(maxChars, #entry.desc + 1 + #preview)
    end
  end
  return maxChars
end

-- Applica la larghezza automatica (se attiva) ad ognuna delle due colonne
-- indipendentemente, senza mai superare il 60% della larghezza reale della
-- finestra di Mudlet — cosi' nessun pannello puo' mai "uscire" dallo schermo.
function NebbieDash.applyAutoWidth()
  if not NebbieDash._guiCreated then return end
  local name = NebbieDash.currentChar
  local data = name and NebbieDash.getCharData(name) or nil
  local charW = calcFontSize(NebbieDash.fontSize) or 8
  local mainW = select(1, getMainWindowSize()) or 1024
  local maxTotal = math.floor(mainW * 0.6)

  if NebbieDash.autoWidthEquip then
    local w = math.floor(charW * (NebbieDash.computeEquipMaxChars(data) + 3))
    w = math.max(NebbieDash.autoWidthMin, math.min(w, maxTotal))
    if w ~= NebbieDash.guiWidthEquip then
      NebbieDash.guiWidthEquip = w
      setBorderLeft(w)
    end
  end
  if NebbieDash.autoWidthRight then
    local chars = NebbieDash.computeRightMaxChars(data) + 3
    local cap = NebbieDash.autoWidthRightMaxChars or 44
    local w = math.floor(charW * math.min(chars, cap))
    w = math.max(NebbieDash.autoWidthMin, math.min(w, maxTotal))
    if w ~= NebbieDash.guiWidthRight then
      NebbieDash.guiWidthRight = w
      setBorderRight(w)
    end
  end
end

function NebbieDash.positionGUI()
  if not NebbieDash._guiCreated then return end
  local w, h = getMainWindowSize()
  w = w or 800
  h = h or 600
  -- Colonna sinistra: equip in alto, barra divisoria, armi in basso.
  local usableHLeft = math.max(0, h - NebbieDash.dividerPx)
  local equipH = math.floor(usableHLeft * NebbieDash.guiRatios.equip)
  local weaponsH = usableHLeft - equipH
  moveWindow("NebbieDashEquip", 0, 0)
  resizeWindow("NebbieDashEquip", NebbieDash.guiWidthEquip, equipH)
  moveWindow("NebbieDashDividerLeft", 0, equipH)
  resizeWindow("NebbieDashDividerLeft", NebbieDash.guiWidthEquip, NebbieDash.dividerPx)
  moveWindow("NebbieDashWeapons", 0, equipH + NebbieDash.dividerPx)
  resizeWindow("NebbieDashWeapons", NebbieDash.guiWidthEquip, weaponsH)
  -- Colonna destra: spell attivi in alto, barra divisoria, speedwalk in basso.
  local x = math.max(0, w - NebbieDash.guiWidthRight)
  local usableH = math.max(0, h - NebbieDash.dividerPx)
  local spellsH = math.floor(usableH * NebbieDash.guiRatios.spells)
  local speedwalkH = usableH - spellsH
  moveWindow("NebbieDashSpells", x, 0)
  resizeWindow("NebbieDashSpells", NebbieDash.guiWidthRight, spellsH)
  moveWindow("NebbieDashDivider", x, spellsH)
  resizeWindow("NebbieDashDivider", NebbieDash.guiWidthRight, NebbieDash.dividerPx)
  moveWindow("NebbieDashSpeedwalks", x, spellsH + NebbieDash.dividerPx)
  resizeWindow("NebbieDashSpeedwalks", NebbieDash.guiWidthRight, speedwalkH)
  NebbieDash.positionHelpButton()
end

-- ---------------------------------------------------------------------------
-- Tasto "Comandi" — richiesto esplicitamente ("tasto custom nell'interfaccia
-- di mudlet che mostri una finestra di testo con tutti i comandi"). Mudlet
-- non offre un modo affidabile per creare/verificare da script una vera voce
-- di toolbar nativa (quella si configura solo via editor pacchetti/XML
-- "Action", non testabile qui senza un'istanza Mudlet reale): usiamo invece
-- una label fluttuante ancorata in cima allo schermo, cliccabile come un
-- pulsante, sempre visibile (anche con `ngui` disattivato) — vedi
-- MUDLET-WIKI-NOTES.md per i dettagli.
-- ---------------------------------------------------------------------------
NebbieDash.helpButtonW = 90
NebbieDash.helpButtonH = 22

function NebbieDash.initHelpButton()
  if NebbieDash._helpButtonCreated then return end
  createLabel("NebbieDashHelpBtn", 0, 0, NebbieDash.helpButtonW, NebbieDash.helpButtonH, 1)
  setBackgroundColor("NebbieDashHelpBtn", 60, 60, 90, 255)
  cecho("NebbieDashHelpBtn", "<center><white><b>? Comandi</b>")
  setLabelClickCallback("NebbieDashHelpBtn", "NebbieDash.toggleHelp")
  setLabelToolTip("NebbieDashHelpBtn", "Mostra/nascondi l'elenco dei comandi NebbieDash")
  NebbieDash._helpButtonCreated = true
  NebbieDash.positionHelpButton()
end

function NebbieDash.positionHelpButton()
  if not NebbieDash._helpButtonCreated then return end
  local w = select(1, getMainWindowSize()) or 800
  -- Centrato in orizzontale sull'area di testo centrale (tra bordo sinistro
  -- equip e bordo destro spell/speedwalk), cosi' non si sovrappone mai ai
  -- nostri pannelli anche quando sono ridimensionati.
  local leftW = NebbieDash._guiCreated and NebbieDash.guiWidthEquip or 0
  local rightW = NebbieDash._guiCreated and NebbieDash.guiWidthRight or 0
  local centerAreaW = math.max(0, w - leftW - rightW)
  local x = leftW + math.max(0, math.floor((centerAreaW - NebbieDash.helpButtonW) / 2))
  moveWindow("NebbieDashHelpBtn", x, 2)
  if NebbieDash._helpWinCreated then
    NebbieDash.positionHelpWindow()
  end
end

function NebbieDash.positionHelpWindow()
  local w, h = getMainWindowSize()
  w, h = w or 800, h or 600
  local winW = math.min(600, math.max(300, math.floor(w * 0.6)))
  local winH = math.min(500, math.max(200, math.floor(h * 0.6)))
  moveWindow("NebbieDashHelpWin", math.floor((w - winW) / 2), NebbieDash.helpButtonH + 6)
  resizeWindow("NebbieDashHelpWin", winW, winH)
end

-- Testo statico dei comandi disponibili. Va aggiornato ogni volta che si
-- aggiunge/rinomina un alias in build-nebbie-complete-dashboard-package.py
-- (stessa regola gia' seguita per USAGE.md/CHANGELOG.md).
NebbieDash.HELP_TEXT = {
  { "c / r / m <spell> [bersaglio]", "Lancia spell (nclass PG); senza bersaglio = PG attivo." },
  { "<shortcut> [bersaglio]", "Alias globali da nebbie-spell-shortcuts.txt (stile zMUD)." },
  { "nspellaliases", "Elenco shortcut + spell nel pannello self-cast." },
  { "nspellaliasesreload", "Ricarica nebbie-spell-shortcuts.txt e nebbie-cast-spells.txt." },
  { "neq", "Mostra l'equip corrente (dati salvati)." },
  { "nattrib", "Mostra le spell attive correnti (dati salvati)." },
  { "nresync", "Invia eq + attrib al gioco per risincronizzare i pannelli." },
  { "nfix", "Ricrea la GUI da zero in caso di problemi visivi." },
  { "ngui", "Mostra/nascondi tutti i pannelli." },
  { "nlayout", "Ripristina larghezze/font/proporzioni di default." },
  { "nchar <nome>", "Forza manualmente il personaggio attivo." },
  { "nclass <cast|recall|mind>", "Imposta il comando di lancio per il personaggio attivo." },
  { "nfont <6-24>", "Imposta la dimensione del font dei pannelli." },
  { "nwidth [equip|right] <n|auto>", "Imposta/auto la larghezza di una colonna." },
  { "nheights <percentuale spell>", "Imposta la proporzione verticale spell/speedwalk (destra)." },
  { "nleftheights <percentuale equip>", "Imposta la proporzione verticale equip/armi (sinistra)." },
  { "nitemlen <n>", "Lunghezza massima delle descrizioni oggetti in equip." },
  { "nspellwarn <tick>", "Sotto questa soglia di tick una spell appare rossa." },
  { "nspeedwalks", "Ricarica il file di configurazione degli speedwalk." },
  { "nspeeddelay <secondi>", "Ritardo tra un comando e l'altro in uno speedwalk." },
  { "npackageupdate", "Scarica e reinstalla il dashboard dal branch mudlet su GitHub (come GMCP Client.GUI)." },
  { "nclanslot <on|off>", "Mostra/nascondi lo slot 22 (simbolo del clan)." },
  { "nloot", "Prende le monete dal cadavere presente (normale o pile of bones)." },
  { "nautoloot <on|off>", "Attiva/disattiva il loot automatico alla fine di ogni combattimento." },
  { "nautosplit <on|off>", "Attiva/disattiva lo split automatico col gruppo dopo ogni loot riuscito." },
  { "nsplit <numero>", "Divide manualmente un importo col gruppo (equivalente a 'split')." },
  { "nautostand <on|off>", "Attiva/disattiva il rialzarsi automatico ('stand') dopo una caduta." },
  { "nautodisarm <on|off>", "Attiva/disattiva il recupero automatico dell'arma dopo un disarmo." },
  { ".<numero><comando>", "Ripete il comando N volte, es. '.4s' invia 's' quattro volte." },
  { "nautofeed <on|off>", "Attiva/disattiva la macro automatica fame/sete (per personaggio, vedi file macro)." },
  { "nhungermacros", "Ricarica le macro fame/sete dal file di configurazione." },
  { "nitemkeywords", "Ricarica le parole chiave per oggetto (condivise tra tutti i personaggi) dal file di configurazione." },
  { "nforgetspell <nome>", "Rimuove una spell memorizzata per errore dall'elenco del personaggio attivo." },
  { "nbatch [nome-toon]", "Esegue comandi admin da CSV (profilo Sirio; inizia con nchar Sirio)." },
  { "nbatchreload", "Ricarica nebbie-batch-commands.txt e nebbie-batch-items.csv." },
  { "nbatchverify [toon] [data]", "Verifica log batch vs CSV (es. nbatchverify GreenBlade 2026-09-21)." },
  { "nidentbatch [nome-toon]", "Identify batch: oload $3, stat/identify/junk con $o (keyword oload)." },
  { "nidentbatch resume [nome-toon]", "Riprende identify batch saltando righe gia' nel CSV di oggi." },
  { "nidentbatchreload", "Ricarica nebbie-ident-batch-commands.txt e nebbie-batch-items.csv." },
  { "(pannello Armi)", "Clicca un'arma: rem borsa, get, rem vecchia, wield, put, wear (come nebbie-play-all)." },
  { "identify <arma>", "(comando di gioco) Rileva il tipo di danno (slash/blunt/pierce) dell'arma per il pannello." },
  { "nhelp", "Mostra/nascondi questa finestra." },
}

function NebbieDash.buildHelpText()
  local lines = { "<cyan><b>NebbieDash — comandi disponibili</b>", "" }
  for _, entry in ipairs(NebbieDash.HELP_TEXT) do
    table.insert(lines, string.format("<yellow>%-32s<white> %s", entry[1], entry[2]))
  end
  table.insert(lines, "")
  table.insert(lines, "<grey>Documentazione completa: docs/mudlet/analysis/USAGE.md")
  return lines
end

function NebbieDash.toggleHelp()
  if not NebbieDash._helpWinCreated then
    createMiniConsole("NebbieDashHelpWin", 0, 0, 10, 10)
    setBackgroundColor("NebbieDashHelpWin", 10, 10, 20, 255)
    setMiniConsoleFontSize("NebbieDashHelpWin", NebbieDash.fontSize)
    NebbieDash._helpWinCreated = true
    NebbieDash.positionHelpWindow()
    clearWindow("NebbieDashHelpWin")
    for _, l in ipairs(NebbieDash.buildHelpText()) do
      cecho("NebbieDashHelpWin", l .. "\n")
    end
    cechoLink("NebbieDashHelpWin", "<orange>[chiudi]", "NebbieDash.toggleHelp()", "Chiudi questa finestra", true)
    cecho("NebbieDashHelpWin", "\n")
    showWindow("NebbieDashHelpWin")
    NebbieDash._helpWinVisible = true
    return
  end
  if NebbieDash._helpWinVisible then
    hideWindow("NebbieDashHelpWin")
    NebbieDash._helpWinVisible = false
  else
    NebbieDash.positionHelpWindow()
    showWindow("NebbieDashHelpWin")
    NebbieDash._helpWinVisible = true
  end
end

function NebbieDash.toggleGUI()
  if not NebbieDash._guiCreated then
    NebbieDash.initGUI()
    NebbieDash._guiHidden = false
  else
    NebbieDash._guiHidden = not NebbieDash._guiHidden
    if NebbieDash._guiHidden then
      for _, win in ipairs(NebbieDash.ALL_GUI_ELEMENTS) do hideWindow(win) end
      setBorderLeft(0)
      setBorderRight(0)
    else
      for _, win in ipairs(NebbieDash.ALL_GUI_ELEMENTS) do showWindow(win) end
      setBorderLeft(NebbieDash.guiWidthEquip)
      setBorderRight(NebbieDash.guiWidthRight)
      NebbieDash.positionGUI()
    end
  end
  NebbieDash.refreshDashboard()
end

function NebbieDash.resetLayout()
  NebbieDash.guiWidthEquip = 260
  NebbieDash.guiWidthRight = 320
  NebbieDash.fontSize = 11
  NebbieDash.autoWidthEquip = true
  NebbieDash.autoWidthRight = true
  NebbieDash.guiRatios = { spells = 0.62, equip = 0.6 }
  if NebbieDash._guiCreated then
    for _, win in ipairs(NebbieDash.GUI_WINDOWS) do
      setMiniConsoleFontSize(win, NebbieDash.fontSize)
    end
    NebbieDash.refreshDashboard()
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

-- "nwidth equip 300", "nwidth right auto", ecc. Senza indicare la colonna
-- (es. "nwidth 300" o "nwidth auto") agisce sulla colonna destra, per
-- compatibilita' con la sintassi usata prima di avere due colonne separate.
function NebbieDash.cmdSetWidth(argStr)
  argStr = argStr or ""
  local side, rest = argStr:match("^%s*(%S+)%s+(.-)%s*$")
  if not side then
    side, rest = "right", argStr:match("^%s*(.-)%s*$")
  end
  side = side:lower()
  local isEquip = (side == "equip" or side == "left" or side == "sinistra")
  local isRight = (side == "right" or side == "spell" or side == "spells" or side == "destra")
  if not isEquip and not isRight then
    cecho("<orange>[NebbieDash] Uso: nwidth <equip|right> <numero tra 150 e 900> oppure <yellow>nwidth <equip|right> auto\n")
    return
  end
  local label = isEquip and "equip (sinistra)" or "spell/speedwalk (destra)"

  if (rest or ""):lower():match("^auto$") then
    if isEquip then NebbieDash.autoWidthEquip = true else NebbieDash.autoWidthRight = true end
    NebbieDash.refreshDashboard()
    cecho("<green>[NebbieDash] Larghezza pannello " .. label .. ": automatica.\n")
    return
  end
  local width = tonumber(rest)
  if not width or width < 150 or width > 900 then
    cecho("<orange>[NebbieDash] Uso: nwidth <equip|right> <numero tra 150 e 900> oppure <yellow>nwidth <equip|right> auto\n")
    return
  end
  if isEquip then
    NebbieDash.autoWidthEquip = false
    NebbieDash.guiWidthEquip = width
    if NebbieDash._guiCreated then setBorderLeft(width) end
  else
    NebbieDash.autoWidthRight = false
    NebbieDash.guiWidthRight = width
    if NebbieDash._guiCreated then setBorderRight(width) end
  end
  if NebbieDash._guiCreated then NebbieDash.positionGUI() end
  cecho("<green>[NebbieDash] Larghezza pannello " .. label .. " impostata a " .. width .. " (manuale).\n")
end

-- Regola la ripartizione verticale della colonna destra tra Spell attivi e
-- Speedwalk (richiesta esplicita: "non riesco a ridimensionare manualmente
-- l'altezza delle sotto-colonne"). Non e' un trascinamento col mouse (la API
-- Lua di Mudlet non espone un modo affidabile per intercettare il drag su un
-- bordo tra due miniconsole), ma un comando che ottiene lo stesso risultato.
function NebbieDash.cmdSetHeights(pctStr)
  local pct = tonumber(pctStr)
  if not pct or pct < 10 or pct > 90 then
    cecho("<orange>[NebbieDash] Uso: nheights <percentuale tra 10 e 90> — quota per 'Spell attivi', il resto va a 'Speedwalk' (attuale: "
      .. math.floor(NebbieDash.guiRatios.spells * 100) .. "%)\n")
    return
  end
  NebbieDash.guiRatios.spells = pct / 100
  NebbieDash.persistGuiRatios()
  if NebbieDash._guiCreated then NebbieDash.positionGUI() end
  cecho("<green>[NebbieDash] Altezza 'Spell attivi' impostata al " .. pct .. "% (Speedwalk: " .. (100 - pct) .. "%).\n")
end

-- Come cmdSetHeights, ma per la colonna sinistra: quota per "Equip", il resto
-- va a "Armi".
function NebbieDash.cmdSetLeftHeights(pctStr)
  local pct = tonumber(pctStr)
  if not pct or pct < 10 or pct > 90 then
    cecho("<orange>[NebbieDash] Uso: nleftheights <percentuale tra 10 e 90> — quota per 'Equip', il resto va a 'Armi' (attuale: "
      .. math.floor(NebbieDash.guiRatios.equip * 100) .. "%)\n")
    return
  end
  NebbieDash.guiRatios.equip = pct / 100
  NebbieDash.persistGuiRatios()
  if NebbieDash._guiCreated then NebbieDash.positionGUI() end
  cecho("<green>[NebbieDash] Altezza 'Equip' impostata al " .. pct .. "% (Armi: " .. (100 - pct) .. "%).\n")
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

-- Rimuove manualmente una spell dall'elenco "conosciuto" del personaggio
-- attivo (richiesto esplicitamente, 2026-08-10: l'utente ha segnalato che,
-- passando da un personaggio all'altro, restavano visibili spell che quel
-- personaggio non puo' lanciare — es. "mirror images"/"shield" mai
-- realmente appartenenti a lui, probabilmente salvate per errore in una
-- sessione precedente al fix del cambio-personaggio del Round 13, e MAI
-- rimosse dall'elenco cumulativo perche' l'elenco "conosciuto" persistente
-- non si ripulisce mai da solo). Nessuna euristica per classe qui: e'
-- l'utente a sapere quali spell non gli appartengono, l'elenco delle spell
-- per classe non e' un dato che abbiamo/possiamo inventare.
function NebbieDash.cmdForgetSpell(argStr)
  local query = (argStr or ""):match("^%s*(.-)%s*$")
  local name = NebbieDash.currentChar
  if not name then
    cecho("<orange>[NebbieDash] Nessun personaggio attivo.\n")
    return
  end
  if query == "" then
    cecho("<orange>[NebbieDash] Uso: nforgetspell <nome spell> — rimuove una spell "
      .. "memorizzata per errore dall'elenco del personaggio attivo (es. nforgetspell mirror images).\n")
    return
  end
  local data = NebbieDash.getCharData(name)
  local matched = nil
  for i, s in ipairs(NebbieDash.castSpellPanelList or {}) do
    if s:lower() == query:lower() then
      matched = s
      table.remove(NebbieDash.castSpellPanelList, i)
      break
    end
  end
  if not matched then
    for i, s in ipairs(data.knownSpellOrder or {}) do
      if s:lower() == query:lower() then
        matched = s
        table.remove(data.knownSpellOrder, i)
        break
      end
    end
  end
  if not matched then
    cecho("<orange>[NebbieDash] '" .. query .. "' non e' nel pannello spell ne nell'elenco di " .. name .. ".\n")
    return
  end
  if data.activeSpells then data.activeSpells[matched] = nil end
  NebbieDash.saveStore()
  NebbieDash.refreshDashboard()
  cecho("<green>[NebbieDash] Rimossa '" .. matched .. "' (pannello/elenco). "
    .. "Aggiorna anche " .. NebbieDash.castSpellsPath() .. " se serve.\n")
end

-- ---------------------------------------------------------------------------
-- Scadenza spell in tempo reale (richiesto esplicitamente, 2026-08-10): fino
-- ad ora una spell diventava rossa solo al successivo `attrib` manuale. Con
-- questi trigger diventa rossa SUBITO al messaggio di scadenza reale, senza
-- aspettare che l'utente rilanci `attrib`. Testi REALI forniti dall'utente
-- (uno per spell, nessuno inventato). Esplicitamente ESCLUSO dall'utente:
-- "Senti i tuoi movimenti accellerare rapidamente." — e' la scadenza di
-- "slowness", un DEBUFF (rallentamento subito, non un buff lanciato da noi),
-- quindi non va trattato come le altre.
-- ---------------------------------------------------------------------------
NebbieDash.SPELL_EXPIRY_PATTERNS = {
  { text = "Non ti senti piu' cosi' invulnerabile.", spell = "sanctuary" },
  { text = "Perdi la tua armatura Divina.", spell = "armor" },
  { text = "Perdi l'aiuto Divino.", spell = "aid" },
  { text = "L'alone d'argento nei tuoi occhi scompare.", spell = "true sight" },
  { text = "Il globo di oscurita' che ti avvolgeva scompare.", spell = "darkness" },
}

function NebbieDash.onSpellExpiredLine(spellName)
  local name = NebbieDash.currentChar
  if not name then return end
  local data = NebbieDash.getCharData(name)
  if data.activeSpells and data.activeSpells[spellName] ~= nil then
    data.activeSpells[spellName] = nil
    NebbieDash.saveStore()
    NebbieDash.refreshDashboard()
  end
end

-- Mostra/nasconde lo slot 22 "simbolo del clan" (non ancora confermato in un
-- output reale di `eq` — vedi nota su EQ_SLOT_CLAN).
function NebbieDash.cmdSetClanSlot(argStr)
  local v = (argStr or ""):lower():match("^%s*(.-)%s*$")
  if v == "on" or v == "1" or v == "true" then
    NebbieDash.showClanSlot = true
  elseif v == "off" or v == "0" or v == "false" then
    NebbieDash.showClanSlot = false
  else
    cecho("<orange>[NebbieDash] Uso: nclanslot <on|off> (attuale: " .. (NebbieDash.showClanSlot and "on" or "off") .. ")\n")
    return
  end
  NebbieDash.refreshDashboard()
  cecho("<green>[NebbieDash] Slot 'simbolo del clan': " .. (NebbieDash.showClanSlot and "attivato" or "disattivato") .. ".\n")
end

function NebbieDash.refreshDashboard()
  if not NebbieDash._guiCreated or NebbieDash._guiHidden then return end
  NebbieDash.applyAutoWidth()
  NebbieDash.positionGUI()
  NebbieDash.refreshSpeedwalkPanel()
  local name = NebbieDash.currentChar
  clearWindow("NebbieDashEquip")
  clearWindow("NebbieDashWeapons")
  clearWindow("NebbieDashSpells")
  if not name then
    cecho("NebbieDashEquip", "<grey>Nessun personaggio rilevato.\n")
    cecho("NebbieDashWeapons", "<grey>Nessun personaggio rilevato.\n")
    cecho("NebbieDashSpells", "<grey>Nessun personaggio rilevato.\n")
    return
  end
  local data = NebbieDash.getCharData(name)

  cecho("NebbieDashEquip", "<cyan><b>Equip — " .. name .. "</b>\n")
  if not (data.eqUpdated) then
    cecho("NebbieDashEquip", "<grey>(mai sincronizzato — esegui <yellow>neq<grey> o <yellow>nresync<grey>)\n")
  else
    -- Una riga per ogni posizione nota (occupata o "(vuoto)") — vedi
    -- buildEquipRows(). Il numero mostrato tra parentesi quadre e' solo la
    -- posizione della riga nel NOSTRO elenco (per somigliare visivamente al
    -- testo di `eq` sul gioco, come richiesto), NON il numero di slot che
    -- riporta il gioco: quel numero e' solo un contatore progressivo sugli
    -- oggetti indossati, non un identificatore di posizione affidabile (vedi
    -- bug corretto in LOG.md, "conteggio slot sbagliato") e non viene mai
    -- usato per decidere quale oggetto va in quale riga.
    for idx, row in ipairs(NebbieDash.buildEquipRows(data)) do
      if row.empty then
        cecho("NebbieDashEquip", string.format("<grey>[%2d] %s (vuoto)\n", idx, row.location))
      else
        local item = NebbieDash.truncate(row.item or "?", NebbieDash.itemMaxLen)
        cecho("NebbieDashEquip", string.format("<grey>[%2d] <white>%s\n     <green>%s\n", idx, row.location, item))
      end
    end
  end

  cecho("NebbieDashWeapons", "<cyan><b>Armi — " .. name .. "</b>\n")
  if data.weapons and #data.weapons > 0 then
    -- Trova la keyword dell'arma attualmente impugnata (se nota) solo per
    -- evidenziarla in elenco — il cambio arma vero e proprio (nremWeapon)
    -- legge comunque lo slot "impugnato" al momento del click, non questo
    -- valore cacheato.
    local currentKeyword = NebbieDash.currentWieldedKeyword(data)
    for i, w in ipairs(data.weapons) do
      local label = NebbieDash.truncate(w.displayName or w.keyword or "?", NebbieDash.itemMaxLen)
      local typeLabel = w.type or "?"
      local isCurrent = currentKeyword ~= "" and NebbieDash.keywordsOverlap(currentKeyword, w.keyword or "")
      local nameColor = isCurrent and "<yellow>" or "<white>"
      cechoLink("NebbieDashWeapons", nameColor .. label,
        string.format("NebbieDash.cmdSwapWeapon(%d)", i),
        "Clicca per impugnare: " .. label, true)
      cecho("NebbieDashWeapons", string.format(" <grey>-- %s\n", typeLabel))
    end
  else
    cecho("NebbieDashWeapons", "<grey>(nessuna — si popola da sola quando impugni un'arma;\n"
      .. " esegui anche <yellow>identify<grey> sull'arma per rilevarne il tipo di danno)\n")
  end

  cecho("NebbieDashSpells", "<cyan><b>Spell attivi — " .. name .. "</b>\n")
  local panelSpells = NebbieDash.castSpellPanelList or {}
  if #panelSpells > 0 then
    local prefix = NebbieDash.getCastPrefixForCharacter(name)
    local activeSpells = data.activeSpells or {}
    for _, spellName in ipairs(panelSpells) do
      local activeTicks = activeSpells[spellName]
      local active = activeTicks ~= nil
      local ticks = active and (tonumber(activeTicks) or 0) or 0
      local color = (active and ticks > NebbieDash.spellWarnTicks) and "<green>" or "<red>"
      cechoLink("NebbieDashSpells", color .. spellName,
        string.format("NebbieDash.cmdQuickCast(%q, %q, %q)", prefix, spellName, name),
        "Clicca per lanciare su " .. name .. ": " .. spellName, true)
      local ticksLabel = active and tostring(ticks) or "-"
      cecho("NebbieDashSpells", string.format(" %s%s tick\n", color, ticksLabel))
    end
  else
    cecho("NebbieDashSpells", "<grey>(nessuna — elenca spell in " .. NebbieDash.castSpellsPath() ..
      " poi <yellow>nspellaliasesreload<grey>)\n")
  end
end

function NebbieDash.refreshSpeedwalkPanel()
  if not NebbieDash._guiCreated or NebbieDash._guiHidden then return end
  clearWindow("NebbieDashSpeedwalks")
  cecho("NebbieDashSpeedwalks", "<cyan><b>Speedwalk</b>\n")
  if #(NebbieDash.speedwalkItems or {}) == 0 and #NebbieDash.speedwalks == 0 then
    cecho("NebbieDashSpeedwalks",
      "<grey>(nessuno — scrivili in " .. NebbieDash.speedwalkPath() .. " poi digita <yellow>nspeedwalks<grey>)\n")
    return
  end
  for i, item in ipairs(NebbieDash.speedwalkItems or {}) do
    if item.kind == "section" then
      local collapsed = NebbieDash.isSpeedwalkSectionCollapsed(item.key)
      local icon = collapsed and "▶" or "▼"
      cechoLink("NebbieDashSpeedwalks", "<yellow><b>" .. icon .. " " .. item.title .. "</b>",
        string.format("NebbieDash.toggleSpeedwalkSection(%d)", i),
        (collapsed and "Espandi sezione" or "Collassa sezione") ..
          " — nel file: (>> " .. item.title .. ")", true)
      cecho("NebbieDashSpeedwalks", "\n")
    elseif item.kind == "walk" then
      if item.sectionKey and NebbieDash.isSpeedwalkSectionCollapsed(item.sectionKey) then
        -- nascosto finche' la sezione e' collassata
      else
        local preview = item.dirString or ""
        local dirLines = NebbieDash.wrapPanelText(preview, NebbieDash.speedwalkPreviewMaxLen)
        cechoLink("NebbieDashSpeedwalks", "<cyan>" .. item.desc,
          string.format("NebbieDash.runSpeedwalk(%d)", item.walkIndex),
          "Clicca per andare: " .. item.desc .. " (" .. preview .. ")", true)
        if #dirLines == 0 then
          cecho("NebbieDashSpeedwalks", "\n")
        elseif #dirLines == 1 then
          cecho("NebbieDashSpeedwalks", " <grey>" .. dirLines[1] .. "\n")
        else
          cecho("NebbieDashSpeedwalks", " <grey>" .. dirLines[1] .. "\n")
          for i = 2, #dirLines do
            cecho("NebbieDashSpeedwalks", "<grey>  " .. dirLines[i] .. "\n")
          end
        end
        if item.note and item.note ~= "" then
          for _, nline in ipairs(NebbieDash.wrapPanelText(item.note, NebbieDash.speedwalkNoteMaxLen)) do
            cecho("NebbieDashSpeedwalks", "<dark_grey>  // " .. nline .. "\n")
          end
        end
      end
    end
  end
end

function NebbieDash.updateVitalsDisplay()
  -- Placeholder minimo: la release 1 si concentra su equip/spell (R5/R11-R12);
  -- una vera barra HP/Mana/Move e' rimandata a una fase successiva (fuori dal
  -- gap risolto ora) e va progettata separatamente se richiesta.
end

-- ---------------------------------------------------------------------------
-- Loot (soldi dal cadavere) + split automatico col gruppo.
-- Prima automazione di gioco (oltre a equip/spell/speedwalk), richiesta
-- esplicitamente dall'utente con testi REALI copiati dal gioco (nessuna
-- regex qui e' inventata):
--   - `get all.coin corp` su un cadavere normale risponde con due righe, es.
--     "Prendi gold coins da il corpo di Il grande drago verde delle
--     foreste." poi "C'erano 100000 monete."; su un bersaglio senza
--     cadavere di quel tipo risponde "Non vedi nessun corp."
--   - `get all.coin pile` e' l'equivalente per i cadaveri di non-morti
--     ("pile of bones"/"dust pile bones", vedi fight.cpp), stessa dinamica
--     ("Non vedi nessun pile." se non c'e' nulla da quel nome).
--   - `group` risponde "But you are a member of no group?!" da soli, oppure
--     un blocco che inizia con `Your group "<nome>" consists of:` se in
--     gruppo.
--   - Fine combattimento (testo REALE fornito dall'utente il 2026-08-10):
--     "Uno Spazzino is dead! R.I.P." seguito da "La tua parte di esperienza
--     e' di N punti." (anche con N=0/1, sempre presente se hai contribuito
--     al combattimento — usato come segnale per il loot automatico invece
--     della riga "is dead!" perche' quest'ultima si vede anche per uccisioni
--     altrui a cui non hai partecipato).
-- ---------------------------------------------------------------------------
NebbieDash.autoSplit = true
NebbieDash.autoLoot = true

function NebbieDash.stripColors(text)
  if not text then return "" end
  text = text:gsub("%$c%d%d%d%d", "")
  text = text:gsub("\27%[[%d;]*m", "")
  return text
end

function NebbieDash.parseLootCoinAmount(text)
  text = NebbieDash.stripColors(text or "")
  text = text:match("^%s*(.-)%s*$") or ""
  if text:match("^%S+%s+C'erano") or text:match("^%S+%s+C'era") then
    return nil
  end
  local amount = text:match("^C'erano%s+(%d+)%s+monete%.%s*$")
  if amount then
    return tonumber(amount)
  end
  if text:match("^C'era una miserabile moneta%.%s*$") then
    return 1
  end
  return nil
end

function NebbieDash.isGroupSoloLine(text)
  text = NebbieDash.stripColors(text or "")
  return text:match("^But you are a member of no group") ~= nil
end

function NebbieDash.isGroupHeaderLine(text)
  text = NebbieDash.stripColors(text or "")
  return text:match("^Your group .-consists of:") ~= nil
end

-- Segnale di fine combattimento: due formati REALI confermati dall'utente —
-- "La tua parte di esperienza e' di N punti." (quota di gruppo) e "La tua
-- esperienza e' aumentata di N punti." (uccisione in solitaria, testo
-- fornito il 2026-08-10 con "Gwynyar is dead!"/"A mindflayer is dead!" ecc.
-- — senza questo secondo shield l'autoloot non scattava affatto per le
-- uccisioni in solitaria con questa frase). Entrambi sempre attivi (stesso
-- principio degli altri trigger a riga singola). Fanno scattare `nloot` da
-- solo se `nautoloot` e' attivo, cosi' non serve piu' digitarlo manualmente
-- dopo ogni uccisione.
function NebbieDash.onCombatEndLine()
  if NebbieDash.autoLoot then
    NebbieDash.cmdLoot()
  end
end

-- ---------------------------------------------------------------------------
-- Rialzarsi da terra e recupero arma dopo un disarmo — richiesti esplicita-
-- mente come "unico trigger di combattimento" che serve ora (2026-08-10),
-- basati su testi REALI forniti dall'utente:
--   - Caduta: "Illyari schiva il tuo urto. Inciampi e cadi per terra." → la
--     parte fissa e' "Inciampi e cadi per terra." (il resto della frase
--     varia in base a chi/cosa causa la caduta — l'utente segnala che
--     questo e' SOLO UNO dei possibili messaggi di caduta: se ce ne sono
--     altri andranno aggiunti quando forniti, non li invento).
--   - Disarmo: "Ti disarmano e la Flamberga di Boris vola dalla tua presa."
--     — il nome dell'arma e' catturato DIRETTAMENTE da questa riga (non
--     dal pannello equip, che potrebbe non essere aggiornato), poi ripulito
--     dagli articoli/preposizioni italiane per ottenere le parole chiave
--     con cui il gioco identifica l'oggetto (confermato dall'utente per
--     "la Flamberga di Boris" → "flamberga boris").
-- ---------------------------------------------------------------------------
NebbieDash.autoStand = true
NebbieDash.autoDisarmRecover = true

-- Parole italiane da scartare per ottenere le parole chiave dell'oggetto dal
-- suo nome descrittivo (articoli, preposizioni semplici/articolate,
-- congiunzioni). Elenco deliberatamente conservativo: in caso di dubbio è
-- meglio lasciare una parola di troppo (il gioco la ignorerebbe comunque se
-- non è un suo keyword) che scartarne una che serve.
NebbieDash.ITEM_STOPWORDS = {
  ["il"] = true, ["lo"] = true, ["la"] = true, ["i"] = true, ["gli"] = true, ["le"] = true,
  ["un"] = true, ["uno"] = true, ["una"] = true,
  ["di"] = true, ["da"] = true, ["in"] = true, ["con"] = true, ["su"] = true, ["per"] = true,
  ["tra"] = true, ["fra"] = true, ["e"] = true, ["ed"] = true, ["a"] = true, ["ad"] = true,
  ["del"] = true, ["dello"] = true, ["della"] = true, ["dei"] = true, ["degli"] = true, ["delle"] = true,
  ["al"] = true, ["allo"] = true, ["alla"] = true, ["ai"] = true, ["agli"] = true, ["alle"] = true,
  ["dal"] = true, ["dallo"] = true, ["dalla"] = true, ["dai"] = true, ["dagli"] = true, ["dalle"] = true,
  ["nel"] = true, ["nello"] = true, ["nella"] = true, ["nei"] = true, ["negli"] = true, ["nelle"] = true,
  ["sul"] = true, ["sullo"] = true, ["sulla"] = true, ["sui"] = true, ["sugli"] = true, ["sulle"] = true,
  -- Forme troncate davanti apostrofo (l'apostrofo viene sostituito da uno
  -- spazio prima del filtro, quindi "dell'Infinito" arriva come due parole
  -- separate "dell" e "infinito").
  ["l"] = true, ["d"] = true, ["dell"] = true, ["nell"] = true, ["sull"] = true, ["dall"] = true, ["all"] = true,
}

-- Rimuove suffissi tra parentesi dall'eq (condizioni, alone luminoso, ecc.):
-- non fanno parte delle keyword MUD per get/rem/wield.
function NebbieDash.stripItemParentheticals(name)
  name = name or ""
  name = name:gsub("%s*%b()", "")
  name = name:gsub("%s+", " ")
  return name:match("^%s*(.-)%s*$") or ""
end

-- Estrae le parole chiave "significative" da un nome oggetto descrittivo,
-- scartando gli articoli/preposizioni sopra (anche nella forma con
-- apostrofo, es. "l'Infinito" → "infinito"). Restituisce una stringa
-- minuscola pronta per essere usata come argomento di `get`/`wield`.
function NebbieDash.extractItemKeywords(name)
  name = NebbieDash.stripItemParentheticals(name)
  name = (name or ""):lower():gsub("'", " "):gsub("[%.,!]", "")
  local words = {}
  for word in name:gmatch("%S+") do
    if not NebbieDash.ITEM_STOPWORDS[word] then
      table.insert(words, word)
    end
  end
  return table.concat(words, " ")
end

-- Shield su substring fissa (sempre attivo, riga singola, stesso principio
-- degli altri trigger a riga singola di questo file).
function NebbieDash.onFallLine()
  if not NebbieDash.autoStand then return end
  send("stand", false)
end

function NebbieDash.onDisarmLine()
  if not NebbieDash.autoDisarmRecover then return end
  local text = line or (type(getCurrentLine) == "function" and getCurrentLine()) or ""
  local weaponName = text:match("^Ti disarmano e (.+) vola dalla tua presa%.%s*$")
  if not weaponName then return end
  local keywords = NebbieDash.resolveItemKeywords(weaponName)
  if keywords == "" then return end
  send("get " .. keywords, false)
  tempTimer(0.5, function() send("wield " .. keywords, false) end)
end

function NebbieDash.cmdSetAutoStand(argStr)
  argStr = (argStr or ""):match("^%s*(.-)%s*$"):lower()
  if argStr == "on" then
    NebbieDash.autoStand = true
  elseif argStr == "off" then
    NebbieDash.autoStand = false
  else
    cecho("<orange>[NebbieDash] Uso: nautostand <on|off> (attuale: " ..
      (NebbieDash.autoStand and "on" or "off") .. ")\n")
    return
  end
  cecho("<green>[NebbieDash] Rialzarsi automaticamente da terra: " .. (NebbieDash.autoStand and "on" or "off") .. ".\n")
end

function NebbieDash.cmdSetAutoDisarmRecover(argStr)
  argStr = (argStr or ""):match("^%s*(.-)%s*$"):lower()
  if argStr == "on" then
    NebbieDash.autoDisarmRecover = true
  elseif argStr == "off" then
    NebbieDash.autoDisarmRecover = false
  else
    cecho("<orange>[NebbieDash] Uso: nautodisarm <on|off> (attuale: " ..
      (NebbieDash.autoDisarmRecover and "on" or "off") .. ")\n")
    return
  end
  cecho("<green>[NebbieDash] Recupero automatico arma dopo disarmo: " .. (NebbieDash.autoDisarmRecover and "on" or "off") .. ".\n")
end

-- ---------------------------------------------------------------------------
-- Gestione armi: elenco persistente per personaggio, con tipo di danno
-- (slash/blunt/pierce) e cambio con un click (2026-08-10).
-- Testi REALI forniti dall'utente:
--   - Impugnare: si presume "Impugni <nome arma>." (confermato dall'utente
--     via risposta a scelta multipla "generic_wield", non con un copia-incolla
--     letterale — se in gioco il testo risultasse diverso, va corretto qui).
--   - `identify` (spell/comando che l'utente esegue lui stesso quando vuole,
--     NON automatizzato: costa una "ondata di stanchezza", quindi non va
--     scatenato in automatico ad ogni wield) risponde su piu' righe, dove le
--     due che servono sono:
--       Oggetto: 'spada elf slayer', Tipo di Oggetto WEAPON
--       Tipo di danno: 'SLASH'
--     (viste separatamente, senza bisogno di una capture multi-riga con
--     inizio/fine: bastano due trigger a riga singola che si "passano" il
--     dato tra una riga e l'altra).
-- ---------------------------------------------------------------------------

-- Vero se due parole chiave condividono almeno una parola (case-insensitive):
-- usato per collegare la keyword vista al wield (euristica/override da
-- nebbie-item-keywords.txt) con quella "canonica" riportata da `identify`,
-- che nella pratica raramente coincidono parola per parola.
function NebbieDash.keywordsOverlap(a, b)
  local wordsB = {}
  for w in (b or ""):lower():gmatch("%S+") do wordsB[w] = true end
  for w in (a or ""):lower():gmatch("%S+") do
    if wordsB[w] then return true end
  end
  return false
end

function NebbieDash.findWeaponByKeyword(data, keyword)
  keyword = (keyword or ""):lower()
  if keyword == "" then return nil end
  for _, w in ipairs(data.weapons or {}) do
    if (w.keyword or ""):lower() == keyword then return w end
  end
  for _, w in ipairs(data.weapons or {}) do
    if NebbieDash.keywordsOverlap(w.keyword or "", keyword) then return w end
  end
  return nil
end

-- Legge lo slot "impugnato" dal pannello equip gia' sincronizzato (nessuna
-- chiamata aggiuntiva al gioco) e ne restituisce la parola chiave risolta,
-- oppure stringa vuota se non impugni nulla o l'equip non e' sincronizzato.
function NebbieDash.currentWieldedKeyword(data)
  if not data or not data.eqUpdated then return "" end
  for _, row in ipairs(NebbieDash.buildEquipRows(data)) do
    if not row.empty and row.location == "impugnato" then
      return NebbieDash.resolveItemKeywords(row.item)
    end
  end
  return ""
end

function NebbieDash.eqItemNamesMatch(cachedItem, gameName)
  if not cachedItem or cachedItem == "" or not gameName or gameName == "" then return false end
  local a = NebbieDash.stripItemParentheticals(cachedItem):lower():match("^%s*(.-)%s*$")
  local b = NebbieDash.stripItemParentheticals(gameName):lower():match("^%s*(.-)%s*$")
  if a == b then return true end
  return NebbieDash.keywordsOverlap(a, b)
end

-- Aggiorna la cache equip (da `eq`) senza rifare neq: usato su messaggi MUD di
-- rem/wield/wear durante il cambio arma automatico.
function NebbieDash.patchCachedEqLocation(data, locationLabel, itemText)
  if not data or not data.eqUpdated then return false end
  data.eq = data.eq or {}
  local canon = (locationLabel or ""):lower():match("^%s*(.-)%s*$")
  if canon == "" then return false end
  local slotIdx, canonLabel = nil, nil
  for idx, label in ipairs(NebbieDash.EQ_SLOT_ORDER) do
    if label:lower() == canon then
      canonLabel = label
      for slot, entry in pairs(data.eq) do
        if entry and (entry.location or ""):lower():match("^%s*(.-)%s*$") == canon then
          slotIdx = slot
          break
        end
      end
      if not slotIdx then slotIdx = idx end
      break
    end
  end
  if not slotIdx or not canonLabel then return false end
  if itemText == nil or itemText == "" then
    data.eq[slotIdx] = nil
  else
    data.eq[slotIdx] = { location = canonLabel, item = itemText:match("^%s*(.-)%s*$") }
  end
  data.eqUpdated = os.time()
  NebbieDash.saveStore()
  NebbieDash.refreshDashboard()
  return true
end

function NebbieDash.onStopUsingLine()
  local text = line or (type(getCurrentLine) == "function" and getCurrentLine()) or ""
  local itemName = text:match("^Smetti di usare (.+)%.%s*$")
  if not itemName then return end
  local name = NebbieDash.currentChar
  if not name then return end
  local data = NebbieDash.getCharData(name)
  if not data.eqUpdated then return end
  for _, row in ipairs(NebbieDash.buildEquipRows(data)) do
    if not row.empty and row.location == "impugnato" then
      if NebbieDash.eqItemNamesMatch(row.item, itemName) then
        NebbieDash.patchCachedEqLocation(data, "impugnato", nil)
        return
      end
    end
  end
  for _, row in ipairs(NebbieDash.buildEquipRows(data)) do
    if not row.empty and row.location == "sulla schiena" then
      if NebbieDash.eqItemNamesMatch(row.item, itemName) then
        NebbieDash.patchCachedEqLocation(data, "sulla schiena", nil)
        return
      end
    end
  end
end

function NebbieDash.onWearBackLine()
  local text = line or (type(getCurrentLine) == "function" and getCurrentLine()) or ""
  local itemName = text:match("^Ti metti (.+) sulle spalle%.%s*$")
  if not itemName then return end
  local name = NebbieDash.currentChar
  if not name then return end
  local data = NebbieDash.getCharData(name)
  if not data.eqUpdated then return end
  NebbieDash.patchCachedEqLocation(data, "sulla schiena", itemName)
end

function NebbieDash.onWieldLine()
  local text = line or (type(getCurrentLine) == "function" and getCurrentLine()) or ""
  local weaponName = text:match("^Impugni (.+)%.%s*$")
  if not weaponName then return end
  local name = NebbieDash.currentChar
  if not name then return end
  local data = NebbieDash.getCharData(name)
  data.weapons = data.weapons or {}
  local keyword = NebbieDash.resolveItemKeywords(weaponName)
  local existing = NebbieDash.findWeaponByKeyword(data, keyword)
  if not existing then
    table.insert(data.weapons, { displayName = weaponName, keyword = keyword, type = nil })
    NebbieDash.saveStore()
    NebbieDash.refreshDashboard()
  elseif existing.displayName ~= weaponName then
    existing.displayName = weaponName
    NebbieDash.saveStore()
    NebbieDash.refreshDashboard()
  end
  NebbieDash.patchCachedEqLocation(data, "impugnato", weaponName)
end

-- Vedi nota sopra: aggiornata/creata solo quando l'utente esegue `identify`
-- di sua iniziativa, mai in automatico.
function NebbieDash.onIdentifyObjectLine()
  local text = line or (type(getCurrentLine) == "function" and getCurrentLine()) or ""
  local keyword, objType = text:match("^Oggetto: '([^']+)', Tipo di Oggetto (%S+)$")
  if not keyword then return end
  NebbieDash._pendingIdentify = { keyword = keyword:lower(), isWeapon = (objType == "WEAPON") }
end

function NebbieDash.onIdentifyDamageLine()
  local pending = NebbieDash._pendingIdentify
  NebbieDash._pendingIdentify = nil
  if not pending or not pending.isWeapon then return end
  local text = line or (type(getCurrentLine) == "function" and getCurrentLine()) or ""
  local dmgType = text:match("^Tipo di danno: '([^']+)'")
  if not dmgType then return end
  local name = NebbieDash.currentChar
  if not name then return end
  local data = NebbieDash.getCharData(name)
  data.weapons = data.weapons or {}
  local entry = NebbieDash.findWeaponByKeyword(data, pending.keyword)
  if entry then
    entry.type = dmgType:lower()
    entry.keyword = pending.keyword -- la keyword di `identify` e' quella "canonica" riportata dal gioco: la preferiamo.
  else
    table.insert(data.weapons, { displayName = pending.keyword, keyword = pending.keyword, type = dmgType:lower() })
  end
  NebbieDash.saveStore()
  NebbieDash.refreshDashboard()
end

-- Click su un'arma in elenco: rem/put l'arma impugnata (se c'e'), get/wield
-- quella selezionata. Usa lo stesso zaino (slot "sulla schiena") delle macro
-- fame/sete, con lo stesso criterio override/euristica (vedi findBackpackKeywords).
function NebbieDash.cmdSwapWeapon(idx)
  local name = NebbieDash.currentChar
  if not name then return end
  if NebbieDash._weaponSwapBusy then
    cecho("<orange>[NebbieDash] Cambio arma gia' in corso.\n")
    return
  end
  local data = NebbieDash.getCharData(name)
  NebbieDash.loadItemKeywords()
  local target = data.weapons and data.weapons[idx]
  if not target or not target.keyword then return end

  local currentKeyword = NebbieDash.currentWieldedKeyword(data)
  if currentKeyword ~= "" and NebbieDash.keywordsOverlap(currentKeyword, target.keyword) then
    cecho("<orange>[NebbieDash] Stai gia' impugnando " .. (target.displayName or target.keyword) .. ".\n")
    return
  end

  local steps, err = NebbieDash.buildWeaponSwapSteps(data, target)
  if not steps then
    if err == "no_backpack" then
      cecho("<orange>[NebbieDash] Nessuno zaino rilevato (slot 'sulla schiena') — esegui <yellow>neq<orange> prima.\n")
    end
    return
  end

  NebbieDash._weaponSwapBusy = true
  NebbieDash.runCommandSequence(steps, NebbieDash.weaponSwapDelay)
  tempTimer(NebbieDash.weaponSwapDelay * #steps + 0.25, function()
    NebbieDash._weaponSwapBusy = false
  end)
end

-- ---------------------------------------------------------------------------
-- Fame/sete: macro configurabile per personaggio (2026-08-10).
-- Testi REALI forniti dall'utente per il trigger: "Hai Fame." / "Hai sete."
-- (nota le maiuscole diverse: "Fame" con la F maiuscola, "sete" tutto
-- minuscolo — copiate esattamente cosi' dall'utente, non uniformate).
--
-- A differenza di loot/disarmo, qui la sequenza di comandi VARIA per
-- personaggio in un modo che non si puo' derivare automaticamente (l'utente
-- lo dice esplicitamente: "o variazioni a seconda del personaggio") — solo
-- la parola chiave dello ZAINO (slot "sulla schiena") si puo' derivare
-- automaticamente dal pannello equip, col resto della sequenza (es. il nome
-- dell'oggetto da bere dentro lo zaino) che resta specifico del personaggio
-- e va scritto a mano. Per questo si usa un file di configurazione (stesso
-- principio degli speedwalk) con un segnaposto "{zaino}" che viene
-- sostituito con la parola chiave derivata al momento dell'esecuzione.
-- ---------------------------------------------------------------------------
NebbieDash.autoFeed = true
NebbieDash.hungerMacros = {}

function NebbieDash.hungerMacrosPath()
  local home = (type(getMudletHomeDir) == "function" and getMudletHomeDir()) or "."
  return home .. "/nebbie-hunger-macros.txt"
end

function NebbieDash.ensureHungerMacrosFile()
  local path = NebbieDash.hungerMacrosPath()
  if type(io.exists) == "function" and io.exists(path) then return end
  local f = io.open(path, "w")
  if not f then return end
  f:write(
    "# File di configurazione fame/sete — nebbie-complete-dashboard-package\n" ..
    "#\n" ..
    "# Una riga per personaggio, formato:\n" ..
    "#   NomePersonaggio: comando1, comando2, ...\n" ..
    "#\n" ..
    "# Scatta quando il gioco mostra \"Hai Fame.\" o \"Hai sete.\" (se\n" ..
    "# nautofeed e' attivo, default si).\n" ..
    "#\n" ..
    "# Il segnaposto {zaino} viene sostituito automaticamente con la parola\n" ..
    "# chiave dell'oggetto nello slot \"sulla schiena\" del personaggio (letta\n" ..
    "# dal pannello equip, non serve scriverla a mano e non serve conoscerla\n" ..
    "# in anticipo).\n" ..
    "#\n" ..
    "# Per ripetere un comando N volte, come nell'alias \".Ncomando\" digitato\n" ..
    "# in gioco, scrivi \".N comando\" come singolo passo (es. \".5 drink cornu\").\n" ..
    "#\n" ..
    "# Le righe che iniziano con # e le righe vuote vengono ignorate.\n" ..
    "# Dopo aver modificato questo file, digita 'nhungermacros' in gioco per\n" ..
    "# ricaricarlo senza dover riavviare Mudlet.\n" ..
    "#\n" ..
    "# Esempio (rimuovi il # iniziale e adatta al tuo personaggio/oggetto):\n" ..
    "# Mirari: rem {zaino}, get cornucopia {zaino}, .5 drink cornu, put cornu {zaino}, wear {zaino}\n"
  )
  f:close()
end

function NebbieDash.parseHungerMacroLine(rawLine)
  local line2 = rawLine:match("^%s*(.-)%s*$")
  if line2 == "" or line2:sub(1, 1) == "#" then return nil end
  local name, macro = line2:match("^([^:]+):%s*(.+)$")
  if not name then return nil end
  return name:match("^%s*(.-)%s*$"), macro:match("^%s*(.-)%s*$")
end

function NebbieDash.loadHungerMacros()
  NebbieDash.ensureHungerMacrosFile()
  NebbieDash.hungerMacros = {}
  local path = NebbieDash.hungerMacrosPath()
  local f = io.open(path, "r")
  if not f then return end
  for rawLine in f:lines() do
    local name, macro = NebbieDash.parseHungerMacroLine(rawLine)
    if name then NebbieDash.hungerMacros[name] = macro end
  end
  f:close()
end

function NebbieDash.cmdReloadHungerMacros()
  NebbieDash.loadHungerMacros()
  local count = 0
  for _ in pairs(NebbieDash.hungerMacros) do count = count + 1 end
  cecho("<green>[NebbieDash] Macro fame/sete ricaricate (" .. count .. ") da " .. NebbieDash.hungerMacrosPath() .. "\n")
end

-- Come cmdRepeat, ma per un singolo "passo" dentro una macro piu' ampia:
-- se il passo inizia con ".N " lo espande in N copie del comando che segue,
-- altrimenti lo lascia come singolo passo. Usata per interpretare la stessa
-- sintassi ".Ncomando"/".N comando" anche dentro le macro fame/sete, senza
-- passare dall'alias di Mudlet (che intercetta solo l'input digitato
-- dall'utente, non i comandi inviati via script).
function NebbieDash.expandMacroSteps(macroStr)
  local steps = {}
  for rawStep in (macroStr or ""):gmatch("[^,]+") do
    local step = rawStep:match("^%s*(.-)%s*$")
    if step ~= "" then
      local count, cmd = step:match("^%.(%d+)%s*(.+)$")
      if count then
        count = tonumber(count)
        for _ = 1, count do table.insert(steps, cmd) end
      else
        table.insert(steps, step)
      end
    end
  end
  return steps
end

-- Trova la parola chiave dell'oggetto nello slot "sulla schiena" (lo zaino)
-- per il personaggio attivo, usando lo stesso pannello equip gia'
-- sincronizzato (nessuna chiamata aggiuntiva al gioco). Vuota se non c'e'
-- nulla in quello slot o l'equip non e' mai stato sincronizzato.
function NebbieDash.findBackpackKeywords(data)
  if not data or not data.eqUpdated then return "", false end
  for _, row in ipairs(NebbieDash.buildEquipRows(data)) do
    if not row.empty and row.location == "sulla schiena" then
      return NebbieDash.resolveItemKeywords(row.item)
    end
  end
  return "", false
end

-- Il "{zaino}" sostituito e' l'ULTIMA parola chiave estratta (tipicamente il
-- nome proprio dell'oggetto, es. "Korred"), non tutta la frase multi-parola:
-- test in gioco (2026-08-10) hanno mostrato che passare la frase intera
-- ("borsa inesauribile korred") a `wear` confonde il parser del MUD, che
-- interpreta l'ultima parola aggiuntiva come una posizione del corpo
-- invece che come parte della descrizione dell'oggetto (risposta osservata:
-- "Non puoi indossare nulla su un inesauribile."). L'esempio originale
-- fornito dall'utente usava comunque una singola parola ("korred"), non la
-- frase completa. Usata solo come ULTIMA risorsa se non c'e' un override
-- nel file nebbie-item-keywords.txt (vedi sotto).
function NebbieDash.lastKeyword(phrase)
  local last = nil
  for word in (phrase or ""):gmatch("%S+") do last = word end
  return last or ""
end

function NebbieDash.pickItemCommandKeyword(phrase, isOverride, avoidPhrases)
  phrase = (phrase or ""):match("^%s*(.-)%s*$") or ""
  if phrase == "" then return "" end
  if isOverride then return phrase end
  local last = NebbieDash.lastKeyword(phrase)
  for _, avoid in ipairs(avoidPhrases or {}) do
    if avoid and avoid ~= "" and NebbieDash.keywordsOverlap(last, avoid) then
      return phrase
    end
  end
  if last ~= "" then return last end
  return phrase
end

function NebbieDash.runCommandSequence(steps, delaySec)
  delaySec = delaySec or NebbieDash.weaponSwapDelay or 0.5
  for i, cmd in ipairs(steps or {}) do
    tempTimer(delaySec * (i - 1), function() send(cmd, false) end)
  end
end

function NebbieDash.buildWeaponSwapSteps(data, target)
  local backPhrase, backOverride = NebbieDash.findBackpackKeywords(data)
  if backPhrase == "" then return nil, "no_backpack" end
  local weaponKw = NebbieDash.resolveWeaponSwapKeyword(target)
  weaponKw = (weaponKw or ""):match("^%s*(.-)%s*$")
  if weaponKw == "" then return nil, "no_weapon" end
  local wieldPhrase = NebbieDash.currentWieldedKeyword(data)
  local wieldConfirmed = wieldPhrase ~= "" and data.eqUpdated
  local backKw = NebbieDash.pickItemCommandKeyword(backPhrase, backOverride, { wieldPhrase, weaponKw })
  local wieldKw = ""
  if wieldConfirmed then
    wieldKw = NebbieDash.pickItemCommandKeyword(wieldPhrase, false, { backPhrase, weaponKw })
  end

  local steps = {}
  table.insert(steps, "rem " .. backKw)
  table.insert(steps, "get " .. weaponKw .. " " .. backKw)
  if wieldConfirmed and wieldKw ~= "" and not NebbieDash.keywordsOverlap(wieldKw, weaponKw) then
    table.insert(steps, "rem " .. wieldKw)
  end
  table.insert(steps, "wield " .. weaponKw)
  if wieldConfirmed and wieldKw ~= "" and not NebbieDash.keywordsOverlap(wieldKw, weaponKw) then
    table.insert(steps, "put " .. wieldKw .. " " .. backKw)
  end
  table.insert(steps, "wear " .. backKw)
  return steps, nil
end

-- ---------------------------------------------------------------------------
-- Parole chiave per oggetto, condivise tra TUTTI i personaggi (2026-08-10).
-- L'euristica automatica (extractItemKeywords, sopra) funziona per alcuni
-- oggetti ma non per altri (es. l'utente ha confermato che passare tutte le
-- parole non-stopword di "Borsa Inesauribile dei Korred" a `wear` confonde
-- il gioco), e l'utente segnala che l'oggetto da cui prendere la cornucopia
-- "potrà cambiare" nel tempo. Invece di indovinare, l'utente puo' scrivere
-- QUI la parola chiave esatta e verificata per ogni oggetto per nome
-- (indipendente dal personaggio, quindi condivisa tra tutti — un dato oggetto
-- ha sempre le stesse parole chiave in game, non cambia da personaggio a
-- personaggio). Se un oggetto non ha una riga qui, si ricade sull'euristica
-- automatica (extractItemKeywords).
-- ---------------------------------------------------------------------------
NebbieDash.itemKeywordOverrides = {}

function NebbieDash.itemKeywordsPath()
  local home = (type(getMudletHomeDir) == "function" and getMudletHomeDir()) or "."
  return home .. "/nebbie-item-keywords.txt"
end

function NebbieDash.ensureItemKeywordsFile()
  local path = NebbieDash.itemKeywordsPath()
  if type(io.exists) == "function" and io.exists(path) then return end
  local f = io.open(path, "w")
  if not f then return end
  f:write(
    "# File di parole chiave per oggetto — nebbie-complete-dashboard-package\n" ..
    "#\n" ..
    "# Una riga per oggetto, formato:\n" ..
    "#   Nome esatto dell'oggetto (come mostrato in eq): parola chiave da usare\n" ..
    "#\n" ..
    "# Vale per TUTTI i personaggi (un dato oggetto ha sempre le stesse parole\n" ..
    "# chiave in game). Usata per: recupero disarmo, {zaino} fame/sete,\n" ..
    "# **cambio arma** (click pannello Armi), zaino sulla schiena.\n" ..
    "# Nome a sinistra: testo come in `eq` (senza parentesi condizione/alone)\n" ..
    "# oppure una parola distintiva contenuta nel nome (es. flamberga).\n" ..
    "# l'estrazione automatica (rimozione di articoli/preposizioni italiane)\n" ..
    "# come prima — questo file serve solo per i casi in cui NON funziona.\n" ..
    "#\n" ..
    "# Le righe che iniziano con # e le righe vuote vengono ignorate.\n" ..
    "# Dopo aver modificato questo file, digita 'nitemkeywords' in gioco per\n" ..
    "# ricaricarlo senza dover riavviare Mudlet.\n" ..
    "#\n" ..
    "# Esempi (rimuovi il # iniziale e adatta ai tuoi oggetti):\n" ..
    "# Borsa Inesauribile dei Korred: korred\n" ..
    "# la Flamberga di Boris: flamberga boris\n" ..
    "# flamberga: flamberga boris\n" ..
    "# It's a Beautiful Day: beautiful\n" ..
    "# nordagh: nordagh\n"
  )
  f:close()
end

function NebbieDash.parseItemKeywordLine(rawLine)
  local line2 = rawLine:match("^%s*(.-)%s*$")
  if line2 == "" or line2:sub(1, 1) == "#" then return nil end
  local itemName, keywords = line2:match("^([^:]+):%s*(.+)$")
  if not itemName then return nil end
  itemName = itemName:match("^%s*(.-)%s*$"):lower()
  keywords = keywords:match("^%s*(.-)%s*$"):lower()
  if itemName == "" or keywords == "" then return nil end
  return itemName, keywords
end

function NebbieDash.loadItemKeywords()
  NebbieDash.ensureItemKeywordsFile()
  NebbieDash.itemKeywordOverrides = {}
  local path = NebbieDash.itemKeywordsPath()
  local f = io.open(path, "r")
  if not f then return end
  for rawLine in f:lines() do
    local itemName, keywords = NebbieDash.parseItemKeywordLine(rawLine)
    if itemName then NebbieDash.itemKeywordOverrides[itemName] = keywords end
  end
  f:close()
end

function NebbieDash.cmdReloadItemKeywords()
  NebbieDash.loadItemKeywords()
  local count = 0
  for _ in pairs(NebbieDash.itemKeywordOverrides) do count = count + 1 end
  cecho("<green>[NebbieDash] Parole chiave oggetti ricaricate (" .. count .. ") da " .. NebbieDash.itemKeywordsPath() .. "\n")
end

-- Punto unico usato da disarmo e macro fame/sete per ottenere le parole
-- chiave di un oggetto: preferisce l'override esplicito dal file (se
-- presente), altrimenti ricade sull'euristica automatica. Il secondo valore
-- di ritorno indica se e' stato usato un override esplicito (utile per
-- decidere se applicare ulteriori restrizioni euristiche, es. lastKeyword).
function NebbieDash.findItemKeywordOverride(itemName)
  local stripped = NebbieDash.stripItemParentheticals(itemName or ""):lower():match("^%s*(.-)%s*$")
  if stripped == "" then return nil end
  local overrides = NebbieDash.itemKeywordOverrides or {}
  if overrides[stripped] then return overrides[stripped] end
  local raw = (itemName or ""):lower():match("^%s*(.-)%s*$")
  if overrides[raw] then return overrides[raw] end
  -- Match parziale: es. riga "flamberga: flamberga boris" vale per "La Flamberga di Boris".
  local bestKw, bestLen = nil, 0
  for pat, kw in pairs(overrides) do
    if #pat >= 3 and stripped:find(pat, 1, true) and #pat > bestLen then
      bestKw, bestLen = kw, #pat
    end
  end
  return bestKw
end

function NebbieDash.resolveItemKeywords(itemName)
  local stripped = NebbieDash.stripItemParentheticals(itemName)
  local override = NebbieDash.findItemKeywordOverride(itemName)
  if override then return override, true end
  return NebbieDash.extractItemKeywords(stripped), false
end

function NebbieDash.resolveWeaponSwapKeyword(target)
  if not target then return "" end
  local disp = (target.displayName or target.keyword or ""):match("^%s*(.-)%s*$")
  if disp ~= "" then
    local fromDisp, isOverride = NebbieDash.resolveItemKeywords(disp)
    if isOverride and fromDisp ~= "" then return fromDisp end
  end
  local idKw = (target.keyword or ""):match("^%s*(.-)%s*$")
  if idKw ~= "" then
    local fromId, isOverrideId = NebbieDash.resolveItemKeywords(idKw)
    if isOverrideId and fromId ~= "" then return fromId end
    if target.type then return idKw end
  end
  if disp ~= "" then
    local fromDispHeur = select(1, NebbieDash.resolveItemKeywords(disp))
    if fromDispHeur ~= "" then return fromDispHeur end
  end
  return idKw
end

function NebbieDash.runHungerMacro()
  local name = NebbieDash.currentChar
  if not name then return end
  local macro = NebbieDash.hungerMacros[name]
  if not macro then
    cecho("<orange>[NebbieDash] Nessuna macro fame/sete configurata per " .. name ..
      " — scrivila in " .. NebbieDash.hungerMacrosPath() .. " poi digita <yellow>nhungermacros<orange>.\n")
    return
  end
  local data = NebbieDash.getCharData(name)
  local backpackKeywords, isOverride = NebbieDash.findBackpackKeywords(data)
  -- Con un override esplicito ci si fida della parola/e scritte dall'utente
  -- (potrebbero essere piu' di una, se serve); senza override si ricade
  -- sull'euristica E si prende solo l'ultima parola per non confondere
  -- comandi come `wear` (vedi nota su lastKeyword sopra).
  local backpackKeyword = isOverride and backpackKeywords or NebbieDash.lastKeyword(backpackKeywords)
  local substituted = macro:gsub("{zaino}", backpackKeyword)
  local steps = NebbieDash.expandMacroSteps(substituted)
  for i, cmd in ipairs(steps) do
    tempTimer(NebbieDash.speedwalkDelay * (i - 1), function() send(cmd, false) end)
  end
end

-- Shield su substring fisse (sempre attivo, riga singola). Due trigger
-- distinti perche' le due frasi non condividono un prefisso comune utile
-- come shield unico ("Hai Fame." / "Hai sete."). Il gioco spesso manda
-- ENTRAMBE le righe insieme (fame E sete allo stesso momento): senza un
-- "cooldown" i due trigger fanno partire la macro DUE VOLTE in parallelo,
-- con le due sequenze di comandi che si accavallano e si intralciano a
-- vicenda (bug osservato in gioco: il secondo "rem" fallisce con "Non lo
-- stai usando." perche' il primo ha gia' tolto lo zaino un istante prima).
NebbieDash.hungerMacroCooldownSec = 3
NebbieDash._lastHungerMacroRun = 0

function NebbieDash.onHungerThirstLine()
  if not NebbieDash.autoFeed then return end
  local now = os.time()
  if now - NebbieDash._lastHungerMacroRun < NebbieDash.hungerMacroCooldownSec then return end
  NebbieDash._lastHungerMacroRun = now
  NebbieDash.runHungerMacro()
end

function NebbieDash.cmdSetAutoFeed(argStr)
  argStr = (argStr or ""):match("^%s*(.-)%s*$"):lower()
  if argStr == "on" then
    NebbieDash.autoFeed = true
  elseif argStr == "off" then
    NebbieDash.autoFeed = false
  else
    cecho("<orange>[NebbieDash] Uso: nautofeed <on|off> (attuale: " ..
      (NebbieDash.autoFeed and "on" or "off") .. ")\n")
    return
  end
  cecho("<green>[NebbieDash] Macro automatica fame/sete: " .. (NebbieDash.autoFeed and "on" or "off") .. ".\n")
end

function NebbieDash.cmdSetAutoLoot(argStr)
  argStr = (argStr or ""):match("^%s*(.-)%s*$"):lower()
  if argStr == "on" then
    NebbieDash.autoLoot = true
  elseif argStr == "off" then
    NebbieDash.autoLoot = false
  else
    cecho("<orange>[NebbieDash] Uso: nautoloot <on|off> (attuale: " ..
      (NebbieDash.autoLoot and "on" or "off") .. ")\n")
    return
  end
  cecho("<green>[NebbieDash] Loot automatico dopo ogni combattimento: " .. (NebbieDash.autoLoot and "on" or "off") .. ".\n")
end

-- Riga di conferma loot riuscito ("C'erano N monete."): shield su substring
-- fissa "C'erano" (vedi MUDLET-WIKI-NOTES.md §1 su shielding/costo dei
-- trigger), poi verifica precisa col pattern completo dentro l'handler.
-- Sempre attivo (costo trascurabile, stesso principio del trigger prompt
-- " M: " gia' presente): non richiede uno stato di "cattura" perche' e' una
-- riga singola e autosufficiente, a differenza dei blocchi eq/attrib.
function NebbieDash.onLootLine()
  local text = line or (type(getCurrentLine) == "function" and getCurrentLine()) or ""
  local amount = NebbieDash.parseLootCoinAmount(text)
  if not amount then return end
  cecho("<green>[NebbieDash] Bottino: " .. amount .. " monete.\n")
  if NebbieDash.autoSplit then
    NebbieDash.startSplitFlow(amount)
  end
end

-- Invia i due comandi di loot noti (cadavere normale + pile of bones): solo
-- uno dei due potra' avere successo per singolo cadavere, l'altro risponde
-- con un semplice "Non vedi nessun ..." innocuo che non fa scattare nulla.
function NebbieDash.cmdLoot()
  send("get all.coin corp", false)
  tempTimer(0.5, [[send("get all.coin pile", false)]])
end

-- Stesso watchdog "a inattivita'" gia' usato per le catture eq/attrib (vedi
-- armEqWatchdog): se ne' "But you are a member of no group" ne' "Your
-- group " arrivano entro pochi secondi (formato imprevisto, lag, ecc.), il
-- controllo si annulla da solo invece di lasciare i trigger di verifica
-- attivi per sempre.
function NebbieDash.armSplitWatchdog(gen)
  tempTimer(NebbieDash.captureTimeoutSec, function()
    if NebbieDash._groupCheckGen == gen and NebbieDash._groupCheckActive then
      NebbieDash.finishSplitFlow(false)
    end
  end)
end

-- Se un controllo gruppo e' GIA' in corso (loot quasi simultanei, es. piu'
-- uccisioni ravvicinate da un incantesimo ad area come "chain lightning" che
-- colpisce piu' mostri in un colpo), NON avviarne un secondo in parallelo:
-- prima si sovrascriveva _pendingSplitAmount/si incrementava la generazione
-- SENZA che onGroupSoloLine()/onGroupHeaderLine() verificassero a quale
-- generazione appartenesse davvero la risposta "group" arrivata, cosi' una
-- risposta "But you are a member of no group?!" relativa al PRIMO loot
-- (da solo) poteva chiudere anche il controllo del SECONDO loot (magari in
-- gruppo, o viceversa) — rischio concreto di split inviato/non inviato in
-- base a un controllo in realta' scaduto. Si accumula semplicemente
-- l'importo nel controllo gia' in corso: un solo controllo gruppo, un solo
-- split (con la somma totale) quando arriva la risposta.
function NebbieDash.startSplitFlow(amount)
  if NebbieDash._groupCheckActive then
    NebbieDash._pendingSplitAmount = (NebbieDash._pendingSplitAmount or 0) + amount
    return
  end
  NebbieDash._pendingSplitAmount = amount
  NebbieDash._groupCheckGen = (NebbieDash._groupCheckGen or 0) + 1
  NebbieDash._groupCheckActive = true
  if NebbieDash._groupSoloTrig then pcall(enableTrigger, NebbieDash._groupSoloTrig) end
  if NebbieDash._groupHeaderTrig then pcall(enableTrigger, NebbieDash._groupHeaderTrig) end
  NebbieDash.armSplitWatchdog(NebbieDash._groupCheckGen)
  send("group", false)
end

function NebbieDash.finishSplitFlow(grouped)
  NebbieDash._groupCheckActive = false
  if NebbieDash._groupSoloTrig then pcall(disableTrigger, NebbieDash._groupSoloTrig) end
  if NebbieDash._groupHeaderTrig then pcall(disableTrigger, NebbieDash._groupHeaderTrig) end
  local amount = NebbieDash._pendingSplitAmount
  NebbieDash._pendingSplitAmount = nil
  if grouped and amount then
    send("split " .. tostring(amount), false)
    cecho("<green>[NebbieDash] Split automatico: " .. amount .. " monete.\n")
  end
end

function NebbieDash.onGroupSoloLine()
  if not NebbieDash._groupCheckActive then return end
  local text = line or (type(getCurrentLine) == "function" and getCurrentLine()) or ""
  if not NebbieDash.isGroupSoloLine(text) then return end
  NebbieDash.finishSplitFlow(false)
end

function NebbieDash.onGroupHeaderLine()
  if not NebbieDash._groupCheckActive then return end
  local text = line or (type(getCurrentLine) == "function" and getCurrentLine()) or ""
  if not NebbieDash.isGroupHeaderLine(text) then return end
  NebbieDash.finishSplitFlow(true)
end

function NebbieDash.cmdSetAutoSplit(argStr)
  argStr = (argStr or ""):match("^%s*(.-)%s*$"):lower()
  if argStr == "on" then
    NebbieDash.autoSplit = true
  elseif argStr == "off" then
    NebbieDash.autoSplit = false
  else
    cecho("<orange>[NebbieDash] Uso: nautosplit <on|off> (attuale: " ..
      (NebbieDash.autoSplit and "on" or "off") .. ")\n")
    return
  end
  cecho("<green>[NebbieDash] Split automatico dopo loot: " .. (NebbieDash.autoSplit and "on" or "off") .. ".\n")
end

function NebbieDash.cmdSplit(argStr)
  local amount = tonumber((argStr or ""):match("^%s*(%d+)%s*$"))
  if not amount then
    cecho("<orange>[NebbieDash] Uso: nsplit <numero>\n")
    return
  end
  send("split " .. tostring(amount), false)
end

-- ---------------------------------------------------------------------------
-- Batch admin (nbatch) — utility Sirio, comandi da file di configurazione.
-- Confermato dall'utente (2026-09-21): solo con Sirio connesso al MUD,
-- attesa prompt tra un comando e l'altro, stop su errore MUD, log completo
-- per nome-toon in <Toon>-YYYY-MM-DD.txt sotto la home Mudlet.
-- Ogni sequenza batch inizia con `nchar Sirio` (comando Mudlet locale, non MUD).
-- ---------------------------------------------------------------------------
NebbieDash.BATCH_EXECUTOR = "Sirio"
NebbieDash.batchTimeoutSec = 45
NebbieDash.batchCommands = {}
NebbieDash.batchItems = {}
NebbieDash.identBatchCommands = {}

-- Pattern di errore noti (server Nebbie, act.wizard.cpp / do_oload / do_osave).
NebbieDash.BATCH_ERROR_PATTERNS = {
  "There is no such object.",
  "Hum, non ho idea di dove sia!",
  "Il v-number non e' valido.",
  "Il secondo valore non e' corretto.",
  "Mi dispiace ma non hai accesso a quella zona.",
  "Sorry, private items.",
  "When monkeys fly out of Ripper",
  "Questo oggetto non e' qui!",
  "Quale oggetto vuoi modificare?",
  "Nessun mobile od oggetto con quel nome nel mondo.",
  "Non hai con te niente del genere.",
  "Non hai niente del genere!",
}

-- Segnale menu oedit (output reale utente 2026-09-21): riga "-->" dopo "Menu:".
NebbieDash.BATCH_MENU_READY_PATTERN = "^%-%->%s*$"

function NebbieDash.batchCommandsPath()
  local home = (type(getMudletHomeDir) == "function" and getMudletHomeDir()) or "."
  return home .. "/nebbie-batch-commands.txt"
end

function NebbieDash.batchItemsPath()
  local home = (type(getMudletHomeDir) == "function" and getMudletHomeDir()) or "."
  return home .. "/nebbie-batch-items.csv"
end

function NebbieDash.identBatchCommandsPath()
  local home = (type(getMudletHomeDir) == "function" and getMudletHomeDir()) or "."
  return home .. "/nebbie-ident-batch-commands.txt"
end

function NebbieDash.identBatchResultsPath()
  local home = (type(getMudletHomeDir) == "function" and getMudletHomeDir()) or "."
  return home .. "/nebbie-ident-results-" .. os.date("%Y-%m-%d") .. ".csv"
end

function NebbieDash.batchLogPath(nomeToon)
  local home = (type(getMudletHomeDir) == "function" and getMudletHomeDir()) or "."
  local date = os.date("%Y-%m-%d")
  return home .. "/" .. (nomeToon or "unknown") .. "-" .. date .. ".txt"
end

function NebbieDash.ensureBatchCommandsFile()
  local path = NebbieDash.batchCommandsPath()
  if type(io.exists) == "function" and io.exists(path) then return end
  local f = io.open(path, "w")
  if not f then return end
  f:write(
    "# Sequenza comandi batch — una riga = un comando (MUD o Mudlet locale).\n" ..
    "# Placeholder: $1 nome-toon (CSV), $2 chiave normalizzata (minuscolo, trattini),\n" ..
    "# $3 vnum-attuale, $4 vnum-originale.\n" ..
    "# Dopo modifiche: nbatchreload (o riavvia Mudlet).\n" ..
    "#\n" ..
    "# Prima riga obbligatoria: nchar Sirio (imposta PG attivo nel pacchetto).\n" ..
    "# Se manca, viene aggiunta automaticamente all'avvio del batch.\n" ..
    "#\n" ..
    "# Esempio workflow osave (Sirio):\n" ..
    "nchar Sirio\n" ..
    "oload $3\n" ..
    "stat $2\n" ..
    "oedit $2\n" ..
    "[enter]\n" ..
    "cast 'identify' $2\n" ..
    "osave $2 $3 $4\n" ..
    "stat $2\n" ..
    "cast 'identify' $2\n" ..
    "#\n" ..
    "# [enter] = invio vuoto (es. uscita menu oedit). Dopo 'oedit ...' il batch\n" ..
    "# attende la riga '-->' nel log, poi [enter], poi il prompt Sirio.\n"
  )
  f:close()
end

function NebbieDash.ensureIdentBatchCommandsFile()
  local path = NebbieDash.identBatchCommandsPath()
  if type(io.exists) == "function" and io.exists(path) then return end
  local f = io.open(path, "w")
  if not f then return end
  f:write(
    "# Sequenza identify batch — una riga = un comando (MUD o Mudlet locale).\n" ..
    "# Placeholder: $1 nome-toon, $2 key (CSV), $3 vnum-attuale, $4 vnum-originale.\n" ..
    "# Input righe: nebbie-batch-items.csv (stesso CSV di nbatch).\n" ..
    "# Output: nebbie-ident-results-YYYY-MM-DD.csv (un file per tutte le righe).\n" ..
    "# Colonne output: object-name,type,extra-flags,vnum-attuale,vnum-originario,affect-1..5\n" ..
    "# (affect-N = testo dopo \"Ti puo' dare :\" in identify, max 5). Nessun log per-toon.\n" ..
    "# Dopo modifiche: nidentbatchreload (o riavvia Mudlet).\n" ..
    "#\n" ..
    "# Workflow aggiornamento campi name:\n" ..
    "# 1) oload $3 -> 'Adesso hai <short desc>.'\n" ..
    "# 2) cast identify / junk: $o o $ed = ED + nome-toon ($1). Mai $2 (key CSV).\n" ..
    "#    NON usare 'stat': cerca nel MONDO, non l'oggetto oloadato in inventario Sirio.\n" ..
    "# 3) il CSV output prende il nome completo da identify (es. ...EDEchoes)\n" ..
    "# Prima riga: nchar Sirio (preposta automaticamente se manca).\n" ..
    "#\n" ..
    "nchar Sirio\n" ..
    "oload $3\n" ..
    "cast 'identify' $ed\n" ..
    "junk $ed\n"
  )
  f:close()
end

function NebbieDash.ensureBatchItemsFile()
  local path = NebbieDash.batchItemsPath()
  if type(io.exists) == "function" and io.exists(path) then return end
  local f = io.open(path, "w")
  if not f then return end
  f:write(
    "# CSV oggetti batch — prima riga = intestazione obbligatoria.\n" ..
    "# Colonne: nome-toon,key,vnum-attuale,vnum-originale\n" ..
    "# key: testo libero; $2 nei comandi = minuscolo con spazi -> trattini.\n" ..
    "# Righe # e vuote ignorate. Dopo modifiche: nbatchreload.\n" ..
    "nome-toon,key,vnum-attuale,vnum-originale\n" ..
    "GreenBlade,equilibrio EDGreenBlade,34424,9030\n" ..
    "GreenBlade,egida foresta EDGreenBlade,34512,15809\n"
  )
  f:close()
end

function NebbieDash.parseCsvLine(rawLine)
  local fields = {}
  local field = {}
  local inQuotes = false
  local i = 1
  while i <= #rawLine do
    local ch = rawLine:sub(i, i)
    if ch == '"' then
      if inQuotes and rawLine:sub(i + 1, i + 1) == '"' then
        table.insert(field, '"')
        i = i + 1
      else
        inQuotes = not inQuotes
      end
    elseif ch == "," and not inQuotes then
      table.insert(fields, table.concat(field))
      field = {}
    else
      table.insert(field, ch)
    end
    i = i + 1
  end
  table.insert(fields, table.concat(field))
  for idx, value in ipairs(fields) do
    fields[idx] = value:match("^%s*(.-)%s*$")
  end
  return fields
end

function NebbieDash.normalizeBatchKey(raw)
  local key = (raw or ""):lower()
  key = key:gsub("%s+", "-")
  key = key:gsub("-+", "-")
  return key
end

function NebbieDash.batchEdToonKey(nomeToon)
  return "ED" .. (nomeToon or "")
end

function NebbieDash.substituteBatchVars(template, row, batch)
  local out = template or ""
  out = out:gsub("%$o", function()
    return NebbieDash.batchEdToonKey(row and row.nomeToon)
  end)
  out = out:gsub("%$ed", function()
    return NebbieDash.batchEdToonKey(row.nomeToon)
  end)
  out = out:gsub("%$(%d)", function(n)
    n = tonumber(n)
    if n == 1 then return row.nomeToon or "" end
    if n == 2 then return row.keyNorm or "" end
    if n == 3 then return tostring(row.vnumAttuale or "") end
    if n == 4 then return tostring(row.vnumOriginale or "") end
    return ""
  end)
  return out
end

function NebbieDash.loadBatchCommands()
  NebbieDash.ensureBatchCommandsFile()
  NebbieDash.batchCommands = {}
  local path = NebbieDash.batchCommandsPath()
  local f = io.open(path, "r")
  if not f then return end
  for rawLine in f:lines() do
    local line2 = rawLine:match("^%s*(.-)%s*$")
    if line2 ~= "" and line2:sub(1, 1) ~= "#" then
      table.insert(NebbieDash.batchCommands, line2)
    end
  end
  f:close()
end

function NebbieDash.loadIdentBatchCommands()
  NebbieDash.ensureIdentBatchCommandsFile()
  NebbieDash.identBatchCommands = {}
  local path = NebbieDash.identBatchCommandsPath()
  local f = io.open(path, "r")
  if not f then return end
  for rawLine in f:lines() do
    local line2 = rawLine:match("^%s*(.-)%s*$")
    if line2 ~= "" and line2:sub(1, 1) ~= "#" then
      table.insert(NebbieDash.identBatchCommands, line2)
    end
  end
  f:close()
  NebbieDash.validateIdentBatchCommands()
end

function NebbieDash.validateIdentBatchCommands()
  local warnings = {}
  for _, cmd in ipairs(NebbieDash.identBatchCommands or {}) do
    if cmd:match("^stat%s") then
      table.insert(warnings,
        "riga 'stat ...' — stat cerca nel MONDO, non l'oggetto oloadato; usa solo identify/junk con $ed")
    end
    if cmd:find("%$2", 1, true) then
      table.insert(warnings,
        "placeholder $2 (key CSV) — usa $ed o $o (= ED+nome-toon da colonna $1)")
    end
  end
  if #warnings > 0 then
    cecho("<orange>[NebbieDash] Attenzione nebbie-ident-batch-commands.txt:\n")
    for _, msg in ipairs(warnings) do
      cecho("<orange>  - " .. msg .. "\n")
    end
  end
end

function NebbieDash.csvEscapeField(value)
  value = tostring(value or "")
  if value:find('[,"\n\r]') then
    return '"' .. value:gsub('"', '""') .. '"'
  end
  return value
end

-- Output identify reale (2026-09-22):
--   Oggetto: 'verse13 move lips EDEchoes', Tipo di Oggetto ARMOR V-Number Originario: 8304
--   L'oggetto e': ORGANIC MAGIC ... EDIT PERSONAL
--   Ti puo' dare : RESISTANCE by SLASH
NebbieDash.IDENT_BATCH_AFFECT_COUNT = 5

function NebbieDash.parseIdentifyBatchAffects(lines)
  local affects = {}
  for _, text in ipairs(lines or {}) do
    local aff = text:match("Ti puo' dare%s*:%s*(.-)%s*$")
    if aff and aff ~= "" then
      table.insert(affects, aff)
    end
  end
  return affects
end

function NebbieDash.parseIdentifyBatchOutput(lines)
  local objName, objType, flags, vnumOriginario
  for _, text in ipairs(lines or {}) do
    if not objName then
      objName, objType, vnumOriginario = text:match(
        "Oggetto: '([^']+)', Tipo di Oggetto (%S+) V%-Number Originario: (%d+)")
    end
    if not vnumOriginario then
      vnumOriginario = text:match("V%-Number Originario:%s*(%d+)")
    end
    if not flags then
      flags = text:match("^L'oggetto e':%s*(.-)%s*$")
    end
  end
  return objName, objType, flags, vnumOriginario
end

NebbieDash.IDENT_BATCH_CSV_HEADER =
  "object-name,type,extra-flags,vnum-attuale,vnum-originario," ..
  "affect-1,affect-2,affect-3,affect-4,affect-5"

function NebbieDash.identBatchEnsureResultsHeader(resultsPath)
  if type(io.exists) == "function" and io.exists(resultsPath) then
    local f = io.open(resultsPath, "r")
    if f then
      local first = f:read("*l")
      f:close()
      if first and first ~= "" then
        return true
      end
    end
  end
  local f = io.open(resultsPath, "a")
  if not f then
    return false, "impossibile creare CSV: " .. tostring(resultsPath)
  end
  f:write(NebbieDash.IDENT_BATCH_CSV_HEADER .. "\n")
  f:close()
  return true
end

function NebbieDash.identBatchAppendRow(row, rowLines, resultsPath)
  local objName, objType, flags, vnumOriginario = NebbieDash.parseIdentifyBatchOutput(rowLines)
  if not objName or objName == "" or not objType or objType == "" then
    return false, "identify non parsato per riga CSV: " .. tostring(row.rawLine or row.keyNorm or "?")
  end
  if not vnumOriginario or vnumOriginario == "" then
    return false, "V-Number Originario non parsato per riga CSV: " .. tostring(row.rawLine or "?")
  end
  local okHeader, headerErr = NebbieDash.identBatchEnsureResultsHeader(resultsPath)
  if not okHeader then
    return false, headerErr
  end
  local affects = NebbieDash.parseIdentifyBatchAffects(rowLines)
  local cols = {
    NebbieDash.csvEscapeField(objName),
    NebbieDash.csvEscapeField(objType),
    NebbieDash.csvEscapeField(flags or ""),
    NebbieDash.csvEscapeField(row.vnumAttuale or ""),
    NebbieDash.csvEscapeField(vnumOriginario),
  }
  for i = 1, NebbieDash.IDENT_BATCH_AFFECT_COUNT do
    table.insert(cols, NebbieDash.csvEscapeField(affects[i] or ""))
  end
  local line = table.concat(cols, ",")
  local f = io.open(resultsPath, "a")
  if not f then
    return false, "impossibile scrivere CSV: " .. tostring(resultsPath)
  end
  f:write(line .. "\n")
  f:close()
  return true
end

-- Righe gia' scritte nel CSV risultati (colonna vnum-attuale = campo 4).
function NebbieDash.identBatchLoadProcessedVnums(resultsPath)
  local done = {}
  local f = io.open(resultsPath, "r")
  if not f then return done end
  local headerDone = false
  for rawLine in f:lines() do
    local line2 = rawLine:match("^%s*(.-)%s*$")
    if line2 ~= "" then
      if not headerDone then
        headerDone = true
      else
        local fields = NebbieDash.parseCsvLine(line2)
        local vnum = fields[4]
        if vnum and vnum ~= "" then
          done[vnum] = true
        end
      end
    end
  end
  f:close()
  return done
end

function NebbieDash.identBatchFilterUnprocessedRows(rows, processedVnums)
  local out = {}
  for _, row in ipairs(rows or {}) do
    local vnum = row.vnumAttuale or ""
    if vnum == "" or not processedVnums[vnum] then
      table.insert(out, row)
    end
  end
  return out
end

function NebbieDash.identBatchParseFilter(filterStr)
  filterStr = (filterStr or ""):match("^%s*(.-)%s*$") or ""
  if filterStr:lower():match("^resume$") or filterStr:lower():match("^resume%s+") then
    local toon = filterStr:match("^[Rr]esume%s+(.*)$") or ""
    toon = toon:match("^%s*(.-)%s*$") or ""
    return true, toon
  end
  return false, filterStr
end

function NebbieDash.loadBatchItems()
  NebbieDash.ensureBatchItemsFile()
  NebbieDash.batchItems = {}
  local path = NebbieDash.batchItemsPath()
  local f = io.open(path, "r")
  if not f then return end
  local headerDone = false
  for rawLine in f:lines() do
    local line2 = rawLine:match("^%s*(.-)%s*$")
    if line2 ~= "" and line2:sub(1, 1) ~= "#" then
      if not headerDone then
        headerDone = true
      else
        local fields = NebbieDash.parseCsvLine(line2)
        if #fields >= 4 then
          table.insert(NebbieDash.batchItems, {
            nomeToon = fields[1],
            keyRaw = fields[2],
            keyNorm = NebbieDash.normalizeBatchKey(fields[2]),
            vnumAttuale = fields[3],
            vnumOriginale = fields[4],
            rawLine = line2,
          })
        end
      end
    end
  end
  f:close()
end

function NebbieDash.filterBatchRows(rows, filterStr)
  filterStr = (filterStr or ""):match("^%s*(.-)%s*$")
  if filterStr == "" then return rows end
  local want = filterStr:lower()
  local out = {}
  for _, row in ipairs(rows or {}) do
    if (row.nomeToon or ""):lower() == want then
      table.insert(out, row)
    end
  end
  return out
end

function NebbieDash.batchDetectError(lines)
  for _, text in ipairs(lines or {}) do
    for _, pattern in ipairs(NebbieDash.BATCH_ERROR_PATTERNS) do
      if text:find(pattern, 1, true) then
        return true, text
      end
    end
  end
  return false
end

function NebbieDash.batchOloadSucceeded(lines)
  for _, text in ipairs(lines or {}) do
    if text:match("^Adesso hai .+%.%s*$") then
      return true
    end
  end
  return false
end

function NebbieDash.batchIsOloadCommand(template)
  return (template or ""):match("^oload%s") ~= nil
end

function NebbieDash.batchStepHasPrompt(lines)
  for _, text in ipairs(lines or {}) do
    if NebbieDash.isAnyPromptLine(text) then
      return true
    end
  end
  return false
end

-- oload: attende sia "Adesso hai ..." sia un prompt (ordine variabile: sysmess puo'
-- far comparire il prompt prima del messaggio oload).
function NebbieDash.batchOloadStepReady(lines, promptText)
  if not NebbieDash.batchOloadSucceeded(lines) then
    return false
  end
  if promptText and NebbieDash.isAnyPromptLine(promptText) then
    return true
  end
  return NebbieDash.batchStepHasPrompt(lines)
end

function NebbieDash.batchTryCompleteOloadStep(promptText)
  local b = NebbieDash._batch
  if not b or not b.active or not b.awaitingOutput or b.waitMode ~= "prompt" then
    return false
  end
  if not NebbieDash.batchOloadStepReady(b.stepLines, promptText) then
    return false
  end
  NebbieDash.onBatchStepComplete(promptText)
  return true
end

function NebbieDash.batchTemplateUsesOloadKey(template)
  local t = template or ""
  return t:find("$o", 1, true) ~= nil or t:find("$ed", 1, true) ~= nil
end

function NebbieDash.batchAppendToLog(nomeToon, text)
  local b = NebbieDash._batch
  if b and b.mode == "ident" then
    return true
  end
  local path = NebbieDash.batchLogPath(nomeToon)
  local f = io.open(path, "a")
  if not f then
    cecho("<red>[NebbieDash] Impossibile scrivere log: " .. path .. "\n")
    return false
  end
  f:write(text)
  f:close()
  return true
end

function NebbieDash.batchEnsureLogSection(b, row)
  local header = string.format(
    "\n========== batch %s (%s) ==========\n",
    os.date("%Y-%m-%d %H:%M:%S"),
    b.filterLabel or "tutte"
  )
  local rowHeader = string.format(
    "\n--- riga %d — %s ---\nCSV: %s\n",
    b.rowIdx,
    os.date("%H:%M:%S"),
    row.rawLine or ""
  )
  if b.currentLogToon ~= row.nomeToon then
    b.currentLogToon = row.nomeToon
    b.logSectionStarted = false
  end
  if not b.logSectionStarted then
    NebbieDash.batchAppendToLog(row.nomeToon, header)
    b.logSectionStarted = true
  end
  NebbieDash.batchAppendToLog(row.nomeToon, rowHeader)
end

function NebbieDash.batchEnableLineCapture()
  if NebbieDash._batchLineTrig then
    pcall(function() killTrigger(NebbieDash._batchLineTrig) end)
  end
  if type(tempRegexTrigger) == "function" then
    NebbieDash._batchLineTrig = tempRegexTrigger("^", [[NebbieDash.onBatchLine()]])
  end
end

function NebbieDash.batchDisableLineCapture()
  if NebbieDash._batchLineTrig then
    pcall(function() killTrigger(NebbieDash._batchLineTrig) end)
    NebbieDash._batchLineTrig = nil
  end
end

function NebbieDash.batchIsEnterCommand(template)
  return (template or ""):match("^%s*%[enter%]%s*$") ~= nil
end

function NebbieDash.batchIsNcharCommand(template)
  return (template or ""):match("^%s*nchar%s+") ~= nil
end

function NebbieDash.batchCommandsWithNcharPrefix(commands)
  local out = {}
  if not commands or #commands == 0 then
    return { "nchar Sirio" }
  end
  local first = (commands[1] or ""):match("^%s*(.-)%s*$")
  if first:lower():match("^nchar%s+sirio%s*$") then
    return commands
  end
  table.insert(out, "nchar Sirio")
  for _, cmd in ipairs(commands) do
    table.insert(out, cmd)
  end
  return out
end

function NebbieDash.batchRunNcharCommand(template, row)
  local substituted = NebbieDash.substituteBatchVars(template, row)
  local name = substituted:match("^%s*nchar%s+(.+)$")
  if name then
    name = name:match("^%s*(.-)%s*$")
  end
  if name and name ~= "" then
    NebbieDash.cmdSetCharacter(name)
  end
end

function NebbieDash.batchSetsMenuWait(sentCmd)
  return (sentCmd or ""):match("^oedit%s") ~= nil
end

function NebbieDash.batchOutputHasMenuReady(lines)
  for _, text in ipairs(lines or {}) do
    if text:match(NebbieDash.BATCH_MENU_READY_PATTERN) then
      return true
    end
  end
  return false
end

function NebbieDash.batchPrepareCommand(template, row, batch)
  if NebbieDash.batchIsEnterCommand(template) then
    return "", "[enter]", "prompt"
  end
  if NebbieDash.batchIsNcharCommand(template) then
    local logLabel = NebbieDash.substituteBatchVars(template, row, batch):match("^%s*(.-)%s*$")
    return nil, logLabel, "local"
  end
  if NebbieDash.batchTemplateUsesOloadKey(template) then
    if not row or not row.nomeToon or row.nomeToon == "" then
      return nil, template, "missing_o"
    end
    if not batch or not batch.oloadDone then
      return nil, template, "missing_o"
    end
  end
  local cmd = NebbieDash.substituteBatchVars(template, row, batch)
  local waitMode = NebbieDash.batchSetsMenuWait(cmd) and "menu" or "prompt"
  return cmd, cmd, waitMode
end

function NebbieDash.onBatchLine()
  local b = NebbieDash._batch
  if not b or not b.active or not b.awaitingOutput then return end
  local text = line
  if (not text or text == "") and type(getCurrentLine) == "function" then
    text = getCurrentLine()
  end
  text = text or ""
  table.insert(b.stepLines, text)
  if b.waitMode == "menu" and NebbieDash.batchOutputHasMenuReady(b.stepLines) then
    NebbieDash.onBatchStepComplete(nil)
    return
  end
  if b.waitMode == "prompt" then
    local tmpl = b.commands[b.cmdIdx]
    if NebbieDash.batchIsOloadCommand(tmpl) then
      NebbieDash.batchTryCompleteOloadStep(text)
    elseif NebbieDash.isAnyPromptLine(text) then
      NebbieDash.onBatchStepComplete(text)
    end
  end
end

function NebbieDash.onBatchPrompt(promptText)
  local b = NebbieDash._batch
  if not b or not b.active or not b.awaitingOutput or b.waitMode ~= "prompt" then return end
  local tmpl = b.commands[b.cmdIdx]
  if NebbieDash.batchIsOloadCommand(tmpl) then
    NebbieDash.batchTryCompleteOloadStep(promptText)
    return
  end
  NebbieDash.onBatchStepComplete(promptText)
end

function NebbieDash.onBatchStepComplete(promptText)
  local b = NebbieDash._batch
  if not b or not b.active or not b.awaitingOutput then return end
  b.awaitingOutput = false
  if b.timeoutId and type(killTimer) == "function" then
    pcall(killTimer, b.timeoutId)
    b.timeoutId = nil
  end

  if promptText and promptText ~= "" then
    local last = b.stepLines[#b.stepLines]
    if last ~= promptText then
      table.insert(b.stepLines, promptText)
    end
  end

  local block = table.concat(b.stepLines, "\n")
  if block ~= "" then
    NebbieDash.batchAppendToLog(b.currentLogToon, block .. "\n")
  end

  local err, errLine = NebbieDash.batchDetectError(b.stepLines)
  local tmpl = b.commands[b.cmdIdx]
  if err then
    if b.mode == "ident" and tmpl and tmpl:match("^stat%s") then
      NebbieDash.batchAppendToLog(b.currentLogToon,
        string.format("[NebbieDash] stat ignorato (ident batch): %s\n", tostring(errLine)))
      cecho("<orange>[NebbieDash] stat fallito (cerca nel mondo), continuo identify/junk con $ed...\n")
    else
      NebbieDash.batchStop("fermato — errore MUD: " .. tostring(errLine))
      return
    end
  end

  if tmpl and tmpl:match("^oload%s") then
    if not NebbieDash.batchOloadSucceeded(b.stepLines) then
      NebbieDash.batchStop("fermato — oload non confermato ('Adesso hai ...' mancante)")
      return
    end
    b.oloadDone = true
  end

  if b.mode == "ident" then
    b.rowLines = b.rowLines or {}
    for _, text in ipairs(b.stepLines) do
      table.insert(b.rowLines, text)
    end
    if b.cmdIdx == #b.commands then
      local row = b.rows[b.rowIdx]
      local ok, parseErr = NebbieDash.identBatchAppendRow(row, b.rowLines, b.identResultsPath)
      if not ok then
        NebbieDash.batchStop("fermato — " .. tostring(parseErr))
        return
      end
      b.rowLines = {}
    end
  end

  b.cmdIdx = b.cmdIdx + 1
  b.waitMode = "prompt"
  NebbieDash.batchRunCurrentStep()
end

function NebbieDash.batchRunCurrentStep()
  local b = NebbieDash._batch
  if not b or not b.active then return end

  if b.rowIdx > #b.rows then
    NebbieDash.batchStop("completato (" .. #b.rows .. " righe)")
    return
  end

  if b.cmdIdx > #b.commands then
    b.rowIdx = b.rowIdx + 1
    b.cmdIdx = 1
    return NebbieDash.batchRunCurrentStep()
  end

  local row = b.rows[b.rowIdx]
  if b.cmdIdx == 1 then
    NebbieDash.batchEnsureLogSection(b, row)
    b.currentLogToon = row.nomeToon
    b.oloadDone = false
    if b.mode == "ident" then
      b.rowLines = {}
    end
  end

  local template = b.commands[b.cmdIdx]
  local sendCmd, logLabel, waitMode = NebbieDash.batchPrepareCommand(template, row, b)
  if waitMode == "missing_o" then
    NebbieDash.batchStop("fermato — $o non disponibile (manca oload $3 o nome-toon CSV)")
    return
  end
  b.stepLines = {}
  b.awaitingOutput = true
  b.waitMode = waitMode
  NebbieDash.batchAppendToLog(row.nomeToon, string.format("[%s] >>> %s\n", os.date("%H:%M:%S"), logLabel))
  if b.mode == "ident" and sendCmd and sendCmd ~= "" then
    cecho("<grey>[NebbieDash ident] >>> " .. sendCmd .. "\n")
  end
  if waitMode == "local" then
    NebbieDash.batchRunNcharCommand(template, row)
    NebbieDash.onBatchStepComplete(nil)
    return
  end
  send(sendCmd, false)

  if type(tempTimer) == "function" then
    local timeoutLabel = logLabel
    b.timeoutId = tempTimer(NebbieDash.batchTimeoutSec, function()
      if b.awaitingOutput then
        local hint = (b.waitMode == "menu") and " (menu oedit, atteso '-->')" or " (atteso prompt Sirio)"
        NebbieDash.batchStop("timeout dopo: " .. timeoutLabel .. hint)
      end
    end)
  end
end

function NebbieDash.batchStop(reason)
  local b = NebbieDash._batch
  if b and b.currentLogToon then
    NebbieDash.batchAppendToLog(b.currentLogToon,
      string.format("\n--- batch terminato: %s (%s) ---\n", reason or "?", os.date("%H:%M:%S")))
  end
  NebbieDash.batchDisableLineCapture()
  if b and b.timeoutId and type(killTimer) == "function" then
    pcall(killTimer, b.timeoutId)
  end
  NebbieDash._batch = nil
  local tone = (reason and reason:find("completato")) and "green" or "orange"
  local batchLabel = (b and b.mode == "ident") and "Ident batch" or "Batch"
  cecho("<" .. tone .. ">[NebbieDash] " .. batchLabel .. ": " .. tostring(reason) .. "\n")
  if b and b.mode == "ident" and b.identResultsPath and reason and reason:find("completato") then
    cecho("<green>  CSV risultati: " .. b.identResultsPath .. "\n")
  end
end

function NebbieDash.cmdReloadBatch()
  NebbieDash.loadBatchCommands()
  NebbieDash.loadIdentBatchCommands()
  NebbieDash.loadBatchItems()
  cecho("<green>[NebbieDash] Batch ricaricato: " .. #NebbieDash.batchCommands ..
    " comandi, " .. #NebbieDash.batchItems .. " righe CSV.\n")
  cecho("<grey>  " .. NebbieDash.batchCommandsPath() .. "\n")
  cecho("<grey>  " .. NebbieDash.batchItemsPath() .. "\n")
end

function NebbieDash.cmdReloadIdentBatch()
  NebbieDash.loadIdentBatchCommands()
  NebbieDash.loadBatchItems()
  cecho("<green>[NebbieDash] Ident batch ricaricato: " .. #NebbieDash.identBatchCommands ..
    " comandi, " .. #NebbieDash.batchItems .. " righe CSV.\n")
  cecho("<grey>  " .. NebbieDash.identBatchCommandsPath() .. "\n")
  cecho("<grey>  " .. NebbieDash.batchItemsPath() .. "\n")
end

function NebbieDash.startBatchJob(mode, filterStr, commands, filterLabel, startMsg, rowsOverride)
  if NebbieDash._batch and NebbieDash._batch.active then
    cecho("<orange>[NebbieDash] Batch gia' in esecuzione.\n")
    return false
  end
  commands = NebbieDash.batchCommandsWithNcharPrefix(commands)
  if #commands == 0 then
    cecho("<orange>[NebbieDash] Nessun comando configurato.\n")
    return false
  end
  if #NebbieDash.batchItems == 0 then
    cecho("<orange>[NebbieDash] Nessuna riga in " .. NebbieDash.batchItemsPath() .. "\n")
    return false
  end

  filterStr = (filterStr or ""):match("^%s*(.-)%s*$")
  local rows = rowsOverride or NebbieDash.filterBatchRows(NebbieDash.batchItems, filterStr)
  if #rows == 0 then
    cecho("<orange>[NebbieDash] Nessuna riga CSV corrisponde al filtro" ..
      (filterStr ~= "" and (" '" .. filterStr .. "'") or "") .. ".\n")
    return false
  end

  local identResultsPath = nil
  if mode == "ident" then
    identResultsPath = NebbieDash.identBatchResultsPath()
  end

  NebbieDash._batch = {
    active = true,
    mode = mode,
    rows = rows,
    commands = commands,
    rowIdx = 1,
    cmdIdx = 1,
    stepLines = {},
    rowLines = {},
    currentLogToon = nil,
    logSectionStarted = false,
    filterLabel = filterLabel,
    awaitingOutput = false,
    waitMode = "prompt",
    identResultsPath = identResultsPath,
    oloadDone = false,
  }

  cecho("<cyan>[NebbieDash] " .. startMsg .. "\n")
  NebbieDash.batchEnableLineCapture()
  NebbieDash.batchRunCurrentStep()
  return true
end

function NebbieDash.cmdBatch(filterStr)
  NebbieDash.loadBatchCommands()
  NebbieDash.loadBatchItems()
  if #NebbieDash.batchCommands == 0 then
    cecho("<orange>[NebbieDash] Nessun comando in " .. NebbieDash.batchCommandsPath() .. "\n")
    return
  end
  filterStr = (filterStr or ""):match("^%s*(.-)%s*$")
  local label = (filterStr ~= "" and ("nbatch " .. filterStr)) or "nbatch"
  NebbieDash.startBatchJob(
    "admin",
    filterStr,
    NebbieDash.batchCommands,
    label,
    "Batch avviato: " .. #NebbieDash.filterBatchRows(NebbieDash.batchItems, filterStr) ..
      " righe, " .. #NebbieDash.batchCommands .. " comandi/riga. Log: <Toon>-YYYY-MM-DD.txt"
  )
end

function NebbieDash.cmdIdentBatch(filterStr)
  NebbieDash.loadIdentBatchCommands()
  NebbieDash.loadBatchItems()
  if #NebbieDash.identBatchCommands == 0 then
    cecho("<orange>[NebbieDash] Nessun comando in " .. NebbieDash.identBatchCommandsPath() .. "\n")
    return
  end
  local resume, toonFilter = NebbieDash.identBatchParseFilter(filterStr)
  local label
  if resume then
    label = (toonFilter ~= "" and ("nidentbatch resume " .. toonFilter)) or "nidentbatch resume"
  else
    label = (toonFilter ~= "" and ("nidentbatch " .. toonFilter)) or "nidentbatch"
  end

  local rows = NebbieDash.filterBatchRows(NebbieDash.batchItems, toonFilter)
  local skipped = 0
  local resultsPath = NebbieDash.identBatchResultsPath()
  if resume then
    local processed = NebbieDash.identBatchLoadProcessedVnums(resultsPath)
    local before = #rows
    rows = NebbieDash.identBatchFilterUnprocessedRows(rows, processed)
    skipped = before - #rows
    if skipped > 0 then
      cecho("<grey>[NebbieDash] Resume: " .. skipped ..
        " righe gia' nel CSV di oggi, saltate.\n")
      cecho("<grey>  " .. resultsPath .. "\n")
    end
    if #rows == 0 then
      cecho("<green>[NebbieDash] Ident batch resume: nessuna riga rimanente" ..
        (skipped > 0 and (" (" .. skipped .. " gia' completate).") or ".") .. "\n")
      return
    end
  end

  local startMsg
  if resume then
    startMsg = "Ident batch ripreso: " .. #rows .. " righe rimanenti" ..
      (skipped > 0 and (", " .. skipped .. " saltate (gia' in CSV)") or "") ..
      ", " .. #NebbieDash.identBatchCommands .. " comandi/riga. CSV: " ..
      resultsPath .. " (append, nessun log <Toon>-YYYY-MM-DD.txt)"
  else
    startMsg = "Ident batch avviato: " .. #rows .. " righe, " .. #NebbieDash.identBatchCommands ..
      " comandi/riga. CSV: " .. resultsPath ..
      " (nessun log <Toon>-YYYY-MM-DD.txt)"
  end

  NebbieDash.startBatchJob(
    "ident",
    toonFilter,
    NebbieDash.identBatchCommands,
    label,
    startMsg,
    rows
  )
end

function NebbieDash.rowFromCsvLine(csvLine)
  local fields = NebbieDash.parseCsvLine(csvLine or "")
  if #fields < 4 then return nil end
  return {
    nomeToon = fields[1],
    keyRaw = fields[2],
    keyNorm = NebbieDash.normalizeBatchKey(fields[2]),
    vnumAttuale = fields[3],
    vnumOriginale = fields[4],
    rawLine = csvLine,
  }
end

function NebbieDash.parseBatchLogSections(content)
  local sections = {}
  if not content or content == "" then return sections end
  local lines = {}
  for line in content:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end
  local i = 1
  while i <= #lines do
    local rowIdx, time = lines[i]:match("^--- riga (%d+) — (.+) ---$")
    if rowIdx then
      local csvLine = ""
      if lines[i + 1] and lines[i + 1]:match("^CSV: ") then
        csvLine = lines[i + 1]:sub(6)
        i = i + 1
      end
      local block = {}
      i = i + 1
      while i <= #lines do
        local l = lines[i]
        if l:match("^--- riga %d+") or l:match("^========== batch ") or l:match("^--- batch terminato") then
          break
        end
        table.insert(block, l)
        i = i + 1
      end
      table.insert(sections, {
        rowIdx = tonumber(rowIdx),
        time = time,
        csvLine = csvLine,
        lines = block,
      })
    else
      i = i + 1
    end
  end
  return sections
end

function NebbieDash.batchSectionHasCommand(blockText, logLabel)
  if not blockText or not logLabel or logLabel == "" then return false end
  if blockText:find(">>> " .. logLabel, 1, true) then return true end
  local escaped = logLabel:gsub("([%-%.%+%*%?%[%]%^%$%(%)%%])", "%%%1")
  return blockText:find("%] >>> " .. escaped, 1) ~= nil
end

function NebbieDash.batchSectionFindOsaveSuccess(blockText, vnumAttuale, vnumOriginale)
  if not blockText then return false end
  local va, vo = tostring(vnumAttuale or ""), tostring(vnumOriginale or "")
  if va == "" then return false end
  local pattern = "Ho salvato .+ con il vnum " .. va:gsub("([%-%.%+%*%?%[%]%^%$%(%)%%])", "%%%1")
    .. " %(originale " .. vo:gsub("([%-%.%+%*%?%[%]%^%$%(%)%%])", "%%%1") .. "%)"
  return blockText:find(pattern) ~= nil
end

function NebbieDash.verifyBatchSection(section, row, commands)
  local issues = {}
  if not section or not row then
    table.insert(issues, "sezione o riga CSV non valida")
    return false, issues
  end
  local blockText = table.concat(section.lines or {}, "\n")
  for _, line in ipairs(section.lines or {}) do
    local err, errLine = NebbieDash.batchDetectError({ line })
    if err then
      table.insert(issues, "errore MUD: " .. tostring(errLine))
    end
  end
  for _, tmpl in ipairs(commands or {}) do
    local _, logLabel = NebbieDash.batchPrepareCommand(tmpl, row)
    if not NebbieDash.batchSectionHasCommand(blockText, logLabel) then
      table.insert(issues, "comando mancante nel log: " .. logLabel)
    end
  end
  local wantsOsave = false
  for _, tmpl in ipairs(commands or {}) do
    if (tmpl or ""):find("osave", 1, true) then
      wantsOsave = true
      break
    end
  end
  if wantsOsave and not NebbieDash.batchSectionFindOsaveSuccess(blockText, row.vnumAttuale, row.vnumOriginale) then
    local gotVa, gotVo = blockText:match("Ho salvato .+ con il vnum (%d+) %(originale (%d+)%)")
    if gotVa then
      table.insert(issues, string.format(
        "osave: atteso vnum %s (orig %s), nel log %s (orig %s)",
        tostring(row.vnumAttuale), tostring(row.vnumOriginale), gotVa, gotVo or "?"))
    else
      table.insert(issues, "messaggio osave di successo non trovato (Ho salvato ... con il vnum ...)")
    end
  end
  return #issues == 0, issues
end

function NebbieDash.readTextFile(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  return content
end

function NebbieDash.writeTextFile(path, content)
  local f = io.open(path, "w")
  if not f then return false end
  f:write(content or "")
  f:close()
  return true
end

function NebbieDash.batchVerifyReportPath(nomeToon, dateStr)
  local home = (type(getMudletHomeDir) == "function" and getMudletHomeDir()) or "."
  return home .. "/" .. (nomeToon or "unknown") .. "-" .. (dateStr or os.date("%Y-%m-%d")) .. ".verify.txt"
end

function NebbieDash.verifyBatchLogFile(logPath, commands, filterRows)
  local content = NebbieDash.readTextFile(logPath)
  if not content then
    return false, { "file log non leggibile: " .. tostring(logPath) }, {}
  end
  local sections = NebbieDash.parseBatchLogSections(content)
  if #sections == 0 then
    return false, { "nessuna sezione '--- riga N ---' nel log" }, {}
  end
  local expectedByCsv = {}
  for _, row in ipairs(filterRows or {}) do
    expectedByCsv[row.rawLine or ""] = row
  end
  local results = {}
  local issues = {}
  local okCount = 0
  for _, section in ipairs(sections) do
    local row = NebbieDash.rowFromCsvLine(section.csvLine)
    if not row then
      table.insert(issues, "riga " .. tostring(section.rowIdx) .. ": CSV non parsabile")
      table.insert(results, { section = section, ok = false, issues = { "CSV non parsabile" } })
    elseif expectedByCsv[row.rawLine] == nil and #filterRows > 0 then
      table.insert(issues, "riga " .. tostring(section.rowIdx) .. ": non presente nel CSV filtrato")
      table.insert(results, { section = section, row = row, ok = false, issues = { "non nel CSV atteso" } })
    else
      local ok, rowIssues = NebbieDash.verifyBatchSection(section, row, commands)
      if ok then okCount = okCount + 1 else
        for _, msg in ipairs(rowIssues) do
          table.insert(issues, "riga " .. tostring(section.rowIdx) .. " (" .. (row.keyNorm or "?") .. "): " .. msg)
        end
      end
      table.insert(results, { section = section, row = row, ok = ok, issues = rowIssues })
    end
  end
  local expectedCount = #filterRows
  if expectedCount > 0 and okCount < expectedCount then
    local seen = {}
    for _, r in ipairs(results) do
      if r.row and r.row.rawLine then seen[r.row.rawLine] = true end
    end
    for _, row in ipairs(filterRows) do
      if not seen[row.rawLine or ""] then
        table.insert(issues, "riga CSV mai eseguita (assente dal log): " .. (row.rawLine or "?"))
      end
    end
  end
  if not content:find("batch terminato: completato") then
    local reason = content:match("--- batch terminato: ([^\n]+) ---")
    if reason then
      table.insert(issues, "batch non completato: " .. reason)
    end
  end
  return #issues == 0, issues, results
end

function NebbieDash.cmdVerifyBatch(argStr)
  argStr = (argStr or ""):match("^%s*(.-)%s*$")
  NebbieDash.loadBatchCommands()
  NebbieDash.loadBatchItems()

  local toonFilter, dateStr = nil, os.date("%Y-%m-%d")
  if argStr ~= "" then
    local a, b = argStr:match("^(%S+)%s+(%d%d%d%d%-%d%d%-%d%d)$")
    if a and b then
      toonFilter, dateStr = a, b
    else
      toonFilter = argStr:match("^(%S+)$")
    end
  end

  local rows = NebbieDash.filterBatchRows(NebbieDash.batchItems, toonFilter or "")
  if toonFilter and #rows == 0 then
    cecho("<orange>[NebbieDash] nbatchverify: nessuna riga CSV per '" .. toonFilter .. "'.\n")
    return
  end
  if #rows == 0 then
    rows = NebbieDash.batchItems
  end

  local toons = {}
  local toonSet = {}
  for _, row in ipairs(rows) do
    if row.nomeToon and not toonSet[row.nomeToon] then
      toonSet[row.nomeToon] = true
      table.insert(toons, row.nomeToon)
    end
  end

  local grandOk = true
  local reportHeader = {
    "NebbieDash nbatchverify — " .. os.date("%Y-%m-%d %H:%M:%S"),
    "CSV: " .. NebbieDash.batchItemsPath(),
    "Comandi: " .. NebbieDash.batchCommandsPath(),
    "Data log: " .. dateStr,
    "",
  }

  for _, toon in ipairs(toons) do
    local toonRows = NebbieDash.filterBatchRows(rows, toon)
    local logPath = (type(getMudletHomeDir) == "function" and getMudletHomeDir() or ".")
      .. "/" .. toon .. "-" .. dateStr .. ".txt"
    local reportLines = {}
    for _, line in ipairs(reportHeader) do table.insert(reportLines, line) end
    table.insert(reportLines, "=== " .. toon .. " ===")
    table.insert(reportLines, "Log: " .. logPath)
    local ok, issues, results = NebbieDash.verifyBatchLogFile(
      logPath, NebbieDash.batchCommandsWithNcharPrefix(NebbieDash.batchCommands), toonRows)
    if not ok then grandOk = false end
    local okN, totN = 0, #results
    for _, r in ipairs(results) do if r.ok then okN = okN + 1 end end
    table.insert(reportLines, string.format("Esito: %d/%d righe OK", okN, totN))
    for _, msg in ipairs(issues) do
      table.insert(reportLines, "  FAIL: " .. msg)
    end
    if ok then
      table.insert(reportLines, "  PASS")
    end
    table.insert(reportLines, "")
    local reportPath = NebbieDash.batchVerifyReportPath(toon, dateStr)
    NebbieDash.writeTextFile(reportPath, table.concat(reportLines, "\n") .. "\n")
    cecho((ok and "<green>" or "<orange>") .. "[NebbieDash] " .. toon .. ": " .. okN .. "/" .. totN ..
      " righe OK — report " .. reportPath .. "\n")
  end

  if grandOk then
    cecho("<green>[NebbieDash] nbatchverify: tutti i log verificati OK.\n")
  else
    cecho("<orange>[NebbieDash] nbatchverify: errori trovati (vedi report .verify.txt).\n")
  end
end

-- ---------------------------------------------------------------------------
-- Installazione trigger — IDEMPOTENTE (2026-08-10): elimina prima eventuali
-- trigger dinamici creati da un boot precedente, poi li ricrea. Prima di
-- questo fix, un guard "una volta sola per sempre" (_triggersInstalled)
-- impediva a `installTriggers()` di rifare qualsiasi cosa dopo il primo
-- avvio della sessione Lua di Mudlet: reinstallare il pacchetto A CALDO
-- (senza riavviare Mudlet) faceva ripartire lo script principale — che
-- ridefinisce le funzioni, quindi la LOGICA si aggiornava — ma qualsiasi
-- trigger NUOVO introdotto dalla versione aggiornata (es. quelli per fame/
-- sete in questa stessa release) non veniva mai creato, perche' il guard
-- bloccava `installTriggers()` fin dall'inizio. Da qui il sintomo segnalato
-- "serve rilanciare Mudlet ogni volta che carico un nuovo package": non era
-- un limite di Mudlet, era che il nostro script non permetteva mai a se
-- stesso di ri-registrare i trigger dopo il primo avvio della sessione.
function NebbieDash.teardownTriggers()
  local ids = {
    NebbieDash._promptTrig, NebbieDash._promptImmTrig, NebbieDash._eqOpenTrig, NebbieDash._attribOpenTrig,
    NebbieDash._eqLineTrig, NebbieDash._attribLineTrig, NebbieDash._lootLineTrig,
    NebbieDash._lootLineTrig2, NebbieDash._groupSoloTrig, NebbieDash._groupHeaderTrig, NebbieDash._combatEndTrig,
    NebbieDash._combatEndTrig2,
    NebbieDash._fallTrig, NebbieDash._disarmTrig, NebbieDash._hungerTrig, NebbieDash._thirstTrig,
    NebbieDash._wieldTrig, NebbieDash._identifyObjTrig, NebbieDash._identifyDmgTrig,
    NebbieDash._stopUsingTrig, NebbieDash._wearBackTrig,
  }
  for _, id in ipairs(ids) do
    if id then pcall(function() killTrigger(id) end) end
  end
  for _, id in ipairs(NebbieDash._spellExpiryTrigs or {}) do
    if id then pcall(function() killTrigger(id) end) end
  end
  NebbieDash._spellExpiryTrigs = {}
  NebbieDash.teardownSpellShortcutTriggers()
end

function NebbieDash.installTriggers()
  NebbieDash.teardownTriggers()
  -- Shield " M:" (SENZA spazio dopo i due punti): esistono almeno due
  -- formati di prompt reali (vedi Q&A.md Round 14) — uno con spazio dopo i
  -- due punti ("M: 532/532", personaggio NomiyaMaki) e uno senza
  -- ("M:533/533", personaggio Mirari, con anche "X:" maiuscolo e separatori
  -- " - "). Lo shield precedente (" M: ", con lo spazio finale) non
  -- matchava mai il secondo formato -> onPromptLine() non veniva MAI
  -- chiamata per quel personaggio -> "nessun personaggio rilevato" per
  -- l'intera sessione, bug segnalato dall'utente. parsePromptLine() gestiva
  -- gia' correttamente entrambi i formati (spazio opzionale, X/x
  -- case-insensitive): il problema era solo nello shield del trigger, non
  -- nel parsing.
  NebbieDash._promptTrig = tempTrigger(" M:", [[NebbieDash.onPromptLine()]])
  -- Prompt immortale (Sirio ecc.): "Nome R### [....]>>" — necessario per nbatch e
  -- rilevamento PG senza dipendere da nchar.
  NebbieDash._promptImmTrig = tempRegexTrigger("%]%s*>>%s*$", [[NebbieDash.onPromptLine()]])
  NebbieDash._eqOpenTrig = tempTrigger("Stai usando:", [[NebbieDash.startEqCapture()]])
  NebbieDash._attribOpenTrig = tempTrigger("Spells attivi", [[NebbieDash.startAttribCapture()]])
  NebbieDash._eqLineTrig = tempRegexTrigger("^", [[NebbieDash.onEqCaptureLine()]])
  NebbieDash._attribLineTrig = tempRegexTrigger("^", [[NebbieDash.onAttribCaptureLine()]])
  if NebbieDash._eqLineTrig then pcall(disableTrigger, NebbieDash._eqLineTrig) end
  if NebbieDash._attribLineTrig then pcall(disableTrigger, NebbieDash._attribLineTrig) end
  -- Loot/split (vedi sezione dedicata sopra): il trigger sulla riga di
  -- bottino e' sempre attivo (riga singola, costo trascurabile, come quello
  -- del prompt); i due trigger di verifica gruppo restano disabilitati
  -- finche' non serve un controllo (dopo un loot riuscito).
  NebbieDash._lootLineTrig = tempTrigger("C'erano", [[NebbieDash.onLootLine()]])
  NebbieDash._lootLineTrig2 = tempTrigger("C'era una miserabile moneta", [[NebbieDash.onLootLine()]])
  -- Trigger gruppo attivi solo durante startSplitFlow (vedi finishSplitFlow).
  -- Substring + validazione in handler (stripColors, pattern server reale):
  --   But you are a member of no group?!
  --   $c0015Your group "nome" consists of:
  --   $c0015Your group consists of:   (senza nome gruppo — prima non matchava)
  NebbieDash._groupSoloTrig = tempTrigger("But you are a member of no group", [[NebbieDash.onGroupSoloLine()]])
  NebbieDash._groupHeaderTrig = tempTrigger("Your group", [[NebbieDash.onGroupHeaderLine()]])
  NebbieDash._combatEndTrig = tempTrigger("La tua parte di esperienza", [[NebbieDash.onCombatEndLine()]])
  NebbieDash._combatEndTrig2 = tempTrigger("La tua esperienza e' aumentata di", [[NebbieDash.onCombatEndLine()]])
  NebbieDash._fallTrig = tempTrigger("Inciampi e cadi per terra.", [[NebbieDash.onFallLine()]])
  NebbieDash._disarmTrig = tempTrigger("vola dalla tua presa", [[NebbieDash.onDisarmLine()]])
  NebbieDash._hungerTrig = tempTrigger("Hai Fame.", [[NebbieDash.onHungerThirstLine()]])
  NebbieDash._thirstTrig = tempTrigger("Hai sete.", [[NebbieDash.onHungerThirstLine()]])
  -- Elenco armi (vedi sezione dedicata sopra): "Impugni " per popolare la
  -- lista da solo ad ogni wield; le due righe di `identify` per rilevarne il
  -- tipo di danno SOLO quando l'utente esegue quel comando di sua iniziativa.
  NebbieDash._wieldTrig = tempTrigger("Impugni ", [[NebbieDash.onWieldLine()]])
  NebbieDash._stopUsingTrig = tempTrigger("Smetti di usare ", [[NebbieDash.onStopUsingLine()]])
  NebbieDash._wearBackTrig = tempRegexTrigger("^Ti metti .+ sulle spalle%.%s*$", [[NebbieDash.onWearBackLine()]])
  NebbieDash._identifyObjTrig = tempTrigger("Tipo di Oggetto", [[NebbieDash.onIdentifyObjectLine()]])
  NebbieDash._identifyDmgTrig = tempTrigger("Tipo di danno:", [[NebbieDash.onIdentifyDamageLine()]])
  -- Scadenza spell (vedi SPELL_EXPIRY_PATTERNS sopra): un trigger per riga,
  -- shield su substring esatta fornita dall'utente per ognuna.
  NebbieDash._spellExpiryTrigs = {}
  for _, entry in ipairs(NebbieDash.SPELL_EXPIRY_PATTERNS) do
    local id = tempTrigger(entry.text, string.format("NebbieDash.onSpellExpiredLine(%q)", entry.spell))
    table.insert(NebbieDash._spellExpiryTrigs, id)
  end
  if NebbieDash._groupSoloTrig then pcall(disableTrigger, NebbieDash._groupSoloTrig) end
  if NebbieDash._groupHeaderTrig then pcall(disableTrigger, NebbieDash._groupHeaderTrig) end
  -- Gli anonymous event handler restano registrati una volta sola (a
  -- differenza dei trigger sopra, qui non c'e' un modo affidabile per
  -- "smontarli" per nome/funzione): non serve comunque rifarli ad ogni
  -- reinstall perche' le funzioni target (onConnectionEvent/onWindowResize)
  -- sono idempotenti — vengono chiamate per nome ad ogni evento, quindi
  -- eseguono sempre la versione PIU' RECENTE del codice anche senza essere
  -- re-registrate.
  if type(registerAnonymousEventHandler) == "function" and not NebbieDash._eventHandlersRegistered then
    registerAnonymousEventHandler("sysConnectionEvent", "NebbieDash.onConnectionEvent")
    registerAnonymousEventHandler("sysWindowResizeEvent", "NebbieDash.onWindowResize")
    NebbieDash._eventHandlersRegistered = true
  end
  NebbieDash.installSpellShortcutTriggers()
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
-- Boot — chiamato SIA dallo script "core" (che si esegue ad ogni caricamento
-- del profilo E ad ogni installazione/reinstallazione a caldo del package,
-- senza bisogno di riavviare Mudlet) SIA dallo script "boot" agganciato a
-- sysLoadEvent (ridondanza difensiva per il normale avvio del profilo). E'
-- sicuro chiamarlo piu' volte: `installTriggers()` e' idempotente (smonta e
-- rimonta), `initGUI()`/`initHelpButton()` si limitano a non far nulla se
-- gia' creati. Il piccolo guard sotto evita solo un doppio messaggio
-- "pronto" se, per qualche motivo, boot() venisse chiamato due volte nello
-- stesso istante (es. al primo avvio di Mudlet, se sia lo script "core" sia
-- l'evento sysLoadEvent scattano nello stesso momento).
function NebbieDash.boot()
  local now = os.time()
  if NebbieDash._mainLoaded and NebbieDash._lastBootTime and (now - NebbieDash._lastBootTime) < 2 then
    return
  end
  NebbieDash._lastBootTime = now
  NebbieDash.loadStore()
  NebbieDash.loadUiStore()
  NebbieDash.loadSpeedwalks()
  NebbieDash.loadSpellCastConfig()
  NebbieDash.loadHungerMacros()
  NebbieDash.loadItemKeywords()
  NebbieDash.loadBatchCommands()
  NebbieDash.loadBatchItems()
  NebbieDash.installTriggers()
  NebbieDash.initGUI()
  NebbieDash.initHelpButton()
  NebbieDash._mainLoaded = true
  if NebbieDash._upgradeFromVer then
    cecho("<yellow>[NebbieDash] Aggiornamento v" .. NebbieDash._upgradeFromVer ..
      " → v" .. NebbieDash.version .. ".\n")
    NebbieDash._upgradeFromVer = nil
  end
  cecho("<green>[NebbieDash] v" .. NebbieDash.version .. " pronto. Usa <yellow>nresync<green> dopo il login.\n")
end

function NebbieDash.runFix()
  NebbieDash._lastBootTime = nil
  NebbieDash.boot()
  cecho("<green>[NebbieDash] nfix completato.\n")
end
