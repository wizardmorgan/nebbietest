
Nebbie.version = "2.2.8"

Nebbie.DEFAULT_EQ_KEYWORDS = {
  { match = "borsa inesauribile dei korred", key = "korred" },
  { match = "forza della natura", key = "forza" },
  { match = "elf slayer", key = "elf" },
  { match = "verdespina", key = "verdespina" },
}

Nebbie.EQ_STOPWORDS = {
  ["del"] = true, ["dei"] = true, ["della"] = true, ["delle"] = true, ["degli"] = true,
  ["de"] = true, ["di"] = true, ["da"] = true, ["in"] = true, ["su"] = true,
  ["the"] = true, ["pair"] = true, ["paio"] = true,
}
Nebbie.buffs = Nebbie.buffs or {}
Nebbie.debuffs = Nebbie.debuffs or {}
Nebbie.stats = Nebbie.stats or {}
Nebbie.promptBuffs = Nebbie.promptBuffs or {}
Nebbie._aliasNames = Nebbie._aliasNames or {}
Nebbie._triggerNames = Nebbie._triggerNames or {}
Nebbie._aliasIds = Nebbie._aliasIds or {}
Nebbie._triggerIds = Nebbie._triggerIds or {}
Nebbie._settings = Nebbie._settings or {}
Nebbie.playerClass = Nebbie.playerClass or nil
Nebbie.attribAuto = false
Nebbie.attribGag = false
Nebbie._attribBusy = false
Nebbie.lootAuto = true
Nebbie._lootBusy = false

local PKG = Nebbie.package
local LEGACY_PKGS = {"nebbie-play-all", "nebbie-spells-skills"}
local CLASS_VAR = "nebbie_class"
Nebbie._settingsFile = getMudletHomeDir() .. "/nebbie-play-all-settings.lua"

Nebbie.PROMPT_SLOTS = {
  { code = "P", name = "polymorph self" },
  { code = "P", name = "change form" },
  { code = "P", name = "tree" },
  { code = "F", name = "fireshield" },
  { code = "S", name = "sanctuary" },
  { code = "I", name = "invisibility" },
  { code = "T", name = "true sight" },
  { code = "M", name = "mirror images" },
  { code = "D", name = "prot energy drain" },
  { code = "A", name = "anti magic shell" },
  { code = "Q", name = "quest" },
}

function Nebbie.now()
  if type(getEpoch) == "function" then return getEpoch() end
  if type(getEpochTime) == "function" then return getEpochTime() end
  return os.time()
end

function Nebbie.stripColors(line)
  if not line then return "" end
  line = line:gsub("%$c%d%d%d%d", "")
  line = line:gsub("\27%[[%d;]*m", "")
  return line
end

function Nebbie.normalizePromptLine(line)
  local plain = Nebbie.stripColors(line)
  plain = plain:gsub(">>%s*$", "")
  plain = plain:gsub("^%s+", ""):gsub("%s+$", "")
  return plain
end

function Nebbie.extractPromptChunk(plain)
  if not plain or plain == "" then return plain end
  local pos = plain:find("H:%d+/%d+")
  if not pos then pos = plain:find("H%d+/%d+") end
  if not pos then return plain end
  if pos > 1 then
    local prefix = plain:sub(1, pos - 1)
    local name = prefix:match("(%S+)%s*$")
    if name and #name >= 2 and name:match("^[%a]") then
      return name .. " " .. plain:sub(pos)
    end
  end
  return plain:sub(pos)
end

function Nebbie.parsePromptPair(plain, letter)
  local cur, maxv = plain:match(letter .. ":(%d+)/(%d+)")
  if cur then return tonumber(cur), tonumber(maxv) end
  cur, maxv = plain:match(letter .. "(%d+)/(%d+)")
  if cur then return tonumber(cur), tonumber(maxv) end
  cur = plain:match(letter .. ":(%d+)")
  if cur then local n = tonumber(cur); return n, n end
  cur = plain:match(letter .. "(%d+)")
  if cur then local n = tonumber(cur); return n, n end
  return nil, nil
end

function Nebbie.parsePromptStats(line)
  local plain = Nebbie.extractPromptChunk(Nebbie.normalizePromptLine(line))
  if plain == "" then
    Nebbie._lastParseError = "riga vuota"
    return nil
  end

  local hp, hpmax = Nebbie.parsePromptPair(plain, "H")
  local mana, manamax = Nebbie.parsePromptPair(plain, "M")
  local move, movemax = Nebbie.parsePromptPair(plain, "V")
  local xp = tonumber(plain:match("X:(%d+)") or plain:match("X(%d+)"))
  if not hp or not mana or not move or not xp then
    Nebbie._lastParseError = "mancano H/M/V/X in: " .. plain:sub(1, 80)
    return nil
  end
  Nebbie._lastParseError = nil

  local name = plain:match("^(%S+)%s+H") or plain:match("^(%S+)")
  local gold = tonumber(plain:match("G:(%d+)") or plain:match("g:(%d+)"))
  local codes = plain:match("%[%[([^%]]*)%]%]") or plain:match("%[([^%]]*)%]")

  local tankC, tankN, mobC, mobT = "*", "*", "*", "*"
  local tail = plain:match("X:%d+%s*(.*)$") or plain:match("X%d+%s*(.*)$") or ""
  local fc, ft, mc, mt = tail:match("-%s+([^/]+)/(%S+)%s+%-%s+([^%-]+)%-(%S+)")
  if fc then
    tankC, tankN = Nebbie.stripColors(fc), ft
    mobC, mobT = Nebbie.stripColors(mc), mt
  end

  return {
    name = name,
    hp = hp, hpmax = hpmax or hp,
    mana = mana, manamax = manamax or mana,
    move = move, movemax = movemax or move,
    xp = xp, gold = gold,
    tankCond = Nebbie.stripColors(tankC or "*"),
    tankName = (tankN ~= "*" and tankN) or nil,
    mobCond = Nebbie.stripColors(mobC or "*"),
    mobName = (mobT ~= "*" and mobT) or nil,
    codes = codes or "",
  }
end

function Nebbie.resolveTriggerLine()
  local text = line
  if (not text or text == "") and type(getCurrentLine) == "function" then
    text = getCurrentLine()
  end
  return text or ""
end

function Nebbie.pollPromptFromBuffer()
  if type(getLastLineNumber) ~= "function" or type(getLines) ~= "function" then return false end
  local last = getLastLineNumber()
  if not last or last < 1 then return false end
  local from = math.max(1, last - 5)
  local lines = getLines(from, last)
  if type(lines) ~= "table" then return false end
  for abs = last, from, -1 do
    local rel = abs - from + 1
    local text = lines[rel]
    if type(text) == "string" and text ~= "" then
      local parsed = Nebbie.parsePromptStats(text)
      if parsed then
        Nebbie.stats = parsed
        Nebbie.promptBuffs = Nebbie.parsePromptCodes(parsed.codes or "")
        Nebbie._lastPromptRaw = text
        return true
      end
    end
  end
  return false
end

function Nebbie.onPrompt(line)
  Nebbie._lastPromptRaw = line
  local parsed = Nebbie.parsePromptStats(line)
  if not parsed then return end
  Nebbie.stats = parsed
  Nebbie.promptBuffs = Nebbie.parsePromptCodes(parsed.codes or "")
  Nebbie.updateGauges()
  Nebbie.refreshGUI()
end

function Nebbie.onPromptLine()
  Nebbie.onPrompt(Nebbie.resolveTriggerLine())
end

function Nebbie.debugPrompt()
  local polled = false
  if not Nebbie.stats then polled = Nebbie.pollPromptFromBuffer() end
  cecho("<cyan>Nebbie v" .. tostring(Nebbie.version) .. " — debug prompt\n")
  cecho("<grey>ultima riga vista: <white>" .. tostring(Nebbie._lastPromptRaw or "(nessuna)") .. "\n")
  cecho("<grey>poll buffer: <yellow>" .. tostring(polled) .. "\n")
  if Nebbie._lastParseError then
    cecho("<orange>parse error: <white>" .. Nebbie._lastParseError .. "\n")
  end
  if Nebbie.stats then
    local s = Nebbie.stats
    cecho(string.format("<green>stats ok: HP %s/%s MN %s/%s MV %s/%s\n",
      tostring(s.hp), tostring(s.hpmax), tostring(s.mana), tostring(s.manamax),
      tostring(s.move), tostring(s.movemax)))
    Nebbie.updateGauges()
  else
    cecho("<orange>stats=nil — digita un comando qualsiasi, poi ripeti nprompt.\n")
  end
end

function Nebbie.testPromptParse(silent)
  local sample = "Mirari H:652/652 M:532/532 V:265/265 X:280457721 - */* - *-* - [[------Tm---]] - G:49287175 >>"
  local parsed = Nebbie.parsePromptStats(sample)
  if parsed and parsed.hp == 652 and parsed.mana == 532 then
    if not silent then cecho("<green>Nebbie: parser prompt OK (v" .. Nebbie.version .. ").\n") end
    return true
  end
  if not silent then
    cecho("<red>Nebbie: parser prompt FALLITO — " .. tostring(Nebbie._lastParseError or "sconosciuto") .. "\n")
  end
  return false
end

function Nebbie.reloadMainScript()
  Nebbie._installedVer = nil
  Nebbie._mainLoaded = false
  Nebbie.boot()
  return true
end

function Nebbie.installPromptHooks()
  Nebbie._promptTrigIds = Nebbie._promptTrigIds or {}
  for _, id in ipairs(Nebbie._promptTrigIds) do
    pcall(function() killTrigger(id) end)
  end
  Nebbie._promptTrigIds = {}
  local hook = [[if Nebbie and Nebbie.onPromptLine then Nebbie.onPromptLine() end]]
  if type(tempSubstringTrigger) == "function" then
    local id = tempSubstringTrigger(" H:", hook)
    if id then table.insert(Nebbie._promptTrigIds, id) end
  end
  if type(tempPromptTrigger) == "function" then
    pcall(function()
      local id = tempPromptTrigger(hook)
      if id then table.insert(Nebbie._promptTrigIds, id) end
    end)
  end
end

function Nebbie.setCastMode(mode)
  if mode ~= "cast" and mode ~= "recall" and mode ~= "mind" then
    cecho("<orange>Modalita' cast: cast | recall | mind\n")
    return
  end
  Nebbie.castMode = mode
  cecho("<green>Nebbie cast mode: <yellow>" .. mode .. "\n")
  Nebbie.refreshGUI()
end

function Nebbie.loadSettings()
  Nebbie._settings = Nebbie._settings or {}
  if type(table.load) == "function" then
    pcall(function() table.load(Nebbie._settingsFile, Nebbie._settings) end)
  end
  Nebbie._settings.eqKeywords = Nebbie._settings.eqKeywords or {}
