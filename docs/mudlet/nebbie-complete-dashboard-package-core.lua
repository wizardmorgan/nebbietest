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

local PKG_VER = "1.7.0"

if NebbieDash and NebbieDash._loadedVer == PKG_VER and NebbieDash._mainLoaded then
  return
end

NebbieDash = NebbieDash or {}
NebbieDash.version = PKG_VER
NebbieDash._loadedVer = PKG_VER
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
  end
end

function NebbieDash.saveStore()
  if not NebbieDash.persistEnabled then return end
  pcall(function() table.save(NebbieDash.storePath(), NebbieDash.chars) end)
end

function NebbieDash.getCharData(name)
  NebbieDash.chars = NebbieDash.chars or {}
  if not NebbieDash.chars[name] then
    NebbieDash.chars[name] = { eq = {}, knownSpellOrder = {}, activeSpells = {}, weaponConfig = {}, lastSeen = nil }
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

-- target opzionale: il gioco legge tutto cio' che segue l'apice di chiusura
-- come nome del bersaglio (vedi ACTION_FUNC(do_cast) in src/spell_parser.cpp,
-- riga ~1822, "argument = one_argument(argument, name)"). Usato dal click
-- sul pannello spell per forzare sempre il personaggio attivo come bersaglio
-- (richiesta esplicita: "devono avere tutti come target il personaggio con
-- cui sto giocando").
function NebbieDash.cmdQuickCast(prefix, argument, target)
  local cmdWord = NebbieDash.CAST_PREFIX[(prefix or ""):lower()]
  if not cmdWord then return end
  argument = (argument or ""):match("^%s*(.-)%s*$")
  if argument == "" then
    cecho("<orange>[NebbieDash] Uso: " .. prefix .. " <nome spell/skill, anche abbreviato>\n")
    return
  end

  -- Lancio manuale (nessun target esplicito passato dal click sul pannello):
  -- se l'ultima parola digitata e' un'abbreviazione plausibile (prefisso
  -- case-insensitive, come abbrevia i nomi il gioco stesso) del personaggio
  -- attivo, la trattiamo come bersaglio esplicito su se stessi e la
  -- stacchiamo dal nome spell. Esempio: con NomiyaMaki attivo,
  -- "c heal nom" -> cast 'heal' NomiyaMaki (non cast 'heal nom', che il gioco
  -- non riconosce). Richiesto esplicitamente dall'utente dopo aver notato che
  -- "c heal nom"/"c darkne nom" fallivano. Limite noto: se il nome del
  -- personaggio inizia per le stesse lettere dell'ultima parola di uno spell
  -- multi-parola che NON deve avere bersaglio, questo taglia comunque
  -- l'ultima parola (falso positivo raro, accettato consapevolmente).
  if not target then
    -- Bersaglio esplicito su QUALSIASI personaggio (non solo se stessi): una
    -- virgola separa nome spell e bersaglio in modo inequivocabile, senza le
    -- ambiguita' del taglio automatico sull'ultima parola (che sotto
    -- funziona solo per il proprio personaggio). Richiesto esplicitamente
    -- dall'utente ("se devo lanciare lo spell su un altro personaggio?").
    -- Esempio: "c heal, bob" -> cast 'heal' bob. Controllata PRIMA
    -- dell'euristica sul proprio nome cosi' una virgola scritta esplicitamente
    -- vince sempre, anche se il bersaglio indicato e' il proprio personaggio.
    local beforeComma, afterComma = argument:match("^(.-)%s*,%s*(.+)$")
    if beforeComma and beforeComma ~= "" and afterComma and afterComma ~= "" then
      argument = beforeComma
      target = afterComma
    end
  end

  -- Lancio manuale senza virgola: se l'ultima parola digitata e'
  -- un'abbreviazione plausibile (prefisso case-insensitive, come abbrevia i
  -- nomi il gioco stesso, almeno 2 lettere per evitare falsi positivi su
  -- abbreviazioni di una sola lettera come "word of r") del personaggio
  -- attivo, la trattiamo come bersaglio esplicito su se stessi e la
  -- stacchiamo dal nome spell. Esempio: con NomiyaMaki attivo,
  -- "c heal nom" -> cast 'heal' NomiyaMaki. Limite noto: se il nome del
  -- personaggio inizia per le stesse lettere dell'ultima parola di uno spell
  -- multi-parola che NON deve avere bersaglio, questo taglia comunque
  -- l'ultima parola (falso positivo raro, accettato consapevolmente).
  if not target then
    local name = NebbieDash.currentChar
    local rest, lastWord = argument:match("^(.-)%s+(%S+)$")
    if name and rest and rest ~= "" and lastWord and #lastWord >= 2
        and name:lower():sub(1, #lastWord) == lastWord:lower() then
      argument = rest
      target = name
    end
  end

  local cmd = cmdWord .. " '" .. argument .. "'"
  if target and target ~= "" then
    cmd = cmd .. " " .. target
  end
  send(cmd, false)
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
NebbieDash.speedwalkPreviewMaxLen = 60
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
-- Speedwalk (in basso, il resto). L'equip occupa sempre tutta l'altezza
-- della colonna sinistra (un solo pannello, niente da dividere li').
NebbieDash.guiRatios = { spells = 0.4 }
-- Altezza (px) della barra divisoria visibile tra Spell attivi e Speedwalk.
NebbieDash.dividerPx = 4
-- Le 3 miniconsole con testo (font/ricaricamento contenuto). La barra
-- divisoria e' un elemento separato (nessun testo, solo colore) — vedi
-- ALL_GUI_ELEMENTS per mostra/nascondi che deve includerla.
NebbieDash.GUI_WINDOWS = { "NebbieDashEquip", "NebbieDashSpells", "NebbieDashSpeedwalks" }
NebbieDash.ALL_GUI_ELEMENTS = { "NebbieDashEquip", "NebbieDashSpells", "NebbieDashSpeedwalks", "NebbieDashDivider" }

function NebbieDash.initGUI()
  if NebbieDash._guiCreated then return end
  setBorderLeft(NebbieDash.guiWidthEquip)
  setBorderRight(NebbieDash.guiWidthRight)
  createMiniConsole("NebbieDashEquip", 0, 0, NebbieDash.guiWidthEquip, 0)
  createMiniConsole("NebbieDashSpells", 0, 0, NebbieDash.guiWidthRight, 0)
  createMiniConsole("NebbieDashSpeedwalks", 0, 0, NebbieDash.guiWidthRight, 0)
  -- Barra divisoria tra Spell attivi e Speedwalk (richiesta esplicita: "manca
  -- una barra tra gli spell attivi e gli speedwalk"). E' una label, non una
  -- miniconsole: serve solo a marcare visivamente il confine tra i due
  -- pannelli, non contiene testo.
  createLabel("NebbieDashDivider", 0, 0, NebbieDash.guiWidthRight, NebbieDash.dividerPx, 1)
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
    for _, spellName in ipairs(data.knownSpellOrder or {}) do
      maxChars = math.max(maxChars, #(spellName or "") + #(" -- tick"))
    end
  end
  for _, entry in ipairs(NebbieDash.speedwalks) do
    local preview = NebbieDash.truncate(entry.dirString, NebbieDash.speedwalkPreviewMaxLen)
    maxChars = math.max(maxChars, #entry.desc + 1 + #preview)
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
    local w = math.floor(charW * (NebbieDash.computeRightMaxChars(data) + 3))
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
  -- Colonna sinistra: equip, tutta l'altezza disponibile.
  moveWindow("NebbieDashEquip", 0, 0)
  resizeWindow("NebbieDashEquip", NebbieDash.guiWidthEquip, h)
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
  { "c / r / m <spell>", "Lancia una spell/skill su te stesso (cast/recall/mind, vedi nclass)." },
  { "c/r/m <spell>, <bersaglio>", "Lancia una spell/skill su un altro personaggio." },
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
  { "nitemlen <n>", "Lunghezza massima delle descrizioni oggetti in equip." },
  { "nspellwarn <tick>", "Sotto questa soglia di tick una spell appare rossa." },
  { "nspeedwalks", "Ricarica il file di configurazione degli speedwalk." },
  { "nspeeddelay <secondi>", "Ritardo tra un comando e l'altro in uno speedwalk." },
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
  NebbieDash.guiRatios = { spells = 0.4 }
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
  if NebbieDash._guiCreated then NebbieDash.positionGUI() end
  cecho("<green>[NebbieDash] Altezza 'Spell attivi' impostata al " .. pct .. "% (Speedwalk: " .. (100 - pct) .. "%).\n")
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

  cecho("NebbieDashSpells", "<cyan><b>Spell attivi — " .. name .. "</b>\n")
  if data.knownSpellOrder and #data.knownSpellOrder > 0 then
    local prefix = data.castPrefix or "c"
    local activeSpells = data.activeSpells or {}
    for _, spellName in ipairs(data.knownSpellOrder) do
      -- Cliccabile per rilanciare: usa il comando (cast/recall/mind) impostato
      -- per questo personaggio con `nclass` (default "cast"). Rosso finche'
      -- `attrib` non la confermi attiva IN QUESTA sessione col personaggio
      -- corrente (vedi setCurrentCharacter — activeSpells si azzera ad ogni
      -- cambio personaggio); verde con i tick residui se attiva e non vicina
      -- alla scadenza (spellWarnTicks).
      local activeTicks = activeSpells[spellName]
      local active = activeTicks ~= nil
      local ticks = active and (tonumber(activeTicks) or 0) or 0
      local color = (active and ticks > NebbieDash.spellWarnTicks) and "<green>" or "<red>"
      cechoLink("NebbieDashSpells", color .. spellName,
        string.format("NebbieDash.cmdQuickCast(%q, %q, %q)", prefix, spellName, name),
        "Clicca per rilanciare su " .. name .. ": " .. spellName, true)
      local ticksLabel = active and tostring(ticks) or "-"
      cecho("NebbieDashSpells", string.format(" %s%s tick\n", color, ticksLabel))
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
    local preview = NebbieDash.truncate(entry.dirString, NebbieDash.speedwalkPreviewMaxLen)
    cechoLink("NebbieDashSpeedwalks", "<cyan>" .. entry.desc,
      string.format("NebbieDash.runSpeedwalk(%d)", i),
      "Clicca per andare: " .. entry.desc .. " (" .. entry.dirString .. ")", true)
    cecho("NebbieDashSpeedwalks", string.format(" <grey>%s\n", preview))
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

-- Segnale di fine combattimento: shield su substring fissa "La tua parte di
-- esperienza" (sempre attivo, stesso principio degli altri trigger a riga
-- singola). Fa scattare `nloot` da solo se `nautoloot` e' attivo, cosi' non
-- serve piu' digitarlo manualmente dopo ogni uccisione.
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

-- Estrae le parole chiave "significative" da un nome oggetto descrittivo,
-- scartando gli articoli/preposizioni sopra (anche nella forma con
-- apostrofo, es. "l'Infinito" → "infinito"). Restituisce una stringa
-- minuscola pronta per essere usata come argomento di `get`/`wield`.
function NebbieDash.extractItemKeywords(name)
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
    "# chiave in game). Usata al posto dell'estrazione automatica per: il\n" ..
    "# recupero arma dopo un disarmo, e il segnaposto {zaino} delle macro\n" ..
    "# fame/sete. Se un oggetto non ha una riga qui, si usa comunque\n" ..
    "# l'estrazione automatica (rimozione di articoli/preposizioni italiane)\n" ..
    "# come prima — questo file serve solo per i casi in cui NON funziona.\n" ..
    "#\n" ..
    "# Le righe che iniziano con # e le righe vuote vengono ignorate.\n" ..
    "# Dopo aver modificato questo file, digita 'nitemkeywords' in gioco per\n" ..
    "# ricaricarlo senza dover riavviare Mudlet.\n" ..
    "#\n" ..
    "# Esempi (rimuovi il # iniziale e adatta ai tuoi oggetti):\n" ..
    "# Borsa Inesauribile dei Korred: korred\n" ..
    "# la Flamberga di Boris: flamberga boris\n"
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
function NebbieDash.resolveItemKeywords(itemName)
  local key = (itemName or ""):lower():match("^%s*(.-)%s*$")
  local override = NebbieDash.itemKeywordOverrides[key]
  if override then return override, true end
  return NebbieDash.extractItemKeywords(itemName), false
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
  local amount = text:match("^C'erano%s+(%d+)%s+monete%.%s*$")
  if not amount then return end
  amount = tonumber(amount)
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

function NebbieDash.startSplitFlow(amount)
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
  end
end

function NebbieDash.onGroupSoloLine()
  if not NebbieDash._groupCheckActive then return end
  NebbieDash.finishSplitFlow(false)
end

function NebbieDash.onGroupHeaderLine()
  if not NebbieDash._groupCheckActive then return end
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
    NebbieDash._promptTrig, NebbieDash._eqOpenTrig, NebbieDash._attribOpenTrig,
    NebbieDash._eqLineTrig, NebbieDash._attribLineTrig, NebbieDash._lootLineTrig,
    NebbieDash._groupSoloTrig, NebbieDash._groupHeaderTrig, NebbieDash._combatEndTrig,
    NebbieDash._fallTrig, NebbieDash._disarmTrig, NebbieDash._hungerTrig, NebbieDash._thirstTrig,
  }
  for _, id in ipairs(ids) do
    if id then pcall(function() killTrigger(id) end) end
  end
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
  -- Regex ancorate a inizio riga (non semplici substring) per i due trigger
  -- di verifica gruppo: costo trascurabile perche' restano disabilitati
  -- tranne il breve intervallo del controllo dopo un loot (vedi
  -- startSplitFlow/finishSplitFlow), e riduce il rischio che una frase
  -- qualunque nel testo di gioco contenga per caso "Your group " a meta'
  -- riga (sospetta causa dello split scattato senza essere in gruppo,
  -- segnalato dall'utente — vedi LOG.md Round 13).
  NebbieDash._groupSoloTrig = tempRegexTrigger("^But you are a member of no group", [[NebbieDash.onGroupSoloLine()]])
  NebbieDash._groupHeaderTrig = tempRegexTrigger("^Your group \"", [[NebbieDash.onGroupHeaderLine()]])
  NebbieDash._combatEndTrig = tempTrigger("La tua parte di esperienza", [[NebbieDash.onCombatEndLine()]])
  NebbieDash._fallTrig = tempTrigger("Inciampi e cadi per terra.", [[NebbieDash.onFallLine()]])
  NebbieDash._disarmTrig = tempTrigger("vola dalla tua presa", [[NebbieDash.onDisarmLine()]])
  NebbieDash._hungerTrig = tempTrigger("Hai Fame.", [[NebbieDash.onHungerThirstLine()]])
  NebbieDash._thirstTrig = tempTrigger("Hai sete.", [[NebbieDash.onHungerThirstLine()]])
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
  NebbieDash.loadSpeedwalks()
  NebbieDash.loadHungerMacros()
  NebbieDash.loadItemKeywords()
  NebbieDash.installTriggers()
  NebbieDash.initGUI()
  NebbieDash.initHelpButton()
  NebbieDash._mainLoaded = true
  cecho("<green>[NebbieDash] v" .. NebbieDash.version .. " pronto. Usa <yellow>nresync<green> dopo il login.\n")
end

function NebbieDash.runFix()
  NebbieDash._lastBootTime = nil
  NebbieDash.boot()
  cecho("<green>[NebbieDash] nfix completato.\n")
end
