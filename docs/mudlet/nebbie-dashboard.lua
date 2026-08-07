-- Nebbie dashboard: equip, spell, paths, weapon config (per-character profiles)

Nebbie.dashboardVer = 3
Nebbie.expiredSpells = Nebbie.expiredSpells or {}
Nebbie.eqWorn = Nebbie.eqWorn or {}
Nebbie.eqWornByLabel = Nebbie.eqWornByLabel or {}
Nebbie._eqParseActive = false

Nebbie.EQ_SLOTS = {
  { tag = "<come luce>", label = "Luce" },
  { tag = "<sul dito destro>", label = "Dito Dx" },
  { tag = "<sul dito sinistro>", label = "Dito Sx" },
  { tag = "<intorno al collo>", label = "Collo 1" },
  { tag = "<intorno al collo>", label = "Collo 2", dup = 2 },
  { tag = "<sul corpo>", label = "Corpo" },
  { tag = "<in testa>", label = "Testa" },
  { tag = "<sulle gambe>", label = "Gambe" },
  { tag = "<ai piedi>", label = "Piedi" },
  { tag = "<sulle mani>", label = "Mani" },
  { tag = "<sulle braccia>", label = "Braccia" },
  { tag = "<come scudo>", label = "Scudo" },
  { tag = "<intorno al corpo>", label = "Sopra" },
  { tag = "<intorno alla vita>", label = "Vita" },
  { tag = "<al polso destro>", label = "Polso Dx" },
  { tag = "<al polso sinistro>", label = "Polso Sx" },
  { tag = "<impugnato>", label = "Impugnato" },
  { tag = "<tenuto>", label = "Tenuto" },
  { tag = "<sulla schiena>", label = "Schiena" },
  { tag = "<all'orecchio destro>", label = "Orecchio Dx" },
  { tag = "<all'orecchio sinistro>", label = "Orecchio Sx" },
  { tag = "<davanti agli occhi>", label = "Occhi" },
  { tag = "<incoccata>", label = "Incoccata" },
}

Nebbie.WEAPON_SLOTS = {
  { key = "current", label = "arma attuale" },
  { key = "slash", label = "slash" },
  { key = "blunt", label = "blunt" },
  { key = "pierce", label = "pierce" },
}

Nebbie.UTILITY_SLOTS = {
  { key = "tiro", label = "tiro" },
  { key = "hold", label = "hold" },
  { key = "sacca", label = "sacca" },
  { key = "bevanda", label = "bevanda" },
}

Nebbie.panels = {
  eq = { bar = "NebbieEqBar", con = "NebbieEq", title = "Equip" },
  spells = { bar = "NebbieSpellsBar", con = "NebbieSpells", title = "SpellWindow" },
  paths = { bar = "NebbiePathsBar", con = "NebbiePaths", title = "UpWindow" },
  config = { bar = "NebbieConfigBar", con = "NebbieConfig", title = "ConfigWindow" },
}

Nebbie.dashMargin = 6
Nebbie.dashHeaderH = 18
Nebbie.dashLeftW = 210
Nebbie.dashRightW = 260
Nebbie.dashSpellH = 130
Nebbie.dashPathsH = 110

function Nebbie.stripColors(line)
  if not line then return "" end
  line = line:gsub("%$c%d%d%d%d", "")
  line = line:gsub("\27%[[%d;]*m", "")
  return line
end

function Nebbie.getCharName()
  if Nebbie.stats and Nebbie.stats.name then return Nebbie.stats.name end
  if Nebbie._charName and Nebbie._charName ~= "" then return Nebbie._charName end
  return nil
end

function Nebbie.parsePromptName(line)
  local plain = Nebbie.stripColors(line or "")
  plain = plain:gsub(">>%s*$", ""):gsub("^%s+", ""):gsub("%s+$", "")
  local pos = plain:find("H:%d+/%d+") or plain:find("H%d+/%d+") or plain:find("PF %d+/%d+")
  if not pos then return nil end
  local prefix = plain:sub(1, pos - 1):gsub("%s+$", "")
  local name = prefix:match("(%S+)%s*$")
  if name and #name >= 2 then
    Nebbie._charName = name
    return name
  end
  return nil