end

function Nebbie.saveSettings()
  if type(table.save) == "function" then
    pcall(function() table.save(Nebbie._settingsFile, Nebbie._settings) end)
  end
end

function Nebbie.stripQuotes(token)
  if not token then return "" end
  local s = token:match("^%s*(.-)%s*$")
  while true do
    local inner = s:match("^['\"](.+)['\"]$")
    if not inner then break end
    s = inner
  end
  return s
end

function Nebbie.killAllByName(name, typ)
  if not name or name == "" then return end
  typ = typ or "trigger"
  if type(findItems) == "function" then
    local ids = findItems(name, typ, true)
    if type(ids) == "table" then
      for _, id in ipairs(ids) do
        if typ == "alias" then
          if type(disableAlias) == "function" then pcall(function() disableAlias(id) end) end
          if type(killAlias) == "function" then pcall(function() killAlias(id) end) end
        elseif typ == "trigger" then
          if type(disableTrigger) == "function" then pcall(function() disableTrigger(id) end) end
          if type(killTrigger) == "function" then pcall(function() killTrigger(id) end) end
        end
      end
    end
  end
  if type(exists) ~= "function" then return end
  local tries = 0
  while exists(name, typ) > 0 and tries < 64 do
    local before = exists(name, typ)
    if typ == "alias" then
      if type(killAlias) == "function" then pcall(function() killAlias(name) end) end
      if exists(name, typ) >= before and type(disableAlias) == "function" then
        disableAlias(name)
      end
    elseif typ == "trigger" then
      if type(killTrigger) == "function" then pcall(function() killTrigger(name) end) end
      if exists(name, typ) >= before and type(disableTrigger) == "function" then
        disableTrigger(name)
      end
    end
    tries = tries + 1
  end
end

function Nebbie.killAllByNameVariants(short, typ)
  if not short or short == "" then return end
  Nebbie.killAllByName(PKG .. "::" .. short, typ)
  Nebbie.killAllByName(short, typ)
  Nebbie.killAllByName("nebbie-spells-skills::" .. short, typ)
end

function Nebbie.killAllTrackedTemps()
  for _, id in pairs(Nebbie._aliasIds or {}) do
    if type(killAlias) == "function" then pcall(function() killAlias(id) end) end
  end
  for _, ids in pairs(Nebbie._triggerIds or {}) do
    for _, id in ipairs(ids) do
      if type(killTrigger) == "function" then pcall(function() killTrigger(id) end) end
    end
  end
  local seenA, seenT = {}, {}
  for _, name in ipairs(Nebbie._aliasNames or {}) do
    if not seenA[name] then
      seenA[name] = true
      Nebbie.killAllByName(name, "alias")
      local short = name:match("::(.+)$")
      if short then Nebbie.killAllByName(short, "alias") end
    end
  end
  for _, name in ipairs(Nebbie._triggerNames or {}) do
    if not seenT[name] then
      seenT[name] = true
      Nebbie.killAllByName(name, "trigger")
      local short = name:match("::(.+)$")
      if short then Nebbie.killAllByName(short, "trigger") end
    end
  end
end

function Nebbie.killTempAlias(full)
  if Nebbie._aliasIds and Nebbie._aliasIds[full] then
    pcall(function() killAlias(Nebbie._aliasIds[full]) end)
    Nebbie._aliasIds[full] = nil
  end
end

function Nebbie.killTempTriggers(full)
  if not Nebbie._triggerIds or not Nebbie._triggerIds[full] then return end
  for _, id in ipairs(Nebbie._triggerIds[full]) do
    pcall(function() killTrigger(id) end)
  end
  Nebbie._triggerIds[full] = nil
end

function Nebbie.isKeepPackageAlias(name)
  return name == "nebbie-fix" or name == "nebbie-purge" or name == "nebbie-nprompt"
end

function Nebbie.purgeLegacyPermItems(silent)
  if type(exists) ~= "function" then return end
  local ta, tt = 0, 0
  for _, name in ipairs(Nebbie.legacyPermTriggers or {}) do
    local before = exists(name, "trigger")
    if before > 0 then
      Nebbie.killAllByName(name, "trigger")
      tt = tt + before
    end
    local short = name:match("::(.+)$")
    if short then
      local b2 = exists(short, "trigger")
      if b2 > 0 then
        Nebbie.killAllByName(short, "trigger")
        tt = tt + b2
      end
    end
  end
  for _, name in ipairs(Nebbie.legacyPermAliases or {}) do
    if not Nebbie.isKeepPackageAlias(name) then
      local before = exists(name, "alias")
      if before > 0 then
        Nebbie.killAllByName(name, "alias")
        ta = ta + before
      end
      local short = name:match("::(.+)$")
      if short and not Nebbie.isKeepPackageAlias(short) then
        local b2 = exists(short, "alias")
        if b2 > 0 then
          Nebbie.killAllByName(short, "alias")
          ta = ta + b2
        end
      end
    end
  end
  if not silent and ta > 0 then
    cecho("<orange>Nebbie: disattivati perm vecchi (~" .. ta .. " item).\n")
  end
  return ta
end

function Nebbie.disableAllLegacyNfixAliases(silent)
  return Nebbie.purgeLegacyPermItems(silent)
end

function Nebbie.disablePackagePermItems()
  Nebbie.purgeLegacyPermItems(true)
  if type(getAliasList) == "function" then
    for _, entry in ipairs(getAliasList()) do
      local name = entry
      if type(getAliasName) == "function" then
        local ok, n = pcall(function() return getAliasName(entry) end)
        if ok and n and n ~= "" then name = n end
      end
      if type(name) == "string" and not Nebbie.isKeepPackageAlias(name) then
        for _, pkg in ipairs(LEGACY_PKGS) do
          if name:find(pkg, 1, true) and type(disableAlias) == "function" then
            disableAlias(name)
            break
          end
        end
      end
    end
  end
  if type(getTriggerList) == "function" then
    for _, entry in ipairs(getTriggerList()) do
      local name = entry
      if type(getTriggerName) == "function" then
        local ok, n = pcall(function() return getTriggerName(entry) end)
        if ok and n and n ~= "" then name = n end
      end
      if type(name) == "string" then
        for _, pkg in ipairs(LEGACY_PKGS) do
          if name:find(pkg, 1, true) and type(disableTrigger) == "function" then
            disableTrigger(name)
            break
          end
        end
      end
    end
  end
end

function Nebbie.purgeTrackedAliases()
  local seen = {}
  for _, name in ipairs(Nebbie._aliasNames or {}) do
    if not seen[name] then
      seen[name] = true
      Nebbie.killAllByName(name, "alias")
    end
  end
end

function Nebbie.purgeTrackedTriggers()
  local seen = {}
  for _, name in ipairs(Nebbie._triggerNames or {}) do
    if not seen[name] then
      seen[name] = true
      Nebbie.killAllByName(name, "trigger")
    end
  end
end

function Nebbie.purgePackageTriggers()
  if type(getTriggerList) ~= "function" then return end
  for _, entry in ipairs(getTriggerList()) do
    local name = entry
    if type(getTriggerName) == "function" then
      local ok, n = pcall(function() return getTriggerName(entry) end)
      if ok and n and n ~= "" then name = n end
    end
    if type(name) == "string" then
      for _, pkg in ipairs(LEGACY_PKGS) do
        if name:find(pkg, 1, true) then
          Nebbie.killAllByName(name, "trigger")
          break
        end
      end
    end
  end
end

function Nebbie.purgeOrphanNebbieTriggers()
  local patterns = {
    "debuff on", "debuff off", "wear off", "soon ", "fail ", "cast started",
    "prompt parse", "attrib gag", "look loot", "eq parse", "mob kill", "coin loot",
  }
  if type(getTriggerList) == "function" then
    for _, entry in ipairs(getTriggerList()) do
      local name = entry
      if type(getTriggerName) == "function" then
        local ok, n = pcall(function() return getTriggerName(entry) end)
        if ok and n and n ~= "" then name = n end
      end
      if type(name) == "string" then
        for _, frag in ipairs(patterns) do
          if name:find(frag, 1, true) then
            Nebbie.killAllByName(name, "trigger")
            break
          end
        end
      end
    end
    return
  end
  for _, name in ipairs(Nebbie._triggerNames or {}) do
    for _, frag in ipairs(patterns) do
      if name:find(frag, 1, true) then
        Nebbie.killAllByName(name, "trigger")
        break
      end
    end
  end
end

function Nebbie.purgePackageAliases()
  if type(getAliasList) ~= "function" then return end
  for _, entry in ipairs(getAliasList()) do
    local name = entry
    if type(getAliasName) == "function" then
      local ok, n = pcall(function() return getAliasName(entry) end)
      if ok and n and n ~= "" then name = n end
    end
    if type(name) == "string" then
      for _, pkg in ipairs(LEGACY_PKGS) do
        if name:find(pkg, 1, true) then
          Nebbie.killAllByName(name, "alias")
          break
        end
      end
    end
  end
end

function Nebbie.purgeOrphanNebbieAliases()
  if type(getAliasList) ~= "function" then return end
  local patterns = {
    "set class", "list classes", "reinstall fix", "reposition gui", "attrib sync",
    "setup hud", "toggle hud", "toggle gui", "loot manual", "loot on", "loot off",
    "swap weapon", "eq key", "generic cast", "recall shortcut", "mind shortcut", "memorize", "mode cast",
    "mode recall", "mode mind", "abbr cast", "fav cast", "quick slot", "return form",
  }
  for _, entry in ipairs(getAliasList()) do
    local name = entry
    if type(getAliasName) == "function" then
      local ok, n = pcall(function() return getAliasName(entry) end)
      if ok and n and n ~= "" then name = n end
    end
    if type(name) == "string" then
      for _, frag in ipairs(patterns) do
        if name:find(frag, 1, true) then
          Nebbie.killAllByName(name, "alias")
          break
        end
      end
    end
  end
end

function Nebbie.warnLegacyPackages()
  if type(getPackageList) ~= "function" then return end
  local ok, pkgs = pcall(getPackageList)
  if not ok or type(pkgs) ~= "table" then return end
  local legacy = false
  for _, name in ipairs(pkgs) do
    if name == "nebbie-spells-skills" then legacy = true break end
  end
  if legacy then
    cecho("<orange>Nebbie: disinstalla il package vecchio <yellow>nebbie-spells-skills<orange> (Alt+O) per evitare cast doppi.\n")
  end
end

function Nebbie.parseClassArg(arg)
  if not arg or arg == "" then return {} end
  if arg == "u" then return {"+"} end
  local parts = {}
  for letter in arg:gmatch("%S+") do table.insert(parts, letter) end
  return parts
end

