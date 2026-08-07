-- Nebbie dashboard panels (equip, spells, paths, weapon config) — per-character profiles
-- Loaded after nebbie-installer-core.lua; hooks existing GUI/buff/eq handlers.

Nebbie.dashboardVer = 2
Nebbie.EQ_LABEL_WIDTH = 13
Nebbie.expiredSpells = Nebbie.expiredSpells or {}
Nebbie.eqWornByLabel = Nebbie.eqWornByLabel or {}
Nebbie._dashboardHidden = Nebbie._dashboardHidden or false

-- Ordine e etichette come pannello equip italiano (screenshot Lamreloc / Nebbie)
Nebbie.EQ_SLOTS = {
  { tag = "<sul dito destro>", label = "Dito Dx" },
  { tag = "<sul dito sinistro>", label = "Dito Sx" },
  { tag = "<intorno al collo>", label = "Collo", alt = 1 },
  { tag = "<intorno al collo>", label = "Collo 2", alt = 2 },
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
  { tag = "<come luce>", label = "Luce" },
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

function Nebbie.getCharName()
  if Nebbie.stats and Nebbie.stats.name then return Nebbie.stats.name end
  if Nebbie._charName and Nebbie._charName ~= "" then return Nebbie._charName end
  return nil
end

function Nebbie.ensureCharProfile()
  local name = Nebbie.getCharName()
  if not name then return nil end
  Nebbie.loadSettings()
  Nebbie._settings.charProfiles = Nebbie._settings.charProfiles or {}
  if not Nebbie._settings.charProfiles[name] then
    Nebbie._settings.charProfiles[name] = { weapons = {}, utility = {}, paths = {} }
    Nebbie.saveSettings()
  end
  return Nebbie._settings.charProfiles[name], name
end

function Nebbie.setWeaponKey(slot, value)
  local profile, name = Nebbie.ensureCharProfile()
  if not profile then
    cecho("<orange>Nebbie: nome PG non rilevato — esegui un comando e riprova.\n")
    return
  end
  slot = (slot or ""):lower()
  value = Nebbie.stripQuotes(value or ""):lower()
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
  value = Nebbie.stripQuotes(value or ""):lower()
  if value == "" then return end
  profile.utility = profile.utility or {}
  profile.utility[slot] = value
  Nebbie.saveSettings()
  cecho("<green>Nebbie [" .. name .. "]: <yellow>" .. slot .. " <green>= <white>" .. value .. "\n")
  Nebbie.refreshConfigPanel()
end

function Nebbie.addPath(name, route)
  local profile = Nebbie.ensureCharProfile()
  if not profile then return end
  name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
  route = (route or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if name == "" or route == "" then
    cecho("<orange>Nebbie: <yellow>npath add <nome> <percorso>\n")
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
  cecho("<cyan><b>Paths [" .. tostring(name) .. "]</b>\n")
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
  if idx then path = profile.paths[idx]
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
    cecho("<orange>Nebbie: speedWalk non disponibile.\n")
  end
end

function Nebbie.castSpellByName(spell)
  if not spell or spell == "" then return end
  local resolved = Nebbie.resolveSpell and Nebbie.resolveSpell(spell) or spell
  if Nebbie.sendCast then
    Nebbie.sendCast(resolved, nil)
  else
    send("cast '" .. resolved .. "'")
  end
end

function Nebbie.useWeaponKeyword(keyword)
  keyword = Nebbie.stripQuotes(keyword or "")
  if keyword == "" then return end
  if Nebbie.swapWeapon then
    Nebbie.swapWeapon(keyword, true)
  else
    send("wie " .. keyword)
  end
end

function Nebbie.eqShortName(item)
  item = item:gsub("^un[oa']%s+", ""):gsub("^uno%s+", ""):gsub("^il%s+", "")
  item = item:gsub("^la%s+", ""):gsub("^lo%s+", ""):gsub("^i%s+", "")
  item = item:gsub("^le%s+", ""):gsub("^gli%s+", ""):gsub("^l['']", "")
  return item:gsub("%s+$", ""):gsub("^%s+", "")
end

function Nebbie.onDashboardEqLine(line)
  if not line or line == "" then return end
  local plain = Nebbie.stripColors(line)
  if plain:find("Stai usando", 1, true) then
    Nebbie._dashEqActive = true
    Nebbie.eqWornByLabel = {}
    Nebbie._dashNeck = 0
    return
  end
  if not Nebbie._dashEqActive then return end
  if plain:match("^Nulla%.?") then
    Nebbie._dashEqActive = false
    Nebbie.refreshEqPanel()
    return
  end
  for _, slot in ipairs(Nebbie.EQ_SLOTS) do
    if plain:find(slot.tag, 1, true) then
      local item = plain:match(slot.tag .. "%s*(.+)$")
      if item then
        item = item:gsub("^%s+", ""):gsub("%s+$", "")
        if item ~= "" and item ~= "Qualcosa." then
          local label = slot.label
          if slot.alt == 1 then
            Nebbie._dashNeck = 1
          elseif slot.alt == 2 then
            Nebbie._dashNeck = 2
          end
          Nebbie.eqWornByLabel[label] = item
          if label == "Impugnato" then
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
end

function Nebbie.requestEqPanel()
  if Nebbie.requestEqCache then
    Nebbie.requestEqCache(false)
  else
    Nebbie._dashEqActive = true
    Nebbie.eqWornByLabel = {}
    send("eq")
    if type(tempTimer) == "function" then
      tempTimer(2, function()
        Nebbie._dashEqActive = false
        Nebbie.refreshEqPanel()
      end)
    end
  end
end

function Nebbie.trackExpiredSpell(spell)
  if not spell then return end
  if Nebbie.normalizeBuffSpell then spell = Nebbie.normalizeBuffSpell(spell) end
  Nebbie.expiredSpells = Nebbie.expiredSpells or {}
  Nebbie.expiredSpells[spell:lower()] = spell
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
  if not p or not l or type(createLabel) ~= "function" then return end
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
  if type(clearWindow) == "function" then pcall(function() clearWindow(con) end) end
end

function Nebbie.echoLinkLine(con, text, cmd, hint)
  if type(echoLink) == "function" then
    echoLink(con, text, cmd, hint or text, true)
  else
    cecho(con, text)
  end
end

function Nebbie.formatEqSlotLabel(label)
  local w = Nebbie.EQ_LABEL_WIDTH or 13
  if #label > w then return label:sub(1, w) end
  return label .. string.rep(" ", w - #label)
end

function Nebbie.refreshEqPanel()
  local p = Nebbie.panels.eq
  if not p or not Nebbie.dashboardExists() then return end
  Nebbie.clearPanel(p.con)
  for _, slot in ipairs(Nebbie.EQ_SLOTS) do
    local item = Nebbie.eqWornByLabel[slot.label]
    local label = Nebbie.formatEqSlotLabel(slot.label)
    cecho(p.con, "<goldenrod>" .. label .. "<grey>: ")
    if item and item ~= "" then
      cecho(p.con, "<light_green>" .. item .. "\n")
    else
      cecho(p.con, "<dark_grey>(vuoto)\n")
    end
  end
end

function Nebbie.refreshSpellPanel()
  local p = Nebbie.panels.spells
  if not p or not Nebbie.dashboardExists() then return end
  Nebbie.clearPanel(p.con)
  local activeLower = {}
  local activeCount = 0
  for spell, data in pairs(Nebbie.buffs or {}) do
    if type(spell) == "string" and spell:sub(1, 1) ~= "_" and type(data) == "table" and data.active then
      activeLower[spell:lower()] = spell
      activeCount = activeCount + 1
      local label = spell:upper()
      local esc = spell:gsub("'", "\\'")
      Nebbie.echoLinkLine(p.con, "<light_green>" .. label .. "\n",
        "Nebbie.castSpellByName('" .. esc .. "')", "Lancia " .. spell)
    end
  end
  local expiredCount = 0
  for lower, spell in pairs(Nebbie.expiredSpells or {}) do
    if not activeLower[lower] then
      expiredCount = expiredCount + 1
      local label = (type(spell) == "string" and spell:upper()) or lower:upper()
      local esc = (type(spell) == "string" and spell) or lower
      esc = esc:gsub("'", "\\'")
      Nebbie.echoLinkLine(p.con, "<red>" .. label .. "\n",
        "Nebbie.castSpellByName('" .. esc .. "')", "Rilancia " .. esc)
    end
  end
  if activeCount == 0 and expiredCount == 0 then
    cecho(p.con, "<grey>(nessuna spell tracciata)\n")
  end
end

function Nebbie.refreshPathsPanel()
  local p = Nebbie.panels.paths
  if not p or not Nebbie.dashboardExists() then return end
  Nebbie.clearPanel(p.con)
  local profile = Nebbie.ensureCharProfile()
  if profile and profile.paths and #profile.paths > 0 then
    for i, path in ipairs(profile.paths) do
      Nebbie.echoLinkLine(p.con, "<cyan>" .. path.name .. ":<grey> ",
        "Nebbie.runPath(" .. i .. ")", "Esegui " .. path.name)
      cecho(p.con, "<sky_blue>" .. path.route:sub(1, 70) .. "\n")
    end
  else
    cecho(p.con, "<grey>npath add <nome> <percorso>\n")
  end
end

function Nebbie.refreshConfigPanel()
  local p = Nebbie.panels.config
  if not p or not Nebbie.dashboardExists() then return end
  Nebbie.clearPanel(p.con)
  local profile, name = Nebbie.ensureCharProfile()
  if name then
    cecho(p.con, "<goldenrod>Personaggio: <white>" .. name .. "\n")
  end
  if not profile then
    cecho(p.con, "<grey>Esegui un comando per rilevare il nome.\n")
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
        "Nebbie.useWeaponKeyword('" .. esc .. "')", "usa " .. val)
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
  cecho(p.con, "<grey>nweapon slash spada | nkey add korred ...\n")
end

function Nebbie.refreshDashboard()
  if not Nebbie.dashboardExists() then return end
  Nebbie.refreshEqPanel()
  Nebbie.refreshSpellPanel()
  Nebbie.refreshPathsPanel()
  Nebbie.refreshConfigPanel()
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
  Nebbie._dashboardHidden = false
end

function Nebbie.hideDashboard()
  for _, p in pairs(Nebbie.panels) do
    hideWindow(p.bar)
    hideWindow(p.con)
  end
  Nebbie._dashboardHidden = true
end

function Nebbie.toggleDashboard()
  if not Nebbie.dashboardExists() then
    Nebbie.initDashboard()
    return
  end
  if Nebbie._dashboardHidden then Nebbie.showDashboard() else Nebbie.hideDashboard() end
end

function Nebbie.destroyDashboard()
  for _, p in pairs(Nebbie.panels) do
    if type(deleteMiniConsole) == "function" then pcall(function() deleteMiniConsole(p.con) end) end
    if type(deleteLabel) == "function" then pcall(function() deleteLabel(p.bar) end) end
  end
  if Nebbie._dashResizeHandler and type(killAnonymousEventHandler) == "function" then
    pcall(function() killAnonymousEventHandler(Nebbie._dashResizeHandler) end)
    Nebbie._dashResizeHandler = nil
  end
end

function Nebbie.buildDashboard()
  local layout = Nebbie.dashboardLayout()
  for key, _ in pairs(Nebbie.panels) do
    Nebbie.buildPanel(key, layout)
  end
  Nebbie.refreshDashboard()
end

function Nebbie.initDashboard()
  Nebbie.loadSettings()
  local ver = Nebbie._settings.dashboardVer or 0
  if ver < Nebbie.dashboardVer then
    Nebbie.destroyDashboard()
    Nebbie._settings.dashboardVer = Nebbie.dashboardVer
    Nebbie.saveSettings()
  end
  if not Nebbie.dashboardExists() then
    Nebbie.buildDashboard()
  else
    Nebbie.refreshDashboard()
  end
  if not Nebbie._dashResizeHandler and type(registerAnonymousEventHandler) == "function" then
    Nebbie._dashResizeHandler = registerAnonymousEventHandler("sysWindowResizeEvent", function()
      if Nebbie.dashboardExists() then Nebbie.buildDashboard() end
    end)
  end
  tempTimer(0.5, function() Nebbie.requestEqPanel() end)
end

-- Hook play-all handlers (dashboard loads after installer core)
do
  local _origOnEqParseLine = Nebbie.onEqParseLine
  function Nebbie.onEqParseLine()
    if Nebbie.onDashboardEqLine then
      Nebbie.onDashboardEqLine(Nebbie.resolveTriggerLine())
    end
    if _origOnEqParseLine then return _origOnEqParseLine() end
  end

  local _origOnBuffWearOff = Nebbie.onBuffWearOff
  function Nebbie.onBuffWearOff(spell)
    if _origOnBuffWearOff then _origOnBuffWearOff(spell) end
    Nebbie.trackExpiredSpell(spell)
    Nebbie.refreshSpellPanel()
  end

  local _origOnBuffApplied = Nebbie.onBuffApplied
  function Nebbie.onBuffApplied(spell)
    if _origOnBuffApplied then _origOnBuffApplied(spell) end
    if spell and Nebbie.expiredSpells then
      local key = spell
      if Nebbie.normalizeBuffSpell then key = Nebbie.normalizeBuffSpell(spell) end
      Nebbie.expiredSpells[key:lower()] = nil
    end
    Nebbie.refreshSpellPanel()
  end

  local _origRefreshGUI = Nebbie.refreshGUI
  function Nebbie.refreshGUI()
    if _origRefreshGUI then _origRefreshGUI() end
    Nebbie.refreshDashboard()
  end

  local _origInitGUI = Nebbie.initGUI
  function Nebbie.initGUI()
    if _origInitGUI then _origInitGUI() end
    Nebbie.initDashboard()
  end

  local _origDestroyGUI = Nebbie.destroyGUI
  function Nebbie.destroyGUI()
    Nebbie.destroyDashboard()
    if _origDestroyGUI then _origDestroyGUI() end
  end

  local _origShowGUI = Nebbie.showGUI
  function Nebbie.showGUI()
    if _origShowGUI then _origShowGUI() end
    Nebbie.showDashboard()
  end

  local _origHideGUI = Nebbie.hideGUI
  function Nebbie.hideGUI()
    if _origHideGUI then _origHideGUI() end
    Nebbie.hideDashboard()
  end
end