end

function Nebbie.ensureCharProfile()
  local name = Nebbie.getCharName()
  if not name then return nil end
  Nebbie.loadSettings()
  Nebbie._settings.charProfiles = Nebbie._settings.charProfiles or {}
  if not Nebbie._settings.charProfiles[name] then
    Nebbie._settings.charProfiles[name] = {
      weapons = {},
      utility = {},
      paths = {},
    }
    Nebbie.saveSettings()
  end
  return Nebbie._settings.charProfiles[name], name
end

function Nebbie.setWeaponKey(slot, value)
  local profile, name = Nebbie.ensureCharProfile()
  if not profile then
    cecho("<orange>Nebbie: nome PG non rilevato — muovi il PG (prompt) e riprova.\n")
    return
  end
  slot = (slot or ""):lower()
  value = (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if value == "" then
    cecho("<orange>Nebbie: <yellow>nweapon " .. slot .. " <parola_mud>\n")
    return
  end
  profile.weapons = profile.weapons or {}
  profile.weapons[slot] = value
  Nebbie.saveSettings()
  cecho("<green>Nebbie [" .. name .. "]: <yellow>" .. slot .. " <green>= <white>" .. value .. "\n")
  Nebbie.refreshConfigPanel()
end

function Nebbie.setUtilityKey(slot, value)
  local profile, name = Nebbie.ensureCharProfile()
  if not profile then return end
  slot = (slot or ""):lower()
  value = (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if value == "" then return end
  profile.utility = profile.utility or {}
  profile.utility[slot] = value
  Nebbie.saveSettings()
  cecho("<green>Nebbie [" .. name .. "]: <yellow>" .. slot .. " <green>= <white>" .. value .. "\n")
  Nebbie.refreshConfigPanel()
end

function Nebbie.addPath(name, route)
  local profile, charName = Nebbie.ensureCharProfile()
  if not profile then return end
  name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
  route = (route or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if name == "" or route == "" then
    cecho("<orange>Nebbie: <yellow>npath add <nome> <percorso>\n")
    cecho("<grey>Esempio: <white>npath add nt s, 2e, 4s, e, w, 7s\n")
    return
  end
  profile.paths = profile.paths or {}
  for i, p in ipairs(profile.paths) do
    if p.name == name then
      profile.paths[i] = { name = name, route = route }
      Nebbie.saveSettings()
      cecho("<green>Nebbie: path <yellow>" .. name .. "<green> aggiornato.\n")
      Nebbie.refreshPathsPanel()
      return
    end
  end
  table.insert(profile.paths, { name = name, route = route })
  Nebbie.saveSettings()
  cecho("<green>Nebbie: path <yellow>" .. name .. "<green> aggiunto.\n")
  Nebbie.refreshPathsPanel()
end

function Nebbie.delPath(name)
  local profile = Nebbie.ensureCharProfile()
  if not profile then return end
  name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
  local kept, found = {}, false
  for _, p in ipairs(profile.paths or {}) do
    if p.name == name then found = true else table.insert(kept, p) end
  end
  profile.paths = kept
  Nebbie.saveSettings()
  if found then
    cecho("<green>Nebbie: path <yellow>" .. name .. "<green> rimosso.\n")
    Nebbie.refreshPathsPanel()
  else
    cecho("<orange>Nebbie: path non trovato.\n")
  end
end

function Nebbie.listPaths()
  local profile, name = Nebbie.ensureCharProfile()
  if not profile then return end
  cecho("<cyan><b>Paths [" .. name .. "]</b>\n")
  if not profile.paths or #profile.paths == 0 then
    cecho("<grey>  (nessuno) — <yellow>npath add <nome> <percorso>\n")
    return
  end
  for i, p in ipairs(profile.paths) do
    cecho("<grey>  <yellow>" .. i .. ". " .. p.name .. " <white>" .. p.route .. "\n")
  end
end

function Nebbie.normalizeSpeedwalk(route)
  if not route then return "" end
  local s = route:gsub("%([^)]+%)", "")
  s = s:gsub(",", "")
  s = s:gsub("%s+", "")
  return s
end

function Nebbie.runPath(indexOrName)
  local profile = Nebbie.ensureCharProfile()
  if not profile or not profile.paths then return end
  local idx = tonumber(indexOrName)
  local path
  if idx then
    path = profile.paths[idx]
  else
    for _, p in ipairs(profile.paths) do
      if p.name == indexOrName then path = p break end
    end
  end
  if not path then
    cecho("<orange>Nebbie: path non trovato.\n")
    return
  end
  local sw = Nebbie.normalizeSpeedwalk(path.route)
  if sw == "" then
    cecho("<orange>Nebbie: percorso vuoto.\n")
    return
  end
  if type(speedWalk) == "function" then
    cecho("<green>Nebbie: speedwalk <yellow>" .. path.name .. "<green> → <white>" .. sw .. "\n")
    speedWalk(sw)
  else
    cecho("<orange>Nebbie: speedWalk non disponibile — Mudlet troppo vecchio?\n")
  end
end

function Nebbie.castSpellByName(spell)
  if not spell or spell == "" then return end
  spell = spell:lower()
  for real, _ in pairs(Nebbie.castSpells or {}) do
    if real:lower() == spell then
      Nebbie.sendCast(real, nil)
      return
    end
  end
  for real, _ in pairs(Nebbie.mindSpells or {}) do
    if real:lower() == spell then
      Nebbie.sendCast(real, nil)
      return
    end
  end
  Nebbie.sendCast(spell, nil)
end

function Nebbie.onEqParseLine(line)
  if not line or line == "" then return end
  local plain = Nebbie.stripColors(line)
  if plain:find("Stai usando", 1, true) then
    Nebbie._eqParseActive = true
    Nebbie.eqWorn = {}
    Nebbie.eqWornByLabel = {}
    return
  end
  if not Nebbie._eqParseActive then return end
  if plain:match("^Nulla%.?") then
    Nebbie._eqParseActive = false
    Nebbie.refreshEqPanel()
    return
  end
  for _, slot in ipairs(Nebbie.EQ_SLOTS) do
    local tag = slot.tag
    if plain:find(tag, 1, true) then
      local item = plain:match(tag .. "%s*(.+)$")
      if item then
        item = item:gsub("^%s+", ""):gsub("%s+$", "")
        if item ~= "" and item ~= "Qualcosa." then
          Nebbie.eqWorn[tag] = item
          Nebbie.eqWornByLabel[slot.label] = item
          if slot.label == "Impugnato" then
            local profile = Nebbie.ensureCharProfile()
            if profile then
              profile.weapons = profile.weapons or {}
              profile.weapons.current = Nebbie.eqShortName(item)
              Nebbie.saveSettings()
            end
          end
        end
      end
      break
    end
  end
  if plain:match("^%[%s*%d+%]") and not plain:find("<", 1, true) then
    Nebbie._eqParseActive = false
    Nebbie.refreshEqPanel()
  end
end

function Nebbie.eqShortName(item)
  item = item:gsub("^un[oa']%s+", ""):gsub("^uno%s+", ""):gsub("^il%s+", "")
  item = item:gsub("^la%s+", ""):gsub("^lo%s+", ""):gsub("^i%s+", "")
  item = item:gsub("^le%s+", ""):gsub("^gli%s+", ""):gsub("^l['']", "")
  return item:gsub("%s+$", ""):gsub("^%s+", "")
end

function Nebbie.requestEqPanel()
  Nebbie._eqParseActive = true
  Nebbie.eqWorn = {}
  send("eq")
  if type(tempTimer) == "function" then
    tempTimer(1.5, function()
      Nebbie._eqParseActive = false
      Nebbie.refreshEqPanel()
    end)
  end
end

function Nebbie.dashboardLayout()
  local mw, mh = getMainWindowSize()
  local m = Nebbie.dashMargin
  local leftW = Nebbie.dashLeftW
  local rightW = Nebbie.dashRightW
  local leftX = m
  local rightX = mw - rightW - m
  local topY = m
  local fullH = mh - 2 * m
  local spellH = Nebbie.dashSpellH
  local pathsH = Nebbie.dashPathsH
  local gap = 6
  local configH = fullH - spellH - pathsH - 2 * gap
  return {
    eq = { x = leftX, y = topY, w = leftW, h = fullH },
    spells = { x = rightX, y = topY, w = rightW, h = spellH },
    paths = { x = rightX, y = topY + spellH + gap, w = rightW, h = pathsH },
    config = { x = rightX, y = topY + spellH + pathsH + 2 * gap, w = rightW, h = configH },
  }
end

function Nebbie.buildPanel(key, layout)
  local p = Nebbie.panels[key]
  local l = layout[key]
  if not p or not l then return end
  local hh = Nebbie.dashHeaderH
  createLabel(p.bar, l.x, l.y, l.w, hh, 1)
  setBackgroundColor(p.bar, 50, 42, 30, 255)
  setFgColor(p.bar, 220, 190, 120)
  echo(p.bar, " " .. p.title)
  createMiniConsole(p.con, l.x, l.y + hh, l.w, l.h - hh, true)
  setMiniConsoleFontSize(p.con, 9)
  setBackgroundColor(p.con, 18, 18, 24, 230)
  setFgColor(p.con, 200, 200, 200)
  showWindow(p.bar)
  showWindow(p.con)
end

function Nebbie.clearPanel(con)
  if type(clearWindow) == "function" then
    pcall(function() clearWindow(con) end)
  end
end

function Nebbie.echoLinkLine(con, text, cmd, hint)
  if type(echoLink) == "function" then
    echoLink(con, text, cmd, hint or text, true)
  else
    cecho(con, text)
  end
end

function Nebbie.refreshEqPanel()
  local p = Nebbie.panels.eq
  if not p or type(isHidden) ~= "function" then return end
  local ok = pcall(function() return isHidden(p.con) end)
  if not ok then return end
  Nebbie.clearPanel(p.con)
  local colTag, colItem = 120, 80
  for _, slot in ipairs(Nebbie.EQ_SLOTS) do
    local item = Nebbie.eqWornByLabel[slot.label] or Nebbie.eqWorn[slot.tag]
    local label = slot.label
    cecho(p.con, "<goldenrod>" .. label .. ":<grey> ")
    if item and item ~= "" then
      cecho(p.con, "<light_green>" .. item .. "\n")
    else
      cecho(p.con, "<dark_grey>(vuoto)\n")
    end
  end
end

function Nebbie.refreshSpellPanel()
  local p = Nebbie.panels.spells
  if not p then return end
  Nebbie.clearPanel(p.con)
  local now = Nebbie.now()
  local activeCount = 0
  for spell, data in pairs(Nebbie.buffs or {}) do
    if type(spell) == "string" and spell:sub(1, 1) ~= "_" and type(data) == "table" and data.active then
      activeCount = activeCount + 1
      local label = spell:upper()
      local esc = spell:gsub("'", "\\'")
      Nebbie.echoLinkLine(p.con, "<light_green>" .. label .. "\n",
        "Nebbie.castSpellByName('" .. esc .. "')", "Lancia " .. spell)
    end
  end
  local expiredCount = 0
  for spell, _ in pairs(Nebbie.expiredSpells or {}) do
    if not (Nebbie.buffs and Nebbie.buffs[spell]) then
      expiredCount = expiredCount + 1
      local label = spell:upper()
      local esc = spell:gsub("'", "\\'")
      Nebbie.echoLinkLine(p.con, "<red>" .. label .. "\n",
        "Nebbie.castSpellByName('" .. esc .. "')", "Rilancia " .. spell)
    end
  end
  if activeCount == 0 and expiredCount == 0 then
    cecho(p.con, "<grey>(nessuna spell tracciata)\n")
  end
end

function Nebbie.refreshPathsPanel()
  local p = Nebbie.panels.paths
  if not p then return end
  Nebbie.clearPanel(p.con)
  local profile, name = Nebbie.ensureCharProfile()
  if profile and profile.paths and #profile.paths > 0 then
    for i, path in ipairs(profile.paths) do
      local esc = path.name:gsub("'", "\\'")
      Nebbie.echoLinkLine(p.con, "<cyan>" .. path.name .. ":<grey> ",
        "Nebbie.runPath(" .. i .. ")", "Esegui " .. path.name)
      cecho(p.con, "<sky_blue>" .. path.route:sub(1, 60) .. "\n")
    end
  else
    cecho(p.con, "<grey>npath add <nome> <percorso>\n")
  end
end

function Nebbie.refreshConfigPanel()
  local p = Nebbie.panels.config
  if not p then return end
  Nebbie.clearPanel(p.con)
  local profile, name = Nebbie.ensureCharProfile()
  if name then
    cecho(p.con, "<goldenrod>Personaggio: <white>" .. name .. "\n")
  end
  if not profile then
    cecho(p.con, "<grey>Muovi il PG per rilevare il nome.\n")
    return
  end
  profile.weapons = profile.weapons or {}
  profile.utility = profile.utility or {}
  for _, slot in ipairs(Nebbie.WEAPON_SLOTS) do
    local val = profile.weapons[slot.key] or "-"
    cecho(p.con, "<yellow>" .. slot.label .. ":<grey> ")
    if val ~= "-" then
      local esc = val:gsub("'", "\\'")
      Nebbie.echoLinkLine(p.con, "<light_green>" .. val .. "\n",
        "send('wie " .. esc .. "')", "wie " .. val)
    else
      cecho(p.con, "<dark_grey>-\n")
    end
  end
  for _, slot in ipairs(Nebbie.UTILITY_SLOTS) do
    local val = profile.utility[slot.key] or "-"
    cecho(p.con, "<yellow>" .. slot.label .. ":<grey> ")
    if val ~= "-" then
      local esc = val:gsub("'", "\\'")
      local cmd = slot.key == "hold" and ("hold " .. esc) or ("get " .. esc)
      Nebbie.echoLinkLine(p.con, "<light_green>" .. val .. "\n",
        "send('" .. cmd .. "')", cmd)
    else
      cecho(p.con, "<dark_grey>-\n")
    end
  end
  cecho(p.con, "<grey>nweapon slash <parola> | nutility hold <parola>\n")
end

function Nebbie.refreshDashboard()
  Nebbie.refreshEqPanel()
  Nebbie.refreshSpellPanel()
  Nebbie.refreshPathsPanel()
  Nebbie.refreshConfigPanel()
end

function Nebbie.destroyDashboard()
  for _, p in pairs(Nebbie.panels) do
    if type(deleteMiniConsole) == "function" then
      pcall(function() deleteMiniConsole(p.con) end)
    end
    if type(deleteLabel) == "function" then
      pcall(function() deleteLabel(p.bar) end)
    end
  end
  if Nebbie.panels.eq then
    pcall(function() deleteMiniConsole(Nebbie.guiConsole) end)
    pcall(function() deleteLabel(Nebbie.guiBar) end)
  end
end

function Nebbie.buildDashboard()
  local layout = Nebbie.dashboardLayout()
  for key, _ in pairs(Nebbie.panels) do
    Nebbie.buildPanel(key, layout)
  end
  Nebbie.refreshDashboard()
end

function Nebbie.dashboardExists()
  local p = Nebbie.panels.eq
  if not p then return false end
  local ok = pcall(function() return isHidden(p.con) end)
  return ok
end

function Nebbie.showDashboard()
  for _, p in pairs(Nebbie.panels) do
    showWindow(p.bar)
    showWindow(p.con)
  end
end

function Nebbie.hideDashboard()
  for _, p in pairs(Nebbie.panels) do
    hideWindow(p.bar)
    hideWindow(p.con)
  end
end

-- Override buff hooks for spell panel + expired tracking
function Nebbie.onBuffApplied(spell)
  local dur = Nebbie.buffDurations[spell] or 0
  Nebbie.buffs[spell] = {
    since = Nebbie.now(),
    duration = dur,
    soon = false,
    active = true,
  }
  Nebbie.buffs._lastCast = spell
  Nebbie.expiredSpells = Nebbie.expiredSpells or {}
  Nebbie.expiredSpells[spell] = nil
  Nebbie.refreshSpellPanel()
  if Nebbie.refreshGUI then Nebbie.refreshGUI() end
end

function Nebbie.onBuffWearOff(spell)
  Nebbie.buffs[spell] = nil
  Nebbie.expiredSpells = Nebbie.expiredSpells or {}
  Nebbie.expiredSpells[spell] = Nebbie.now()
  Nebbie.refreshSpellPanel()
  if Nebbie.refreshGUI then Nebbie.refreshGUI() end
end

function Nebbie.onBuffSoon(spell)
  if Nebbie.buffs[spell] then
    Nebbie.buffs[spell].soon = true
  else
    Nebbie.buffs[spell] = { since = Nebbie.now(), duration = 0, soon = true, active = true }
  end
  Nebbie.refreshSpellPanel()
  if Nebbie.refreshGUI then Nebbie.refreshGUI() end
end

-- Replace single buff panel with dashboard
function Nebbie.guiExists()
  return Nebbie.dashboardExists()
end

function Nebbie.destroyGUI()
  Nebbie.destroyDashboard()
  Nebbie.buffConsole = false
  Nebbie._dragReady = false
end

function Nebbie.buildGUI()
  Nebbie.buildDashboard()
  Nebbie.buffConsole = true
end

function Nebbie.applyGUIPosition(x, y, w, h)
  Nebbie.buildDashboard()
end

function Nebbie.positionGUI(verbose)
  if not Nebbie.dashboardExists() then
    if verbose then cecho("<orange>Nebbie: dashboard assente — <yellow>nfix\n") end
    return false
  end
  Nebbie.buildDashboard()
  if verbose then cecho("<green>Nebbie: dashboard laterale attiva.\n") end
  return true
end

function Nebbie.resetGUIPosition()
  Nebbie._settings.guiCustom = false
  return Nebbie.positionGUI(true)
end

function Nebbie.toggleGUI()
  if Nebbie.dashboardExists() and isHidden(Nebbie.panels.eq.con) then
    Nebbie.showDashboard()
  else
    Nebbie.hideDashboard()
  end
end

function Nebbie.initGUI()
  Nebbie.stopGUI()
  Nebbie.loadSettings()
  local ver = Nebbie._settings.dashboardVer or 0
  if ver < Nebbie.dashboardVer then
    Nebbie.destroyGUI()
    Nebbie._settings.dashboardVer = Nebbie.dashboardVer
    Nebbie.saveSettings()
  elseif Nebbie.dashboardExists() then
    Nebbie.refreshDashboard()
    if not Nebbie.resizeHandler and type(registerAnonymousEventHandler) == "function" then
      Nebbie.resizeHandler = registerAnonymousEventHandler("sysWindowResizeEvent", function()
        Nebbie.buildDashboard()
      end)
    end
    Nebbie.guiTimer = tempTimer(2, function() Nebbie.refreshDashboard() end, true)
    return
  end
  if not Nebbie.dashboardExists() then
    Nebbie.buildGUI()
  end
  if not Nebbie.resizeHandler and type(registerAnonymousEventHandler) == "function" then
    Nebbie.resizeHandler = registerAnonymousEventHandler("sysWindowResizeEvent", function()
      Nebbie.buildDashboard()
    end)
  end
  tempTimer(0.2, function()
    Nebbie.requestEqPanel()
  end)
  Nebbie.guiTimer = tempTimer(2, function() Nebbie.refreshDashboard() end, true)
end

function Nebbie.refreshGUI()
  Nebbie.refreshDashboard()
end