function Nebbie.buildMergedPreset(parts)
  local key = table.concat(parts, " ")
  Nebbie._mergedCache = Nebbie._mergedCache or {}
  if Nebbie._mergedCache[key] then return Nebbie._mergedCache[key] end
  local quick, seen, names = {}, {}, {}
  for _, cls in ipairs(parts) do
    local p = Nebbie.classes[cls]
    if p then
      table.insert(names, p.name)
      for _, entry in ipairs(p.quick) do
        local sk = entry.abbr .. "\0" .. entry.kind .. "\0" .. entry.target
        if not seen[sk] and #quick < 9 then
          seen[sk] = true
          table.insert(quick, entry)
        end
      end
    end
  end
  local preset = { name = table.concat(names, " + "), mode = "cast", quick = quick }
  Nebbie._mergedCache[key] = preset
  return preset
end

function Nebbie.getActivePreset()
  if not Nebbie.playerClass or Nebbie.playerClass == "" then return nil end
  if Nebbie.classes[Nebbie.playerClass] then return Nebbie.classes[Nebbie.playerClass] end
  local parts = Nebbie.parseClassArg(Nebbie.playerClass)
  if #parts > 1 then return Nebbie.buildMergedPreset(parts) end
  return nil
end

function Nebbie.listClasses()
  cecho("<cyan><b>Classi Nebbie</b> <grey>(default multiclasse: <yellow>nclass +<grey>):\n")
  local order = {"+", "m", "s", "c", "d", "p", "r", "I", "t", "w", "k", "b"}
  for _, cls in ipairs(order) do
    local preset = Nebbie.classes[cls]
    if preset then
      local mark = (cls == Nebbie.playerClass) and "<green>* " or "  "
      local slots = {}
      for i, q in ipairs(preset.quick) do slots[i] = "q" .. i .. "=" .. q.abbr end
      cecho(mark .. "<yellow>" .. cls .. " <white>" .. preset.name
        .. " <grey>[" .. table.concat(slots, " ") .. "]\n")
    end
  end
  cecho("<grey>Multiclasse: <yellow>nclass m c<grey> | universale: <yellow>nclass +<grey>\n")
end

function Nebbie.saveClass(cls)
  Nebbie._settings = Nebbie._settings or {}
  Nebbie._settings.class = cls
  if type(setVariable) == "function" then pcall(function() setVariable(CLASS_VAR, cls) end) end
  Nebbie.saveSettings()
end

function Nebbie.loadClass()
  Nebbie.loadSettings()
  local saved = Nebbie._settings.class
  if type(getVariable) == "function" then
    local ok, v = pcall(function() return getVariable(CLASS_VAR) end)
    if ok and v and v ~= "" then saved = v end
  end
  if saved and saved ~= "" then
    if Nebbie.classes[saved] or #Nebbie.parseClassArg(saved) > 1 then
      Nebbie.setClass(saved, true)
      return true
    end
  end
  return false
end

function Nebbie.setMulticlass(parts, silent)
  local names, missing = {}, {}
  for _, cls in ipairs(parts) do
    if Nebbie.classes[cls] then table.insert(names, Nebbie.classes[cls].name)
    else table.insert(missing, cls) end
  end
  if #missing > 0 then
    if not silent then cecho("<orange>Classe sconosciuta: <yellow>" .. table.concat(missing, ", ") .. "\n") end
    return false
  end
  local key = table.concat(parts, " ")
  local preset = Nebbie.buildMergedPreset(parts)
  Nebbie.playerClass = key
  Nebbie.saveClass(key)
  Nebbie.castMode = preset.mode
  if not silent then
    cecho("<green>Nebbie multiclasse: <yellow>" .. preset.name .. "\n")
  end
  Nebbie.refreshGUI()
  return true
end

function Nebbie.setClass(cls, silent)
  local parts = Nebbie.parseClassArg(cls)
  if #parts > 1 then return Nebbie.setMulticlass(parts, silent) end
  if #parts == 1 then cls = parts[1] end
  local preset = Nebbie.classes[cls]
  if not preset then
    if not silent then
      cecho("<orange>Classi: + u m s c d p r I t w k b — <yellow>nclass +<grey> consigliato\n")
    end
    return false
  end
  Nebbie.playerClass = cls
  Nebbie.saveClass(cls)
  Nebbie.castMode = preset.mode
  if not silent then
    cecho("<green>Nebbie classe: <yellow>" .. preset.name .. " <grey>(" .. cls .. ")\n")
  end
  Nebbie.refreshGUI()
  return true
end

Nebbie.TICK_SECONDS = 4

function Nebbie.formatTime(secs)
  secs = math.max(0, math.floor(secs))
  local m = math.floor(secs / 60)
  local s = secs % 60
  return string.format("%02d:%02d", m, s)
end

function Nebbie.shouldTrackBuff(spell)
  if not spell or spell == "" then return false end
  if Nebbie.noBuffSpells and Nebbie.noBuffSpells[spell] then return false end
  if Nebbie.buffDurations and Nebbie.buffDurations[spell] then return true end
  for _, entry in ipairs(Nebbie.wearOff or {}) do
    if entry.name == spell then return true end
  end
  for _, entry in ipairs(Nebbie.wearOffSoon or {}) do
    if entry.name == spell then return true end
  end
  return false
end

function Nebbie.normalizeBuffSpell(spell)
  if not spell or spell == "" then return nil end
  spell = spell:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%.$", "")
  if spell == "" then return nil end
  if Nebbie.buffDurations and Nebbie.buffDurations[spell] then return spell end
  local lower = spell:lower()
  for name, _ in pairs(Nebbie.buffDurations or {}) do
    if name:lower() == lower then return name end
  end
  for _, entry in ipairs(Nebbie.wearOff or {}) do
    if entry.name:lower() == lower then return entry.name end
  end
  for _, entry in ipairs(Nebbie.wearOffSoon or {}) do
    if entry.name:lower() == lower then return entry.name end
  end
  return spell
end

function Nebbie.buffTimeLeft(data, now)
  now = now or Nebbie.now()
  if not data or not data.since then return nil end
  if data.duration and data.duration > 0 then
    return data.duration - (now - data.since)
  end
  return nil
end

function Nebbie.isBuffExpired(data, now)
  if not data or not data.synced then return false end
  local left = Nebbie.buffTimeLeft(data, now)
  if left == nil then return false end
  return left <= 0
end

function Nebbie.pruneExpiredBuffs()
  local now = Nebbie.now()
  local remove = {}
  for spell, data in pairs(Nebbie.buffs or {}) do
    if type(spell) == "string" and spell:sub(1, 1) ~= "_" and type(data) == "table" then
      if Nebbie.isBuffExpired(data, now) then
        table.insert(remove, spell)
      end
    end
  end
  for _, spell in ipairs(remove) do
    Nebbie.buffs[spell] = nil
  end
end

function Nebbie.pruneInvalidBuffs()
  for spell, _ in pairs(Nebbie.buffs or {}) do
    if type(spell) == "string" and spell:sub(1, 1) ~= "_" and not Nebbie.shouldTrackBuff(spell) then
      Nebbie.buffs[spell] = nil
    end
  end
end

function Nebbie.onBuffApplied(spell)
  spell = Nebbie.normalizeBuffSpell(spell)
  if not spell or not Nebbie.shouldTrackBuff(spell) then return end
  local lower = spell:lower()
  for key, _ in pairs(Nebbie.buffs or {}) do
    if type(key) == "string" and key:sub(1, 1) ~= "_" and key:lower() == lower and key ~= spell then
      Nebbie.buffs[key] = nil
    end
  end
  local est = Nebbie.buffDurations[spell] or 0
  Nebbie.buffs[spell] = {
    since = Nebbie.now(),
    duration = est,
    soon = false,
    active = true,
    synced = false,
  }
  Nebbie.buffs._lastCast = spell
  Nebbie.refreshGUI()
end

function Nebbie.onBuffWearOff(spell)
  spell = Nebbie.normalizeBuffSpell(spell)
  if spell then Nebbie.buffs[spell] = nil end
  Nebbie.refreshGUI()
end

function Nebbie.onBuffSoon(spell)
  spell = Nebbie.normalizeBuffSpell(spell)
  if not spell or not Nebbie.shouldTrackBuff(spell) then return end
  if Nebbie.buffs[spell] then Nebbie.buffs[spell].soon = true
  else
    Nebbie.buffs[spell] = {
      since = Nebbie.now(),
      duration = Nebbie.buffDurations[spell] or 0,
      soon = true,
      active = true,
      synced = false,
    }
  end
  Nebbie.refreshGUI()
end

function Nebbie.matchDebuffApply(name, plain)
  if not plain or plain == "" then return false end
  local low = plain:lower()
  if name == "web" then
    return low:find("ragnatela", 1, true) ~= nil or low:find("ragnatele", 1, true) ~= nil
  end
  return true
end

function Nebbie.onDebuffApplied(name)
  Nebbie.debuffs[name] = { since = Nebbie.now(), active = true }
  Nebbie.refreshGUI()
end

function Nebbie.onDebuffWearOff(name)
  Nebbie.debuffs[name] = nil
  Nebbie.refreshGUI()
end

-- Loot mob corpo / pile of dust and bones (not PC corpses).
-- Uses look snapshot: corp, 2.corp, 3.corp … / pile, 2.pile, 3.pile …
function Nebbie.isMobKillExpLine(line)
  local plain = Nebbie.stripColors(line or "")
  if plain == "" then return false end
  if plain:find("%$c") then return false end
  return plain:match("^La tua esperienza e' aumentata di %d+ punti%.?$") ~= nil
end

function Nebbie.isTrustedCoinLine(line)
  local plain = Nebbie.stripColors(line or "")
  if plain == "" then return false end
  if plain:find("%$c") then return false end
  if plain:match("^%S+%s+C'erano") or plain:match("^%S+%s+C'era") then return false end
  return plain:match("^C'erano %d+ monete%.?$") ~= nil
    or plain:match("^C'era una miserabile moneta%.?$") ~= nil
end

function Nebbie.classifyCorpseLookLine(plain)
  if not plain or plain == "" then return nil end
  local low = plain:lower()
  if low:find("pile of dust and bones") or low:find("polvere") and low:find("ossa") then
    return "pile"
  end
  if low:find("corpo sfigurato") then return "corp" end
  if low:find("il corpo di un ") or low:find("il corpo di una ") or low:find("il corpo di uno ") then
    return "corp"
  end
  if low:find("il corpo di ") then
    if plain:match("il corpo di [%u%u'][%a']*$") or plain:match("il corpo di [%u%u'][%a']*%s") then
      return "pc"
    end
    return "corp"
  end
  return nil
end

function Nebbie.resetLookLoot()
  Nebbie._lookLootActive = false
  Nebbie._lookLootCorpses = 0
  Nebbie._lookLootPiles = 0
end

function Nebbie.onLookLootLine(line)
  if not Nebbie._lookLootActive then return end
  local plain = Nebbie.stripColors(line or "")
  local kind = Nebbie.classifyCorpseLookLine(plain)
  if kind == "corp" then
    Nebbie._lookLootCorpses = (Nebbie._lookLootCorpses or 0) + 1
  elseif kind == "pile" then
    Nebbie._lookLootPiles = (Nebbie._lookLootPiles or 0) + 1
  end
end

function Nebbie.runCmdQueue(cmds, idx, onDone)
  idx = idx or 1
  if not cmds or idx > #cmds then
    if onDone then onDone() end
    return
  end
  send(cmds[idx])
  tempTimer(0.5, function() Nebbie.runCmdQueue(cmds, idx + 1, onDone) end)
end

function Nebbie.runLootQueue(cmds, idx)
  Nebbie.runCmdQueue(cmds, idx, function() Nebbie._lootBusy = false end)
end

function Nebbie.buildLootCommands()
  local cmds = {}
  local corpses = Nebbie._lookLootCorpses or 0
  local piles = Nebbie._lookLootPiles or 0
  for i = 1, corpses do
    if i == 1 then
      table.insert(cmds, "get all corp")
    else
      table.insert(cmds, "get all " .. i .. ".corp")
    end
  end
  for i = 1, piles do
    if i == 1 then
      table.insert(cmds, "get all pile")
    else
      table.insert(cmds, "get all " .. i .. ".pile")
    end
  end
  if corpses == 0 and piles == 0 then
    cmds = {"get all corp", "get all pile"}
  end
  return cmds
end

function Nebbie.finishLookLoot(verbose)
  Nebbie._lookLootActive = false
  local cmds = Nebbie.buildLootCommands()
  if verbose then
    cecho("<green>Nebbie: loot <yellow>" .. #cmds .. "<green> comandi"
      .. " (<grey>corp=" .. tostring(Nebbie._lookLootCorpses or 0)
      .. " pile=" .. tostring(Nebbie._lookLootPiles or 0) .. "<grey>).\n")
  end
  Nebbie._lootBusy = true
  Nebbie.runLootQueue(cmds, 1)
end

function Nebbie.startLookLoot(verbose)
  if Nebbie._lootBusy then
    if verbose then cecho("<orange>Nebbie: loot gia' in corso.\n") end
    return
  end
  Nebbie.resetLookLoot()
  Nebbie._lookLootActive = true
  Nebbie._lookLootCorpses = 0
  Nebbie._lookLootPiles = 0
  send("look")
  if Nebbie._lookLootTimer then killTimer(Nebbie._lookLootTimer) end
  Nebbie._lookLootTimer = tempTimer(1.0, function()
    Nebbie._lookLootTimer = nil
    Nebbie.finishLookLoot(verbose)
  end)
end

function Nebbie.lootMobRemains(verbose)
  Nebbie.startLookLoot(verbose)
end

-- Cambio arma da borsa sulla schiena: usa <arma>
function Nebbie.normalizeEqDesc(desc)
  if not desc or desc == "" then return "" end
  local plain = Nebbie.stripColors(desc)
  plain = plain:gsub("%s*%b()", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  return plain:lower()
end

function Nebbie.getEqKeywordRules()
  Nebbie.loadSettings()
  local rules = {}
  for _, r in ipairs(Nebbie.DEFAULT_EQ_KEYWORDS or {}) do
    table.insert(rules, r)
  end
  for _, r in ipairs(Nebbie._settings.eqKeywords or {}) do
    if type(r) == "table" and r.match and r.key then
      table.insert(rules, r)
    end
  end
  return rules
end

function Nebbie.guessEqKeyword(desc)
  local plain = Nebbie.normalizeEqDesc(desc)
  if plain == "" then return "" end
  local orig = Nebbie.stripColors(desc):gsub("%s*%b()", "")
  for word in orig:gmatch("[%w']+") do
    if word:match("^%u") and #word >= 4 then
      local low = word:lower()
      if not Nebbie.EQ_STOPWORDS[low] then return low end
    end
  end
  plain = plain:gsub("^un[oa']%s+", ""):gsub("^uno%s+", ""):gsub("^il%s+", "")
  plain = plain:gsub("^la%s+", ""):gsub("^lo%s+", ""):gsub("^i%s+", "")
  plain = plain:gsub("^le%s+", ""):gsub("^gli%s+", ""):gsub("^l['']", "")
  plain = plain:gsub("^a%s+", ""):gsub("^an%s+", "")
  local first = plain:match("^(%S+)")
  return first or plain
end

function Nebbie.lookupEqKeyword(desc)
  local norm = Nebbie.normalizeEqDesc(desc)
  if norm == "" then return "" end
  local bestKey, bestLen = nil, 0
  for _, r in ipairs(Nebbie.getEqKeywordRules()) do
    local m = (r.match or ""):lower()
    if m ~= "" and norm:find(m, 1, true) and #m > bestLen then
      bestKey = r.key
      bestLen = #m
    end
  end
  if bestKey then return bestKey end
  return Nebbie.guessEqKeyword(desc)
end

function Nebbie.eqItemKeyword(desc)
  return Nebbie.lookupEqKeyword(desc)
end

function Nebbie.addEqKey(key, pattern)
  key = Nebbie.stripQuotes(key or ""):lower()
  pattern = Nebbie.stripQuotes(pattern or ""):lower()
  if key == "" or pattern == "" then
    cecho("<orange>Nebbie: <yellow>nkey add <chiave> <testo nel nome eq><orange>\n")
    cecho("<grey>Esempio: <yellow>nkey add korred borsa inesauribile korred\n")
    return
  end
  Nebbie.loadSettings()
  Nebbie._settings.eqKeywords = Nebbie._settings.eqKeywords or {}
  for i, r in ipairs(Nebbie._settings.eqKeywords) do
    if r.match == pattern then
      Nebbie._settings.eqKeywords[i] = { match = pattern, key = key }
      Nebbie.saveSettings()
      cecho("<green>Nebbie: aggiornato <yellow>" .. pattern .. " <green>→ <yellow>" .. key .. "\n")
      return
    end
  end
  table.insert(Nebbie._settings.eqKeywords, { match = pattern, key = key })
  Nebbie.saveSettings()
  cecho("<green>Nebbie: chiave <yellow>" .. key .. " <green>per nome che contiene <yellow>" .. pattern .. "\n")
end

function Nebbie.delEqKey(pattern)
  pattern = Nebbie.stripQuotes(pattern or ""):lower()
  if pattern == "" then
    cecho("<orange>Nebbie: <yellow>nkey del <testo><orange>\n")
    return
  end
  Nebbie.loadSettings()
  local kept, removed = {}, false
  for _, r in ipairs(Nebbie._settings.eqKeywords or {}) do
    if r.match == pattern then removed = true
    else table.insert(kept, r) end
  end
  Nebbie._settings.eqKeywords = kept
  Nebbie.saveSettings()
  if removed then
    cecho("<green>Nebbie: rimossa regola per <yellow>" .. pattern .. "\n")
  else
    cecho("<orange>Nebbie: nessuna regola custom per <yellow>" .. pattern .. "\n")
  end
end

function Nebbie.listEqKeys()
  cecho("<cyan><b>Chiavi eq Nebbie</b> <grey>(match nel nome da eq → parola MUD)\n")
  for _, r in ipairs(Nebbie.DEFAULT_EQ_KEYWORDS or {}) do
    cecho("<grey>  <yellow>" .. r.key .. " <grey>← <white>" .. r.match .. " <dark_green>(default)\n")
  end
  Nebbie.loadSettings()
  for _, r in ipairs(Nebbie._settings.eqKeywords or {}) do
    cecho("<grey>  <yellow>" .. r.key .. " <grey>← <white>" .. r.match .. "\n")
  end
  cecho("<grey>Aggiungi: <yellow>nkey add korred borsa korred<grey> | <yellow>nkey del testo\n")
end

function Nebbie.parseEqSlotLine(line)
  if not line or line == "" then return nil, nil end
  local plain = Nebbie.stripColors(line)
  local wield = plain:match("<impugnato>%s+(.+)")
  if wield and wield ~= "Qualcosa." then return "wield", wield end
  local back = plain:match("<sulla schiena>%s+(.+)")
  if back and back ~= "Qualcosa." then return "back", back end
  return nil, nil
end

function Nebbie.onEqParseLine(line)
  if not Nebbie._eqParseActive or not Nebbie._weaponSwap then return end
  local slot, item = Nebbie.parseEqSlotLine(line)
  if slot == "wield" then Nebbie._weaponSwap.wield = item
  elseif slot == "back" then Nebbie._weaponSwap.back = item end
end

function Nebbie.pollEqFromBuffer()
  if type(getLastLineNumber) ~= "function" or type(getLines) ~= "function" then return end
  local last = getLastLineNumber()
  if not last or last < 1 then return end
  local from = math.max(1, last - 80)
  local lines = getLines(from, last)
  if type(lines) ~= "table" then return end
  for _, text in ipairs(lines) do
    if type(text) == "string" and text ~= "" then
      Nebbie.onEqParseLine(text)
    end
  end
end

function Nebbie.buildWeaponSwapCommands(ws)
  local backKw = Nebbie.eqItemKeyword(ws.back)
  local wieldKw = ws.wield and Nebbie.eqItemKeyword(ws.wield) or nil
  local weapon = ws.weapon
  if backKw == "" or not weapon or weapon == "" then return nil end
  local cmds = {
    "rem " .. backKw,
    "get " .. weapon .. " " .. backKw,
  }
  if wieldKw and wieldKw ~= "" then
    table.insert(cmds, "rem " .. wieldKw)
  end
  table.insert(cmds, "wie " .. weapon)
  if wieldKw and wieldKw ~= "" then
    table.insert(cmds, "put " .. wieldKw .. " " .. backKw)
  end
  table.insert(cmds, "wear " .. backKw)
  return cmds
end

function Nebbie.finishWeaponSwap(verbose)
  if Nebbie._weaponSwapTimer then
    killTimer(Nebbie._weaponSwapTimer)
    Nebbie._weaponSwapTimer = nil
  end
  Nebbie._eqParseActive = false
  local ws = Nebbie._weaponSwap
  Nebbie._weaponSwap = nil
  if not ws then return end
  Nebbie.pollEqFromBuffer()
  if not ws.back then
    cecho("<red>Nebbie: nessun oggetto nello slot <sulla schiena> — controlla con eq.\n")
    return
  end
  local cmds = Nebbie.buildWeaponSwapCommands(ws)
  if not cmds then
    cecho("<red>Nebbie: impossibile costruire la sequenza cambio arma.\n")
    return
  end
  if verbose then
    cecho("<green>Nebbie: cambio arma → <yellow>" .. ws.weapon
      .. "<green> (borsa: <yellow>" .. Nebbie.lookupEqKeyword(ws.back)
      .. "<green>, impugnato: <yellow>" .. tostring(ws.wield and Nebbie.lookupEqKeyword(ws.wield) or "(vuoto)")
      .. "<green>).\n")
  end
  Nebbie._weaponSwapBusy = true
  Nebbie.runCmdQueue(cmds, 1, function() Nebbie._weaponSwapBusy = false end)
end

function Nebbie.swapWeapon(weaponKw, verbose)
  weaponKw = Nebbie.stripQuotes(weaponKw or "")
  if weaponKw == "" then
    cecho("<orange>Nebbie: sintassi <yellow>usa <arma><orange> (es. <yellow>usa spada<orange>).\n")
    return
  end
  if Nebbie._weaponSwapBusy then
    if verbose ~= false then cecho("<orange>Nebbie: cambio arma gia' in corso.\n") end
    return
  end
  Nebbie._weaponSwap = { weapon = weaponKw, wield = nil, back = nil }
  Nebbie._eqParseActive = true
  send("eq")
  if Nebbie._weaponSwapTimer then killTimer(Nebbie._weaponSwapTimer) end
  Nebbie._weaponSwapTimer = tempTimer(1.5, function()
    Nebbie._weaponSwapTimer = nil
    Nebbie.pollEqFromBuffer()
    Nebbie.finishWeaponSwap(verbose ~= false)
  end)
end

function Nebbie.onMobKillExp(line)
  if not Nebbie.lootAuto then return end
  if not Nebbie.isMobKillExpLine(line) then return end
  tempTimer(0.25, function() Nebbie.startLookLoot(false) end)
end

function Nebbie.setLootAuto(on)
  Nebbie.lootAuto = on
  Nebbie._settings.lootAuto = on
  Nebbie.saveSettings()
  if on then
    cecho("<green>Nebbie: loot automatico mob attivo (su exp reale).\n")
  else
    cecho("<green>Nebbie: loot automatico disattivato — usa <yellow>nloot<green>.\n")
  end
end

function Nebbie.execQuick(entry, target)
  if entry.kind == "cast" then
    Nebbie.sendCast(entry.target, target)
  elseif entry.kind == "recall" then
    local cmd = "recall '" .. entry.target .. "'"
    if target and target ~= "" then cmd = cmd .. " " .. target end
    send(cmd)
  elseif entry.kind == "mind" then
    local cmd = "mind '" .. entry.target .. "'"
    if target and target ~= "" then cmd = cmd .. " " .. target end
    send(cmd)
  elseif entry.kind == "skill" then
    local info = Nebbie.dedicatedSkills[entry.target]
    local cmd = info and info.cmd or entry.target
    if target and target ~= "" then send(cmd .. " " .. target) else send(cmd) end
  end
end

Nebbie.guiW = 600
Nebbie.guiH = 680
Nebbie.guiHeaderH = 28
Nebbie.guiMargin = 12
Nebbie.guiLayoutVer = 8
Nebbie.guiGaugeH = 22
Nebbie.guiGaugeGap = 6
Nebbie.guiGaugeArea = 96
Nebbie.guiFontSize = 11
Nebbie.guiBar = "NebbieHUDBar"
Nebbie.guiConsole = "NebbieHUD"
Nebbie._bars = Nebbie._bars or {}

function Nebbie.guiExists()
  return Nebbie._guiBuilt == true
end

function Nebbie.guiHidden()
  return Nebbie._guiHidden == true
end

function Nebbie.showGUI()
  if type(showWindow) ~= "function" then return end
  showWindow(Nebbie.guiConsole)
  showWindow(Nebbie.guiBar)
  for key, _ in pairs(Nebbie._bars) do
    Nebbie.showBar(key)
  end
  Nebbie._guiHidden = false
end

function Nebbie.hideGUI()
  if type(hideWindow) ~= "function" then return end
  hideWindow(Nebbie.guiConsole)
  hideWindow(Nebbie.guiBar)
  for key, _ in pairs(Nebbie._bars) do
    Nebbie.hideBar(key)
  end
  Nebbie._guiHidden = true
end

function Nebbie.calcGUIPos()
  local mw, mh = getMainWindowSize()
  local w, h, m = Nebbie.guiW, Nebbie.guiH, Nebbie.guiMargin
  local x = math.max(m, mw - w - m)
  local y = m
  return x, y, w, h
end

function Nebbie.raiseBarLayers(key)
  if type(raiseWindow) ~= "function" then return end
  local bar = Nebbie._bars[key]
  if not bar then return end
  pcall(function() raiseWindow(bar.back) end)
  pcall(function() raiseWindow(bar.front) end)
  pcall(function() raiseWindow(bar.text) end)
end

function Nebbie.showBar(key)
  local bar = Nebbie._bars[key]
  if not bar or type(showWindow) ~= "function" then return end
  showWindow(bar.back)
  showWindow(bar.front)
  showWindow(bar.text)
end

function Nebbie.hideBar(key)
  local bar = Nebbie._bars[key]
  if not bar or type(hideWindow) ~= "function" then return end
  hideWindow(bar.back)
  hideWindow(bar.front)
  hideWindow(bar.text)
end

function Nebbie.deleteBar(key)
  local bar = Nebbie._bars[key]
  if not bar then return end
  if type(deleteLabel) == "function" then
    pcall(function() deleteLabel(bar.back) end)
    pcall(function() deleteLabel(bar.front) end)
    pcall(function() deleteLabel(bar.text) end)
  end
  Nebbie._bars[key] = nil
end

function Nebbie.deleteLegacyGauges()
  local keys = {"NebbieHP", "NebbieMN", "NebbieMV"}
  if type(deleteGauge) ~= "function" then return end
  for _, key in ipairs(keys) do
    pcall(function() deleteGauge(key) end)
  end
end

function Nebbie.paintBar(key, rgb, backRgb)
  backRgb = backRgb or {42, 42, 56}
  local bar = Nebbie._bars[key]
  if not bar or type(setBackgroundColor) ~= "function" then return end
  local r, g, b = rgb[1], rgb[2], rgb[3]
  pcall(function() setBackgroundColor(bar.back, backRgb[1], backRgb[2], backRgb[3], 255) end)
  pcall(function() setBackgroundColor(bar.front, r, g, b, 255) end)
  pcall(function() setBackgroundColor(bar.text, 0, 0, 0, 0) end)
  if type(setFgColor) == "function" then
    pcall(function() setFgColor(bar.text, 240, 240, 240) end)
  end
  Nebbie.raiseBarLayers(key)
end

Nebbie.paintGauge = Nebbie.paintBar

function Nebbie.createBar(spec, gx, gy2, gw)
  if type(createLabel) ~= "function" then return false end
  local x, y = math.floor(gx), math.floor(gy2)
  local h = Nebbie.guiGaugeH
  local backK = spec.key .. "_back"
  local frontK = spec.key .. "_front"
  local textK = spec.key .. "_text"
  local ok = pcall(function()
    createLabel(backK, x, y, gw, h, 0)
    createLabel(frontK, x, y, 1, h, 0)
    createLabel(textK, x, y, gw, h, 0)
  end)
  if not ok then return false end
  Nebbie._bars[spec.key] = { x = x, y = y, w = gw, h = h, back = backK, front = frontK, text = textK }
  Nebbie.paintBar(spec.key, spec.color, {42, 42, 56})
  Nebbie.showBar(spec.key)
  return true
end

function Nebbie.moveBar(key, gx, gy2, gw)
  local bar = Nebbie._bars[key]
  if not bar or type(moveWindow) ~= "function" or type(resizeWindow) ~= "function" then
    return false
  end
  local x, y = math.floor(gx), math.floor(gy2)
  local h = Nebbie.guiGaugeH
  bar.x, bar.y, bar.w, bar.h = x, y, gw, h
  pcall(function() moveWindow(bar.back, x, y) end)
  pcall(function() resizeWindow(bar.back, gw, h) end)
  pcall(function() moveWindow(bar.text, x, y) end)
  pcall(function() resizeWindow(bar.text, gw, h) end)
  return true
end

function Nebbie.ensureBars(x, y, w)
  local gx, gy = x + 12, y + Nebbie.guiHeaderH + 6
  local gw = w - 24
  Nebbie._barSpecs = {
    NebbieHP = { key = "NebbieHP", label = "HP", color = {45, 200, 70} },
    NebbieMN = { key = "NebbieMN", label = "MN", color = {70, 150, 255} },
    NebbieMV = { key = "NebbieMV", label = "MV", color = {230, 190, 50} },
  }
  local specs = {
    Nebbie._barSpecs.NebbieHP,
    Nebbie._barSpecs.NebbieMN,
    Nebbie._barSpecs.NebbieMV,
  }
  for i, spec in ipairs(specs) do
    local gy2 = gy + (i - 1) * (Nebbie.guiGaugeH + Nebbie.guiGaugeGap)
    if Nebbie._bars[spec.key] then
      if not Nebbie.moveBar(spec.key, gx, gy2, gw) then
        Nebbie.deleteBar(spec.key)
      end
    end
    if not Nebbie._bars[spec.key] then
      Nebbie.createBar(spec, gx, gy2, gw)
    else
      Nebbie.paintBar(spec.key, spec.color, {42, 42, 56})
    end
  end
  Nebbie.updateGauges()
end

function Nebbie.setBarText(key, text)
  local bar = Nebbie._bars[key]
  if not bar then return end
  if type(clearWindow) == "function" then
    pcall(function() clearWindow(bar.text) end)
  end
  if type(echo) == "function" then
    pcall(function() echo(bar.text, " " .. text) end)
  end
end

function Nebbie.applyBarValue(key, cur, max, label)
  local bar = Nebbie._bars[key]
  if not bar or not cur or not max or max <= 0 then return end
  local pct = math.max(0, math.min(1, cur / max))
  local fw = math.max(1, math.floor(bar.w * pct))
  local text = label .. " " .. cur .. "/" .. max
  if type(moveWindow) == "function" and type(resizeWindow) == "function" then
    pcall(function() moveWindow(bar.front, bar.x, bar.y) end)
    pcall(function() resizeWindow(bar.front, fw, bar.h) end)
  end
  Nebbie.setBarText(key, text)
  local spec = Nebbie._barSpecs and Nebbie._barSpecs[key]
  if spec then Nebbie.paintBar(key, spec.color, {42, 42, 56}) end
  Nebbie.showBar(key)
  Nebbie.raiseBarLayers(key)
end

function Nebbie.setGauge(key, cur, max, text)
  local label = key:gsub("^Nebbie", "")
  if text and text ~= "" then
    local fromText = text:match("^(%S+)")
    if fromText then label = fromText end
  end
  Nebbie.applyBarValue(key, cur, max, label)
end

function Nebbie.updateGauges()
  local s = Nebbie.stats
  if s and s.hp and s.hpmax and s.hpmax > 0 then
    Nebbie.applyBarValue("NebbieHP", s.hp, s.hpmax, "HP")
    Nebbie.applyBarValue("NebbieMN", s.mana, s.manamax, "MN")
    Nebbie.applyBarValue("NebbieMV", s.move, s.movemax, "MV")
    return
  end
  Nebbie.applyBarValue("NebbieHP", 0, 1, "HP")
  Nebbie.applyBarValue("NebbieMN", 0, 1, "MN")
  Nebbie.applyBarValue("NebbieMV", 0, 1, "MV")
end

function Nebbie.applyGUIPosition(x, y, w, h)
  local bar, con = Nebbie.guiBar, Nebbie.guiConsole
  local hh = Nebbie.guiHeaderH
  if type(moveWindow) == "function" and type(resizeWindow) == "function" then
    moveWindow(bar, x, y)
    resizeWindow(bar, w, hh)
    local conY = y + hh + Nebbie.guiGaugeArea
    moveWindow(con, x, conY)
    resizeWindow(con, w, h - hh - Nebbie.guiGaugeArea)
    if type(raiseWindow) == "function" then raiseWindow(bar) end
  end
  Nebbie.ensureBars(x, y, w)
  for key, _ in pairs(Nebbie._bars or {}) do Nebbie.raiseBarLayers(key) end
  Nebbie._guiX, Nebbie._guiY = x, y
end

function Nebbie.moveGUITo(x, y, persist)
  local mw, mh = getMainWindowSize()
  local w, h, m = Nebbie.guiW, Nebbie.guiH, Nebbie.guiMargin
  x = math.max(m, math.min(x, mw - w - m))
  y = math.max(m, math.min(y, mh - h - m))
  Nebbie.applyGUIPosition(x, y, w, h)
  if persist then
    Nebbie._settings.guiCustom = true
    Nebbie._settings.guiX = x
    Nebbie._settings.guiY = y
    Nebbie.saveSettings()
  end
end

function Nebbie.positionGUI(verbose)
  if not Nebbie.guiExists() then
    if verbose then cecho("<orange>Nebbie: HUD assente — <yellow>nfix<orange>.\n") end
    return false
  end
  Nebbie.buffConsole = true
  local x, y, w, h
  if Nebbie._settings.guiCustom and Nebbie._settings.guiX and Nebbie._settings.guiY then
    x, y = Nebbie._settings.guiX, Nebbie._settings.guiY
    w, h = Nebbie.guiW, Nebbie.guiH
  else
    x, y, w, h = Nebbie.calcGUIPos()
  end
  Nebbie.applyGUIPosition(x, y, w, h)
  if verbose then cecho("<green>Nebbie: HUD in alto a destra (" .. x .. ", " .. y .. ").\n") end
  return true
end

function Nebbie.resetGUIPosition()
  Nebbie._settings.guiCustom = false
  Nebbie._settings.guiX = nil
  Nebbie._settings.guiY = nil
  Nebbie.saveSettings()
  return Nebbie.positionGUI(true)
end

function Nebbie.barClick(event)
  Nebbie._drag = Nebbie._drag or {}
  Nebbie._drag.active = true
  Nebbie._drag.gx0 = event.globalX or event.x or 0
  Nebbie._drag.gy0 = event.globalY or event.y or 0
  Nebbie._drag.x0 = Nebbie._guiX or 0
  Nebbie._drag.y0 = Nebbie._guiY or 0
end

function Nebbie.barMove(event)
  if not Nebbie._drag or not Nebbie._drag.active then return end
  local gx = event.globalX or event.x or 0
  local gy = event.globalY or event.y or 0
  local x = Nebbie._drag.x0 + (gx - Nebbie._drag.gx0)
  local y = Nebbie._drag.y0 + (gy - Nebbie._drag.gy0)
  Nebbie.moveGUITo(x, y, false)
end

function Nebbie.barRelease()
  if Nebbie._drag then Nebbie._drag.active = false end
  Nebbie._settings.guiCustom = true
  Nebbie._settings.guiX = Nebbie._guiX
  Nebbie._settings.guiY = Nebbie._guiY
  Nebbie.saveSettings()
end

function Nebbie.setupDragBar()
  if Nebbie._dragReady then return end
  if type(setLabelClickCallback) == "function" then setLabelClickCallback(Nebbie.guiBar, "Nebbie.barClick") end
  if type(setLabelMoveCallback) == "function" then setLabelMoveCallback(Nebbie.guiBar, "Nebbie.barMove") end
  if type(setLabelReleaseCallback) == "function" then setLabelReleaseCallback(Nebbie.guiBar, "Nebbie.barRelease") end
  Nebbie._dragReady = true
end

function Nebbie.buildGUI()
  local x, y, w, h = Nebbie.calcGUIPos()
  local hh = Nebbie.guiHeaderH
  createLabel(Nebbie.guiBar, x, y, w, hh, 1)
  setBackgroundColor(Nebbie.guiBar, 45, 45, 60, 255)
  setFgColor(Nebbie.guiBar, 200, 200, 220)
  echo(Nebbie.guiBar, " Nebbie HUD — trascina qui")
  local conY = y + hh + Nebbie.guiGaugeArea
  createMiniConsole(Nebbie.guiConsole, x, conY, w, h - hh - Nebbie.guiGaugeArea, true)
  setMiniConsoleFontSize(Nebbie.guiConsole, Nebbie.guiFontSize or 11)
  setBackgroundColor(Nebbie.guiConsole, 20, 20, 30, 200)
  setFgColor(Nebbie.guiConsole, 200, 200, 200)
  showWindow(Nebbie.guiBar)
  showWindow(Nebbie.guiConsole)
  Nebbie._guiBuilt = true
  Nebbie._guiHidden = false
  Nebbie.buffConsole = true
  Nebbie.setupDragBar()
  Nebbie.applyGUIPosition(x, y, w, h)
end

function Nebbie.destroyGUI()
  for key, _ in pairs(Nebbie._bars) do
    Nebbie.deleteBar(key)
  end
  Nebbie._bars = {}
  Nebbie.deleteLegacyGauges()
  if type(deleteMiniConsole) == "function" then pcall(function() deleteMiniConsole(Nebbie.guiConsole) end) end
  if type(deleteLabel) == "function" then pcall(function() deleteLabel(Nebbie.guiBar) end) end
  Nebbie._guiBuilt = false
  Nebbie._guiHidden = nil
  Nebbie.buffConsole = false
  Nebbie._dragReady = false
end

function Nebbie.stopGUI()
  if Nebbie.guiTimer then killTimer(Nebbie.guiTimer); Nebbie.guiTimer = nil end
  if Nebbie.attribTimer then killTimer(Nebbie.attribTimer); Nebbie.attribTimer = nil end
end

function Nebbie.initGUI()
  Nebbie.stopGUI()
  Nebbie.loadSettings()
  local layout = Nebbie._settings.guiLayout or 0
  if layout < Nebbie.guiLayoutVer then
    Nebbie.destroyGUI()
    Nebbie._settings.guiLayout = Nebbie.guiLayoutVer
    Nebbie._settings.guiCustom = false
    Nebbie._settings.guiX = nil
    Nebbie._settings.guiY = nil
    Nebbie.saveSettings()
  elseif Nebbie.guiExists() and not Nebbie.buffConsole then
    Nebbie.destroyGUI()
  end
  if not Nebbie.guiExists() then Nebbie.buildGUI()
  else
    Nebbie.buffConsole = true
    Nebbie.setupDragBar()
    Nebbie.positionGUI(false)
  end
  if not Nebbie.resizeHandler and type(registerAnonymousEventHandler) == "function" then
    Nebbie.resizeHandler = registerAnonymousEventHandler("sysWindowResizeEvent", function()
      if Nebbie._settings.guiCustom then
        Nebbie.moveGUITo(Nebbie._settings.guiX or Nebbie._guiX, Nebbie._settings.guiY or Nebbie._guiY, false)
      else
        Nebbie.positionGUI(false)
      end
    end)
  end
  tempTimer(0.05, function() Nebbie.positionGUI(false) end)
  Nebbie.guiTimer = tempTimer(1, function() Nebbie.refreshGUI() end, true)
  Nebbie.syncAttribTimer()
end

function Nebbie.toggleGUI()
  if not Nebbie.guiExists() then
    Nebbie.initGUI()
    return
  end
  if Nebbie.guiHidden() then Nebbie.showGUI() else Nebbie.hideGUI() end
end

function Nebbie.parsePromptCodes(raw)
  local out = {}
  if not raw or raw == "" then return out end
  local i = 1
  for _, slot in ipairs(Nebbie.PROMPT_SLOTS) do
    local ch = raw:sub(i, i)
    if ch and ch ~= "-" and ch ~= " " then
      table.insert(out, slot.name)
    end
    i = i + 1
  end
  return out
end

function Nebbie.parseAttribSpellLine(line)
  local plain = Nebbie.stripColors(line)
  local spell, dur = plain:match("Spell%s*:%s*'(.-)'%s*%-%s*(%d+)")
  if not spell or not dur then return end
  spell = Nebbie.normalizeBuffSpell(spell)
  if not spell or not Nebbie.shouldTrackBuff(spell) then return end
  local n = tonumber(dur) or 0
  if n <= 0 then
    Nebbie.buffs[spell] = nil
    return
  end
  local prev = Nebbie.buffs[spell]
  Nebbie.buffs[spell] = {
    since = Nebbie.now(),
    duration = n * Nebbie.TICK_SECONDS,
    ticks = n,
    soon = prev and prev.soon or false,
    active = true,
    source = "attribute",
    synced = true,
  }
end

function Nebbie.onAttribLine(line)
  if not Nebbie.attribGag then return end
  local plain = Nebbie.stripColors(line)
  if plain:find("Spells attivi") or plain:find("^%-%-%-%-") then
    if type(deleteLine) == "function" then deleteLine() end
    return
  end
  if plain:find("Spell%s*:%s*'") then
    Nebbie.parseAttribSpellLine(line)
    if type(deleteLine) == "function" then deleteLine() end
    return
  end
  if plain:match("^Tu hai") or plain:match("^Stai trasportando") or plain:match("^Tu sei")
      or plain:match("^Armor class") or plain:match("^Spellfail") or plain:match("^La tua capacita")
      or plain:match("^I tuoi hit") or plain:match("^Il tuo equipaggiamento") or plain:match("^Hit:")
      or plain:match("^anni e") then
    if type(deleteLine) == "function" then deleteLine() end
  end
end

function Nebbie.requestAttrib(silent)
  if Nebbie._attribBusy then return end
  Nebbie._attribBusy = true
  Nebbie.attribGag = true
  send("attribute")
  tempTimer(2, function()
    Nebbie.attribGag = false
    Nebbie._attribBusy = false
    Nebbie.refreshGUI()
    if not silent then cecho("<green>Nebbie: attribute sincronizzato.\n") end
  end)
end

function Nebbie.setAttribAuto(on)
  Nebbie.attribAuto = on
  Nebbie._settings.attribAuto = on
  Nebbie.saveSettings()
  Nebbie.syncAttribTimer()
  if on then cecho("<green>Nebbie: sync attribute ogni 90s attivo (gagged).\n")
  else cecho("<green>Nebbie: sync attribute automatico disattivato.\n") end
end

function Nebbie.syncAttribTimer()
  if Nebbie.attribTimer then killTimer(Nebbie.attribTimer); Nebbie.attribTimer = nil end
  if Nebbie.attribAuto then
    Nebbie.attribTimer = tempTimer(90, function()
      if Nebbie.attribAuto then Nebbie.requestAttrib(true) end
    end, true)
  end
end

function Nebbie.setupHUD()
  if Nebbie._setupRunning then return end
  Nebbie._setupRunning = true
  cecho("<green>Nebbie HUD v" .. Nebbie.version .. ": parser prompt attivo.\n")
  cecho("<grey>Comandi MUD liberi: <yellow>inv<grey>, <yellow>eq<grey>. Loot mob: <yellow>nloot<grey> | auto <yellow>nloot on<grey>\n")
  if not Nebbie.playerClass or Nebbie.playerClass == "" then Nebbie.setClass("+", true) end
  Nebbie.initGUI()
  Nebbie.pollPromptFromBuffer()
  Nebbie.updateGauges()
  Nebbie._setupRunning = false
end

function Nebbie.refreshGUI()
  if not Nebbie.guiExists() then return end
  if not Nebbie.stats then Nebbie.pollPromptFromBuffer() end
  Nebbie.pruneInvalidBuffs()
  Nebbie.pruneExpiredBuffs()
  local ok, err = pcall(function()
    clearWindow(Nebbie.guiConsole)
    local s = Nebbie.stats or {}
    cecho("NebbieHUD", "<cyan><b>=== Nebbie HUD v" .. Nebbie.version .. " ===</b>\n")
    if s.name then
      cecho("NebbieHUD", "<white>" .. s.name .. "  <grey>XP:<yellow>" .. tostring(s.xp or "?")
        .. " <grey>Oro:<yellow>" .. tostring(s.gold or "?") .. "\n")
    end
    if s.hp then
      cecho("NebbieHUD", "<grey>HP <white>" .. s.hp .. "/" .. s.hpmax
        .. "  <grey>MN <white>" .. s.mana .. "/" .. s.manamax
        .. "  <grey>MV <white>" .. s.move .. "/" .. s.movemax .. "\n")
    end
    if s.mobName and s.mobName ~= "*" then
      cecho("NebbieHUD", "<orange>Fight: <white>" .. (s.tankCond or "?") .. "/" .. (s.tankName or "?")
        .. " <grey>— <red>" .. (s.mobCond or "?") .. "/" .. s.mobName .. "\n")
    end
    if Nebbie.promptBuffs and #Nebbie.promptBuffs > 0 then
      cecho("NebbieHUD", "<grey>Prompt: <green>" .. table.concat(Nebbie.promptBuffs, ", ") .. "\n")
    end
    local now = Nebbie.now()
    local bcount = 0
    cecho("NebbieHUD", "<cyan>Buff:\n")
    for spell, data in pairs(Nebbie.buffs) do
      if type(spell) == "string" and spell:sub(1, 1) ~= "_" and type(data) == "table" then
        bcount = bcount + 1
        local elapsed = now - (data.since or now)
        local status = "<green>OK"
        local timeTxt = Nebbie.formatTime(elapsed)
        if data.soon then status = "<orange>!" end
        if data.duration and data.duration > 0 then
          local left = Nebbie.buffTimeLeft(data, now)
          timeTxt = Nebbie.formatTime(left or 0)
          if data.synced and left and left <= 0 then
            status = "<red>SCAD"
          elseif not data.synced and left and left <= 0 then
            timeTxt = timeTxt .. " ~"
          end
        end
        cecho("NebbieHUD", " " .. status .. " <white>" .. spell .. "  <grey>" .. timeTxt .. "\n")
      end
    end
    if bcount == 0 then cecho("NebbieHUD", " <grey>(nessun buff tracciato)\n") end
    local dcount = 0
    cecho("NebbieHUD", "<red>Debuff:\n")
    for name, data in pairs(Nebbie.debuffs) do
      if type(name) == "string" and type(data) == "table" then
        dcount = dcount + 1
        local elapsed = now - (data.since or now)
        cecho("NebbieHUD", " <red>!! <white>" .. name .. "  <grey>" .. Nebbie.formatTime(elapsed) .. "\n")
      end
    end
    if dcount == 0 then cecho("NebbieHUD", " <grey>(nessun debuff)\n") end
    local preset = Nebbie.getActivePreset()
    if preset and preset.quick then
      cecho("NebbieHUD", "<grey>Quick: ")
      for i, q in ipairs(preset.quick) do
        cecho("NebbieHUD", "<dark_green>q" .. i .. "<grey>=" .. tostring(q.abbr) .. " ")
      end
      cecho("NebbieHUD", "\n")
    end
  end)
  if not ok then cecho("<red>[Nebbie GUI] " .. tostring(err) .. "\n") end
  Nebbie.updateGauges()
end

function Nebbie.resolveSpell(token)
  local lower = Nebbie.stripQuotes(token):lower()
  for spell, abbr in pairs(Nebbie.abbrevs) do
    if abbr == lower then return spell end
  end
  for spell, _ in pairs(Nebbie.castSpells) do
    if spell:lower() == lower or spell:lower():gsub(" ", "") == lower:gsub(" ", "") then return spell end
  end
  for name, _ in pairs(Nebbie.dedicatedSkills) do
    if name:lower() == lower then return name end
  end
  for name, _ in pairs(Nebbie.mindSpells) do
    if name:lower() == lower then return name end
  end
  return token
end

function Nebbie.sendCast(spell, target)
  local mode = Nebbie.castMode
  if Nebbie.mindSpells[spell] then mode = "mind" end
  local cmd
  if mode == "mind" then cmd = "mind '" .. spell .. "'"
  elseif mode == "recall" then cmd = "recall '" .. spell .. "'"
  else cmd = "cast '" .. spell .. "'" end
  if target and target ~= "" then cmd = cmd .. " " .. target end
  send(cmd)
end

function Nebbie.uninstall()
  for full, _ in pairs(Nebbie._aliasIds or {}) do Nebbie.killTempAlias(full) end
  for full, _ in pairs(Nebbie._triggerIds or {}) do Nebbie.killTempTriggers(full) end
  Nebbie.purgePackageAliases()
  Nebbie.purgePackageTriggers()
  Nebbie.stopGUI()
  Nebbie.destroyGUI()
  Nebbie._aliasNames = {}
  Nebbie._triggerNames = {}
  Nebbie._aliasIds = {}
  Nebbie._triggerIds = {}
  cecho("<orange>Nebbie play-all: alias/trigger disattivati.\n")
end

function Nebbie.runFix()
  if Nebbie._fixRunning then return end
  Nebbie._fixRunning = true
  Nebbie.killAllTrackedTemps()
  Nebbie.purgeLegacyPermItems(true)
  Nebbie.disablePackagePermItems()
  Nebbie.killAllByNameVariants("reinstall fix", "alias")
  Nebbie.stopGUI()
  Nebbie.destroyGUI()
  Nebbie._installedVer = nil
  Nebbie.install()
  Nebbie.loadClass()
  if not Nebbie.playerClass then Nebbie.setClass("+", true) end
  cecho("<green>Nebbie v" .. Nebbie.version .. " reinstallato.\n")
  cecho("<grey>Alias vecchi perm disattivati. Se restano in Scripts, riavvia Mudlet una volta.\n")
  if type(tempTimer) == "function" then
    tempTimer(3, function() Nebbie._fixRunning = false end)
  else
    Nebbie._fixRunning = false
  end
end

function Nebbie.install()
  if Nebbie._installing then return end
  Nebbie._installing = true
  Nebbie.stopGUI()
  Nebbie.killAllTrackedTemps()
  Nebbie.disablePackagePermItems()
  Nebbie.purgeTrackedAliases()
  Nebbie.purgeTrackedTriggers()
  Nebbie.purgePackageAliases()
  Nebbie.purgePackageTriggers()
  Nebbie.purgeOrphanNebbieAliases()
  Nebbie.purgeOrphanNebbieTriggers()
  Nebbie._aliasNames = {}
  Nebbie._triggerNames = {}
  Nebbie._aliasIds = {}
  Nebbie._triggerIds = {}

  local function perm(short, pattern, script)
    if type(tempAlias) ~= "function" then return end
    local full = PKG .. "::" .. short
    Nebbie.killTempAlias(full)
    Nebbie.killAllByNameVariants(short, "alias")
    local id = tempAlias(pattern, script)
    if id then
      Nebbie._aliasIds[full] = id
      table.insert(Nebbie._aliasNames, full)
    else
      cecho("<red>[Nebbie] alias non creato: " .. full .. "\n")
    end
  end

  local function trig(short, patterns, script, isRegex)
    local full = PKG .. "::" .. short
    Nebbie.killTempTriggers(full)
    Nebbie.killAllByNameVariants(short, "trigger")
    local ids = {}
    if isRegex then
      if type(tempRegexTrigger) ~= "function" then return end
      local pats = type(patterns) == "table" and patterns or {patterns}
      for _, p in ipairs(pats) do
        local id = tempRegexTrigger(p, script)
        if id then table.insert(ids, id) end
      end
    elseif type(patterns) == "table" then
      if type(tempTrigger) ~= "function" then return end
      for _, p in ipairs(patterns) do
        local id = tempTrigger(p, script)
        if id then table.insert(ids, id) end
      end
    else
      if type(tempTrigger) ~= "function" then return end
      local id = tempTrigger(patterns, script)
      if id then table.insert(ids, id) end
    end
    if #ids > 0 then
      Nebbie._triggerIds[full] = ids
      table.insert(Nebbie._triggerNames, full)
    end
  end

  perm("mode cast", [[^ncast$]], [[Nebbie.setCastMode("cast")]])
  perm("mode recall", [[^nrecall$]], [[Nebbie.setCastMode("recall")]])
  perm("mode mind", [[^nmind$]], [[Nebbie.setCastMode("mind")]])
  perm("toggle gui", [[^ngui$]], [[Nebbie.toggleGUI()]])
  perm("toggle hud", [[^nhud$]], [[Nebbie.toggleGUI()]])
  perm("reposition gui", [[^npos$]], [[Nebbie.resetGUIPosition()]])
  perm("setup hud", [[^nsetup$]], [[Nebbie.setupHUD()]])
  perm("prompt debug", [[^nprompt$]], [[Nebbie.debugPrompt()]])
  perm("attrib sync", [[^nattrib$]], [[Nebbie.requestAttrib(false)]])
  perm("attrib on", [[^nattrib on$]], [[Nebbie.setAttribAuto(true)]])
  perm("attrib off", [[^nattrib off$]], [[Nebbie.setAttribAuto(false)]])
  perm("loot manual", [[^nloot$]], [[Nebbie.lootMobRemains(true)]])
  perm("loot on", [[^nloot on$]], [[Nebbie.setLootAuto(true)]])
  perm("loot off", [[^nloot off$]], [[Nebbie.setLootAuto(false)]])
  perm("swap weapon", [[^usa (.+)$]], [[Nebbie.swapWeapon(matches[2], true)]])
  perm("eq key list", [[^nkey$]], [[Nebbie.listEqKeys()]])
  perm("eq key add", [[^nkey add (.+) (.+)$]], [[Nebbie.addEqKey(matches[2], matches[3])]])
  perm("eq key del", [[^nkey del (.+)$]], [[Nebbie.delEqKey(matches[2])]])
  -- nfix: unico alias XML nel package (nebbie-fix), non crearlo qui

  perm("generic cast c", [[^c (.+)$]], [[
    local rest = matches[2]
    local spell, target = rest:match("^(%S+)%s+(.+)$")
    if not spell then spell, target = rest, nil end
    spell = Nebbie.resolveSpell(spell)
    if target then target = Nebbie.stripQuotes(target) end
    Nebbie.sendCast(spell, target)
  ]])
  perm("generic cast word", [[^cast (.+)$]], [[
    local rest = matches[2]
    local spell, target = rest:match("^(%S+)%s+(.+)$")
    if not spell then spell, target = rest, nil end
    spell = Nebbie.resolveSpell(spell)
    if target then target = Nebbie.stripQuotes(target) end
    Nebbie.sendCast(spell, target)
  ]])

  perm("memorize", [[^mem (.+)$]], [[
    local spell = Nebbie.resolveSpell(matches[2])
    send("memorize '" .. spell .. "'")
  ]])
  perm("recall shortcut", [[^r (.+)$]], [[
    local rest = matches[2]
    local spell, target = rest:match("^(%S+)%s+(.+)$")
    if not spell then spell, target = rest, nil end
    spell = Nebbie.resolveSpell(spell)
    local cmd = "recall '" .. spell .. "'"
    if target then cmd = cmd .. " " .. target end
    send(cmd)
  ]])
  perm("mind shortcut", [[^m (.+)$]], [[
    local rest = matches[2]
    local spell, target = rest:match("^(%S+)%s+(.+)$")
    if not spell then spell, target = rest, nil end
    spell = Nebbie.resolveSpell(spell)
    local cmd = "mind '" .. spell .. "'"
    if target then cmd = cmd .. " " .. target end
    send(cmd)
  ]])

  for spell, abbr in pairs(Nebbie.abbrevs) do
    if (Nebbie.castSpells[spell] or Nebbie.mindSpells[spell]) and Nebbie.safeStandalone[abbr] then
      local s = spell:gsub("'", "\\'")
      local a = abbr:gsub("([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1")
      perm("abbr cast " .. abbr, "^" .. a .. "(?: (.+))?$", string.format([[
        local target = matches[2]
        Nebbie.sendCast('%s', target)
      ]], s))
    end
  end

  for _, spell in ipairs(Nebbie.favoriteSpells or {}) do
    if Nebbie.castSpells[spell] or Nebbie.mindSpells[spell] then
      local s = spell:gsub("'", "\\'")
      local abbr = Nebbie.abbrevs[spell]
      if not abbr or abbr ~= spell then
        local p = spell:gsub("([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1")
        perm("fav cast " .. spell, "^" .. p .. "(?: (.+))?$", string.format([[
          local target = matches[2]
          Nebbie.sendCast('%s', target)
        ]], s))
      end
    end
  end

  for skillName, info in pairs(Nebbie.dedicatedSkills) do
    local abbr = Nebbie.abbrevs[skillName] or Nebbie.abbrevs[info.cmd] or info.cmd:gsub(" ", "")
    if Nebbie.safeStandalone[abbr] then
      abbr = abbr:gsub("([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1")
      local cmd = info.cmd
      perm("skill " .. info.cmd, "^" .. abbr .. "(?: (.+))?$", string.format([[
        local args = matches[2]
        if args and args ~= "" then send("%s " .. args) else send("%s") end
      ]], cmd, cmd))
    end
  end

  perm("list classes", [[^nclass$]], [[Nebbie.listClasses()]])
  perm("set class", [[^nclass (.+)$]], [[Nebbie.setClass(matches[2])]])

  for slot = 1, 9 do
    perm("quick slot " .. slot, "^q" .. slot .. "(?: (.+))?$", string.format([[
      local preset = Nebbie.getActivePreset()
      if not preset or not preset.quick[%d] then
        cecho("<red>Slot q%d non configurato.\n")
        return
      end
      Nebbie.execQuick(preset.quick[%d], matches[2])
    ]], slot, slot, slot))
  end

  perm("return form", [[^return$]], [[send("return")]])

  trig("prompt parse", {[[H:\d+/\d+.*M:\d+/\d+.*V:\d+/\d+.*X:\d+]]}, [[if Nebbie and Nebbie.onPromptLine then Nebbie.onPromptLine() end]], true)
  trig("attrib gag", {"Tu hai", "Spells attivi", "Spell :"}, [[if Nebbie and Nebbie.onAttribLine then Nebbie.onAttribLine(line) end]])

  trig("eq parse wield", {"<impugnato>", "<sulla schiena>"}, [[
    if Nebbie and Nebbie.onEqParseLine then Nebbie.onEqParseLine(line) end
  ]])

  trig("look loot parse", {"il corpo di", "corpo sfigurato", "pile of dust", "Pile of dust"}, [[
    if Nebbie and Nebbie._lookLootActive and Nebbie.onLookLootLine then Nebbie.onLookLootLine(line) end
  ]])

  trig("mob kill exp loot", {[[^La tua esperienza e' aumentata di \d+ punti\.?$]]}, [[
    if Nebbie and Nebbie.onMobKillExp then Nebbie.onMobKillExp(line) end
  ]], true)

  trig("cast started", {"Pronunci le parole"}, [[
    if Nebbie and Nebbie.stripColors and Nebbie.onBuffApplied then
      local plain = Nebbie.stripColors(line)
      local spell = plain:match("Pronunci le parole, '(.-)'")
      if spell then Nebbie.onBuffApplied(spell) end
    end
  ]])

  for _, entry in ipairs(Nebbie.wearOff) do
    local label = entry.name:gsub("'", "\\'")
    trig("wearoff " .. entry.name, {entry.pattern}, string.format([[
      if Nebbie and Nebbie.onBuffWearOff then Nebbie.onBuffWearOff('%s') end
    ]], label))
  end

  for _, entry in ipairs(Nebbie.wearOffSoon) do
    trig("soon " .. entry.name, {entry.pattern}, string.format([[
      if Nebbie and Nebbie.onBuffSoon then Nebbie.onBuffSoon('%s') end
    ]], entry.name:gsub("'", "\\'")))
  end

  for _, entry in ipairs(Nebbie.debuffApply or {}) do
    local label = entry.name:gsub("'", "\\'")
    trig("debuff on " .. entry.name .. " " .. entry.pattern, {entry.pattern}, string.format([[
      if Nebbie and Nebbie.stripColors and Nebbie.onDebuffApplied then
        local plain = Nebbie.stripColors(line)
        if plain:find("%s", 1, true) and Nebbie.matchDebuffApply('%s', plain) then
          Nebbie.onDebuffApplied('%s')
        end
      end
    ]], entry.pattern:gsub("([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1"), label, label))
  end

  for _, entry in ipairs(Nebbie.debuffWearOff or {}) do
    local label = entry.name:gsub("'", "\\'")
    trig("debuff off " .. entry.name .. " " .. entry.pattern, {entry.pattern}, string.format([[
      if Nebbie and Nebbie.stripColors and Nebbie.onDebuffWearOff then
        local plain = Nebbie.stripColors(line)
        if plain:find("%s", 1, true) then Nebbie.onDebuffWearOff('%s') end
      end
    ]], entry.pattern:gsub("([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1"), label))
  end

  for _, entry in ipairs(Nebbie.failures) do
    trig("fail " .. entry.name, {entry.pattern}, "")
  end

  Nebbie.installPromptHooks()
  Nebbie.testPromptParse(true)

  cecho("<green>Nebbie v" .. Nebbie.version .. ": " .. #Nebbie._aliasNames .. " alias, " .. #Nebbie._triggerNames .. " trigger.\n")
  cecho("<grey>Pronto: <yellow>nclass +<grey>, <yellow>q1<grey>, <yellow>ngui<grey> | <yellow>nfix<grey> <yellow>nprompt<grey>\n")
  cecho("<grey>inv/eq liberi per MUD. Loot: corp/2.corp/… + pile/2.pile/…; <yellow>nloot off<grey> disattiva auto.\n")
  Nebbie._installing = false
  Nebbie.initGUI()
end

function Nebbie.boot()
  if Nebbie._bootInProgress then return end
  Nebbie._bootInProgress = true
  Nebbie.loadSettings()
  if Nebbie._settings.attribAuto then Nebbie.attribAuto = true end
  if Nebbie._settings.lootAuto == false then Nebbie.lootAuto = false end
  Nebbie.warnLegacyPackages()
  Nebbie.pruneInvalidBuffs()
  Nebbie.pruneExpiredBuffs()
  Nebbie.purgeLegacyPermItems(true)
  if Nebbie._installedVer == Nebbie.version and Nebbie._aliasIds and next(Nebbie._aliasIds) ~= nil then
    if not Nebbie.guiExists() then Nebbie.initGUI() end
    if not Nebbie.loadClass() then Nebbie.setClass("+", true) end
    Nebbie.syncAttribTimer()
    Nebbie._mainLoaded = true
    Nebbie._bootInProgress = false
    return
  end
  Nebbie._installedVer = Nebbie.version
  Nebbie.install()
  Nebbie.testPromptParse(false)
  if not Nebbie.loadClass() then Nebbie.setClass("+", true) end
  Nebbie.syncAttribTimer()
  Nebbie._mainLoaded = true
  Nebbie._bootInProgress = false
end

Nebbie.boot()
