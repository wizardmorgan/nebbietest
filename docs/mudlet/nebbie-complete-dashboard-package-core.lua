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

local PKG_VER = "1.15.68"
local PKG_REPO = "wizardmorgan/nebbie-mudlet-dashboard"
local PKG_FILE = "nebbie-complete-dashboard-package.mpackage"
-- @main su jsDelivr puo' restare stale (osservato: restava 1.15.56 mentre tip
-- era 1.15.59). npackageupdate risolve lo SHA tip via GitHub API e scarica
-- pinnato a quel commit. Installazione manuale: lua installPackage("URL")
-- (NON esiste un bottone "Installa da URL" in Package Manager).
local PKG_MPACKAGE_URL =
  "https://cdn.jsdelivr.net/gh/" .. PKG_REPO .. "@main/" .. PKG_FILE
local PKG_CORE_RAW_URL =
  "https://cdn.jsdelivr.net/gh/" .. PKG_REPO .. "@main/nebbie-complete-dashboard-package-core.lua"
local PKG_GITHUB_TIP_URL =
  "https://api.github.com/repos/" .. PKG_REPO .. "/commits/main"

local _prevPkgVer = NebbieDash and NebbieDash._loadedVer
-- Non uscire in anticipo dal chunk core (alias/trigger del package possono essere
-- appena stati rimontati da installPackage): serve sempre rieseguire boot() in coda.
if NebbieDash and _prevPkgVer and _prevPkgVer ~= PKG_VER then
  NebbieDash._mainLoaded = false
  NebbieDash._lastBootTime = nil
end

NebbieDash = NebbieDash or {}
NebbieDash.version = PKG_VER
NebbieDash._loadedVer = PKG_VER
NebbieDash._upgradeFromVer = (_prevPkgVer and _prevPkgVer ~= PKG_VER) and _prevPkgVer or nil
NebbieDash.package = "nebbie-complete-dashboard-package"
NebbieDash.PACKAGE_UPDATE_URL = PKG_MPACKAGE_URL

function NebbieDash.echoManualInstallHint(url)
  url = url or NebbieDash.PACKAGE_UPDATE_URL or PKG_MPACKAGE_URL
  cecho("<orange>Installazione manuale (non c'e' un bottone \"Installa da URL\" in Alt+O):\n")
  cecho("<white>lua installPackage(\"" .. url .. "\")\n")
  cecho("<grey>Oppure trascina il link .mpackage sul profilo Mudlet (4.11+).\n")
end

-- Self-update: funzioni su _G + tempTimer stringa, cosi' l'install sopravvive a
-- uninstallPackage (che rimuove alias/script del package prima di installPackage).
function _G.NebbieDashPostPackageInstall(pkg)
  pkg = pkg or "nebbie-complete-dashboard-package"
  tempTimer(0.6, function()
    NebbieDash = NebbieDash or {}
    NebbieDash._mainLoaded = false
    NebbieDash._lastBootTime = nil
    if type(NebbieDash.boot) == "function" then
      local bok, berr = pcall(NebbieDash.boot)
      if not bok then
        cecho("<red>[NebbieDash] boot dopo update fallito: " .. tostring(berr) .. "\n")
      end
    end
    local vRun = (NebbieDash and NebbieDash.version) or "?"
    local vPkg = ""
    if type(getPackageInfo) == "function" then
      vPkg = getPackageInfo(pkg, "version") or ""
    end
    if vPkg == "" then
      cecho("<red>Package non risulta installato.\n")
    else
      cecho("<green>[NebbieDash] Package Manager: <white>" .. vPkg ..
        "<green> — in esecuzione: <white>v" .. vRun .. "<green>.\n")
      if vPkg ~= vRun then
        cecho("<orange>Versioni diverse: riavvia Mudlet o digita <yellow>nfix<orange>.\n")
      end
    end
  end)
end

function NebbieDash.mpackageUrlForSha(sha)
  sha = tostring(sha or ""):match("^%s*([0-9a-fA-F]+)") or ""
  if #sha < 7 then return PKG_MPACKAGE_URL end
  -- jsDelivr accetta SHA corto o pieno; preferiamo i primi 7 (come git).
  local short = sha:sub(1, 7)
  return "https://cdn.jsdelivr.net/gh/" .. PKG_REPO .. "@" .. short .. "/" .. PKG_FILE
end

function NebbieDash.parseGithubCommitSha(body)
  if type(body) ~= "string" or body == "" then return nil end
  -- commits/main: {"sha":"abcdef..."}  (primo sha nel JSON)
  return body:match('"sha"%s*:%s*"([0-9a-fA-F]+)"')
end

function _G.NebbieDashOnPackageDownloadDone(_, saveTo)
  -- Fase 1: risoluzione tip di main via GitHub API.
  local resolve = _G.NebbieDashPendingRefResolve
  if resolve and resolve.saveTo and saveTo == resolve.saveTo then
    _G.NebbieDashPendingRefResolve = nil
    local body = ""
    local f = io.open(saveTo, "r")
    if f then
      body = f:read("*a") or ""
      f:close()
    end
    pcall(function() os.remove(saveTo) end)
    local sha = NebbieDash.parseGithubCommitSha(body)
    local pkg = resolve.pkg or "nebbie-complete-dashboard-package"
    local url
    if sha then
      url = NebbieDash.mpackageUrlForSha(sha)
      cecho("<grey>Tip main risolto: <white>" .. sha:sub(1, 7) ..
        "<grey> → scarico package pinnato (evita cache jsDelivr @main).\n")
      cecho("<grey>" .. url .. "\n")
    else
      url = PKG_MPACKAGE_URL
      cecho("<orange>[NebbieDash] SHA tip non letto dall'API; fallback su @main (puo' essere stale).\n")
      NebbieDash.echoManualInstallHint(url)
    end
    NebbieDash.runPackageUpdateInstall(url, pkg, resolve.hadInstalledVer)
    return
  end

  -- Fase 2: .mpackage scaricato → installPackage.
  local pending = _G.NebbieDashPendingPackageInstall
  if not pending or not pending.saveTo or saveTo ~= pending.saveTo then return end
  if pending.installStarted then return end
  pending.installStarted = true
  local pkg = pending.pkg or "nebbie-complete-dashboard-package"
  cecho("<grey>Installo il file scaricato...\n")
  if type(installPackage) ~= "function" then
    _G.NebbieDashPendingPackageInstall = nil
    return
  end
  local ok, err = pcall(installPackage, saveTo)
  _G.NebbieDashPendingPackageInstall = nil
  if not ok then
    cecho("<red>installPackage fallito: " .. tostring(err) .. "\n")
    return
  end
  _G.NebbieDashPostPackageInstall(pkg)
end

function _G.NebbieDashOnPackageDownloadError(_, msg, saveTo)
  local resolve = _G.NebbieDashPendingRefResolve
  if resolve and resolve.saveTo and saveTo == resolve.saveTo then
    _G.NebbieDashPendingRefResolve = nil
    cecho("<red>Risoluzione tip main fallita: " .. tostring(msg) .. "\n")
    cecho("<orange>Fallback su @main (puo' essere cache vecchia).\n")
    NebbieDash.echoManualInstallHint(PKG_MPACKAGE_URL)
    NebbieDash.runPackageUpdateInstall(PKG_MPACKAGE_URL, resolve.pkg, resolve.hadInstalledVer)
    return
  end
  local pending = _G.NebbieDashPendingPackageInstall
  if not pending or saveTo ~= pending.saveTo then return end
  local url = pending.url or PKG_MPACKAGE_URL
  _G.NebbieDashPendingPackageInstall = nil
  cecho("<red>Download .mpackage fallito: " .. tostring(msg) .. "\n")
  NebbieDash.echoManualInstallHint(url)
end

function NebbieDash.ensurePackageDownloadHandlers()
  if type(registerAnonymousEventHandler) ~= "function" then return end
  if _G._NebbieDashPkgDownloadHandlersInstalled then return end
  registerAnonymousEventHandler("sysDownloadDone", "_G.NebbieDashOnPackageDownloadDone")
  registerAnonymousEventHandler("sysDownloadError", "_G.NebbieDashOnPackageDownloadError")
  _G._NebbieDashPkgDownloadHandlersInstalled = true
end

function NebbieDash.cleanMpackageUrl(url)
  url = url or PKG_MPACKAGE_URL
  return (url:match("^([^%?]+)")) or url
end

function NebbieDash.isValidMpackageInstallUrl(url)
  -- Rifiuta query string: installPackage(URL?cb=) e' fragile; il cache-bust
  -- va solo su downloadFile (vedi NebbieDashRunPendingPackageInstall).
  if type(url) ~= "string" or url == "" then return false end
  if url:find("?", 1, true) then return false end
  local clean = NebbieDash.cleanMpackageUrl(url)
  return clean:match("%.mpackage%s*$") ~= nil
    and clean:match("^https://") ~= nil
end

function _G.NebbieDashRunPendingPackageInstall()
  local pending = _G.NebbieDashPendingPackageInstall
  if not pending or pending.started then return end
  pending.started = true
  local url = pending.url
  local pkg = pending.pkg or "nebbie-complete-dashboard-package"
  if not url or url == "" then
    _G.NebbieDashPendingPackageInstall = nil
    return
  end
  local cleanUrl = NebbieDash.cleanMpackageUrl(url)
  pending.url = cleanUrl

  if type(downloadFile) == "function" and type(installPackage) == "function" then
    NebbieDash.ensurePackageDownloadHandlers()
    local home = (type(getMudletHomeDir) == "function" and getMudletHomeDir()) or "."
    pending.saveTo = home .. "/nebbie-dash-update.mpackage"
    pending.installStarted = false
    pcall(function() os.remove(pending.saveTo) end)
    cecho("<grey>Scarico '" .. pkg .. "'...\n")
    -- Cache-bust query su URL gia' pinnato allo SHA (jsDelivr ignora spesso ?cb su @main).
    downloadFile(pending.saveTo, cleanUrl .. "?cb=" .. tostring(os.time()))
    return true
  end

  cecho("<grey>Scarico e installo '" .. pkg .. "' da GitHub...\n")
  if type(installPackage) ~= "function" then
    cecho("<red>installPackage non disponibile.\n")
    NebbieDash.echoManualInstallHint(cleanUrl)
    _G.NebbieDashPendingPackageInstall = nil
    return false
  end
  local ok, err = pcall(installPackage, cleanUrl)
  _G.NebbieDashPendingPackageInstall = nil
  if not ok then
    cecho("<red>installPackage fallito: " .. tostring(err) .. "\n")
    return false
  end
  _G.NebbieDashPostPackageInstall(pkg)
  return true
end

function _G.NebbieDashOnUninstallSchedulePackageInstall(_, packageName)
  if packageName and packageName ~= "nebbie-complete-dashboard-package" then return end
  local pending = _G.NebbieDashPendingPackageInstall
  if not pending or pending.started or pending.timerScheduled then return end
  pending.timerScheduled = true
  tempTimer(0.2, "_G.NebbieDashRunPendingPackageInstall()")
end

function NebbieDash.ensurePackageUpdateEventHandler()
  if type(registerAnonymousEventHandler) ~= "function" then return end
  if _G._NebbieDashPkgUpdateHandlerInstalled then return end
  registerAnonymousEventHandler("sysUninstallPackage", "_G.NebbieDashOnUninstallSchedulePackageInstall")
  _G._NebbieDashPkgUpdateHandlerInstalled = true
end

function NebbieDash.parsePkgVerFromCoreLua(text)
  if not text then return nil end
  return text:match('local%s+PKG_VER%s*=%s*"([^"]+)"')
end

function NebbieDash.fetchRemotePackageVersionSync()
  if type(getHttp) == "function" then
    local ok, body = pcall(getHttp, PKG_CORE_RAW_URL .. "?cb=" .. tostring(os.time()))
    if ok and type(body) == "string" then
      return NebbieDash.parsePkgVerFromCoreLua(body)
    end
  end
  return nil
end

function NebbieDash.runPackageUpdateInstall(installUrl, pkg, hadInstalledVer)
  pkg = pkg or NebbieDash.package or "nebbie-complete-dashboard-package"
  local cleanUrl = NebbieDash.cleanMpackageUrl(installUrl or PKG_MPACKAGE_URL)
  _G.NebbieDashPendingPackageInstall = {
    url = cleanUrl,
    pkg = pkg,
    started = false,
    timerScheduled = false,
  }
  NebbieDash.ensurePackageUpdateEventHandler()
  NebbieDash._mainLoaded = false
  NebbieDash._lastBootTime = nil

  if hadInstalledVer and type(uninstallPackage) == "function" then
    cecho("<grey>Disinstallo '" .. pkg .. "' (installazione tra un attimo)...\n")
    tempTimer(0.45, "_G.NebbieDashRunPendingPackageInstall()")
    _G.NebbieDashPendingPackageInstall.timerScheduled = true
    tempTimer(0.05, function()
      local uok, uerr = pcall(uninstallPackage, pkg)
      if not uok then
        cecho("<red>uninstallPackage fallito: " .. tostring(uerr) .. "\n")
        NebbieDash.echoManualInstallHint(cleanUrl)
        _G.NebbieDashPendingPackageInstall = nil
      end
    end)
    return true
  end

  cecho("<grey>Scarico e installo da GitHub...\n")
  tempTimer(0.05, "_G.NebbieDashRunPendingPackageInstall()")
  _G.NebbieDashPendingPackageInstall.timerScheduled = true
  return true
end

-- Prima risolve lo SHA tip di main (API GitHub), poi uninstall+download pinnato.
function NebbieDash.startPackageUpdateResolveTip(pkg, hadInstalledVer)
  pkg = pkg or NebbieDash.package or "nebbie-complete-dashboard-package"
  if type(downloadFile) ~= "function" then
    cecho("<orange>[NebbieDash] downloadFile assente — uso URL @main direttamente.\n")
    NebbieDash.runPackageUpdateInstall(PKG_MPACKAGE_URL, pkg, hadInstalledVer)
    return
  end
  NebbieDash.ensurePackageDownloadHandlers()
  local home = (type(getMudletHomeDir) == "function" and getMudletHomeDir()) or "."
  local saveTo = home .. "/nebbie-dash-main-tip.json"
  pcall(function() os.remove(saveTo) end)
  _G.NebbieDashPendingRefResolve = {
    saveTo = saveTo,
    pkg = pkg,
    hadInstalledVer = hadInstalledVer and true or false,
  }
  cecho("<grey>Risolvo tip di <white>main<grey> via GitHub API...\n")
  downloadFile(saveTo, PKG_GITHUB_TIP_URL .. "?cb=" .. tostring(os.time()))
end

function NebbieDash.cmdPackageUpdate(argStr)
  argStr = (argStr or ""):match("^%s*(.-)%s*$"):lower()
  local force = (argStr == "force" or argStr == "forza")
  local pkg = NebbieDash.package or "nebbie-complete-dashboard-package"
  local installedVer = ""
  if type(getPackageInfo) == "function" then
    installedVer = getPackageInfo(pkg, "version") or ""
  end
  local remoteVer = NebbieDash.fetchRemotePackageVersionSync()
  cecho("<yellow>[NebbieDash] Aggiornamento da " .. PKG_REPO .. " (main)...\n")
  cecho("<grey>Package Manager (installato): <white>" .. (installedVer ~= "" and installedVer or "—") ..
    "<grey> — in esecuzione ora: <white>" .. (NebbieDash.version or "?") .. "\n")
  if remoteVer then
    cecho("<grey>Ultima versione nota (getHttp): <white>" .. remoteVer .. "\n")
  else
    cecho("<grey>Versione remota: <white>risolvo tip main (SHA) poi scarico package pinnato\n")
  end
  if not force and remoteVer and installedVer ~= "" and remoteVer == installedVer and remoteVer == NebbieDash.version then
    cecho("<yellow>Sei gia' alla <white>" .. remoteVer ..
      "<yellow>. Reinstallo comunque (o usa <white>npackageupdate force<yellow>).\n")
  end
  if type(installPackage) ~= "function" then
    cecho("<red>installPackage non disponibile — scarica il .mpackage a mano da GitHub.\n")
    return
  end
  if installedVer ~= "" and type(uninstallPackage) ~= "function" then
    cecho("<orange>uninstallPackage non disponibile — disinstalla da Package Manager e reinstalla.\n")
    return
  end
  cecho("<green>Avvio aggiornamento — attendi risoluzione tip, poi Package Manager / v… pronto.\n")
  tempTimer(0.05, function()
    NebbieDash.startPackageUpdateResolveTip(pkg, installedVer ~= "")
  end)
end

function NebbieDash.parseVersionParts(ver)
  local parts = {}
  for n in (ver or ""):gmatch("%d+") do
    table.insert(parts, tonumber(n) or 0)
  end
  return parts
end

function NebbieDash.versionLessThan(a, b)
  local pa, pb = NebbieDash.parseVersionParts(a), NebbieDash.parseVersionParts(b)
  local n = math.max(#pa, #pb)
  for i = 1, n do
    local da, db = pa[i] or 0, pb[i] or 0
    if da < db then return true end
    if da > db then return false end
  end
  return false
end

-- Confronto versione Package Manager vs codice. Nota: la tab "Aggiornamenti"
-- di Alt+O elenca SOLO pacchetti del repository ufficiale mpkg.
function NebbieDash.printPackageVersionHint()
  if type(getPackageInfo) ~= "function" then return end
  local pkg = NebbieDash.package or "nebbie-complete-dashboard-package"
  local vPkg = getPackageInfo(pkg, "version") or ""
  local vRun = NebbieDash.version or "?"
  local web = getPackageInfo(pkg, "website") or ""
  if web == "" then
    cecho("<yellow>[NebbieDash] Package senza campo <white>website<yellow>. "
      .. "Aggiorna con <yellow>npackageupdate<yellow> oppure:\n")
    NebbieDash.echoManualInstallHint(NebbieDash.PACKAGE_UPDATE_URL)
  elseif vPkg ~= "" and vPkg ~= vRun then
    cecho("<orange>[NebbieDash] Package Manager: <white>v" .. vPkg ..
      "<orange> — in esecuzione: <white>v" .. vRun ..
      "<orange>. Usa <yellow>npackageupdate<orange> oppure:\n")
    NebbieDash.echoManualInstallHint(NebbieDash.PACKAGE_UPDATE_URL)
  end
end

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

-- Cartella dati condivisa: <mudlet>/profiles/ndashboard/ (Windows es.
-- C:/Users/.../.config/mudlet/profiles/ndashboard). Indice in
-- profiles/nebbie-dash-config-root.txt (percorso assoluto scritto al boot).
function NebbieDash.mudletProfileHome()
  return (type(getMudletHomeDir) == "function" and getMudletHomeDir()) or "."
end

function NebbieDash.normalizePathSlashes(path)
  return (path or ""):gsub("\\", "/")
end

function NebbieDash.mudletProfilesDir()
  local home = NebbieDash.normalizePathSlashes(NebbieDash.mudletProfileHome())
  if not home or home == "" or home == "." then return home end
  local profiles = home:match("^(.+/profiles)/[^/]+$")
  if profiles then return profiles end
  if home:match("/profiles$") then return home end
  return home
end

function NebbieDash.configRootPointerPath()
  return NebbieDash.mudletProfilesDir() .. "/nebbie-dash-config-root.txt"
end

function NebbieDash.configRoot()
  return NebbieDash.mudletProfilesDir() .. "/ndashboard"
end

function NebbieDash.ensureDirectory(path)
  path = NebbieDash.normalizePathSlashes(path)
  if type(io.exists) == "function" and io.exists(path) then return true end
  if type(lfs) == "table" and type(lfs.mkdir) == "function" then
    pcall(lfs.mkdir, path)
    if type(io.exists) == "function" and io.exists(path) then return true end
  end
  local win = package.config:sub(1, 1) == "\\"
  if win then
    os.execute('mkdir "' .. path:gsub("/", "\\") .. '" 2>nul')
  else
    os.execute('mkdir -p "' .. path .. '" 2>/dev/null')
  end
  return type(io.exists) == "function" and io.exists(path)
end

function NebbieDash.writeConfigRootPointer()
  local profiles = NebbieDash.mudletProfilesDir()
  local root = NebbieDash.configRoot()
  if not profiles or profiles == "" then return end
  NebbieDash.ensureDirectory(root)
  local pointer = NebbieDash.configRootPointerPath()
  local f = io.open(pointer, "w")
  if not f then return end
  f:write(
    "# Cartella dati NebbieDash (condivisa tra tutti i profili Mudlet)\n" ..
    "# Percorso assoluto — apri questa cartella in Explorer/Finder:\n" ..
    root .. "\n"
  )
  f:close()
end

function NebbieDash.ensureConfigDir()
  NebbieDash.ensureDirectory(NebbieDash.configRoot())
  NebbieDash.writeConfigRootPointer()
end

function NebbieDash.ensureDefaultConfigFiles()
  NebbieDash.ensureSpellShortcutsFile()
  NebbieDash.ensureCastSpellsFile()
  NebbieDash.ensureSpeedwalkFile()
  NebbieDash.ensureHungerMacrosFile()
  NebbieDash.ensureItemKeywordsFile()
  NebbieDash.ensureBatchCommandsFile()
  NebbieDash.ensureIdentBatchCommandsFile()
  NebbieDash.ensureBatchItemsFile()
  NebbieDash.ensurePreferencesFile()
  NebbieDash.ensureSoundsFile()
end

function NebbieDash.preferencesPath()
  return NebbieDash.configPath("nebbie-dash-preferences.txt")
end

function NebbieDash.ensurePreferencesFile()
  local path = NebbieDash.preferencesPath()
  if type(io.exists) == "function" and io.exists(path) then return end
  local f = io.open(path, "w")
  if not f then return end
  f:write(
    "# NebbieDash — preferenze globali (cartella profiles/ndashboard)\n" ..
    "# Dopo modifiche: npreferencesreload (o riavvio Mudlet)\n" ..
    "#\n" ..
    "# sidebar_mode = float    # float = pannello trascinabile (più spazio al testo centrale)\n" ..
    "# sidebar_mode = dock     # dock = bordo sinistro classico Mudlet\n" ..
    "# weapon_swap_delay = 0.5 # secondi tra i comandi di usa / cambio arma\n" ..
    "# sanity_neq_on_login = on  # se l'equip in cache è vuoto ma marcato sincronizzato, invia eq\n" ..
    "# text_highlights = on      # gemme/metalli + evidenziazioni aura/disarm/dig/sanc\n" ..
    "# chat_window = on          # finestra floating per say/gt/tell/whisper/ask/gossip/shout\n" ..
    "# auto_loot = on            # loot monete a fine combattimento (nautoloot)\n" ..
    "# auto_split = on           # split monete dopo loot riuscito (nautosplit)\n" ..
    "sidebar_mode = dock\n" ..
    "weapon_swap_delay = 0.5\n" ..
    "sanity_neq_on_login = on\n" ..
    "text_highlights = on\n" ..
    "chat_window = on\n" ..
    "auto_loot = on\n" ..
    "auto_split = on\n"
  )
  f:close()
end

function NebbieDash.parsePreferencesBool(v)
  v = (v or ""):lower():match("^%s*(.-)%s*$")
  return v == "on" or v == "yes" or v == "true" or v == "1"
end

function NebbieDash.loadPreferences()
  NebbieDash.migrateConfigFileIfNeeded("nebbie-dash-preferences.txt")
  NebbieDash.prefs = NebbieDash.prefs or {
    sidebar_mode = "dock",
    weapon_swap_delay = 0.5,
    sanity_neq_on_login = true,
    text_highlights = true,
    chat_window = true,
    auto_loot = true,
    auto_split = true,
  }
  local path = NebbieDash.preferencesPath()
  if type(io.exists) == "function" and io.exists(path) then
    local f = io.open(path, "r")
    if f then
      for line in f:lines() do
        local key, val = line:match("^%s*([%w_]+)%s*=%s*(.+)%s*$")
        if key and val and not key:match("^#") then
          val = val:gsub("%s*#.*$", ""):match("^%s*(.-)%s*$")
          if key == "sidebar_mode" and (val == "float" or val == "dock") then
            NebbieDash.prefs.sidebar_mode = val
          elseif key == "weapon_swap_delay" then
            local n = tonumber(val)
            if n and n >= 0.1 and n <= 3 then NebbieDash.prefs.weapon_swap_delay = n end
          elseif key == "sanity_neq_on_login" then
            NebbieDash.prefs.sanity_neq_on_login = NebbieDash.parsePreferencesBool(val)
          elseif key == "text_highlights" then
            NebbieDash.prefs.text_highlights = NebbieDash.parsePreferencesBool(val)
          elseif key == "chat_window" then
            NebbieDash.prefs.chat_window = NebbieDash.parsePreferencesBool(val)
          elseif key == "auto_loot" then
            NebbieDash.prefs.auto_loot = NebbieDash.parsePreferencesBool(val)
          elseif key == "auto_split" then
            NebbieDash.prefs.auto_split = NebbieDash.parsePreferencesBool(val)
          end
        end
      end
      f:close()
    end
  end
  NebbieDash.sidebarMode = NebbieDash.prefs.sidebar_mode
  NebbieDash.weaponSwapDelay = NebbieDash.prefs.weapon_swap_delay or NebbieDash.weaponSwapDelay
  NebbieDash.textHighlights = NebbieDash.prefs.text_highlights ~= false
  NebbieDash.chatEnabled = NebbieDash.prefs.chat_window ~= false
  NebbieDash.autoLoot = NebbieDash.prefs.auto_loot ~= false
  NebbieDash.autoSplit = NebbieDash.prefs.auto_split ~= false
end

function NebbieDash.savePreferencesFile()
  NebbieDash.ensureConfigDir()
  local path = NebbieDash.preferencesPath()
  local f = io.open(path, "w")
  if not f then return end
  f:write(
    "# NebbieDash — preferenze (npreferencesreload)\n" ..
    "sidebar_mode = " .. tostring(NebbieDash.sidebarMode or NebbieDash.prefs.sidebar_mode or "float") .. "\n" ..
    "weapon_swap_delay = " .. tostring(NebbieDash.weaponSwapDelay or 0.5) .. "\n" ..
    "sanity_neq_on_login = " .. ((NebbieDash.prefs and NebbieDash.prefs.sanity_neq_on_login) and "on" or "off") .. "\n" ..
    "text_highlights = " .. ((NebbieDash.prefs and NebbieDash.prefs.text_highlights ~= false) and "on" or "off") .. "\n" ..
    "chat_window = " .. ((NebbieDash.chatEnabled ~= false) and "on" or "off") .. "\n" ..
    "auto_loot = " .. ((NebbieDash.autoLoot ~= false) and "on" or "off") .. "\n" ..
    "auto_split = " .. ((NebbieDash.autoSplit ~= false) and "on" or "off") .. "\n"
  )
  f:close()
end

function NebbieDash.legacyNebbieDashHomePath(filename)
  local home = os.getenv("HOME") or os.getenv("USERPROFILE")
  if not home or home == "" then return nil end
  return NebbieDash.normalizePathSlashes(home) .. "/NebbieDash/" .. filename
end

function NebbieDash.configPath(filename)
  return NebbieDash.configRoot() .. "/" .. filename
end

function NebbieDash.legacyProfilePath(filename)
  return NebbieDash.mudletProfileHome() .. "/" .. filename
end

function NebbieDash.migrateConfigFileIfNeeded(filename)
  if type(io.exists) ~= "function" then return end
  NebbieDash.ensureConfigDir()
  local newPath = NebbieDash.configPath(filename)
  if io.exists(newPath) then return end
  local tryPaths = {
    NebbieDash.legacyProfilePath(filename),
    NebbieDash.legacyNebbieDashHomePath(filename),
  }
  for _, oldPath in ipairs(tryPaths) do
    if oldPath and io.exists(oldPath) then
      local rf = io.open(oldPath, "rb")
      if rf then
        local content = rf:read("*a")
        rf:close()
        local wf = io.open(newPath, "wb")
        if wf then
          wf:write(content or "")
          wf:close()
          cecho("<yellow>[NebbieDash] Copiato in ndashboard: <white>" .. newPath .. "\n")
        end
      end
      return
    end
  end
end

function NebbieDash.storePath()
  return NebbieDash.configPath("nebbie-complete-dashboard-package-chars.lua")
end

function NebbieDash.loadStore()
  NebbieDash.chars = NebbieDash.chars or {}
  NebbieDash.migrateConfigFileIfNeeded("nebbie-complete-dashboard-package-chars.lua")
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
  return NebbieDash.configPath("nebbie-dash-ui.lua")
end

function NebbieDash.loadUiStore()
  NebbieDash.migrateConfigFileIfNeeded("nebbie-dash-ui.lua")
  NebbieDash.uiState = NebbieDash.uiState or { speedwalkSectionCollapsed = {} }
  local path = NebbieDash.uiStorePath()
  if type(io.exists) == "function" and io.exists(path) then
    pcall(function() table.load(path, NebbieDash.uiState) end)
  end
  NebbieDash.uiState.speedwalkSectionCollapsed = NebbieDash.uiState.speedwalkSectionCollapsed or {}
  local gr = NebbieDash.uiState.guiRatios
  if type(gr) == "table" and type(gr.equip) == "number" then
    NebbieDash.guiRatios = NebbieDash.guiRatios or {}
    NebbieDash.guiRatios.equip = math.max(0.1, math.min(0.9, gr.equip))
    NebbieDash.guiRatios.manualEquip = gr.manualEquip == true
  end
  if NebbieDash.uiState.showClanSlot == true then
    NebbieDash.showClanSlot = true
  end
end

function NebbieDash.persistGuiRatios()
  NebbieDash.uiState = NebbieDash.uiState or {}
  NebbieDash.uiState.guiRatios = {
    equip = NebbieDash.guiRatios and NebbieDash.guiRatios.equip,
    manualEquip = NebbieDash.guiRatios and NebbieDash.guiRatios.manualEquip,
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
  if not manual then
    tempTimer(1.2, function()
      NebbieDash.maybeSanityResyncEq(name)
    end)
  end
  cecho("<cyan>[NebbieDash] Personaggio attivo: <yellow>" .. name .. "\n")
end

function NebbieDash.onInstallPackageEvent(event, packageName)
  if packageName and packageName ~= NebbieDash.package then return end
  NebbieDash._mainLoaded = false
  NebbieDash._lastBootTime = nil
  tempTimer(0, function()
    if type(NebbieDash.boot) == "function" then NebbieDash.boot() end
    tempTimer(0.2, function() NebbieDash.printPackageVersionHint() end)
  end)
end

function NebbieDash.onUninstallPackageEvent(event, packageName)
  if packageName and packageName ~= NebbieDash.package then return end
  NebbieDash._mainLoaded = false
  if type(NebbieDash.teardownTriggers) == "function" then NebbieDash.teardownTriggers() end
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
  NebbieDash._sanityNeqForChar = {}
  NebbieDash._groupKnown = nil
  NebbieDash._lootFlowActive = false
  NebbieDash._lootFlowStartedAt = nil
  NebbieDash._lastLootAmount = nil
  NebbieDash._lastLootAt = nil
  NebbieDash._lastSplitAmount = nil
  NebbieDash._lastSplitAt = nil
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
-- NOTA: tempRegexTrigger usa PCRE, NON pattern Lua (%s/%d).
function NebbieDash.parseImmortalPromptLine(text)
  if not text or text == "" then return nil end
  text = NebbieDash.stripColors(text):match("^%s*(.-)%s*$") or ""
  local name = text:match("^(%S+)%s+R%d+%s+%[[^%]]+%]%s*>>%s*$")
  if not name then return nil end
  -- Evita nomi contaminati da residui colore se strip fallisce in parte.
  if not name:match("^[%a][%w_%-]*$") then return nil end
  return { name = name, immortal = true }
end

function NebbieDash.isAnyPromptLine(text)
  return NebbieDash.parsePromptLine(text) or NebbieDash.parseImmortalPromptLine(text)
      or (text and NebbieDash.stripColors(text):match("^%s*>>%s*$")
        and { name = NebbieDash.currentChar or "?" })
end

function NebbieDash.onPromptLine()
  local text = line
  if (not text or text == "") and type(getCurrentLine) == "function" then
    text = getCurrentLine()
  end
  text = NebbieDash.stripColors(text or ""):match("^%s*(.-)%s*$") or ""
  local parsed = NebbieDash.parsePromptLine(text)
  if not parsed then
    parsed = NebbieDash.parseImmortalPromptLine(text)
  end
  if not parsed then return end
  NebbieDash.stats = parsed
  NebbieDash.setCurrentCharacter(parsed.name, false)
  NebbieDash._awaitingPromptAfterConnect = false
  NebbieDash.updateVitalsDisplay()
  NebbieDash.enforceTriggerHygiene()
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
  NebbieDash._eqCaptureStartedAt = os.time()
  if NebbieDash._eqLineTrig then
    pcall(enableTrigger, NebbieDash._eqLineTrig)
  end
  NebbieDash.armEqWatchdog(gen)
end

function NebbieDash.finishEqCapture()
  local cap = NebbieDash._eqCapture
  NebbieDash._eqCapture = nil
  NebbieDash._eqCaptureStartedAt = nil
  if NebbieDash._eqLineTrig then
    pcall(disableTrigger, NebbieDash._eqLineTrig)
  end
  if not cap then return end
  local slotCount = NebbieDash.countSlots(cap.slots)
  local name = NebbieDash.currentChar
  if not name then return end
  local data = NebbieDash.getCharData(name)
  if slotCount == 0 then
    cecho("<orange>[NebbieDash] Cattura eq incompleta (0 slot) — equip non modificato. Riprova <yellow>neq<orange>.\n")
    return
  end
  NebbieDash.syncClanSlotFromCapturedEq(cap.slots)
  data.eq = cap.slots
  data.eqUpdated = os.time()
  NebbieDash.refreshHungerBackKeywordFromEq(data, true)
  NebbieDash.saveStore()
  NebbieDash.refreshDashboard()
  cecho("<green>[NebbieDash] " .. NebbieDash.formatEquipCaptureSummary(data, slotCount) .. "\n")
end

function NebbieDash.countSlots(slots)
  local n = 0
  for _ in pairs(slots or {}) do n = n + 1 end
  return n
end

function NebbieDash.canonicalEquipPositionCount()
  local n = #NebbieDash.EQ_SLOT_ORDER
  if NebbieDash.showClanSlot then n = n + 1 end
  return n
end

function NebbieDash.countOccupiedEquipRows(data)
  local occupied, empty = 0, 0
  for _, row in ipairs(NebbieDash.buildEquipRows(data)) do
    if row.empty then empty = empty + 1 else occupied = occupied + 1 end
  end
  return occupied, empty
end

function NebbieDash.syncClanSlotFromCapturedEq(slots)
  for _, entry in pairs(slots or {}) do
    local loc = (entry and entry.location or ""):lower():match("^%s*(.-)%s*$")
    if loc == NebbieDash.EQ_SLOT_CLAN:lower() then
      if not NebbieDash.showClanSlot then
        NebbieDash.showClanSlot = true
        NebbieDash.uiState = NebbieDash.uiState or {}
        NebbieDash.uiState.showClanSlot = true
        NebbieDash.saveUiStore()
        cecho("<grey>[NebbieDash] Rilevato <white>simbolo del clan<grey> in eq — slot clan attivato (nclanslot off per nasconderlo).\n")
      end
      return
    end
  end
end

function NebbieDash.formatEquipCaptureSummary(data, linesFromGame)
  local occupied, empty = NebbieDash.countOccupiedEquipRows(data)
  local positions = NebbieDash.canonicalEquipPositionCount()
  local msg = string.format(
    "Equip aggiornato: %d occupati, %d vuoti su %d posizioni",
    occupied, empty, positions)
  if linesFromGame and linesFromGame ~= occupied then
    msg = msg .. string.format(" (%d righe numerate in eq)", linesFromGame)
  end
  if empty > 0 then
    local names = {}
    for _, row in ipairs(NebbieDash.buildEquipRows(data)) do
      if row.empty then table.insert(names, row.location) end
    end
    if #names <= 3 then
      msg = msg .. " — vuoto: " .. table.concat(names, ", ")
    end
  end
  return msg
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
    if NebbieDash.countSlots(cap.slots) > 0 then
      NebbieDash.finishEqCapture()
    end
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
    if NebbieDash.countSlots(cap.slots) > 0 then
      NebbieDash.finishEqCapture()
    end
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
  NebbieDash._attribCaptureStartedAt = os.time()
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
  NebbieDash._attribCaptureStartedAt = nil
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
NebbieDash._spellShortcutAliases = {}

-- Alias riservati (comandi Nebbie + prefissi c/r/m): non usabili come shortcut spell.
NebbieDash.SHORTCUT_RESERVED = {
  c = true, r = true, m = true,
  nhelp = true, nfix = true, ntriggers = true, neq = true, nattrib = true, nresync = true, ngui = true,
  nlayout = true, nchar = true, nclass = true, nfont = true, nwidth = true, nitemlen = true,
  nspellwarn = true, nspeedwalks = true, nspeeddelay = true, nheights = true, nleftheights = true,
  nclanslot = true, nloot = true, nautoloot = true, nautosplit = true, nsplit = true,
  nautostand = true, nautodisarm = true, nautofeed = true, nhungermacros = true, nitemkeywords = true,
  nforgetspell = true, nbatch = true, nbatchreload = true, nbatchverify = true,
  nidentbatch = true, nidentbatchreload = true, nspellaliases = true, nspellaliasesreload = true,
  nidentdb = true, nidentdbreload = true,
  nknowdb = true, nknowdbreload = true,
  npackageupdate = true,
  nchat = true,
  nidentui = true,
  usa = true,
  nconfigdir = true,
  nsidebar = true,
  npreferencesreload = true,
  nkeys = true,
}

function NebbieDash.spellShortcutsPath()
  return NebbieDash.configPath("nebbie-spell-shortcuts.txt")
end

function NebbieDash.castSpellsPath()
  return NebbieDash.configPath("nebbie-cast-spells.txt")
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

function NebbieDash.teardownSpellShortcutAliases()
  for _, id in ipairs(NebbieDash._spellShortcutAliases or {}) do
    if id then pcall(function() killAlias(id) end) end
  end
  NebbieDash._spellShortcutAliases = {}
end

function NebbieDash.installSpellShortcutAliases()
  NebbieDash.teardownSpellShortcutAliases()
  if type(tempAlias) ~= "function" then return end
  for lk, entry in pairs(NebbieDash.spellShortcuts or {}) do
    local esc = NebbieDash.regexEscapePattern(entry.key)
    local id1 = tempAlias("^" .. esc .. "$",
      string.format([[NebbieDash.cmdSpellShortcut(%q)]], lk))
    local id2 = tempAlias("^" .. esc .. "%s+(.+)$",
      string.format([[NebbieDash.cmdSpellShortcut(%q, matches[2])]], lk))
    table.insert(NebbieDash._spellShortcutAliases, id1)
    table.insert(NebbieDash._spellShortcutAliases, id2)
  end
end

function NebbieDash.teardownSpellShortcutTriggers()
  NebbieDash.teardownSpellShortcutAliases()
end

function NebbieDash.installSpellShortcutTriggers()
  NebbieDash.installSpellShortcutAliases()
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
  return NebbieDash.configPath("nebbie-speedwalks.txt")
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
  -- Righe (desc) dirs … o dirs (desc) hanno testo fuori da un'unica coppia di
  -- parentesi: non sono note standalone (es. hell … (w medusa…) finisce con )
  -- ma contiene ) desc) dirs (nota)).
  if NebbieDash.parseSpeedwalkLine(rawLine) then return nil end
  if not line2:match("^%([^)]*%)%s*$") then return nil end
  local note = line2:match("^%((.-)%)$")
  if not note then return nil end
  note = note:match("^%s*(.-)%s*$")
  if note == "" then return nil end
  return note
end

function NebbieDash.splitSpeedwalkTrailingNote(dirPart)
  dirPart = (dirPart or ""):match("^%s*(.-)%s*$")
  if dirPart == "" then return dirPart, nil end
  local body, note = dirPart:match("^(.-)%s+%((.-)%)$")
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
  if NebbieDash.parseSpeedwalkLine(rawLine) then return nil end
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
        local parenNote = NebbieDash.parseSpeedwalkParenNoteLine(rawLine)
        if parenNote then
          local last = NebbieDash.speedwalkItems[#NebbieDash.speedwalkItems]
          if last and last.kind == "walk" then
            last.note = last.note and (last.note .. "\n" .. parenNote) or parenNote
            local sw = NebbieDash.speedwalks[last.walkIndex]
            if sw then sw.note = last.note end
          end
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
    cecho("<grey>Modifica i file in <white>" .. NebbieDash.configRoot() .. "<grey> (cartella condivisa, vedi <yellow>nconfigdir<grey>).\n")
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
  cecho("<grey>Layout: altezza Equip/Speedwalk auto (testo) — <yellow>nheights 40<grey> / <yellow>nheights auto<grey>; larghezza <yellow>nwidth auto<grey> / <yellow>nlayout<grey>. Sezione: <yellow>(>> titolo)<grey>.\n")
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
-- Dashboard: un solo bordo sinistro — Equip sopra, Speedwalk sotto (niente pannello spell).
-- Larghezza e ripartizione verticale si adattano al testo visibile.
NebbieDash.guiWidthEquip = 260
NebbieDash.guiWidthRight = 0
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
NebbieDash.speedwalkPreviewMaxLen = 96
NebbieDash.speedwalkNoteMaxLen = 96
-- Limite caratteri per l'auto-larghezza colonna destra.
NebbieDash.autoWidthRightMaxChars = 58
NebbieDash.autoWidthSidebarMaxWindowPct = 0.38
NebbieDash.autoWidthEquip = true
NebbieDash.autoWidthRight = true
NebbieDash.autoWidthMin = 180

function NebbieDash.truncate(s, maxLen)
  if not s or #s <= maxLen then return s end
  return s:sub(1, math.max(1, maxLen - 1)) .. "…"
end

-- A capo morbido per miniconsole (Mudlet non fa wrap da solo: righe troppo
-- lunghe vengono tagliate/nascoste). Preferisce virgola o spazio prima del limite.
function NebbieDash.wrapPanelText(s, maxLen)
  maxLen = maxLen or 80
  if maxLen < 8 then maxLen = 8 end
  local lines = {}
  local rest = (s or ""):match("^%s*(.-)%s*$")
  while rest and #rest > maxLen do
    local cut = maxLen
    local searchFrom = math.min(#rest, maxLen)
    local searchTo = math.max(1, searchFrom - 48)
    for i = searchFrom, searchTo, -1 do
      local c = rest:sub(i, i)
      if c == "," or c == " " then
        cut = i
        break
      end
    end
    local piece = rest:sub(1, cut):match("^%s*(.-)%s*$")
    if piece == "" then
      piece = rest:sub(1, maxLen)
      cut = maxLen
    end
    table.insert(lines, piece)
    rest = rest:sub(cut + 1):match("^%s*(.-)%s*$")
  end
  if rest and rest ~= "" then table.insert(lines, rest) end
  return lines
end

-- Colonne utili per il wrap (larghezza bordo / font meno indentazione "  " / "    ").
function NebbieDash.panelWrapCols(_side, indentCols)
  indentCols = indentCols or 0
  local w = NebbieDash.guiWidthEquip or 260
  local charW = (type(calcFontSize) == "function" and calcFontSize(NebbieDash.fontSize)) or 8
  if type(charW) == "table" then charW = charW[1] or 8 end
  charW = charW or 8
  if charW <= 0 then charW = 8 end
  return math.max(16, math.floor(w / charW) - indentCols - 1)
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

-- Ripartizione verticale Equip / Speedwalk (bordo sinistro).
NebbieDash.guiRatios = { equip = 0.5, manualEquip = false }
NebbieDash.dividerPx = 4
NebbieDash.GUI_WINDOWS = { "NebbieDashEquip", "NebbieDashSpeedwalks" }
NebbieDash.ALL_GUI_ELEMENTS = {
  "NebbieDashEquip", "NebbieDashSpeedwalks",
  "NebbieDashDivider",
}

function NebbieDash.estimateEquipContentLines(data)
  local lines = 1
  if not data or not data.eqUpdated then
    return lines + 1
  end
  for _, row in ipairs(NebbieDash.buildEquipRows(data)) do
    if row.empty then
      lines = lines + 1
    else
      lines = lines + 2
    end
  end
  return lines
end

function NebbieDash.estimateSpeedwalkContentLines()
  local lines = 1
  if #(NebbieDash.speedwalkItems or {}) == 0 and #(NebbieDash.speedwalks or {}) == 0 then
    return lines + 1
  end
  local descCols = NebbieDash.panelWrapCols("left", 0)
  local lineCols = NebbieDash.panelWrapCols("left", 2)
  local noteCols = NebbieDash.panelWrapCols("left", 4)
  for _, item in ipairs(NebbieDash.speedwalkItems or {}) do
    if item.kind == "section" then
      lines = lines + 1
    elseif item.kind == "walk" then
      if item.sectionKey and NebbieDash.isSpeedwalkSectionCollapsed(item.sectionKey) then
        -- nascosto
      else
        lines = lines + #NebbieDash.wrapPanelText(item.desc or "", descCols)
        lines = lines + #NebbieDash.wrapPanelText(item.dirString or "", lineCols)
        if item.note and item.note ~= "" then
          lines = lines + #NebbieDash.wrapPanelText(item.note, noteCols)
        end
      end
    end
  end
  if lines <= 1 and #(NebbieDash.speedwalks or {}) > 0 then
    for _, entry in ipairs(NebbieDash.speedwalks) do
      lines = lines + 1 + (entry.dirString and 1 or 0)
    end
  end
  return math.max(lines, 2)
end

function NebbieDash.computeSidebarEquipRatio(data)
  if NebbieDash.guiRatios and NebbieDash.guiRatios.manualEquip and NebbieDash.guiRatios.equip then
    return math.max(0.1, math.min(0.9, NebbieDash.guiRatios.equip))
  end
  local eqLines = NebbieDash.estimateEquipContentLines(data)
  local swLines = NebbieDash.estimateSpeedwalkContentLines()
  local total = math.max(1, eqLines + swLines)
  return math.max(0.12, math.min(0.88, eqLines / total))
end

function NebbieDash.canUseFloatingSidebar()
  return type(Adjustable) == "table" and type(Adjustable.Container) == "table"
    and type(Geyser) == "table" and type(Geyser.MiniConsole) == "table"
end

function NebbieDash.effectiveSidebarMode()
  -- Dock (bordo sinistro Mudlet): unico layout supportato in produzione — il float
  -- Geyser non riceveva cecho() globale e lasciava pannelli neri vuoti.
  return "dock"
end

function NebbieDash.panelGeyser(win)
  if win == "NebbieDashEquip" then return NebbieDash._equipGeyser end
  if win == "NebbieDashSpeedwalks" then return NebbieDash._swGeyser end
  return nil
end

function NebbieDash.panelCecho(win, text)
  local g = NebbieDash.panelGeyser(win)
  if g and type(g.cecho) == "function" then
    g:cecho(text)
  else
    cecho(win, text)
  end
end

function NebbieDash.panelCechoLink(win, text, command, hint, paste)
  local g = NebbieDash.panelGeyser(win)
  if g and type(g.cechoLink) == "function" then
    g:cechoLink(text, command, hint, paste)
  else
    cechoLink(win, text, command, hint, paste)
  end
end

function NebbieDash.destroyFloatSidebarArtifacts()
  if NebbieDash._sidebarContainer then
    if type(NebbieDash._sidebarContainer.delete) == "function" then
      pcall(function() NebbieDash._sidebarContainer:delete() end)
    elseif type(NebbieDash._sidebarContainer.hide) == "function" then
      pcall(function() NebbieDash._sidebarContainer:hide() end)
    end
  end
  for _, name in ipairs({ "NebbieDashSidebarContainer", "NebbieDashEquip", "NebbieDashSpeedwalks" }) do
    if type(deleteWindow) == "function" then pcall(deleteWindow, name) end
  end
  NebbieDash._sidebarContainer = nil
  NebbieDash._equipGeyser = nil
  NebbieDash._swGeyser = nil
  NebbieDash._dividerLabel = nil
  NebbieDash._floatSidebarCreated = false
end

function NebbieDash.equipLocationCechoTag(location)
  local loc = (location or ""):lower():match("^%s*(.-)%s*$")
  if loc == "impugnato" or loc == "tenuto" then return "yellow" end
  if loc == "sulla schiena" then return "cyan" end
  if loc == "davanti agli occhi" then return "magenta" end
  return "green"
end

-- Miniconsole Mudlet/Geyser: solo tag cecho, non HTML (le <table> compaiono come testo grezzo).
function NebbieDash.renderEquipPanel(name, data)
  NebbieDash.panelCecho("NebbieDashEquip", "<cyan><b>Equip — " .. name .. "</b>\n")
  if not (data and data.eqUpdated) then
    NebbieDash.panelCecho("NebbieDashEquip",
      "<grey>(mai sincronizzato — esegui <yellow>neq<grey> o <yellow>nresync<grey>)\n")
    return
  end
  for idx, row in ipairs(NebbieDash.buildEquipRows(data)) do
    if row.empty then
      NebbieDash.panelCecho("NebbieDashEquip", string.format(
        "<grey>[%2d] <yellow>%s\n     <red><b>▢ VUOTO ▢</b>\n", idx, row.location))
    else
      local item = NebbieDash.truncate(row.item or "?", NebbieDash.itemMaxLen)
      local tag = NebbieDash.equipLocationCechoTag(row.location)
      NebbieDash.panelCecho("NebbieDashEquip", string.format(
        "<grey>[%2d] <%s>%s\n     <white>%s\n", idx, tag, row.location, item))
    end
  end
end

function NebbieDash.clearPanel(win)
  local g = NebbieDash.panelGeyser(win)
  if g and type(g.clear) == "function" then
    g:clear()
    return
  end
  if type(clearWindow) == "function" then
    pcall(clearWindow, win)
  end
end

function NebbieDash.applySidebarBorder()
  if not NebbieDash._guiCreated then return end
  if NebbieDash._guiHidden then
    setBorderLeft(0)
    return
  end
  setBorderLeft(NebbieDash.guiWidthEquip or 260)
end

function NebbieDash.maybeSanityResyncEq(charName)
  if not charName or charName == "" then return end
  if not (NebbieDash.prefs and NebbieDash.prefs.sanity_neq_on_login) then return end
  NebbieDash._sanityNeqForChar = NebbieDash._sanityNeqForChar or {}
  if NebbieDash._sanityNeqForChar[charName] then return end
  local data = NebbieDash.getCharData(charName)
  if not data.eqUpdated then return end
  if NebbieDash.countSlots(data.eq) > 0 then return end
  NebbieDash._sanityNeqForChar[charName] = true
  cecho("<yellow>[NebbieDash] Equip in cache vuoto per <white>" .. charName ..
    "<yellow> — invio automatico <white>eq<yellow> (sanity_neq_on_login).\n")
  send("eq")
  NebbieDash.startEqCapture()
end

function NebbieDash.teardownGui()
  for _, w in ipairs(NebbieDash.ALL_GUI_ELEMENTS or {}) do
    if type(deleteWindow) == "function" then pcall(deleteWindow, w) end
  end
  if NebbieDash._sidebarContainer then
    if type(NebbieDash._sidebarContainer.delete) == "function" then
      pcall(function() NebbieDash._sidebarContainer:delete() end)
    elseif type(NebbieDash._sidebarContainer.hide) == "function" then
      pcall(function() NebbieDash._sidebarContainer:hide() end)
    end
  end
  NebbieDash._sidebarContainer = nil
  NebbieDash._equipGeyser = nil
  NebbieDash._swGeyser = nil
  NebbieDash._dividerLabel = nil
  NebbieDash._guiCreated = false
  NebbieDash._floatSidebarCreated = false
  NebbieDash._equipRatioDragReady = false
  NebbieDash._equipRatioDrag = nil
  NebbieDash.destroyChatWindow()
  NebbieDash.destroyIdentUiWindow()
  pcall(setBorderLeft, 0)
  pcall(setBorderRight, 0)
end

-- ---------------------------------------------------------------------------
-- Finestra floating chat: raccoglie say / gtell / tell / whisper / ask /
-- gossip / shout (formati reali da act.comm.cpp). Indipendente dal sidebar.
-- ---------------------------------------------------------------------------
NebbieDash.chatEnabled = true
NebbieDash._chatTrigs = NebbieDash._chatTrigs or {}
NebbieDash.CHAT_CHANNEL_COLORS = {
  say = "white",
  gossip = "yellow",
  gtell = "cyan",
  tell = "magenta",
  whisper = "green",
  ask = "blue",
  shout = "red",
}

function NebbieDash.canUseChatWindow()
  return type(Adjustable) == "table" and type(Adjustable.Container) == "table"
    and type(Geyser) == "table" and type(Geyser.MiniConsole) == "table"
end

function NebbieDash.destroyChatWindow()
  if NebbieDash._chatContainer then
    if type(NebbieDash._chatContainer.hide) == "function" then
      pcall(function() NebbieDash._chatContainer:hide() end)
    end
    if type(NebbieDash._chatContainer.delete) == "function" then
      pcall(function() NebbieDash._chatContainer:delete() end)
    end
  end
  for _, name in ipairs({ "NebbieDashChatContainer", "NebbieDashChat" }) do
    if type(deleteWindow) == "function" then pcall(deleteWindow, name) end
  end
  NebbieDash._chatContainer = nil
  NebbieDash._chatGeyser = nil
  NebbieDash._chatCreated = false
  NebbieDash._chatHidden = false
end

function NebbieDash.chatConsoleCecho(text)
  local g = NebbieDash._chatGeyser
  if g and type(g.cecho) == "function" then
    g:cecho(text)
  elseif type(cecho) == "function" then
    cecho("NebbieDashChat", text)
  end
end

function NebbieDash.clearChatWindow()
  if NebbieDash._chatGeyser and type(NebbieDash._chatGeyser.clear) == "function" then
    pcall(function() NebbieDash._chatGeyser:clear() end)
  elseif type(clearWindow) == "function" then
    pcall(clearWindow, "NebbieDashChat")
  end
end

function NebbieDash.showChatWindow()
  if NebbieDash._chatContainer and type(NebbieDash._chatContainer.show) == "function" then
    pcall(function() NebbieDash._chatContainer:show() end)
  elseif type(showWindow) == "function" then
    pcall(showWindow, "NebbieDashChatContainer")
    pcall(showWindow, "NebbieDashChat")
  end
  NebbieDash._chatHidden = false
end

function NebbieDash.hideChatWindow()
  if NebbieDash._chatContainer and type(NebbieDash._chatContainer.hide) == "function" then
    pcall(function() NebbieDash._chatContainer:hide() end)
  elseif type(hideWindow) == "function" then
    pcall(hideWindow, "NebbieDashChatContainer")
    pcall(hideWindow, "NebbieDashChat")
  end
  NebbieDash._chatHidden = true
end

function NebbieDash.initChatWindow()
  if NebbieDash.chatEnabled == false then return end
  if not NebbieDash.canUseChatWindow() then
    cecho("<orange>[NebbieDash] Finestra chat non disponibile (serve Adjustable.Container / Geyser).\n")
    return
  end
  if NebbieDash._chatCreated and NebbieDash._chatContainer then
    NebbieDash.showChatWindow()
    return
  end
  NebbieDash.destroyChatWindow()
  local w, h = 440, 300
  NebbieDash._chatContainer = Adjustable.Container:new({
    name = "NebbieDashChatContainer",
    x = "-460",
    y = 40,
    width = w,
    height = h,
    titleText = "Nebbie — Chat",
    titleTxtColor = "white",
    adjLabelstyle = [[
      background-color: rgb(12, 12, 18);
      border: 2px solid rgb(70, 110, 70);
      border-radius: 6px;
    ]],
  })
  local pad = 4
  local titleH = 22
  NebbieDash._chatGeyser = Geyser.MiniConsole:new({
    name = "NebbieDashChat",
    x = pad,
    y = titleH,
    width = "100%-" .. tostring(pad * 2),
    height = "100%-" .. tostring(titleH + pad),
  }, NebbieDash._chatContainer)
  NebbieDash._chatGeyser:setColor(12, 12, 16, 255)
  if type(setMiniConsoleFontSize) == "function" then
    setMiniConsoleFontSize("NebbieDashChat", NebbieDash.fontSize or 10)
  end
  if type(enableScrollBar) == "function" then
    enableScrollBar("NebbieDashChat", true)
  end
  if type(setMaxLines) == "function" then
    setMaxLines("NebbieDashChat", 2000)
  end
  if type(NebbieDash._chatContainer.load) == "function" then
    pcall(function() NebbieDash._chatContainer:load() end)
  end
  NebbieDash._chatCreated = true
  NebbieDash._chatHidden = false
  NebbieDash.chatConsoleCecho(
    "<grey>Canali: say · gt · tell · whisper · ask · gossip · shout\n"
      .. "Comandi: <yellow>nchat<grey> (toggle) · <yellow>nchat clear<grey> · <yellow>nchat off\n")
end

-- Parser canali chat (testo già senza colori Mudlet). Ordine: casi più specifici prima.
function NebbieDash.parseChatLine(text)
  text = NebbieDash.stripColors(text or ""):match("^%s*(.-)%s*$") or ""
  if text == "" then return nil end

  local msg = text:match("^Tu dici al gruppo '(.+)'%s*$")
  if msg then
    return { channel = "gtell", speaker = "Tu", message = msg, self = true }
  end

  local target
  target, msg = text:match("^Tu dici a (.+) %(che e' AFK%) '(.+)'%s*$")
  if target and msg then
    return { channel = "tell", speaker = "Tu", target = target, message = msg, self = true, afk = true }
  end
  target, msg = text:match("^Tu dici a (.+) '(.+)'%s*$")
  if target and msg then
    return { channel = "tell", speaker = "Tu", target = target, message = msg, self = true }
  end

  target, msg = text:match("^Tu sussurri a (.+), '(.+)'%s*$")
  if target and msg then
    return { channel = "whisper", speaker = "Tu", target = target, message = msg, self = true }
  end

  target, msg = text:match("^Tu chiedi a (.+), '(.+)'%s*$")
  if target and msg then
    return { channel = "ask", speaker = "Tu", target = target, message = msg, self = true }
  end

  msg = text:match("^Tu gridi '(.+)'%s*$")
  if msg then
    return { channel = "shout", speaker = "Tu", message = msg, self = true }
  end

  -- Gossip e say: stesso echo parlante "Tu dici '…'" (gossip giallo in gioco).
  msg = text:match("^Tu dici '(.+)'%s*$")
  if msg then
    return { channel = "say", speaker = "Tu", message = msg, self = true, ambiguousGossip = true }
  end

  local who
  who, msg = text:match("^%[(.-)%] dice al gruppo '(.+)'%s*$")
  if who and msg then
    return { channel = "gtell", speaker = who, message = msg }
  end
  who, msg = text:match("^%[(.-)%] vi dice '(.+)'%s*$")
  if who and msg then
    return { channel = "gossip", speaker = who, message = msg }
  end
  who, msg = text:match("^%[(.-)%] ti dice '(.+)'%s*$")
  if who and msg then
    return { channel = "tell", speaker = who, message = msg }
  end
  who, msg = text:match("^%[(.-)%] ti sussurra '(.+)'%s*$")
  if who and msg then
    return { channel = "whisper", speaker = who, message = msg }
  end
  who, msg = text:match("^%[(.-)%] ti chiede '(.+)'%s*$")
  if who and msg then
    return { channel = "ask", speaker = who, message = msg }
  end
  who, msg = text:match("^%[(.-)%] grida '(.+)'%s*$")
  if who and msg then
    return { channel = "shout", speaker = who, message = msg }
  end
  who, msg = text:match("^%[(.-)%] dice '(.+)'%s*$")
  if who and msg then
    return { channel = "say", speaker = who, message = msg }
  end
  return nil
end

function NebbieDash.formatChatEcho(parsed)
  if not parsed then return nil end
  local color = NebbieDash.CHAT_CHANNEL_COLORS[parsed.channel] or "white"
  local who = parsed.speaker or "?"
  if parsed.self and parsed.target and parsed.target ~= "" then
    who = "Tu → " .. parsed.target
  end
  local chan = parsed.channel or "?"
  if parsed.ambiguousGossip then
    chan = "say"
  end
  return string.format("<%s>[%s]<white> %s: %s\n", color, chan, who, parsed.message or "")
end

function NebbieDash.appendChatParsed(parsed)
  if not parsed or NebbieDash.chatEnabled == false then return end
  if not NebbieDash._chatCreated then
    NebbieDash.initChatWindow()
  end
  if NebbieDash._chatHidden then return end
  local echo = NebbieDash.formatChatEcho(parsed)
  if echo then NebbieDash.chatConsoleCecho(echo) end
end

function NebbieDash.onChatCaptureLine()
  if NebbieDash.chatEnabled == false then return end
  local text = line or (type(getCurrentLine) == "function" and getCurrentLine()) or ""
  local parsed = NebbieDash.parseChatLine(text)
  if parsed then NebbieDash.appendChatParsed(parsed) end
end

function NebbieDash.teardownChatTriggers()
  for _, id in ipairs(NebbieDash._chatTrigs or {}) do
    if id then pcall(function() killTrigger(id) end) end
  end
  NebbieDash._chatTrigs = {}
end

function NebbieDash.installChatTriggers()
  NebbieDash.teardownChatTriggers()
  if NebbieDash.chatEnabled == false then return end
  if type(tempTrigger) ~= "function" then return end
  local patterns = {
    "Tu dici al gruppo '",
    "Tu dici a ",
    "Tu sussurri a ",
    "Tu chiedi a ",
    "Tu gridi '",
    "Tu dici '",
    "] dice al gruppo '",
    "] vi dice '",
    "] ti dice '",
    "] ti sussurra '",
    "] ti chiede '",
    "] grida '",
    "] dice '",
  }
  for _, pat in ipairs(patterns) do
    local id = tempTrigger(pat, [[NebbieDash.onChatCaptureLine()]])
    table.insert(NebbieDash._chatTrigs, id)
  end
end

function NebbieDash.cmdChat(argStr)
  argStr = (argStr or ""):match("^%s*(.-)%s*$") or ""
  local mode = argStr:lower()
  if mode == "" or mode == "toggle" then
    if not NebbieDash._chatCreated then
      NebbieDash.chatEnabled = true
      NebbieDash.prefs = NebbieDash.prefs or {}
      NebbieDash.prefs.chat_window = true
      NebbieDash.savePreferencesFile()
      NebbieDash.initChatWindow()
      NebbieDash.installChatTriggers()
      cecho("<green>[NebbieDash] Finestra chat aperta (<yellow>nchat clear<green> / <yellow>nchat off<green>).\n")
      return
    end
    if NebbieDash._chatHidden then
      NebbieDash.showChatWindow()
      cecho("<green>[NebbieDash] Finestra chat mostrata.\n")
    else
      NebbieDash.hideChatWindow()
      cecho("<grey>[NebbieDash] Finestra chat nascosta (<yellow>nchat<grey> per riaprire).\n")
    end
    return
  end
  if mode == "on" or mode == "show" then
    NebbieDash.chatEnabled = true
    NebbieDash.prefs = NebbieDash.prefs or {}
    NebbieDash.prefs.chat_window = true
    NebbieDash.savePreferencesFile()
    NebbieDash.initChatWindow()
    NebbieDash.installChatTriggers()
    NebbieDash.showChatWindow()
    cecho("<green>[NebbieDash] Chat window on.\n")
    return
  end
  if mode == "off" or mode == "hide" then
    NebbieDash.hideChatWindow()
    if mode == "off" then
      NebbieDash.chatEnabled = false
      NebbieDash.prefs = NebbieDash.prefs or {}
      NebbieDash.prefs.chat_window = false
      NebbieDash.savePreferencesFile()
      NebbieDash.teardownChatTriggers()
      cecho("<grey>[NebbieDash] Chat window off (preferenza salvata).\n")
    else
      cecho("<grey>[NebbieDash] Chat window nascosta.\n")
    end
    return
  end
  if mode == "clear" or mode == "cls" then
    NebbieDash.clearChatWindow()
    cecho("<green>[NebbieDash] Chat window svuotata.\n")
    return
  end
  cecho("<orange>[NebbieDash] Uso: <yellow>nchat<orange> | <yellow>nchat on|off|clear\n")
  cecho("<grey>Raccoglie: say, gt/gtell, tell, whisper, ask, gossip, shout.\n")
end

-- ---------------------------------------------------------------------------
-- Finestra floating gestione archivio identify (nidentui).
-- Lista filtrabile + dettaglio con azioni (elimina, cedibile, possesso, export).
-- ---------------------------------------------------------------------------
NebbieDash._identUiState = NebbieDash._identUiState or {
  filter = "",
  charFilter = "",
  onlyCedibile = false,
  sort = "name", -- name | recent | type
  page = 1,
  pageSize = 12,
  view = "list", -- list | detail
  selectedKey = nil,
  pendingDeleteKey = nil,
}

function NebbieDash.canUseIdentUiWindow()
  return NebbieDash.canUseChatWindow()
end

function NebbieDash.destroyIdentUiWindow()
  if NebbieDash._identUiContainer then
    if type(NebbieDash._identUiContainer.hide) == "function" then
      pcall(function() NebbieDash._identUiContainer:hide() end)
    end
    if type(NebbieDash._identUiContainer.delete) == "function" then
      pcall(function() NebbieDash._identUiContainer:delete() end)
    end
  end
  for _, name in ipairs({ "NebbieDashIdentUiContainer", "NebbieDashIdentUi" }) do
    if type(deleteWindow) == "function" then pcall(deleteWindow, name) end
  end
  NebbieDash._identUiContainer = nil
  NebbieDash._identUiGeyser = nil
  NebbieDash._identUiCreated = false
  NebbieDash._identUiHidden = false
  NebbieDash._identUiRows = nil
end

function NebbieDash.identUiCecho(text)
  local g = NebbieDash._identUiGeyser
  if g and type(g.cecho) == "function" then
    g:cecho(text)
  elseif type(cecho) == "function" then
    cecho("NebbieDashIdentUi", text)
  end
end

function NebbieDash.identUiCechoLink(text, command, hint)
  local g = NebbieDash._identUiGeyser
  if g and type(g.cechoLink) == "function" then
    g:cechoLink(text, command, hint or "", true)
  elseif type(cechoLink) == "function" then
    cechoLink("NebbieDashIdentUi", text, command, hint or "", true)
  else
    NebbieDash.identUiCecho(text)
  end
end

function NebbieDash.clearIdentUiWindow()
  if NebbieDash._identUiGeyser and type(NebbieDash._identUiGeyser.clear) == "function" then
    pcall(function() NebbieDash._identUiGeyser:clear() end)
  elseif type(clearWindow) == "function" then
    pcall(clearWindow, "NebbieDashIdentUi")
  end
end

function NebbieDash.showIdentUiWindow()
  if NebbieDash._identUiContainer and type(NebbieDash._identUiContainer.show) == "function" then
    pcall(function() NebbieDash._identUiContainer:show() end)
  elseif type(showWindow) == "function" then
    pcall(showWindow, "NebbieDashIdentUiContainer")
    pcall(showWindow, "NebbieDashIdentUi")
  end
  NebbieDash._identUiHidden = false
end

function NebbieDash.hideIdentUiWindow()
  if NebbieDash._identUiContainer and type(NebbieDash._identUiContainer.hide) == "function" then
    pcall(function() NebbieDash._identUiContainer:hide() end)
  elseif type(hideWindow) == "function" then
    pcall(hideWindow, "NebbieDashIdentUiContainer")
    pcall(hideWindow, "NebbieDashIdentUi")
  end
  NebbieDash._identUiHidden = true
end

function NebbieDash.initIdentUiWindow()
  if not NebbieDash.canUseIdentUiWindow() then
    cecho("<orange>[NebbieDash] Finestra ident non disponibile (serve Adjustable.Container / Geyser).\n")
    return false
  end
  if NebbieDash._identUiCreated and NebbieDash._identUiContainer then
    NebbieDash.showIdentUiWindow()
    NebbieDash.refreshIdentUi()
    return true
  end
  NebbieDash.destroyIdentUiWindow()
  local w, h = 560, 420
  NebbieDash._identUiContainer = Adjustable.Container:new({
    name = "NebbieDashIdentUiContainer",
    x = "-580",
    y = 80,
    width = w,
    height = h,
    titleText = "Nebbie — Ident DB",
    titleTxtColor = "white",
    adjLabelstyle = [[
      background-color: rgb(14, 14, 20);
      border: 2px solid rgb(120, 90, 50);
      border-radius: 6px;
    ]],
  })
  local pad = 4
  local titleH = 22
  NebbieDash._identUiGeyser = Geyser.MiniConsole:new({
    name = "NebbieDashIdentUi",
    x = pad,
    y = titleH,
    width = "100%-" .. tostring(pad * 2),
    height = "100%-" .. tostring(titleH + pad),
  }, NebbieDash._identUiContainer)
  NebbieDash._identUiGeyser:setColor(14, 14, 18, 255)
  if type(setMiniConsoleFontSize) == "function" then
    setMiniConsoleFontSize("NebbieDashIdentUi", NebbieDash.fontSize or 10)
  end
  if type(enableScrollBar) == "function" then
    enableScrollBar("NebbieDashIdentUi", true)
  end
  if type(setMaxLines) == "function" then
    setMaxLines("NebbieDashIdentUi", 4000)
  end
  if type(NebbieDash._identUiContainer.load) == "function" then
    pcall(function() NebbieDash._identUiContainer:load() end)
  end
  NebbieDash._identUiCreated = true
  NebbieDash._identUiHidden = false
  NebbieDash.refreshIdentUi()
  return true
end

function NebbieDash.deleteIdentEntry(key)
  key = key or ""
  if key == "" then return false, "chiave vuota" end
  NebbieDash.identDb = NebbieDash.identDb or { entries = {} }
  NebbieDash.identDb.entries = NebbieDash.identDb.entries or {}
  if not NebbieDash.identDb.entries[key] then return false, "non trovato" end
  NebbieDash.identDb.entries[key] = nil
  if NebbieDash._identDropPending and NebbieDash._identDropPending.key == key then
    NebbieDash._identDropPending = nil
  end
  local st = NebbieDash._identUiState
  if st and st.selectedKey == key then
    st.selectedKey = nil
    st.view = "list"
  end
  if st and st.pendingDeleteKey == key then
    st.pendingDeleteKey = nil
  end
  NebbieDash.scheduleIdentDbSave()
  return true
end

function NebbieDash.getIdentEntryByKey(key)
  return NebbieDash.identDb and NebbieDash.identDb.entries and NebbieDash.identDb.entries[key]
end

function NebbieDash.collectIdentUiEntries()
  local st = NebbieDash._identUiState or {}
  local results
  if st.charFilter and st.charFilter ~= "" then
    results = NebbieDash.listIdentDbByCharacter(st.charFilter)
  else
    results = NebbieDash.searchIdentDb(st.filter or "")
  end
  if st.charFilter and st.charFilter ~= "" and st.filter and st.filter ~= "" then
    local q = st.filter:lower()
    local filtered = {}
    for _, e in ipairs(results) do
      local hay = table.concat({
        e.objectName or "", e.objectType or "", e.flags or "",
        table.concat(e.affects or {}, " "),
      }, " "):lower()
      if hay:find(q, 1, true) then table.insert(filtered, e) end
    end
    results = filtered
  end
  if st.onlyCedibile then
    local filtered = {}
    for _, e in ipairs(results) do
      if e.cedibile then table.insert(filtered, e) end
    end
    results = filtered
  end
  local sort = st.sort or "name"
  table.sort(results, function(a, b)
    if sort == "recent" then
      return (a.lastAt or 0) > (b.lastAt or 0)
    end
    if sort == "type" then
      local ta, tb = a.objectType or "", b.objectType or ""
      if ta ~= tb then return ta < tb end
    end
    return (a.objectName or "") < (b.objectName or "")
  end)
  return results
end

function NebbieDash.identUiToolbar()
  local st = NebbieDash._identUiState
  NebbieDash.identUiCecho("<grey>Totale DB: <white>" .. tostring(NebbieDash.identDbEntryCount())
    .. "  <grey>| filtro: <yellow>" .. ((st.filter ~= "" and st.filter) or "(nessuno)")
    .. "  <grey>| PG: <yellow>" .. ((st.charFilter ~= "" and st.charFilter) or "tutti")
    .. "  <grey>| sort: <yellow>" .. tostring(st.sort)
    .. (st.onlyCedibile and "  <green>[solo cedibili]" or "")
    .. "\n")
  NebbieDash.identUiCechoLink("<cyan>[lista]", "NebbieDash.identUiShowList()", "Torna alla lista")
  NebbieDash.identUiCecho(" ")
  NebbieDash.identUiCechoLink("<cyan>[refresh]", "NebbieDash.refreshIdentUi()", "Ricarica vista")
  NebbieDash.identUiCecho(" ")
  NebbieDash.identUiCechoLink("<yellow>[sort nome]", "NebbieDash.identUiSetSort(\"name\")", "Ordina per nome")
  NebbieDash.identUiCecho(" ")
  NebbieDash.identUiCechoLink("<yellow>[sort data]", "NebbieDash.identUiSetSort(\"recent\")", "Ordina per ultimo ident")
  NebbieDash.identUiCecho(" ")
  NebbieDash.identUiCechoLink("<yellow>[sort tipo]", "NebbieDash.identUiSetSort(\"type\")", "Ordina per tipo")
  NebbieDash.identUiCecho("\n")
  NebbieDash.identUiCechoLink(
    st.onlyCedibile and "<green>[cedibili: ON]" or "<grey>[cedibili: off]",
    "NebbieDash.identUiToggleCedibileFilter()",
    "Mostra solo oggetti cedibili")
  NebbieDash.identUiCecho(" ")
  if NebbieDash.currentChar and NebbieDash.currentChar ~= "" then
    NebbieDash.identUiCechoLink(
      "<magenta>[PG: " .. NebbieDash.currentChar .. "]",
      string.format("NebbieDash.identUiSetCharFilter(%q)", NebbieDash.currentChar),
      "Filtra possesso/ident del PG attivo")
    NebbieDash.identUiCecho(" ")
  end
  NebbieDash.identUiCechoLink("<grey>[reset filtri]", "NebbieDash.identUiResetFilters()", "Azzera filtri")
  NebbieDash.identUiCecho("\n")
  -- Niente <...> letterali in cecho (sono tag colore); usiamo [arg].
  NebbieDash.identUiCecho(
    "<grey>Comandi: <yellow>nidentui filter [testo]<grey> · <yellow>nidentui char [Pg]<grey> · "
      .. "<yellow>nidentui del [ogg]\n")
  NebbieDash.identUiCecho("<grey>─────────────────────────────────────\n")
end

function NebbieDash.refreshIdentUi()
  if not NebbieDash._identUiCreated or NebbieDash._identUiHidden then return end
  NebbieDash.clearIdentUiWindow()
  NebbieDash.identUiToolbar()
  local st = NebbieDash._identUiState
  if st.view == "detail" and st.selectedKey then
    NebbieDash.renderIdentUiDetail(st.selectedKey)
  else
    NebbieDash.renderIdentUiList()
  end
end

function NebbieDash.renderIdentUiList()
  local st = NebbieDash._identUiState
  local all = NebbieDash.collectIdentUiEntries()
  local pageSize = st.pageSize or 12
  local pages = math.max(1, math.ceil(#all / pageSize))
  if st.page > pages then st.page = pages end
  if st.page < 1 then st.page = 1 end
  local from = (st.page - 1) * pageSize + 1
  local to = math.min(#all, st.page * pageSize)
  NebbieDash.identUiCecho(string.format(
    "<green>%d risultati<grey> — pagina <white>%d/%d\n", #all, st.page, pages))
  if #all == 0 then
    NebbieDash.identUiCecho("<orange>(nessuna entry — prova nidentui reset oppure identify in gioco)\n")
    return
  end
  if st.page > 1 then
    NebbieDash.identUiCechoLink("<cyan>[« prec]", "NebbieDash.identUiPage(-1)", "Pagina precedente")
    NebbieDash.identUiCecho("  ")
  end
  if st.page < pages then
    NebbieDash.identUiCechoLink("<cyan>[succ »]", "NebbieDash.identUiPage(1)", "Pagina successiva")
  end
  if st.page > 1 or st.page < pages then
    NebbieDash.identUiCecho("\n")
  end

  NebbieDash._identUiRows = {}
  local rowIdx = 0
  for i = from, to do
    local entry = all[i]
    rowIdx = rowIdx + 1
    NebbieDash._identUiRows[rowIdx] = entry
    local poss = entry.possession
    local possTxt = ""
    if poss and poss.status == "held" and poss.character then
      possTxt = " <grey>@" .. poss.character
    elseif poss and poss.status == "ground" then
      possTxt = " <orange>@terra"
    end
    local ced = entry.cedibile and " <green>●" or " <grey>○"
    local rare = entry.rare and " <orange>R" or ""
    NebbieDash.identUiCecho(string.format("<grey>%2d. ", rowIdx))
    NebbieDash.identUiCechoLink(
      "<yellow>" .. (entry.objectName or "?"),
      string.format("NebbieDash.identUiOpenRow(%d)", rowIdx),
      "Apri dettaglio")
    NebbieDash.identUiCecho(string.format(
      " <white>(%s)%s%s%s\n",
      entry.objectType or "?", ced, rare, possTxt))
    NebbieDash.identUiCecho("    ")
    NebbieDash.identUiCechoLink(
      "<red>[x]",
      string.format("NebbieDash.identUiAskDelete(%d)", rowIdx),
      "Elimina entry")
    NebbieDash.identUiCecho(" ")
    NebbieDash.identUiCechoLink(
      entry.cedibile and "<green>[ced]" or "<grey>[ced]",
      string.format("NebbieDash.identUiToggleCedibileRow(%d)", rowIdx),
      "Toggle cedibile")
    if entry.affects and #entry.affects > 0 then
      local short = table.concat(entry.affects, " | ")
      if #short > 70 then short = short:sub(1, 67) .. "…" end
      NebbieDash.identUiCecho(" <grey>" .. short)
    end
    NebbieDash.identUiCecho("\n")
  end
end

function NebbieDash.renderIdentUiDetail(key)
  local entry = NebbieDash.getIdentEntryByKey(key)
  if not entry then
    NebbieDash.identUiCecho("<orange>Entry non trovata.\n")
    NebbieDash._identUiState.view = "list"
    NebbieDash._identUiState.selectedKey = nil
    return
  end
  NebbieDash._identUiRows = { entry }
  for _, lineTxt in ipairs(NebbieDash.formatIdentDbEntry(entry, true)) do
    NebbieDash.identUiCecho(lineTxt .. "\n")
  end
  NebbieDash.identUiCecho("<grey>─────────────────────────────────────\n")
  NebbieDash.identUiCecho("<white>Azioni: ")
  local pending = NebbieDash._identUiState.pendingDeleteKey == key
  if pending then
    NebbieDash.identUiCechoLink(
      "<red><b>[CONFERMA ELIMINA]</b>",
      "NebbieDash.identUiConfirmDelete()",
      "Conferma eliminazione definitiva")
    NebbieDash.identUiCecho(" ")
    NebbieDash.identUiCechoLink(
      "<grey>[annulla]",
      "NebbieDash.identUiCancelDelete()",
      "Annulla eliminazione")
  else
    NebbieDash.identUiCechoLink(
      "<red>[elimina]",
      "NebbieDash.identUiAskDelete(1)",
      "Chiedi conferma eliminazione")
  end
  NebbieDash.identUiCecho(" ")
  NebbieDash.identUiCechoLink(
    entry.cedibile and "<green>[togli cedibile]" or "<yellow>[rendi cedibile]",
    "NebbieDash.identUiToggleCedibileRow(1)",
    "Toggle flag cedibile")
  NebbieDash.identUiCecho("\n")
  if NebbieDash.currentChar and NebbieDash.currentChar ~= "" then
    NebbieDash.identUiCechoLink(
      "<magenta>[possesso → " .. NebbieDash.currentChar .. "]",
      string.format("NebbieDash.identUiAssignHold(%q)", NebbieDash.currentChar),
      "Assegna possesso al PG attivo")
    NebbieDash.identUiCecho(" ")
  end
  local who = (entry.possession and entry.possession.character)
    or entry.lastCharacter
  if who and who ~= "" then
    NebbieDash.identUiCechoLink(
      "<cyan>[export CSV " .. who .. "]",
      string.format("NebbieDash.identUiExportChar(%q)", who),
      "Esporta CSV identify di questo PG")
  end
  NebbieDash.identUiCecho("\n")
end

function NebbieDash.identUiShowList()
  local st = NebbieDash._identUiState
  st.view = "list"
  st.selectedKey = nil
  st.pendingDeleteKey = nil
  NebbieDash.refreshIdentUi()
end

function NebbieDash.identUiOpenRow(idx)
  local entry = NebbieDash._identUiRows and NebbieDash._identUiRows[idx]
  if not entry then return end
  local st = NebbieDash._identUiState
  st.view = "detail"
  st.selectedKey = entry.key
  st.pendingDeleteKey = nil
  NebbieDash.refreshIdentUi()
end

function NebbieDash.identUiAskDelete(idx)
  local entry = NebbieDash._identUiRows and NebbieDash._identUiRows[idx]
  if not entry or not entry.key then return end
  NebbieDash._identUiState.pendingDeleteKey = entry.key
  if NebbieDash._identUiState.view ~= "detail" then
    NebbieDash._identUiState.view = "detail"
    NebbieDash._identUiState.selectedKey = entry.key
  end
  NebbieDash.refreshIdentUi()
  cecho("<orange>[NebbieDash] Conferma eliminazione di <white>"
    .. (entry.objectName or entry.key) .. "<orange> nella finestra Ident.\n")
end

function NebbieDash.identUiCancelDelete()
  NebbieDash._identUiState.pendingDeleteKey = nil
  NebbieDash.refreshIdentUi()
end

function NebbieDash.identUiConfirmDelete()
  local key = NebbieDash._identUiState.pendingDeleteKey
  if not key then return end
  local entry = NebbieDash.getIdentEntryByKey(key)
  local name = entry and entry.objectName or key
  local ok = NebbieDash.deleteIdentEntry(key)
  if ok then
    cecho("<green>[NebbieDash] Ident eliminato: <white>" .. tostring(name) .. "\n")
  else
    cecho("<orange>[NebbieDash] Eliminazione fallita per <white>" .. tostring(key) .. "\n")
  end
  NebbieDash._identUiState.pendingDeleteKey = nil
  NebbieDash._identUiState.view = "list"
  NebbieDash._identUiState.selectedKey = nil
  NebbieDash.refreshIdentUi()
end

function NebbieDash.identUiToggleCedibileRow(idx)
  local entry = NebbieDash._identUiRows and NebbieDash._identUiRows[idx]
  if not entry then return end
  NebbieDash.setIdentCedibile(entry, not entry.cedibile, true)
  cecho(string.format(
    "<green>[NebbieDash] <white>%s<green> → %s\n",
    entry.objectName or "?",
    entry.cedibile and "cedibile" or "non cedibile"))
  NebbieDash.refreshIdentUi()
end

function NebbieDash.identUiAssignHold(charName)
  local key = NebbieDash._identUiState.selectedKey
  local entry = NebbieDash.getIdentEntryByKey(key)
  if not entry then return end
  NebbieDash.setIdentPossession(entry, "held", charName, "hold", nil,
    entry.possession and entry.possession.character)
  cecho(string.format(
    "<green>[NebbieDash] Possesso <white>%s<green> → <yellow>%s\n",
    entry.objectName or "?", charName))
  NebbieDash.refreshIdentUi()
end

function NebbieDash.identUiExportChar(charName)
  NebbieDash.exportIdentDbCsvForCharacter(charName)
end

function NebbieDash.identUiSetSort(sort)
  NebbieDash._identUiState.sort = sort or "name"
  NebbieDash._identUiState.page = 1
  NebbieDash._identUiState.view = "list"
  NebbieDash.refreshIdentUi()
end

function NebbieDash.identUiToggleCedibileFilter()
  local st = NebbieDash._identUiState
  st.onlyCedibile = not st.onlyCedibile
  st.page = 1
  st.view = "list"
  NebbieDash.refreshIdentUi()
end

function NebbieDash.identUiSetCharFilter(charName)
  local st = NebbieDash._identUiState
  if st.charFilter == charName then
    st.charFilter = ""
  else
    st.charFilter = charName or ""
  end
  st.page = 1
  st.view = "list"
  NebbieDash.refreshIdentUi()
end

function NebbieDash.identUiResetFilters()
  local st = NebbieDash._identUiState
  st.filter = ""
  st.charFilter = ""
  st.onlyCedibile = false
  st.sort = "name"
  st.page = 1
  st.view = "list"
  st.pendingDeleteKey = nil
  NebbieDash.refreshIdentUi()
end

function NebbieDash.identUiPage(delta)
  local st = NebbieDash._identUiState
  st.page = (st.page or 1) + (delta or 0)
  st.view = "list"
  NebbieDash.refreshIdentUi()
end

function NebbieDash.cmdIdentUi(argStr)
  argStr = (argStr or ""):match("^%s*(.-)%s*$") or ""
  local mode, rest = argStr:match("^(%S+)%s+(.-)%s*$")
  if not mode then mode, rest = argStr, "" end
  mode = (mode or ""):lower()

  if mode == "off" or mode == "hide" or mode == "close" then
    NebbieDash.hideIdentUiWindow()
    cecho("<grey>[NebbieDash] Finestra Ident nascosta (<yellow>nidentui<grey> per riaprire).\n")
    return
  end

  if mode == "filter" or mode == "cerca" or mode == "q" then
    NebbieDash._identUiState.filter = rest or ""
    NebbieDash._identUiState.page = 1
    NebbieDash._identUiState.view = "list"
    if not NebbieDash.initIdentUiWindow() then return end
    NebbieDash.refreshIdentUi()
    return
  end

  if mode == "char" or mode == "pg" then
    NebbieDash._identUiState.charFilter = rest or ""
    NebbieDash._identUiState.page = 1
    NebbieDash._identUiState.view = "list"
    if not NebbieDash.initIdentUiWindow() then return end
    NebbieDash.refreshIdentUi()
    return
  end

  if mode == "reset" then
    NebbieDash.identUiResetFilters()
    if not NebbieDash.initIdentUiWindow() then return end
    return
  end

  if mode == "del" or mode == "delete" or mode == "rm" then
    local results = NebbieDash.searchIdentDb(rest)
    if not results or #results == 0 then
      cecho("<orange>[NebbieDash] Nessun identify per <white>" .. tostring(rest) .. "\n")
      return
    end
    if #results > 1 then
      cecho("<orange>[NebbieDash] Query ambigua (" .. tostring(#results)
        .. "). Apri <yellow>nidentui<orange> e elimina dalla lista, oppure specifica meglio.\n")
      for i, e in ipairs(results) do
        if i > 8 then break end
        cecho(string.format("  <grey>%s<white> %s\n", e.key or "?", e.objectName or "?"))
      end
      return
    end
    local entry = results[1]
    local ok = NebbieDash.deleteIdentEntry(entry.key)
    if ok then
      cecho("<green>[NebbieDash] Ident eliminato: <white>" .. tostring(entry.objectName) .. "\n")
      NebbieDash.refreshIdentUi()
    end
    return
  end

  if mode == "help" or mode == "?" then
    cecho("<green>[NebbieDash] nidentui — gestore floating archivio identify\n")
    cecho("<grey>  <yellow>nidentui<grey>              apri / mostra finestra\n")
    cecho("<grey>  <yellow>nidentui filter [testo]<grey>  filtra nome/flags/affects\n")
    cecho("<grey>  <yellow>nidentui char [Pg]<grey>     filtra per personaggio\n")
    cecho("<grey>  <yellow>nidentui del [oggetto]<grey>  elimina (se univoco)\n")
    cecho("<grey>  <yellow>nidentui reset<grey>         azzera filtri\n")
    cecho("<grey>  <yellow>nidentui off<grey>            nascondi finestra\n")
    cecho("<grey>In finestra: click nome=dettaglio, [x]=elimina, [ced]=cedibile, sort/pagine.\n")
    return
  end

  if not NebbieDash.initIdentUiWindow() then return end
  if mode == "" or mode == "on" or mode == "show" or mode == "open" or mode == "toggle" then
    if NebbieDash._identUiHidden then
      NebbieDash.showIdentUiWindow()
      NebbieDash.refreshIdentUi()
    end
    cecho("<green>[NebbieDash] Finestra Ident aperta (<yellow>nidentui help<green> per comandi).\n")
    return
  end
  -- testo libero = filtro
  NebbieDash._identUiState.filter = argStr
  NebbieDash._identUiState.page = 1
  NebbieDash._identUiState.view = "list"
  NebbieDash.refreshIdentUi()
end

function NebbieDash.equipDividerPointerY(event)
  if type(getMousePosition) == "function" then
    local _x, y = getMousePosition()
    if type(y) == "number" then return y end
  end
  if type(event) == "table" then
    return event.y or event.yPos or event["y-pos"] or 0
  end
  return 0
end

function NebbieDash.setEquipHeightRatioFromPointerY(y)
  local _w, h = getMainWindowSize()
  h = h or 600
  local usableH = math.max(1, h - (NebbieDash.dividerPx or 4))
  local ratio = math.max(0.1, math.min(0.9, (y or 0) / usableH))
  NebbieDash.guiRatios = NebbieDash.guiRatios or {}
  NebbieDash.guiRatios.equip = ratio
  NebbieDash.guiRatios.manualEquip = true
  NebbieDash.positionGUI()
end

function NebbieDash.onEquipDividerPress(event)
  if event and event.button and event.button ~= "LeftButton" then return end
  NebbieDash._equipRatioDrag = true
  NebbieDash.setEquipHeightRatioFromPointerY(NebbieDash.equipDividerPointerY(event))
end

function NebbieDash.onEquipDividerMove(event)
  if not NebbieDash._equipRatioDrag then return end
  NebbieDash.setEquipHeightRatioFromPointerY(NebbieDash.equipDividerPointerY(event))
end

function NebbieDash.onEquipDividerRelease(_event)
  if not NebbieDash._equipRatioDrag then return end
  NebbieDash._equipRatioDrag = nil
  NebbieDash.persistGuiRatios()
end

function NebbieDash.setupEquipDividerDrag()
  if NebbieDash._equipRatioDragReady then return end
  if type(setLabelClickCallback) ~= "function"
    or type(setLabelMoveCallback) ~= "function"
    or type(setLabelReleaseCallback) ~= "function" then
    return
  end
  if type(setLabelCursor) == "function" then
    pcall(setLabelCursor, "NebbieDashDivider", "splitVCursor")
  end
  if type(setLabelToolTip) == "function" then
    setLabelToolTip("NebbieDashDivider", "Trascina per regolare altezza Equip / Speedwalk (oppure nheights)")
  end
  setLabelClickCallback("NebbieDashDivider", "NebbieDash.onEquipDividerPress")
  setLabelMoveCallback("NebbieDashDivider", "NebbieDash.onEquipDividerMove")
  setLabelReleaseCallback("NebbieDashDivider", "NebbieDash.onEquipDividerRelease")
  NebbieDash._equipRatioDragReady = true
end

function NebbieDash.initDockSidebar()
  setBorderLeft(NebbieDash.guiWidthEquip)
  setBorderRight(0)
  createMiniConsole("NebbieDashEquip", 0, 0, NebbieDash.guiWidthEquip, 0)
  createMiniConsole("NebbieDashSpeedwalks", 0, 0, NebbieDash.guiWidthEquip, 0)
  if type(enableScrollBar) == "function" then
    enableScrollBar("NebbieDashEquip", true)
    enableScrollBar("NebbieDashSpeedwalks", true)
  end
  if type(setMaxLines) == "function" then
    setMaxLines("NebbieDashEquip", 400)
    setMaxLines("NebbieDashSpeedwalks", 500)
  end
  -- enableClickthrough = 0: altrimenti il mouse passa alle miniconsole sotto e il drag non funziona.
  createLabel("NebbieDashDivider", 0, 0, NebbieDash.guiWidthEquip, NebbieDash.dividerPx, 1, 0)
end

function NebbieDash.initFloatSidebar()
  setBorderLeft(0)
  setBorderRight(0)
  if NebbieDash._floatSidebarCreated and NebbieDash._sidebarContainer then return end
  local sideW = NebbieDash.guiWidthEquip or 280
  NebbieDash._sidebarContainer = Adjustable.Container:new({
    name = "NebbieDashSidebarContainer",
    x = 0, y = 0,
    width = sideW, height = "100%",
    titleText = "Nebbie — Equip + Speedwalk",
    titleTxtColor = "white",
    adjLabelstyle = [[
      background-color: rgb(10, 10, 16);
      border: 2px solid rgb(70, 70, 100);
      border-radius: 8px;
    ]],
  })
  local pad = 4
  local titleH = 26
  NebbieDash._equipGeyser = Geyser.MiniConsole:new({
    name = "NebbieDashEquip",
    x = pad, y = titleH, width = sideW - pad * 2, height = 200,
  }, NebbieDash._sidebarContainer)
  NebbieDash._equipGeyser:setColor(15, 15, 15, 255)
  if type(enableScrollBar) == "function" then
    enableScrollBar("NebbieDashEquip", true)
  end
  NebbieDash._dividerLabel = Geyser.Label:new({
    name = "NebbieDashDivider",
    x = pad, y = titleH + 200, width = sideW - pad * 2, height = NebbieDash.dividerPx,
  }, NebbieDash._sidebarContainer)
  NebbieDash._dividerLabel:setStyleSheet("background-color: rgb(90, 90, 100);")
  NebbieDash._swGeyser = Geyser.MiniConsole:new({
    name = "NebbieDashSpeedwalks",
    x = pad, y = titleH + 200 + NebbieDash.dividerPx, width = sideW - pad * 2, height = 200,
  }, NebbieDash._sidebarContainer)
  NebbieDash._swGeyser:setColor(15, 15, 15, 255)
  if type(enableScrollBar) == "function" then
    enableScrollBar("NebbieDashSpeedwalks", true)
  end
  NebbieDash._floatSidebarCreated = true
end

function NebbieDash.destroyLegacyGuiWindows()
  NebbieDash.destroyFloatSidebarArtifacts()
  local legacy = {
    "NebbieDashSpells", "NebbieDashWeapons", "NebbieDashDividerLeft",
    "NebbieDashAttrib", "NebbieDashSidebarContainer",
  }
  for _, win in ipairs(legacy) do
    if type(deleteWindow) == "function" then
      pcall(deleteWindow, win)
    elseif type(hideWindow) == "function" then
      pcall(hideWindow, win)
    end
  end
  if type(setBorderRight) == "function" then
    pcall(setBorderRight, 0)
  end
end

function NebbieDash.initGUI()
  if NebbieDash._guiCreated then return end
  NebbieDash.destroyFloatSidebarArtifacts()
  NebbieDash.sidebarMode = "dock"
  NebbieDash.initDockSidebar()
  for _, win in ipairs(NebbieDash.GUI_WINDOWS) do
    setMiniConsoleFontSize(win, NebbieDash.fontSize)
    setBackgroundColor(win, 15, 15, 15, 255)
  end
  setBackgroundColor("NebbieDashDivider", 90, 90, 100, 255)
  NebbieDash.setupEquipDividerDrag()
  NebbieDash._guiCreated = true
  NebbieDash.positionGUI()
  NebbieDash.destroyLegacyGuiWindows()
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

-- Larghezza bordo sinistro da contenuto Equip + Speedwalk.
function NebbieDash.computeSidebarMaxChars(data)
  local maxChars = NebbieDash.computeEquipMaxChars(data)
  for _, item in ipairs(NebbieDash.speedwalkItems or {}) do
    if item.kind == "section" then
      maxChars = math.max(maxChars, #item.title + 3)
    elseif item.kind == "walk" then
      maxChars = math.max(maxChars, #item.desc + 4)
      if item.dirString and item.dirString ~= "" then
        maxChars = math.max(maxChars, math.min(#item.dirString, 72) + 4)
      end
    end
  end
  if not NebbieDash.speedwalkItems or #NebbieDash.speedwalkItems == 0 then
    for _, entry in ipairs(NebbieDash.speedwalks or {}) do
      maxChars = math.max(maxChars, #entry.desc + 4)
      if entry.dirString then
        maxChars = math.max(maxChars, math.min(#entry.dirString, 72) + 4)
      end
    end
  end
  maxChars = math.max(maxChars, #("Speedwalk") + 2)
  return math.min(maxChars, NebbieDash.autoWidthRightMaxChars or 58)
end

function NebbieDash.applyAutoWidth()
  if not NebbieDash._guiCreated then return end
  local name = NebbieDash.currentChar
  local data = name and NebbieDash.getCharData(name) or nil
  local charW = calcFontSize(NebbieDash.fontSize) or 8
  local mainW = select(1, getMainWindowSize()) or 1024
  local maxSidebar = math.floor(mainW * (NebbieDash.autoWidthSidebarMaxWindowPct or 0.38))

  if NebbieDash.autoWidthEquip or NebbieDash.autoWidthRight then
    local chars = NebbieDash.computeSidebarMaxChars(data) + 3
    local cap = NebbieDash.autoWidthRightMaxChars or 58
    local w = math.floor(charW * math.min(chars, cap))
    w = math.max(NebbieDash.autoWidthMin, math.min(w, maxSidebar))
    if w ~= NebbieDash.guiWidthEquip then
      NebbieDash.guiWidthEquip = w
    end
  end
  NebbieDash.applySidebarBorder()
  setBorderRight(0)
end

function NebbieDash.positionGUI()
  if not NebbieDash._guiCreated then return end
  local _w, h = getMainWindowSize()
  h = h or 600
  local sideW = NebbieDash.guiWidthEquip or 260
  local name = NebbieDash.currentChar
  local data = name and NebbieDash.getCharData(name) or nil
  local usableH = math.max(0, h - NebbieDash.dividerPx)
  local equipRatio = NebbieDash.computeSidebarEquipRatio(data)
  local equipH = math.floor(usableH * equipRatio)
  local speedwalkH = usableH - equipH
  moveWindow("NebbieDashEquip", 0, 0)
  resizeWindow("NebbieDashEquip", sideW, equipH)
  moveWindow("NebbieDashDivider", 0, equipH)
  resizeWindow("NebbieDashDivider", sideW, NebbieDash.dividerPx)
  moveWindow("NebbieDashSpeedwalks", 0, equipH + NebbieDash.dividerPx)
  resizeWindow("NebbieDashSpeedwalks", sideW, speedwalkH)
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
  local leftW = 0
    if NebbieDash._guiCreated and NebbieDash._guiHidden ~= true then
    leftW = NebbieDash.guiWidthEquip or 0
  end
  local centerAreaW = math.max(0, w - leftW)
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
  { "nfix", "Riavvia il package e rimuove pannelli legacy (Spell/Armi)." },
  { "npackageupdate [force]", "Scarica/reinstalla il .mpackage da GitHub (wizardmorgan/nebbie-mudlet-dashboard main)." },
  { "ntriggers", "Reinstalla i trigger NebbieDash (fame/sete, prompt, loot, …) senza riavviare Mudlet." },
  { "nkeys", "Tastierino numerico (Nebbie Keypad) e shortcut spell da command line." },
  { "ngui", "Mostra/nascondi tutti i pannelli." },
  { "nlayout", "Ripristina larghezze/font/proporzioni di default." },
  { "nchar <nome>", "Forza manualmente il personaggio attivo." },
  { "nclass <cast|recall|mind>", "Imposta il comando di lancio per il personaggio attivo." },
  { "nfont <6-24>", "Imposta la dimensione del font dei pannelli." },
  { "nwidth [auto|<px>]", "Larghezza colonna Equip+Speedwalk (dock o float); default auto." },
  { "nsidebar dock", "Layout bordo sinistro (unico supportato); rimuove eventuali pannelli float residui + nfix." },
  { "npreferencesreload", "Ricarica preferenze + suoni highlight; reinstalla evidenziazioni testo." },
  { "nheights <10-90>|auto", "Altezza Equip vs Speedwalk: auto = proporzione al testo; o % Equip manuale." },
  { "usa <parola-chiave>", "Cambio arma da zaino (rem/get/wield — come nebbie-play-all)." },
  { "nconfigdir", "Mostra cartella profiles/ndashboard e file indice nebbie-dash-config-root.txt." },
  { "nitemlen <n>", "Lunghezza massima delle descrizioni oggetti in equip." },
  { "nspellwarn <tick>", "(Legacy) soglia colore pannello spell rimosso — ignorato." },
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
  { "nforgetspell <nome>", "Rimuove una spell memorizzata per errore dall'elenco del personaggio attivo." },
  { "nbatch [nome-toon]", "Esegue comandi admin da CSV (profilo Sirio; inizia con nchar Sirio)." },
  { "nbatchreload", "Ricarica nebbie-batch-commands.txt e nebbie-batch-items.csv." },
  { "nbatchverify [toon] [data]", "Verifica log batch vs CSV (es. nbatchverify GreenBlade 2026-09-21)." },
  { "nidentbatch [nome-toon]", "Identify batch: oload $3, stat/identify/junk con $o (keyword oload)." },
  { "nidentbatch resume [nome-toon]", "Riprende identify batch saltando righe gia' nel CSV di oggi." },
  { "nidentbatchreload", "Ricarica nebbie-ident-batch-commands.txt e nebbie-batch-items.csv." },
  { "nidentdb [query]", "Cerca nell'archivio identify condiviso (profiles/ndashboard)." },
  { "nidentdb where <query>", "Come nidentdb + possesso + chi ha l'oggetto in equip (cache eq)." },
  { "nidentdb char <nome>", "Identify / possesso di quel personaggio." },
  { "nidentdb hold <NomePg>", "Dopo un drop: assegna l'oggetto a terra a un PG." },
  { "nidentdb hold <ogg> <Pg>", "Assegna possesso identify a un PG (senza drop pendente)." },
  { "nidentdb cedibile <ogg>", "Marca l'oggetto come cedibile (inventario give/drop)." },
  { "nidentdb noncedibile <ogg>", "Toglie il flag cedibile (give/drop non lo toccano)." },
  { "nidentdb del <ogg>", "Elimina una entry identify (se la query e' univoca)." },
  { "nidentui", "Finestra floating per gestire l'archivio identify (lista, filtri, elimina)." },
  { "nidentui filter|char|del|reset", "Filtri / elimina / reset nella finestra Ident." },
  { "nidentdb export <NomePg>", "CSV di tutti gli identify di un PG (file NomePg-gg-mm-aaaa-hh-mm-ss.csv)." },
  { "nidentdbreload", "Ricarica nebbie-ident-db.lua dalla cartella condivisa." },
  { "nknowdb [query]", "Cerca nell'archivio know monster condiviso (profiles/ndashboard)." },
  { "nknowdb race <razza>", "Elenca mostri per razza (es. nknowdb race Goblinoid)." },
  { "nknowdbreload", "Ricarica nebbie-know-db.lua dalla cartella condivisa." },
  { "nchat", "Mostra/nascondi la finestra floating chat (say/gt/tell/whisper/ask/gossip/shout)." },
  { "nchat on|off|clear", "Attiva/disattiva o svuota la finestra chat." },
  { "identify <arma>", "(comando di gioco) Rileva il tipo di danno (slash/blunt/pierce) per usa/disarmo." },
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
      NebbieDash.applySidebarBorder()
      setBorderRight(0)
      NebbieDash.positionGUI()
    end
  end
  NebbieDash.refreshDashboard()
end

function NebbieDash.resetLayout()
  NebbieDash.guiWidthEquip = 260
  NebbieDash.guiWidthRight = 0
  NebbieDash.fontSize = 11
  NebbieDash.autoWidthEquip = true
  NebbieDash.autoWidthRight = true
  NebbieDash.guiRatios = { equip = 0.5, manualEquip = false }
  NebbieDash.persistGuiRatios()
  if NebbieDash._guiCreated then
    for _, win in ipairs(NebbieDash.GUI_WINDOWS) do
      setMiniConsoleFontSize(win, NebbieDash.fontSize)
    end
    NebbieDash.applySidebarBorder()
    setBorderRight(0)
    NebbieDash.applyAutoWidth()
    NebbieDash.positionGUI()
    NebbieDash.refreshDashboard()
  end
  cecho("<green>[NebbieDash] Layout ripristinato: larghezza auto, Equip/Speedwalk proporzionali al testo, font 11.\n")
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

-- Larghezza bordo sinistro (Equip + Speedwalk impilati).
function NebbieDash.cmdSetWidth(argStr)
  argStr = (argStr or ""):match("^%s*(.-)%s*$")
  if argStr == "" or argStr:lower() == "auto" then
    NebbieDash.autoWidthEquip = true
    NebbieDash.autoWidthRight = true
    NebbieDash.refreshDashboard()
    cecho("<green>[NebbieDash] Larghezza bordo sinistro: automatica.\n")
    return
  end
  local width = tonumber(argStr)
  if not width or width < 150 or width > 900 then
    cecho("<orange>[NebbieDash] Uso: nwidth <numero 150-900> oppure <yellow>nwidth auto\n")
    return
  end
  NebbieDash.autoWidthEquip = false
  NebbieDash.autoWidthRight = false
  NebbieDash.guiWidthEquip = width
  if NebbieDash._guiCreated then
    setBorderLeft(width)
    setBorderRight(0)
    NebbieDash.positionGUI()
  end
  cecho("<green>[NebbieDash] Larghezza bordo sinistro impostata a " .. width .. " (manuale).\n")
end

function NebbieDash.cmdSetHeights(pctStr)
  pctStr = (pctStr or ""):match("^%s*(.-)%s*$"):lower()
  if pctStr == "auto" then
    NebbieDash.guiRatios = NebbieDash.guiRatios or {}
    NebbieDash.guiRatios.manualEquip = false
    NebbieDash.persistGuiRatios()
    if NebbieDash._guiCreated then NebbieDash.positionGUI() end
    cecho("<green>[NebbieDash] Altezza Equip/Speedwalk: automatica (proporzione al testo).\n")
    return
  end
  local pct = tonumber(pctStr)
  if not pct or pct < 10 or pct > 90 then
    local cur = NebbieDash.guiRatios.manualEquip and math.floor((NebbieDash.guiRatios.equip or 0.5) * 100)
      or "auto"
    cecho("<orange>[NebbieDash] Uso: nheights <10-90> (% altezza Equip) oppure <yellow>nheights auto<grey> (attuale: "
      .. tostring(cur) .. ")\n")
    return
  end
  NebbieDash.guiRatios = NebbieDash.guiRatios or {}
  NebbieDash.guiRatios.equip = pct / 100
  NebbieDash.guiRatios.manualEquip = true
  NebbieDash.persistGuiRatios()
  if NebbieDash._guiCreated then NebbieDash.positionGUI() end
  cecho("<green>[NebbieDash] Equip al " .. pct .. "% dell'altezza sinistra (Speedwalk: " .. (100 - pct) .. "%).\n")
end

function NebbieDash.cmdSetLeftHeights(_pctStr)
  cecho("<grey>[NebbieDash] nleftheights: pannello armi rimosso — la colonna equip usa tutta l'altezza.\n")
end

function NebbieDash.cmdConfigDir(_arg)
  NebbieDash.ensureConfigDir()
  NebbieDash.ensureDefaultConfigFiles()
  cecho("<cyan><b>Config NebbieDash</b>\n")
  cecho("<grey>Cartella dati (modifica speedwalk, spell, macro, …):\n<white>" ..
    NebbieDash.configRoot() .. "\n")
  cecho("<grey>File indice in profiles (percorso scritto qui):\n<white>" ..
    NebbieDash.configRootPointerPath() .. "\n")
  cecho("<grey>Profilo Mudlet attivo: <white>" .. NebbieDash.mudletProfileHome() .. "\n")
end

function NebbieDash.cmdReloadPreferences()
  NebbieDash.loadPreferences()
  NebbieDash.loadSoundsConfig()
  NebbieDash.weaponSwapDelay = NebbieDash.prefs.weapon_swap_delay or NebbieDash.weaponSwapDelay
  NebbieDash.chatEnabled = NebbieDash.prefs.chat_window ~= false
  NebbieDash.installTextHighlightTriggers()
  if NebbieDash.chatEnabled then
    NebbieDash.initChatWindow()
    NebbieDash.installChatTriggers()
  else
    NebbieDash.teardownChatTriggers()
    NebbieDash.hideChatWindow()
  end
  cecho("<green>[NebbieDash] Preferenze ricaricate da <white>" .. NebbieDash.preferencesPath() ..
    "<green> (sidebar=" .. tostring(NebbieDash.effectiveSidebarMode()) ..
    ", weapon_swap_delay=" .. tostring(NebbieDash.weaponSwapDelay) ..
    ", text_highlights=" .. ((NebbieDash.textHighlights ~= false) and "on" or "off") ..
    ", chat_window=" .. ((NebbieDash.chatEnabled ~= false) and "on" or "off") .. ").\n")
end

function NebbieDash.cmdSetSidebar(modeStr)
  modeStr = (modeStr or ""):lower():match("^%s*(.-)%s*$")
  if modeStr == "float" then
    cecho("<grey>[NebbieDash] Modalita' float disabilitata (pannelli neri in Mudlet) — uso <yellow>dock<grey>.\n")
    modeStr = "dock"
  end
  if modeStr ~= "dock" then
    cecho("<orange>[NebbieDash] Uso: nsidebar <yellow>dock<orange> (attuale: dock)\n")
    return
  end
  NebbieDash.prefs = NebbieDash.prefs or {}
  NebbieDash.prefs.sidebar_mode = modeStr
  NebbieDash.sidebarMode = modeStr
  NebbieDash.savePreferencesFile()
  NebbieDash.teardownGui()
  NebbieDash.initGUI()
  NebbieDash.refreshDashboard()
  cecho("<green>[NebbieDash] Sidebar impostata su <yellow>" .. modeStr ..
    "<green>. Modifica anche <white>nebbie-dash-preferences.txt<green>.\n")
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
  NebbieDash.uiState = NebbieDash.uiState or {}
  NebbieDash.uiState.showClanSlot = NebbieDash.showClanSlot
  NebbieDash.saveUiStore()
  NebbieDash.refreshDashboard()
  cecho("<green>[NebbieDash] Slot 'simbolo del clan': " .. (NebbieDash.showClanSlot and "attivato" or "disattivato") .. ".\n")
end

function NebbieDash.refreshDashboard()
  if not NebbieDash._guiCreated or NebbieDash._guiHidden then return end
  NebbieDash.applyAutoWidth()
  NebbieDash.positionGUI()
  NebbieDash.refreshSpeedwalkPanel()
  local name = NebbieDash.currentChar
  NebbieDash.clearPanel("NebbieDashEquip")
  if not name then
    NebbieDash.panelCecho("NebbieDashEquip", "<grey>Nessun personaggio rilevato.\n")
    return
  end
  NebbieDash.renderEquipPanel(name, NebbieDash.getCharData(name))
end

function NebbieDash.refreshSpeedwalkPanel()
  if not NebbieDash._guiCreated or NebbieDash._guiHidden then return end
  NebbieDash.clearPanel("NebbieDashSpeedwalks")
  NebbieDash.panelCecho("NebbieDashSpeedwalks", "<cyan><b>Speedwalk</b>\n")
  if #(NebbieDash.speedwalkItems or {}) == 0 and #NebbieDash.speedwalks == 0 then
    NebbieDash.panelCecho("NebbieDashSpeedwalks",
      "<grey>(nessuno — scrivili in " .. NebbieDash.speedwalkPath() .. " poi digita <yellow>nspeedwalks<grey>)\n")
    NebbieDash.positionGUI()
    return
  end
  for i, item in ipairs(NebbieDash.speedwalkItems or {}) do
    if item.kind == "section" then
      local collapsed = NebbieDash.isSpeedwalkSectionCollapsed(item.key)
      local icon = collapsed and "▶" or "▼"
      NebbieDash.panelCechoLink("NebbieDashSpeedwalks", "<yellow><b>" .. icon .. " " .. item.title .. "</b>",
        string.format("NebbieDash.toggleSpeedwalkSection(%d)", i),
        (collapsed and "Espandi sezione" or "Collassa sezione") ..
          " — nel file: (>> " .. item.title .. ")", true)
      NebbieDash.panelCecho("NebbieDashSpeedwalks", "\n")
    elseif item.kind == "walk" then
      if item.sectionKey and NebbieDash.isSpeedwalkSectionCollapsed(item.sectionKey) then
        -- nascosto finche' la sezione e' collassata
      else
        local preview = item.dirString or ""
        local descCols = NebbieDash.panelWrapCols("left", 0)
        local lineCols = NebbieDash.panelWrapCols("left", 2)
        local noteCols = NebbieDash.panelWrapCols("left", 4)
        local dirLines = NebbieDash.wrapPanelText(preview, lineCols)
        for idx, dline in ipairs(NebbieDash.wrapPanelText(item.desc, descCols)) do
          if idx == 1 then
            NebbieDash.panelCechoLink("NebbieDashSpeedwalks", "<cyan>" .. dline,
              string.format("NebbieDash.runSpeedwalk(%d)", item.walkIndex),
              "Clicca per andare: " .. item.desc .. " (" .. preview .. ")", true)
            NebbieDash.panelCecho("NebbieDashSpeedwalks", "\n")
          else
            NebbieDash.panelCecho("NebbieDashSpeedwalks", "<cyan>  " .. dline .. "\n")
          end
        end
        for _, dline in ipairs(dirLines) do
          NebbieDash.panelCecho("NebbieDashSpeedwalks", "<grey>  " .. dline .. "\n")
        end
        if item.note and item.note ~= "" then
          local noteLines = NebbieDash.wrapPanelText(item.note, noteCols)
          if #noteLines == 1 then
            NebbieDash.panelCecho("NebbieDashSpeedwalks", "<grey>  (" .. noteLines[1] .. ")\n")
          else
            for ni, nline in ipairs(noteLines) do
              if ni == 1 then
                NebbieDash.panelCecho("NebbieDashSpeedwalks", "<grey>  (" .. nline .. "\n")
              elseif ni == #noteLines then
                NebbieDash.panelCecho("NebbieDashSpeedwalks", "<grey>    " .. nline .. ")\n")
              else
                NebbieDash.panelCecho("NebbieDashSpeedwalks", "<grey>    " .. nline .. "\n")
              end
            end
          end
        end
      end
    end
  end
  NebbieDash.positionGUI()
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

-- Righe di fine combattimento (fight.cpp). Variante senza "punti" esiste per NPC.
-- Non usare "La tua parte e' di N monete." (messaggio split).
function NebbieDash.isCombatExpLine(text)
  text = NebbieDash.stripColors(text or ""):match("^%s*(.-)%s*$") or ""
  if text:match("^La tua parte di esperienza e' di %d+ punti%.%s*$") then return true end
  if text:match("^La tua parte di esperienza e' di %d+%.%s*$") then return true end
  if text:match("^La tua esperienza e' aumentata di %d+ punti%.%s*$") then return true end
  return false
end

-- Segnale di fine combattimento → nloot se nautoloot on.
function NebbieDash.onCombatEndLine()
  if NebbieDash.autoLoot == false then return end
  local text = line or (type(getCurrentLine) == "function" and getCurrentLine()) or ""
  if not NebbieDash.isCombatExpLine(text) then return end
  NebbieDash.scheduleAutoLoot()
end

function NebbieDash.scheduleAutoLoot()
  if NebbieDash.autoLoot == false then return end
  local now = os.clock()
  if NebbieDash._lastAutoLootClock and (now - NebbieDash._lastAutoLootClock) < 0.6 then
    return
  end
  NebbieDash._lastAutoLootClock = now
  if NebbieDash._autoLootDelayTimer and type(killTimer) == "function" then
    pcall(killTimer, NebbieDash._autoLootDelayTimer)
  end
  -- Breve attesa: il cadavere compare spesso un attimo dopo la riga exp.
  NebbieDash._autoLootDelayTimer = tempTimer(0.35, function()
    NebbieDash._autoLootDelayTimer = nil
    if NebbieDash.autoLoot == false then return end
    NebbieDash.cmdLoot()
  end)
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
--   - Disarmo (arma a terra): "Ti disarmano e la Flamberga di Boris vola dalla tua presa."
--     — get + wield dopo breve delay (oggetto caduto).
--   - Disarmo (resta in mano, rune): es. "Ti disarmano e Nordagh, La rosa spinosa dei Noor ti sfugge
--     dalle mani, ma le rune del luogo non la lasciano cadere." — solo wield (override da
--     nebbie-item-keywords.txt se il nome in riga non coincide con le keyword MUD).
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

-- Parole chiave per get/wield dopo disarmo (nome preso dalla riga di gioco).
function NebbieDash.resolveDisarmKeywords(weaponName)
  local override = NebbieDash.findItemKeywordOverride(weaponName)
  if override and override ~= "" then return override, true end
  local stripped = NebbieDash.stripItemParentheticals(weaponName):lower():match("^%s*(.-)%s*$") or ""
  if stripped == "" then return "", false end
  -- Oggetti con articolo inglese (es. "the ebony kris"): tenere il nome intero.
  -- `get ebony kris` altrimenti e' interpretato come "prendi ebony dal contenitore kris".
  if stripped:match("^the ") or stripped:match("^a ") or stripped:match("^an ") then
    return stripped, false
  end
  return NebbieDash.extractItemKeywords(weaponName), false
end

function NebbieDash.onDisarmLine()
  if not NebbieDash.autoDisarmRecover then return end
  local text = line or (type(getCurrentLine) == "function" and getCurrentLine()) or ""
  text = NebbieDash.stripColors(text):match("^%s*(.-)%s*$") or ""
  local weaponName, wieldOnly
  weaponName = text:match("^Ti disarmano e (.-) ti sfugge dalle mani")
  if weaponName then
    wieldOnly = true
  else
    weaponName = text:match("^Ti disarmano e (.+) vola dalla tua presa%.?%s*$")
    wieldOnly = false
  end
  if not weaponName then return end
  weaponName = weaponName:match("^%s*(.-)%s*$")
  local keywords = NebbieDash.resolveDisarmKeywords(weaponName)
  if keywords == "" then return end
  if wieldOnly then
    send("wield " .. keywords, false)
  else
    send("get " .. keywords, false)
    tempTimer(0.5, function() send("wield " .. keywords, false) end)
  end
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
local function eqEntryLocationCanon(entry)
  if not entry then return "" end
  return (entry.location or ""):lower():match("^%s*(.-)%s*$") or ""
end

function NebbieDash.patchCachedEqLocation(data, locationLabel, itemText)
  if not data or not data.eqUpdated then return false end
  data.eq = data.eq or {}
  local canon = (locationLabel or ""):lower():match("^%s*(.-)%s*$")
  if canon == "" then return false end
  local canonLabel, orderIdx = nil, nil
  for idx, label in ipairs(NebbieDash.EQ_SLOT_ORDER) do
    if label:lower() == canon then
      canonLabel = label
      orderIdx = idx
      break
    end
  end
  if not canonLabel then return false end

  local matchingSlots = {}
  for slot, entry in pairs(data.eq) do
    if eqEntryLocationCanon(entry) == canon then
      table.insert(matchingSlots, slot)
    end
  end
  table.sort(matchingSlots, function(a, b) return a < b end)

  if itemText == nil or itemText == "" then
    for _, slot in ipairs(matchingSlots) do
      data.eq[slot] = nil
    end
  else
    local item = itemText:match("^%s*(.-)%s*$")
    local preferSlot = (#matchingSlots > 0) and matchingSlots[1] or nil
    for slot, entry in pairs(data.eq) do
      if eqEntryLocationCanon(entry) == canon then
        data.eq[slot] = nil
      end
    end
    -- I numeri di slot in cache seguono l'output di `eq` del gioco (es. 16 =
    -- tenuto), non l'indice in EQ_SLOT_ORDER (16 = impugnato): non sovrascrivere
    -- un'altra posizione se l'indice canonico e' già occupato.
    local slotIdx = preferSlot
    if not slotIdx and orderIdx then
      local occupant = data.eq[orderIdx]
      if not occupant or eqEntryLocationCanon(occupant) == canon then
        slotIdx = orderIdx
      end
    end
    if not slotIdx then
      local maxK = 0
      for slot in pairs(data.eq) do
        if type(slot) == "number" and slot > maxK then maxK = slot end
      end
      slotIdx = maxK + 1
      if slotIdx < 1 then slotIdx = orderIdx or 1 end
    end
    data.eq[slotIdx] = { location = canonLabel, item = item }
  end
  data.eqUpdated = os.time()
  NebbieDash.saveStore()
  NebbieDash.refreshDashboard()
  return true
end

-- Guard cambio arma / fame: evita che un "Smetti di usare <zaino>" in ritardo
-- (dopo che _weaponSwapBusy e' gia' sceso) svuoti lo slot «sulla schiena»
-- quando il wear e' gia' avvenuto o e' ancora in volo.
function NebbieDash.beginWeaponSwapGuard(data)
  NebbieDash._weaponSwapBusy = true
  NebbieDash._weaponSwapGen = (NebbieDash._weaponSwapGen or 0) + 1
  NebbieDash._weaponSwapBackItem = nil
  if data and data.eqUpdated then
    for _, row in ipairs(NebbieDash.buildEquipRows(data)) do
      if not row.empty and row.location == "sulla schiena" then
        NebbieDash._weaponSwapBackItem = row.item
        break
      end
    end
  end
  return NebbieDash._weaponSwapGen
end

function NebbieDash.endWeaponSwapGuard(gen, restoreIfEmpty)
  if gen and NebbieDash._weaponSwapGen ~= gen then return end
  -- Chiude busy subito (nuovo `usa` permesso), ma lo stash resta finche'
  -- restoreIfEmpty=true: altrimenti onWearBackLine → end(..., false) azzera lo
  -- stash e un "Smetti di usare" in ritardo svuota «sulla schiena».
  NebbieDash._weaponSwapBusy = false
  if not restoreIfEmpty then return end
  local stash = NebbieDash._weaponSwapBackItem
  NebbieDash._weaponSwapBackItem = nil
  if not stash or stash == "" then return end
  local name = NebbieDash.currentChar
  if not name then return end
  local data = NebbieDash.getCharData(name)
  if not data or not data.eqUpdated then return end
  for _, row in ipairs(NebbieDash.buildEquipRows(data)) do
    if not row.empty and row.location == "sulla schiena" then
      return
    end
  end
  NebbieDash.patchCachedEqLocation(data, "sulla schiena", stash)
end

function NebbieDash.shouldPreserveBackSlot(_itemName)
  if NebbieDash._hungerMacroBusy or NebbieDash._weaponSwapBusy then
    return true
  end
  -- Finche' resta lo stash del cambio arma, NON svuotare la schiena su rem:
  -- anche se il nome $p non matcha perfettamente la cache (eqItemNamesMatch).
  local stash = NebbieDash._weaponSwapBackItem
  if stash and stash ~= "" then
    return true
  end
  return false
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
        -- Durante usa/fame il rem zaino non deve lasciare lo slot vuoto: il wear
        -- ripristina, e un rem in ritardo dopo il wear non deve ri-svuotare.
        if not NebbieDash.shouldPreserveBackSlot(itemName) then
          NebbieDash.patchCachedEqLocation(data, "sulla schiena", nil)
        end
        return
      end
    end
  end
end

function NebbieDash.onWearBackLine()
  local text = line or (type(getCurrentLine) == "function" and getCurrentLine()) or ""
  text = NebbieDash.stripColors(text)
  local itemName = text:match("^Ti metti (.+) sulle spalle%.%s*$")
  if not itemName then return end
  local name = NebbieDash.currentChar
  if not name then return end
  local data = NebbieDash.getCharData(name)
  if not data.eqUpdated then return end
  NebbieDash.patchCachedEqLocation(data, "sulla schiena", itemName)
  if NebbieDash._weaponSwapBusy then
    NebbieDash._weaponSwapBackItem = itemName
    NebbieDash.endWeaponSwapGuard(NebbieDash._weaponSwapGen, false)
  end
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

-- ---------------------------------------------------------------------------
-- Archivio identify condiviso (profiles/ndashboard/nebbie-ident-db.lua)
--
-- Ogni volta che un personaggio fa identify (spell o pergamena), il blocco
-- "La conoscenza ti pervade: … Vieni sopraffatt…" viene catturato e salvato
-- in un DB comune a tutti i profili Mudlet. Persistenza deferred/coalesced
-- (tempTimer) per non lagare il gioco; i trigger catch-all (^) restano
-- disabilitati fuori dalla cattura (stesso schema di eq/attrib).
-- ---------------------------------------------------------------------------
NebbieDash.identDb = NebbieDash.identDb or { entries = {} }
NebbieDash.IDENT_DB_SAVE_DELAY = 0.2
NebbieDash.IDENT_CAPTURE_TIMEOUT = 3
-- Hint fonte (spell/scroll) valido solo pochi secondi prima di "La conoscenza…".
NebbieDash.IDENT_SOURCE_HINT_TTL = 8

function NebbieDash.identDbPath()
  return NebbieDash.configPath("nebbie-ident-db.lua")
end

function NebbieDash.migrateIdentCedibileFlags()
  for _, entry in pairs((NebbieDash.identDb and NebbieDash.identDb.entries) or {}) do
    if entry.cedibile == nil and not entry.cedibileManual then
      NebbieDash.applyCedibileFromFlags(entry, entry.flags)
    end
  end
end

function NebbieDash.loadIdentDb()
  NebbieDash.ensureConfigDir()
  NebbieDash.identDb = NebbieDash.identDb or { entries = {} }
  NebbieDash.identDb.entries = NebbieDash.identDb.entries or {}
  local path = NebbieDash.identDbPath()
  if type(io.exists) == "function" and io.exists(path) then
    local loaded = {}
    local ok = pcall(function() table.load(path, loaded) end)
    if ok and type(loaded.entries) == "table" then
      NebbieDash.identDb = loaded
      NebbieDash.identDb.entries = NebbieDash.identDb.entries or {}
      NebbieDash.migrateIdentCedibileFlags()
    elseif ok and type(loaded) == "table" and loaded.objectName then
      -- file corrotto/parziale: ignora
    end
  end
end

function NebbieDash.saveIdentDb()
  if not NebbieDash.persistEnabled then return end
  NebbieDash.ensureConfigDir()
  NebbieDash.identDb = NebbieDash.identDb or { entries = {} }
  pcall(function() table.save(NebbieDash.identDbPath(), NebbieDash.identDb) end)
end

function NebbieDash.flushIdentDbSave()
  NebbieDash._identDbSavePending = false
  NebbieDash._identDbSaveTimer = nil
  NebbieDash.saveIdentDb()
end

function NebbieDash.scheduleIdentDbSave()
  if NebbieDash._identDbSavePending then return end
  NebbieDash._identDbSavePending = true
  if type(tempTimer) == "function" then
    NebbieDash._identDbSaveTimer = tempTimer(NebbieDash.IDENT_DB_SAVE_DELAY or 0.2, function()
      NebbieDash.flushIdentDbSave()
    end)
  else
    NebbieDash.flushIdentDbSave()
  end
end

function NebbieDash.normalizeIdentObjectKey(name)
  return ((name or ""):lower():match("^%s*(.-)%s*$")) or ""
end

-- Chiave archivio senza suffisso #N (es. "mantello ...#2" → "mantello ...").
function NebbieDash.identBaseKeyFromKey(key)
  key = NebbieDash.normalizeIdentObjectKey(key)
  return (key:match("^(.-)#%d+$")) or key
end

function NebbieDash.identAffectsSignature(affects)
  local parts = {}
  for _, a in ipairs(affects or {}) do
    local t = (a or ""):lower():match("^%s*(.-)%s*$") or ""
    if t ~= "" then table.insert(parts, t) end
  end
  table.sort(parts)
  return table.concat(parts, " | ")
end

-- Firma delle caratteristiche immagazzinate: stesso nome + stessa firma = stesso
-- pezzo (upsert). Stesso nome + firma diversa = nuova entry con suffisso #2, #3…
function NebbieDash.identStatsSignature(entry)
  if not entry then return "" end
  local function n(v)
    if v == nil then return "" end
    return tostring(v)
  end
  return table.concat({
    n(entry.objectType):lower(),
    n(entry.flags):lower(),
    n(entry.vnumOriginario),
    n(entry.weight),
    n(entry.value),
    n(entry.rent),
    entry.rare and "1" or "0",
    n(entry.acApply),
    n(entry.damageDice):lower(),
    n(entry.damageType):lower(),
    NebbieDash.identAffectsSignature(entry.affects),
  }, "\n")
end

function NebbieDash.identStatsEqual(a, b)
  return NebbieDash.identStatsSignature(a) == NebbieDash.identStatsSignature(b)
end

-- Cerca entry con stesso nome oggetto e stesse caratteristiche; altrimenti nil.
function NebbieDash.findIdentEntryMatchingStats(parsed)
  if not parsed or not parsed.objectName then return nil, nil end
  local base = NebbieDash.normalizeIdentObjectKey(parsed.objectName)
  if base == "" then return nil, nil end
  for key, entry in pairs((NebbieDash.identDb and NebbieDash.identDb.entries) or {}) do
    local entryBase = entry.baseKey
      or NebbieDash.identBaseKeyFromKey(key)
      or NebbieDash.normalizeIdentObjectKey(entry.objectName)
    if entryBase == base and NebbieDash.identStatsEqual(entry, parsed) then
      return key, entry
    end
  end
  return nil, nil
end

-- Alloca chiave: nome normalizzato, oppure nome#2, nome#3… se già preso da
-- un pezzo con caratteristiche diverse.
function NebbieDash.allocIdentDbKey(baseKey)
  baseKey = NebbieDash.normalizeIdentObjectKey(baseKey)
  local entries = (NebbieDash.identDb and NebbieDash.identDb.entries) or {}
  if not entries[baseKey] then return baseKey end
  local n = 2
  while entries[baseKey .. "#" .. n] do
    n = n + 1
  end
  return baseKey .. "#" .. n
end

-- Parser completo del blocco identify (spell o pergamena). Accetta sia il
-- formato mortale (senza V-Number) sia quello immortale/batch.
function NebbieDash.parseIdentifyFull(lines)
  local entry = {
    objectName = nil,
    objectType = nil,
    flags = nil,
    vnumOriginario = nil,
    weight = nil,
    value = nil,
    rent = nil,
    rare = false,
    acApply = nil,
    damageDice = nil,
    damageType = nil,
    affects = {},
  }
  for _, raw in ipairs(lines or {}) do
    local text = NebbieDash.stripColors(raw or ""):match("^%s*(.-)%s*$") or ""
    if text == "" then
      -- skip
    else
      if not entry.objectName then
        local n, t, v = text:match(
          "^Oggetto: '([^']+)', Tipo di Oggetto (%S+) V%-Number Originario: (%d+)%s*$")
        if n then
          entry.objectName, entry.objectType, entry.vnumOriginario = n, t, v
        else
          n, t = text:match("^Oggetto: '([^']+)', Tipo di Oggetto (%S+)%s*$")
          if n then
            entry.objectName, entry.objectType = n, t
          end
        end
      end
      if not entry.vnumOriginario then
        entry.vnumOriginario = text:match("V%-Number Originario:%s*(%d+)")
      end
      if not entry.flags then
        entry.flags = text:match("^L'oggetto e':%s*(.-)%s*$")
        if entry.flags then
          entry.flags = entry.flags:match("^%s*(.-)%s*$")
        end
      end
      local w, val, rent = text:match(
        "^Peso:%s*([%d%.]+),%s*Valore:%s*([%d%.]+),%s*Costo di rent:%s*([%d%.]+)")
      if w then
        entry.weight = tonumber(w)
        entry.value = tonumber(val)
        entry.rent = tonumber(rent)
        if text:find("%[RARO%]", 1) then entry.rare = true end
      end
      local ac = text:match("^AC%-apply di ([%d%.]+)%.%s*$")
      if ac then entry.acApply = tonumber(ac) end
      local dice = text:match("^Dado di danno:%s*'([^']+)'")
      if dice then entry.damageDice = dice end
      local dmg = text:match("^Tipo di danno:%s*'([^']+)'")
      if dmg then entry.damageType = dmg end
      local aff = text:match("Ti puo' dare%s*:%s*(.-)%s*$")
      if aff and aff ~= "" then
        table.insert(entry.affects, aff)
      end
    end
  end
  if not entry.objectName or entry.objectName == "" then return nil end
  if not entry.objectType or entry.objectType == "" then return nil end
  return entry
end

function NebbieDash.upsertIdentRecord(parsed, character, source)
  if not parsed or not parsed.objectName then return nil end
  local baseKey = NebbieDash.normalizeIdentObjectKey(parsed.objectName)
  if baseKey == "" then return nil end
  NebbieDash.identDb = NebbieDash.identDb or { entries = {} }
  NebbieDash.identDb.entries = NebbieDash.identDb.entries or {}
  local now = os.time()
  local key, existing = NebbieDash.findIdentEntryMatchingStats(parsed)
  if not key then
    key = NebbieDash.allocIdentDbKey(baseKey)
    existing = {}
  end
  existing.key = key
  existing.baseKey = baseKey
  existing.objectName = parsed.objectName
  existing.objectType = parsed.objectType
  existing.flags = parsed.flags
  existing.vnumOriginario = parsed.vnumOriginario
  existing.weight = parsed.weight
  existing.value = parsed.value
  existing.rent = parsed.rent
  existing.rare = parsed.rare and true or false
  existing.acApply = parsed.acApply
  existing.damageDice = parsed.damageDice
  existing.damageType = parsed.damageType
  existing.affects = parsed.affects or {}
  existing.statsSig = NebbieDash.identStatsSignature(parsed)
  existing.lastAt = now
  existing.lastCharacter = character or existing.lastCharacter or "unknown"
  existing.lastSource = source or existing.lastSource
  existing.byCharacter = existing.byCharacter or {}
  local who = character or "unknown"
  existing.byCharacter[who] = {
    at = now,
    source = source or existing.byCharacter[who] and existing.byCharacter[who].source,
  }
  -- Identify implica che il PG ha l'oggetto a portata: aggiorna possesso.
  existing.possession = {
    status = "held",
    character = who,
    at = now,
    via = "identify",
    from = existing.possession and existing.possession.character,
    displaySeen = existing.possession and existing.possession.displaySeen,
  }
  NebbieDash.applyCedibileFromFlags(existing, existing.flags)
  NebbieDash.identDb.entries[key] = existing
  NebbieDash.scheduleIdentDbSave()
  if NebbieDash._identUiCreated and not NebbieDash._identUiHidden then
    NebbieDash.refreshIdentUi()
  end
  return existing
end

-- PROCAREA-REWARD → cedibile automatico (inventario trasferibile). Override
-- manuale con nidentdb cedibile / noncedibile (cedibileManual).
function NebbieDash.flagsHaveProcareReward(flags)
  return (flags or ""):upper():find("PROCAREA%-REWARD", 1, false) ~= nil
end

function NebbieDash.applyCedibileFromFlags(entry, flags)
  if not entry then return end
  if entry.cedibileManual then return end
  entry.cedibile = NebbieDash.flagsHaveProcareReward(flags) and true or false
end

function NebbieDash.setIdentCedibile(entry, cedibile, manual)
  if not entry then return nil end
  entry.cedibile = cedibile and true or false
  if manual then
    entry.cedibileManual = true
  end
  NebbieDash.scheduleIdentDbSave()
  return entry
end

function NebbieDash.isIdentEntryCedibile(entry)
  return entry and entry.cedibile == true
end

-- Normalizza il nome oggetto da messaggi give/drop (articoli, dall'/dell', …)
-- per poterlo confrontare con la keyword da identify.
function NebbieDash.normalizeIdentItemText(text)
  text = NebbieDash.stripColors(text or ""):lower()
  text = text:match("^%s*(.-)%s*$") or ""
  text = text:gsub("^l'", ""):gsub("^un'", "")
  text = text:gsub("^il%s+", ""):gsub("^la%s+", ""):gsub("^lo%s+", "")
  text = text:gsub("^un%s+", ""):gsub("^una%s+", ""):gsub("^uno%s+", "")
  text = text:gsub("^gli%s+", ""):gsub("^le%s+", ""):gsub("^i%s+", "")
  text = text:gsub("dall'", " "):gsub("dell'", " "):gsub("all'", " "):gsub("nell'", " ")
  text = text:gsub("%sdal%s+", " "):gsub("%sdel%s+", " "):gsub("%sal%s+", " ")
  text = text:gsub("%sdei%s+", " "):gsub("%sdegli%s+", " "):gsub("%sdelle%s+", " ")
  text = text:gsub("%sdi%s+", " "):gsub("%sda%s+", " ")
  text = text:gsub("%s+", " ")
  return text:match("^%s*(.-)%s*$") or ""
end

function NebbieDash.identTokenSet(text)
  local set = {}
  for w in NebbieDash.normalizeIdentItemText(text):gmatch("%S+") do
    if #w >= 3 then set[w] = true end
  end
  return set
end

function NebbieDash.identTokenCount(set)
  local n = 0
  for _ in pairs(set or {}) do n = n + 1 end
  return n
end

function NebbieDash.identTokenOverlapScore(a, b)
  local sa, sb = NebbieDash.identTokenSet(a), NebbieDash.identTokenSet(b)
  local n = 0
  for w, _ in pairs(sa) do
    if sb[w] then n = n + 1 end
  end
  return n
end

-- Score stretto: niente match su un solo token generico (es. "anello" →
-- "anello varco…"). Richiede copertura alta sul set piu' corto.
function NebbieDash.identMatchQuality(itemText, entryName)
  local needle = NebbieDash.normalizeIdentItemText(itemText)
  local hay = NebbieDash.normalizeIdentItemText(entryName)
  if needle == "" or hay == "" then return 0 end
  if needle == hay then return 100 end
  local sa, sb = NebbieDash.identTokenSet(needle), NebbieDash.identTokenSet(hay)
  local na, nb = NebbieDash.identTokenCount(sa), NebbieDash.identTokenCount(sb)
  if na == 0 or nb == 0 then return 0 end
  local score = 0
  for w, _ in pairs(sa) do
    if sb[w] then score = score + 1 end
  end
  if score == 0 then return 0 end
  -- Un solo token nel messaggio: accetta solo se anche l'entry e' mono-token
  -- e coincide (altrimenti "anello" agganciava pezzi lunghi omonimi).
  if na == 1 then
    if nb == 1 and score == 1 then return score end
    return 0
  end
  local shorter = math.min(na, nb)
  local need = math.max(2, math.ceil(shorter * 0.75))
  if score < need then return 0 end
  return score
end

-- Trova la migliore entry in archivio per un testo give/drop/eq.
-- opts.onlyCedibile: solo entry marcate cedibili (give/drop automatici).
-- opts.preferChar: preferisci possesso di quel PG in caso di parita'.
function NebbieDash.matchIdentEntryByItemText(itemText, opts)
  opts = opts or {}
  local needle = NebbieDash.normalizeIdentItemText(itemText)
  if needle == "" then return nil, 0 end
  local preferChar = opts.preferChar and tostring(opts.preferChar):lower() or nil
  local best, bestScore, secondScore = nil, 0, 0
  for _, entry in pairs((NebbieDash.identDb and NebbieDash.identDb.entries) or {}) do
    if opts.onlyCedibile and not NebbieDash.isIdentEntryCedibile(entry) then
      -- skip non cedibili
    else
      local score = NebbieDash.identMatchQuality(needle, entry.objectName or "")
      if entry.possession and entry.possession.displaySeen then
        local alt = NebbieDash.identMatchQuality(needle, entry.possession.displaySeen)
        if alt > score then score = alt end
      end
      if score > 0 then
        local preferBoost = 0
        if preferChar and entry.possession and entry.possession.status == "held"
            and entry.possession.character
            and tostring(entry.possession.character):lower() == preferChar then
          preferBoost = 0.5
        end
        local effective = score + preferBoost
        if effective > bestScore then
          secondScore = bestScore
          best, bestScore = entry, effective
        elseif effective > secondScore then
          secondScore = effective
        end
      end
    end
  end
  if bestScore < 1 then return nil, 0 end
  -- Ambiguita': due entry con score quasi uguale → non aggiornare in automatico.
  if secondScore > 0 and (bestScore - secondScore) < 0.6 then
    return nil, 0
  end
  return best, math.floor(bestScore)
end

function NebbieDash.setIdentPossession(entry, status, character, via, displaySeen, fromChar)
  if not entry then return nil end
  local now = os.time()
  local prev = entry.possession and entry.possession.character
  entry.possession = {
    status = status or "unknown",
    character = (status == "held") and character or nil,
    at = now,
    via = via,
    from = fromChar or prev,
    displaySeen = displaySeen or (entry.possession and entry.possession.displaySeen),
  }
  if status == "held" and character and character ~= "" then
    entry.byCharacter = entry.byCharacter or {}
    entry.byCharacter[character] = entry.byCharacter[character] or { at = now }
    entry.byCharacter[character].at = now
  end
  NebbieDash.scheduleIdentDbSave()
  return entry
end

function NebbieDash.parseGiveLine(text)
  text = NebbieDash.stripColors(text or ""):match("^%s*(.-)%s*$") or ""
  local item, target = text:match("^Dai%s+(.+)%s+a%s+(%S+)%.%s*$")
  if not item or not target then return nil end
  return { item = item, target = target }
end

function NebbieDash.parseDropLine(text)
  text = NebbieDash.stripColors(text or ""):match("^%s*(.-)%s*$") or ""
  local item = text:match("^Posi%s+(.+)%.%s*$")
  if not item then return nil end
  return { item = item }
end

function NebbieDash.onIdentGiveLine()
  local text = line or (type(getCurrentLine) == "function" and getCurrentLine()) or ""
  local parsed = NebbieDash.parseGiveLine(text)
  if not parsed then return end
  local entry = select(1, NebbieDash.matchIdentEntryByItemText(parsed.item, {
    onlyCedibile = true,
    preferChar = NebbieDash.currentChar,
  }))
  if not entry then return end
  local fromChar = NebbieDash.currentChar or (entry.possession and entry.possession.character)
  NebbieDash.setIdentPossession(entry, "held", parsed.target, "give", parsed.item, fromChar)
  cecho(string.format(
    "<green>[NebbieDash] Ident: <white>%s<green> passato a <yellow>%s<green> (da %s).\n",
    entry.objectName or parsed.item, parsed.target, tostring(fromChar or "?")))
end

function NebbieDash.onIdentDropLine()
  local text = line or (type(getCurrentLine) == "function" and getCurrentLine()) or ""
  local parsed = NebbieDash.parseDropLine(text)
  if not parsed then return end
  local entry = select(1, NebbieDash.matchIdentEntryByItemText(parsed.item, {
    onlyCedibile = true,
    preferChar = NebbieDash.currentChar,
  }))
  if not entry then return end
  local fromChar = NebbieDash.currentChar or (entry.possession and entry.possession.character)
  NebbieDash.setIdentPossession(entry, "ground", nil, "drop", parsed.item, fromChar)
  NebbieDash._identDropPending = {
    key = entry.key,
    objectName = entry.objectName,
    displaySeen = parsed.item,
    from = fromChar,
    at = os.time(),
  }
  cecho(string.format(
    "<orange>[NebbieDash] Ident: <white>%s<orange> → oggetto lasciato in terra (da %s).\n",
    entry.objectName or parsed.item, tostring(fromChar or "?")))
  cecho("<grey>Chi lo raccoglie? Digita <yellow>nidentdb hold <NomePg><grey> (es. <yellow>nidentdb hold Sirio<grey>).\n")
end

function NebbieDash.cmdIdentDbHold(charName)
  charName = (charName or ""):match("^%s*(.-)%s*$") or ""
  if charName == "" then
    cecho("<orange>[NebbieDash] Uso: <yellow>nidentdb hold <NomePg><orange> — assegna l'oggetto lasciato in terra.\n")
    return
  end
  local pending = NebbieDash._identDropPending
  if not pending or not pending.key then
    cecho("<orange>[NebbieDash] Nessun drop in attesa. Fai un <white>drop<orange> di un oggetto già in archivio identify, oppure <yellow>nidentdb hold <oggetto> <NomePg><orange>.\n")
    return
  end
  local entry = NebbieDash.identDb.entries and NebbieDash.identDb.entries[pending.key]
  if not entry then
    NebbieDash._identDropPending = nil
    cecho("<orange>[NebbieDash] Entry identify del drop non trovata più in archivio.\n")
    return
  end
  NebbieDash.setIdentPossession(entry, "held", charName, "hold", pending.displaySeen, pending.from)
  NebbieDash._identDropPending = nil
  cecho(string.format(
    "<green>[NebbieDash] Ident: <white>%s<green> ora in possesso di <yellow>%s<green>.\n",
    entry.objectName or "?", charName))
end

function NebbieDash.cmdIdentDbHoldExplicit(objectQuery, charName)
  objectQuery = (objectQuery or ""):match("^%s*(.-)%s*$") or ""
  charName = (charName or ""):match("^%s*(.-)%s*$") or ""
  if objectQuery == "" or charName == "" then
    cecho("<orange>[NebbieDash] Uso: <yellow>nidentdb hold <oggetto> <NomePg>\n")
    return
  end
  local results = NebbieDash.searchIdentDb(objectQuery)
  if not results or #results == 0 then
    local entry = select(1, NebbieDash.matchIdentEntryByItemText(objectQuery))
    if entry then results = { entry } end
  end
  if not results or #results == 0 then
    cecho("<orange>[NebbieDash] Nessun identify per <white>" .. objectQuery .. "\n")
    return
  end
  local entry = results[1]
  local fromChar = entry.possession and entry.possession.character
  NebbieDash.setIdentPossession(entry, "held", charName, "hold", objectQuery, fromChar)
  if NebbieDash._identDropPending and NebbieDash._identDropPending.key == entry.key then
    NebbieDash._identDropPending = nil
  end
  cecho(string.format(
    "<green>[NebbieDash] Ident: <white>%s<green> ora in possesso di <yellow>%s<green>.\n",
    entry.objectName or "?", charName))
end

function NebbieDash.noteIdentSourceHint(source)
  if not source or source == "" then return end
  NebbieDash._identSourceHint = { source = source, at = os.time() }
end

function NebbieDash.consumeIdentSourceHint()
  local hint = NebbieDash._identSourceHint
  NebbieDash._identSourceHint = nil
  if not hint or not hint.at then return nil end
  if (os.time() - hint.at) > (NebbieDash.IDENT_SOURCE_HINT_TTL or 8) then
    return nil
  end
  return hint.source
end

function NebbieDash.onIdentSourceSpellLine()
  local text = line or (type(getCurrentLine) == "function" and getCurrentLine()) or ""
  text = NebbieDash.stripColors(text)
  if text:find("Pronunci le parole, 'identify'", 1, true)
      or text:find('Pronunci le parole, "identify"', 1, true) then
    NebbieDash.noteIdentSourceHint("spell")
  end
end

function NebbieDash.onIdentSourceScrollLine()
  local text = line or (type(getCurrentLine) == "function" and getCurrentLine()) or ""
  text = NebbieDash.stripColors(text)
  if text:find("pergamena di identificazione", 1, true) then
    NebbieDash.noteIdentSourceHint("scroll")
  end
end

function NebbieDash.isIdentFatigueLine(text)
  text = NebbieDash.stripColors(text or "")
  return text:match("^Vieni sopraffatt[oa] da un'ondata di stanchezza%.%s*$") ~= nil
end

function NebbieDash.armIdentCaptureWatchdog(gen)
  if type(tempTimer) ~= "function" then return end
  tempTimer(NebbieDash.IDENT_CAPTURE_TIMEOUT or 3, function()
    local cap = NebbieDash._identCapture
    if not cap or NebbieDash._identCaptureGen ~= gen then return end
    if cap.activity ~= cap.watchedActivity then
      cap.watchedActivity = cap.activity
      NebbieDash.armIdentCaptureWatchdog(gen)
    else
      NebbieDash.finishIdentArchiveCapture()
    end
  end)
end

function NebbieDash.startIdentArchiveCapture()
  if NebbieDash._identCapture then
    NebbieDash.finishIdentArchiveCapture()
  end
  NebbieDash._identCaptureGen = (NebbieDash._identCaptureGen or 0) + 1
  local gen = NebbieDash._identCaptureGen
  NebbieDash._identCapture = {
    lines = {},
    character = NebbieDash.currentChar or "unknown",
    source = NebbieDash.consumeIdentSourceHint(),
    activity = 0,
    watchedActivity = 0,
    startedAt = os.time(),
  }
  if NebbieDash._identLineTrig then
    pcall(enableTrigger, NebbieDash._identLineTrig)
  end
  NebbieDash.armIdentCaptureWatchdog(gen)
end

function NebbieDash.onIdentKnowledgeLine()
  NebbieDash.startIdentArchiveCapture()
end

function NebbieDash.onIdentArchiveLine()
  local cap = NebbieDash._identCapture
  if not cap then
    if NebbieDash._identLineTrig then pcall(disableTrigger, NebbieDash._identLineTrig) end
    return
  end
  local text = line or (type(getCurrentLine) == "function" and getCurrentLine()) or ""
  text = NebbieDash.stripColors(text or "")
  local trimmed = text:match("^%s*(.-)%s*$") or ""
  if NebbieDash.isIdentFatigueLine(trimmed) then
    NebbieDash.finishIdentArchiveCapture()
    return
  end
  if NebbieDash.isAnyPromptLine(trimmed) then
    NebbieDash.finishIdentArchiveCapture()
    return
  end
  if trimmed ~= "" then
    table.insert(cap.lines, trimmed)
    cap.activity = (cap.activity or 0) + 1
  end
end

function NebbieDash.finishIdentArchiveCapture()
  local cap = NebbieDash._identCapture
  NebbieDash._identCapture = nil
  if NebbieDash._identLineTrig then
    pcall(disableTrigger, NebbieDash._identLineTrig)
  end
  if not cap then return end
  local parsed = NebbieDash.parseIdentifyFull(cap.lines)
  if not parsed then return end
  NebbieDash.upsertIdentRecord(parsed, cap.character, cap.source)
end

function NebbieDash.identDbEntryCount()
  local n = 0
  for _ in pairs((NebbieDash.identDb and NebbieDash.identDb.entries) or {}) do
    n = n + 1
  end
  return n
end

function NebbieDash.searchIdentDb(query)
  query = (query or ""):lower():match("^%s*(.-)%s*$") or ""
  local results = {}
  for _, entry in pairs((NebbieDash.identDb and NebbieDash.identDb.entries) or {}) do
    if query == "" then
      table.insert(results, entry)
    else
      local possChar = entry.possession and entry.possession.character or ""
      local possStatus = entry.possession and entry.possession.status or ""
      local hay = table.concat({
        entry.objectName or "",
        entry.objectType or "",
        entry.flags or "",
        entry.vnumOriginario or "",
        table.concat(entry.affects or {}, " "),
        entry.lastCharacter or "",
        possChar,
        possStatus,
        entry.possession and entry.possession.displaySeen or "",
      }, " "):lower()
      if hay:find(query, 1, true) then
        table.insert(results, entry)
      end
    end
  end
  table.sort(results, function(a, b)
    return (a.objectName or "") < (b.objectName or "")
  end)
  return results
end

function NebbieDash.listIdentDbByCharacter(charName)
  charName = (charName or ""):match("^%s*(.-)%s*$") or ""
  local needle = charName:lower()
  local results = {}
  for _, entry in pairs((NebbieDash.identDb and NebbieDash.identDb.entries) or {}) do
    local by = entry.byCharacter or {}
    local hit = false
    if needle == "" then
      hit = true
    else
      for who, _ in pairs(by) do
        if who:lower() == needle or who:lower():find(needle, 1, true) then
          hit = true
          break
        end
      end
      if not hit and entry.lastCharacter
          and entry.lastCharacter:lower():find(needle, 1, true) then
        hit = true
      end
      local pc = entry.possession and entry.possession.character
      if not hit and pc and pc:lower():find(needle, 1, true) then
        hit = true
      end
    end
    if hit then table.insert(results, entry) end
  end
  table.sort(results, function(a, b)
    return (a.lastAt or 0) > (b.lastAt or 0)
  end)
  return results
end

-- Incrocia nome identify con la cache eq dei personaggi (neq/nresync).
function NebbieDash.findIdentEqHolders(objectName)
  local key = NebbieDash.normalizeIdentObjectKey(objectName)
  local holders = {}
  if key == "" then return holders end
  for charName, data in pairs(NebbieDash.chars or {}) do
    for slot, entry in pairs((data and data.eq) or {}) do
      local item = type(entry) == "table" and (entry.item or "") or tostring(entry or "")
      local loc = type(entry) == "table" and (entry.location or slot) or slot
      if item ~= "" then
        local itemLow = item:lower()
        if itemLow == key
            or itemLow:find(key, 1, true)
            or key:find(itemLow, 1, true)
            or NebbieDash.keywordsOverlap(item, key) then
          table.insert(holders, {
            character = charName,
            location = loc,
            item = item,
            slot = slot,
          })
        end
      end
    end
  end
  table.sort(holders, function(a, b)
    if a.character == b.character then
      return tostring(a.location) < tostring(b.location)
    end
    return a.character < b.character
  end)
  return holders
end

function NebbieDash.formatIdentDbEntry(entry, withHolders)
  if not entry then return {} end
  local lines = {}
  local variant = (entry.key or ""):match("#(%d+)$")
  local head = string.format("<yellow>%s<white> (%s)",
    entry.objectName or "?", entry.objectType or "?")
  if variant then
    head = head .. string.format(" <orange>#%s<white>", variant)
  end
  if entry.vnumOriginario then
    head = head .. " vnumOrig=" .. tostring(entry.vnumOriginario)
  end
  if entry.rare then head = head .. " <orange>[RARO]" end
  if entry.cedibile then
    head = head .. " <green>[cedibile]"
  elseif entry.cedibileManual then
    head = head .. " <grey>[non cedibile]"
  end
  table.insert(lines, head)
  if entry.flags and entry.flags ~= "" then
    table.insert(lines, "  <grey>flags:<white> " .. entry.flags)
  end
  local stats = {}
  if entry.weight ~= nil then table.insert(stats, "peso " .. tostring(entry.weight)) end
  if entry.value ~= nil then table.insert(stats, "val " .. tostring(entry.value)) end
  if entry.rent ~= nil then table.insert(stats, "rent " .. tostring(entry.rent)) end
  if entry.acApply ~= nil then table.insert(stats, "AC " .. tostring(entry.acApply)) end
  if entry.damageDice then table.insert(stats, "dado " .. entry.damageDice) end
  if entry.damageType then table.insert(stats, "dmg " .. entry.damageType) end
  if #stats > 0 then
    table.insert(lines, "  <grey>stats:<white> " .. table.concat(stats, ", "))
  end
  if entry.affects and #entry.affects > 0 then
    table.insert(lines, "  <grey>affects:<white> " .. table.concat(entry.affects, " | "))
  end
  local when = entry.lastAt and os.date("%Y-%m-%d %H:%M", entry.lastAt) or "?"
  local src = entry.lastSource and (" (" .. entry.lastSource .. ")") or ""
  table.insert(lines, string.format(
    "  <grey>ultimo ident:<white> %s%s <grey>@ %s",
    tostring(entry.lastCharacter or "?"), src, when))
  local poss = entry.possession
  if poss then
    local pwhen = poss.at and os.date("%Y-%m-%d %H:%M", poss.at) or "?"
    if poss.status == "ground" then
      table.insert(lines, string.format(
        "  <orange>possesso:<white> oggetto lasciato in terra <grey>(da %s @ %s)",
        tostring(poss.from or "?"), pwhen))
    elseif poss.status == "held" and poss.character then
      local via = poss.via and (" via " .. poss.via) or ""
      table.insert(lines, string.format(
        "  <grey>possesso:<white> %s%s <grey>@ %s",
        poss.character, via, pwhen))
    end
  end
  if withHolders then
    local holders = NebbieDash.findIdentEqHolders(entry.objectName)
    if #holders == 0 then
      table.insert(lines, "  <grey>in equip:<white> (nessun match nella cache eq — prova nresync)")
    else
      for _, h in ipairs(holders) do
        table.insert(lines, string.format(
          "  <grey>in equip:<white> %s <grey>@<white> %s <grey>(%s)",
          h.character, tostring(h.location), h.item))
      end
    end
  end
  return lines
end

function NebbieDash.csvEscapeField(value)
  local s = tostring(value == nil and "" or value)
  if s:find('[,"\r\n]', 1) then
    return '"' .. s:gsub('"', '""') .. '"'
  end
  return s
end

function NebbieDash.identExportCsvPath(charName)
  local safe = (charName or "unknown"):gsub("[^%w%-_]", "_")
  if safe == "" then safe = "unknown" end
  local stamp = os.date("%d-%m-%Y-%H-%M-%S")
  return NebbieDash.configPath(safe .. "-" .. stamp .. ".csv")
end

function NebbieDash.formatIdentEntryCsvRow(entry)
  local affects = table.concat(entry.affects or {}, " | ")
  local poss = entry.possession or {}
  return {
    entry.key or "",
    entry.objectName or "",
    entry.objectType or "",
    entry.flags or "",
    entry.vnumOriginario or "",
    entry.weight ~= nil and tostring(entry.weight) or "",
    entry.value ~= nil and tostring(entry.value) or "",
    entry.rent ~= nil and tostring(entry.rent) or "",
    entry.rare and "1" or "0",
    entry.acApply ~= nil and tostring(entry.acApply) or "",
    entry.damageDice or "",
    entry.damageType or "",
    affects,
    entry.cedibile and "1" or "0",
    entry.cedibileManual and "1" or "0",
    entry.lastCharacter or "",
    entry.lastSource or "",
    entry.lastAt and os.date("%Y-%m-%d %H:%M:%S", entry.lastAt) or "",
    poss.status or "",
    poss.character or "",
    poss.via or "",
  }
end

NebbieDash.IDENT_CSV_HEADER = {
  "key", "objectName", "objectType", "flags", "vnumOriginario",
  "weight", "value", "rent", "rare", "acApply", "damageDice", "damageType",
  "affects", "cedibile", "cedibileManual",
  "lastCharacter", "lastSource", "lastAt",
  "possessionStatus", "possessionCharacter", "possessionVia",
}

function NebbieDash.cmdIdentDbSetCedibile(query, cedibile)
  query = (query or ""):match("^%s*(.-)%s*$") or ""
  if query == "" then
    cecho("<orange>[NebbieDash] Uso: <yellow>nidentdb "
      .. (cedibile and "cedibile" or "noncedibile") .. " <oggetto>\n")
    return
  end
  local results = NebbieDash.searchIdentDb(query)
  if not results or #results == 0 then
    local entry = select(1, NebbieDash.matchIdentEntryByItemText(query))
    if entry then results = { entry } end
  end
  if not results or #results == 0 then
    cecho("<orange>[NebbieDash] Nessun identify per <white>" .. query .. "\n")
    return
  end
  if #results > 1 then
    cecho("<orange>[NebbieDash] Query ambigua (" .. tostring(#results)
      .. " entry). Specifica meglio il nome.\n")
    for i, entry in ipairs(results) do
      if i > 8 then break end
      cecho(string.format("  <grey>%s<white> %s\n",
        entry.key or "?", entry.objectName or "?"))
    end
    return
  end
  local entry = results[1]
  NebbieDash.setIdentCedibile(entry, cedibile, true)
  cecho(string.format(
    "<green>[NebbieDash] Ident: <white>%s<green> ora %s.\n",
    entry.objectName or entry.key or "?",
    cedibile and "cedibile (give/drop tracciati)" or "non cedibile"))
end

function NebbieDash.exportIdentDbCsvForCharacter(charName)
  charName = (charName or ""):match("^%s*(.-)%s*$") or ""
  if charName == "" then
    cecho("<orange>[NebbieDash] Uso: <yellow>nidentdb export <NomePg>\n")
    return nil
  end
  local results = NebbieDash.listIdentDbByCharacter(charName)
  if not results or #results == 0 then
    cecho("<orange>[NebbieDash] Nessun identify in archivio per PG <white>" .. charName .. "\n")
    return nil
  end
  NebbieDash.ensureConfigDir()
  local path = NebbieDash.identExportCsvPath(charName)
  local f, err = io.open(path, "w")
  if not f then
    cecho("<red>[NebbieDash] Impossibile scrivere CSV: <white>" .. tostring(err) .. "\n")
    return nil
  end
  local header = {}
  for _, col in ipairs(NebbieDash.IDENT_CSV_HEADER) do
    table.insert(header, NebbieDash.csvEscapeField(col))
  end
  f:write(table.concat(header, ",") .. "\n")
  for _, entry in ipairs(results) do
    local cols = NebbieDash.formatIdentEntryCsvRow(entry)
    local row = {}
    for _, c in ipairs(cols) do
      table.insert(row, NebbieDash.csvEscapeField(c))
    end
    f:write(table.concat(row, ",") .. "\n")
  end
  f:close()
  cecho(string.format(
    "<green>[NebbieDash] Export identify: <white>%d<green> righe → <yellow>%s\n",
    #results, path))
  return path
end

function NebbieDash.cmdIdentDb(argStr)
  argStr = (argStr or ""):match("^%s*(.-)%s*$") or ""
  local mode, rest = argStr:match("^(%S+)%s+(.-)%s*$")
  if not mode then
    mode, rest = argStr, ""
  end
  mode = (mode or ""):lower()

  if argStr == "" or mode == "help" or mode == "?" then
    cecho("<green>[NebbieDash] Archivio identify: <white>" ..
      tostring(NebbieDash.identDbEntryCount()) ..
      "<green> oggetti in <white>" .. NebbieDash.identDbPath() .. "\n")
    cecho("<grey>Uso: <yellow>nidentdb <query><grey> | <yellow>nidentdb where <query><grey> | <yellow>nidentdb char <nome>\n")
    cecho("<grey>     <yellow>nidentdb hold <NomePg><grey> | <yellow>nidentdb hold <oggetto> <NomePg>\n")
    cecho("<grey>     <yellow>nidentdb cedibile <oggetto><grey> | <yellow>nidentdb noncedibile <oggetto>\n")
    cecho("<grey>     <yellow>nidentdb del <oggetto><grey> | <yellow>nidentdb ui<grey> (= nidentui)\n")
    cecho("<grey>     <yellow>nidentdb export <NomePg><grey> | <yellow>nidentdbreload\n")
    cecho("<grey>Give/drop aggiornano solo oggetti <white>cedibili<grey> (auto con PROCAREA-REWARD).\n")
    cecho("<grey>Stesso nome + stesse stats/affects = aggiorna; stats diverse = nuova entry #2/#3…\n")
    return
  end

  if mode == "ui" or mode == "gui" or mode == "window" then
    NebbieDash.cmdIdentUi(rest)
    return
  end

  if mode == "del" or mode == "delete" or mode == "rm" then
    NebbieDash.cmdIdentUi("del " .. (rest or ""))
    return
  end

  if mode == "hold" then
    -- "hold Sirio" (drop pendente) oppure "hold mantello Sirio" (oggetto + PG).
    local objPart, charPart = rest:match("^(.+)%s+(%S+)$")
    if objPart and charPart and objPart:match("%S") then
      NebbieDash.cmdIdentDbHoldExplicit(objPart, charPart)
    else
      NebbieDash.cmdIdentDbHold(rest)
    end
    return
  end

  if mode == "cedibile" then
    NebbieDash.cmdIdentDbSetCedibile(rest, true)
    return
  end
  if mode == "noncedibile" then
    NebbieDash.cmdIdentDbSetCedibile(rest, false)
    return
  end

  if mode == "export" then
    NebbieDash.exportIdentDbCsvForCharacter(rest)
    return
  end

  local results
  local withHolders = false
  if mode == "where" then
    withHolders = true
    results = NebbieDash.searchIdentDb(rest)
  elseif mode == "char" then
    results = NebbieDash.listIdentDbByCharacter(rest)
  else
    results = NebbieDash.searchIdentDb(argStr)
  end

  if not results or #results == 0 then
    cecho("<orange>[NebbieDash] Nessun identify in archivio per <white>" .. argStr .. "\n")
    return
  end
  local limit = 25
  cecho("<green>[NebbieDash] " .. tostring(#results) .. " identify"
    .. (#results > limit and (" (mostro i primi " .. limit .. ")") or "")
    .. ":\n")
  for i, entry in ipairs(results) do
    if i > limit then break end
    for _, lineTxt in ipairs(NebbieDash.formatIdentDbEntry(entry, withHolders or mode == "where")) do
      cecho(lineTxt .. "\n")
    end
  end
end

function NebbieDash.cmdReloadIdentDb()
  NebbieDash.loadIdentDb()
  cecho("<green>[NebbieDash] Ident DB ricaricato: <white>" ..
    tostring(NebbieDash.identDbEntryCount()) ..
    "<green> oggetti (<white>" .. NebbieDash.identDbPath() .. "<green>).\n")
end

-- ---------------------------------------------------------------------------
-- Archivio know monster (condiviso profiles/ndashboard) — stesso schema di
-- nidentdb. Cattura il blocco di cast 'know monster' (format string da
-- spell_know_monster in magic3.cpp). Numeri GetApprox: noisy, si aggiornano
-- a ogni cast. Colori/aggiunte testo stile dadomud: criteri in seguito.
-- ---------------------------------------------------------------------------
NebbieDash.KNOW_DB_SAVE_DELAY = 0.2
NebbieDash.KNOW_CAPTURE_TIMEOUT = 3
NebbieDash.KNOW_SOURCE_HINT_TTL = 8

function NebbieDash.knowDbPath()
  return NebbieDash.configPath("nebbie-know-db.lua")
end

function NebbieDash.loadKnowDb()
  NebbieDash.ensureConfigDir()
  NebbieDash.knowDb = NebbieDash.knowDb or { entries = {} }
  NebbieDash.knowDb.entries = NebbieDash.knowDb.entries or {}
  local path = NebbieDash.knowDbPath()
  if type(io.exists) == "function" and io.exists(path) then
    local loaded = {}
    local ok = pcall(function() table.load(path, loaded) end)
    if ok and type(loaded.entries) == "table" then
      NebbieDash.knowDb = loaded
      NebbieDash.knowDb.entries = NebbieDash.knowDb.entries or {}
    end
  end
end

function NebbieDash.saveKnowDb()
  if not NebbieDash.persistEnabled then return end
  NebbieDash.ensureConfigDir()
  NebbieDash.knowDb = NebbieDash.knowDb or { entries = {} }
  pcall(function() table.save(NebbieDash.knowDbPath(), NebbieDash.knowDb) end)
end

function NebbieDash.flushKnowDbSave()
  NebbieDash._knowDbSavePending = false
  NebbieDash._knowDbSaveTimer = nil
  NebbieDash.saveKnowDb()
end

function NebbieDash.scheduleKnowDbSave()
  if NebbieDash._knowDbSavePending then return end
  NebbieDash._knowDbSavePending = true
  if type(tempTimer) == "function" then
    NebbieDash._knowDbSaveTimer = tempTimer(NebbieDash.KNOW_DB_SAVE_DELAY or 0.2, function()
      NebbieDash.flushKnowDbSave()
    end)
  else
    NebbieDash.flushKnowDbSave()
  end
end

function NebbieDash.normalizeKnowMonsterKey(name)
  return ((name or ""):lower():match("^%s*(.-)%s*$")) or ""
end

-- Spezza la lista tipi (FIRE COLD …). I token "+N" NON sono tipi: sono la
-- soglia di hitroll dell'arma (armi da +0 a +N fanno 0 danni vs quella
-- resist/immune). Restituisce bits, hitrollMax (numero N oppure nil).
function NebbieDash.splitKnowBitList(text)
  local out = {}
  local hitrollMax = nil
  for token in (text or ""):gmatch("%S+") do
    token = token:gsub("[%.%,%;%:]+$", "")
    local hr = token:match("^%+(%d+)$")
    if hr then
      local n = tonumber(hr)
      if n and (not hitrollMax or n > hitrollMax) then
        hitrollMax = n
      end
    elseif token ~= "" and not token:match("^%-%d+$") then
      table.insert(out, token)
    end
  end
  return out, hitrollMax
end

-- Se un tipo è sia immune sia resistente, vince immune: resta solo in immune.
function NebbieDash.filterKnowResistantByImmune(resistant, immune)
  if not resistant or #resistant == 0 then return resistant or {} end
  if not immune or #immune == 0 then return resistant end
  local immSet = {}
  for _, t in ipairs(immune) do
    immSet[(t or ""):upper()] = true
  end
  local out = {}
  for _, t in ipairs(resistant) do
    if not immSet[(t or ""):upper()] then
      table.insert(out, t)
    end
  end
  return out
end

function NebbieDash.applyKnowImmuneWins(entry)
  if not entry then return entry end
  if entry.resistant and entry.immune then
    entry.resistant = NebbieDash.filterKnowResistantByImmune(entry.resistant, entry.immune)
  end
  return entry
end

-- Parser del blocco know monster (righe già senza colori ANSI Mudlet).
-- Livelli caster (codice, non help): razza sempre; exp>5; livello>10; hate>15;
-- hits>20; susc>25; resist>30; immune>35; attacchi>40; danno>45.
function NebbieDash.parseKnowMonsterFull(lines)
  local entry = {
    monsterName = nil,
    race = nil,
    exp = nil,
    warriorLevel = nil,
    hateRace = nil,
    hateClass = nil,
    hits = nil,
    susceptible = nil,
    resistant = nil,
    immune = nil,
    hitrollResistMax = nil, -- armi +0..+N fanno 0 vs quella resist
    hitrollImmuneMax = nil, -- idem vs quella immune
    attacks = nil,
    damageDice = nil,
  }
  for _, raw in ipairs(lines or {}) do
    local text = NebbieDash.stripColors(raw or ""):match("^%s*(.-)%s*$") or ""
    if text == "" then
      -- skip
    elseif text:match("^Non e' realmente un mostro%.%s*$") then
      return nil
    else
      local name, race = text:match("^(.+) e' di razza (.+)%.%s*$")
      if name and race then
        entry.monsterName = name
        entry.race = race:match("^%s*(.-)%s*$")
      end
      local nExp, exp = text:match("^(.+) ha circa (%d+) punti esperienza%.%s*$")
      if nExp and exp then
        entry.monsterName = entry.monsterName or nExp
        entry.exp = tonumber(exp)
      end
      local nLev, lev = text:match(
        "^(.+) combatte piu' o meno come un guerriero del (%d+)%^ livello%.%s*$")
      if nLev and lev then
        entry.monsterName = entry.monsterName or nLev
        entry.warriorLevel = tonumber(lev)
      end
      local nHr, hr = text:match("^(.+) sembra odiare la razza dei (.+)%.%s*$")
      if nHr and hr then
        entry.monsterName = entry.monsterName or nHr
        entry.hateRace = hr:match("^%s*(.-)%s*$")
      end
      local nHc, hc = text:match("^(.+) sembra odiare la classe (.+)%.%s*$")
      if nHc and hc then
        entry.monsterName = entry.monsterName or nHc
        entry.hateClass = hc:match("^%s*(.-)%s*$")
      end
      local nHit, hits = text:match("^Probabilmente (.+) ha (%d+) punti vita%.%s*$")
      if nHit and hits then
        entry.monsterName = entry.monsterName or nHit
        entry.hits = tonumber(hits)
      end
      local nSus, sus = text:match("^(.+) e' suscettibile a (.+)%.%s*$")
      if nSus and sus then
        entry.monsterName = entry.monsterName or nSus
        entry.susceptible = select(1, NebbieDash.splitKnowBitList(sus))
      end
      local nRes, res = text:match("^(.+) e' resistente a (.+)%.%s*$")
      if nRes and res then
        entry.monsterName = entry.monsterName or nRes
        local bits, hrMax = NebbieDash.splitKnowBitList(res)
        entry.resistant = bits
        if hrMax ~= nil then entry.hitrollResistMax = hrMax end
      end
      local nImm, imm = text:match("^(.+) e' immune a (.+)%.%s*$")
      if nImm and imm then
        entry.monsterName = entry.monsterName or nImm
        local bits, hrMax = NebbieDash.splitKnowBitList(imm)
        entry.immune = bits
        if hrMax ~= nil then entry.hitrollImmuneMax = hrMax end
      end
      local nAtt, att = text:match("^(.+) ha circa (%d+)%.0 attacchi per turno%.%s*$")
      if nAtt and att then
        entry.monsterName = entry.monsterName or nAtt
        entry.attacks = tonumber(att)
      end
      local dA, dB = text:match(
        "^Ognuno dei quali fa circa (%d+)d(%d+) punti di danno%.%s*$")
      if dA and dB then
        entry.damageDice = tostring(dA) .. "d" .. tostring(dB)
      end
    end
  end
  if not entry.monsterName or entry.monsterName == "" then return nil end
  if not entry.race or entry.race == "" then return nil end
  return NebbieDash.applyKnowImmuneWins(entry)
end

-- Soglia hitroll effettiva (max tra resist e immune): armi +0..+N → 0 danni.
function NebbieDash.knowHitrollThreshold(entry)
  if not entry then return nil end
  local a, b = entry.hitrollResistMax, entry.hitrollImmuneMax
  if a and b then return math.max(a, b) end
  return a or b
end

-- Tag corto da appendere al look in stanza (solo info critiche).
function NebbieDash.formatKnowRoomTag(entry)
  if not entry then return nil end
  local resistant = NebbieDash.filterKnowResistantByImmune(entry.resistant, entry.immune)
  local parts = {}
  if entry.warriorLevel ~= nil then
    table.insert(parts, "L" .. tostring(entry.warriorLevel))
  end
  if entry.susceptible and #entry.susceptible > 0 then
    table.insert(parts, "SUSC:" .. table.concat(entry.susceptible, ","))
  end
  if entry.immune and #entry.immune > 0 then
    table.insert(parts, "IMM:" .. table.concat(entry.immune, ","))
  end
  if resistant and #resistant > 0 then
    table.insert(parts, "RESI:" .. table.concat(resistant, ","))
  end
  local hr = NebbieDash.knowHitrollThreshold(entry)
  if hr ~= nil then
    -- Serve arma con hitroll > N (es. +4 → serve +5).
    table.insert(parts, "HR>+" .. tostring(hr))
  end
  if #parts == 0 then return nil end
  return " [" .. table.concat(parts, " | ") .. "]"
end

function NebbieDash.normalizeKnowNameForMatch(name)
  name = (name or ""):lower():match("^%s*(.-)%s*$") or ""
  name = name:gsub("^l'", ""):gsub("^un'", "")
  name = name:gsub("^il%s+", ""):gsub("^la%s+", ""):gsub("^lo%s+", "")
  name = name:gsub("^un%s+", ""):gsub("^una%s+", ""):gsub("^uno%s+", "")
  name = name:gsub("^gli%s+", ""):gsub("^le%s+", ""):gsub("^i%s+", "")
  return name:match("^%s*(.-)%s*$") or ""
end

-- Trova la migliore entry know per una riga di presenza in stanza.
function NebbieDash.findKnowEntryForRoomLine(text)
  text = NebbieDash.stripColors(text or ""):lower()
  if text == "" then return nil end
  local best, bestScore = nil, 0
  for _, entry in pairs((NebbieDash.knowDb and NebbieDash.knowDb.entries) or {}) do
    local name = entry.monsterName or ""
    local nameLow = name:lower()
    local score = 0
    if nameLow ~= "" and text:find(nameLow, 1, true) then
      score = 100 + #nameLow
    else
      local bare = NebbieDash.normalizeKnowNameForMatch(name)
      if bare ~= "" and #bare >= 4 and text:find(bare, 1, true) then
        score = 50 + #bare
      end
    end
    if score > bestScore then
      best, bestScore = entry, score
    end
  end
  if bestScore < 50 then return nil end
  return best
end

function NebbieDash.onKnowRoomPresenceLine()
  local text = line or (type(getCurrentLine) == "function" and getCurrentLine()) or ""
  text = NebbieDash.stripColors(text or "")
  -- Solo righe di presenza in stanza (look / entrata).
  if not (text:find(" e' qui", 1, true)
      or text:find(" sono qui", 1, true)
      or text:find(" vola qui", 1, true)
      or text:find(" giace qui", 1, true)
      or text:find(" sta dormendo qui", 1, true)
      or text:find(" sta riposando qui", 1, true)
      or text:find(" sta galleggiando qui", 1, true)) then
    return
  end
  local entry = NebbieDash.findKnowEntryForRoomLine(text)
  if not entry then return end
  local tag = NebbieDash.formatKnowRoomTag(entry)
  if not tag then return end
  if type(decho) == "function" then
    decho("<255,200,0>" .. tag)
  elseif type(cecho) == "function" then
    cecho("<yellow>" .. tag)
  end
end

function NebbieDash.upsertKnowRecord(parsed, character, source)
  if not parsed or not parsed.monsterName then return nil end
  local key = NebbieDash.normalizeKnowMonsterKey(parsed.monsterName)
  if key == "" then return nil end
  NebbieDash.knowDb = NebbieDash.knowDb or { entries = {} }
  NebbieDash.knowDb.entries = NebbieDash.knowDb.entries or {}
  local now = os.time()
  local existing = NebbieDash.knowDb.entries[key] or {}
  existing.key = key
  existing.monsterName = parsed.monsterName
  existing.race = parsed.race
  -- Merge: aggiorna i campi presenti; conserva quelli noti da cast di livello
  -- più alto se il cast corrente non li ha rivelati.
  if parsed.exp ~= nil then existing.exp = parsed.exp end
  if parsed.warriorLevel ~= nil then existing.warriorLevel = parsed.warriorLevel end
  if parsed.hateRace ~= nil then existing.hateRace = parsed.hateRace end
  if parsed.hateClass ~= nil then existing.hateClass = parsed.hateClass end
  if parsed.hits ~= nil then existing.hits = parsed.hits end
  if parsed.susceptible ~= nil then existing.susceptible = parsed.susceptible end
  if parsed.resistant ~= nil then existing.resistant = parsed.resistant end
  if parsed.immune ~= nil then existing.immune = parsed.immune end
  if parsed.hitrollResistMax ~= nil then
    existing.hitrollResistMax = math.max(existing.hitrollResistMax or 0, parsed.hitrollResistMax)
  end
  if parsed.hitrollImmuneMax ~= nil then
    existing.hitrollImmuneMax = math.max(existing.hitrollImmuneMax or 0, parsed.hitrollImmuneMax)
  end
  if parsed.attacks ~= nil then existing.attacks = parsed.attacks end
  if parsed.damageDice ~= nil then existing.damageDice = parsed.damageDice end
  NebbieDash.applyKnowImmuneWins(existing)
  existing.lastAt = now
  existing.lastCharacter = character or existing.lastCharacter or "unknown"
  existing.lastSource = source or existing.lastSource
  existing.byCharacter = existing.byCharacter or {}
  local who = character or "unknown"
  existing.byCharacter[who] = {
    at = now,
    source = source or (existing.byCharacter[who] and existing.byCharacter[who].source),
  }
  NebbieDash.knowDb.entries[key] = existing
  NebbieDash.scheduleKnowDbSave()
  return existing
end

function NebbieDash.noteKnowSourceHint(source)
  if not source or source == "" then return end
  NebbieDash._knowSourceHint = { source = source, at = os.time() }
end

function NebbieDash.consumeKnowSourceHint()
  local hint = NebbieDash._knowSourceHint
  NebbieDash._knowSourceHint = nil
  if not hint or not hint.at then return nil end
  if (os.time() - hint.at) > (NebbieDash.KNOW_SOURCE_HINT_TTL or 8) then
    return nil
  end
  return hint.source
end

function NebbieDash.onKnowSourceSpellLine()
  local text = line or (type(getCurrentLine) == "function" and getCurrentLine()) or ""
  text = NebbieDash.stripColors(text)
  if text:find("Pronunci le parole, 'know monster'", 1, true)
      or text:find('Pronunci le parole, "know monster"', 1, true) then
    NebbieDash.noteKnowSourceHint("spell")
  end
end

function NebbieDash.armKnowCaptureWatchdog(gen)
  if type(tempTimer) ~= "function" then return end
  tempTimer(NebbieDash.KNOW_CAPTURE_TIMEOUT or 3, function()
    local cap = NebbieDash._knowCapture
    if not cap or NebbieDash._knowCaptureGen ~= gen then return end
    if cap.activity ~= cap.watchedActivity then
      cap.watchedActivity = cap.activity
      NebbieDash.armKnowCaptureWatchdog(gen)
    else
      NebbieDash.finishKnowArchiveCapture()
    end
  end)
end

function NebbieDash.startKnowMonsterCapture()
  if NebbieDash._knowCapture then
    NebbieDash.finishKnowArchiveCapture()
  end
  NebbieDash._knowCaptureGen = (NebbieDash._knowCaptureGen or 0) + 1
  local gen = NebbieDash._knowCaptureGen
  NebbieDash._knowCapture = {
    lines = {},
    character = NebbieDash.currentChar or "unknown",
    source = NebbieDash.consumeKnowSourceHint(),
    activity = 0,
    watchedActivity = 0,
    startedAt = os.time(),
  }
  if NebbieDash._knowLineTrig then
    pcall(enableTrigger, NebbieDash._knowLineTrig)
  end
  NebbieDash.armKnowCaptureWatchdog(gen)
end

-- Prima riga utile del blocco: "<Nome> e' di razza <Razza>."
function NebbieDash.onKnowMonsterRaceLine()
  local text = line or (type(getCurrentLine) == "function" and getCurrentLine()) or ""
  text = NebbieDash.stripColors(text or "")
  local trimmed = text:match("^%s*(.-)%s*$") or ""
  if not trimmed:match("e' di razza ") then return end
  NebbieDash.startKnowMonsterCapture()
  local cap = NebbieDash._knowCapture
  if not cap then return end
  table.insert(cap.lines, trimmed)
  cap.activity = (cap.activity or 0) + 1
end

function NebbieDash.onKnowArchiveLine()
  local cap = NebbieDash._knowCapture
  if not cap then
    if NebbieDash._knowLineTrig then pcall(disableTrigger, NebbieDash._knowLineTrig) end
    return
  end
  local text = line or (type(getCurrentLine) == "function" and getCurrentLine()) or ""
  text = NebbieDash.stripColors(text or "")
  local trimmed = text:match("^%s*(.-)%s*$") or ""
  if NebbieDash.isAnyPromptLine(trimmed) then
    NebbieDash.finishKnowArchiveCapture()
    return
  end
  -- Evita di duplicare la riga razza già inserita dallo start handler.
  if #cap.lines == 1 and trimmed == cap.lines[1] then
    return
  end
  if trimmed ~= "" then
    table.insert(cap.lines, trimmed)
    cap.activity = (cap.activity or 0) + 1
  end
end

function NebbieDash.echoKnowMonsterSummary(entry)
  if not entry then return end
  local name = entry.monsterName or "?"
  if entry.warriorLevel ~= nil then
    cecho(string.format(
      "<yellow>[Know]<white> %s <grey>— livello ~<yellow>%d\n",
      name, entry.warriorLevel))
  else
    cecho(string.format("<yellow>[Know]<white> %s\n", name))
  end
  if entry.susceptible and #entry.susceptible > 0 then
    cecho("<yellow>[Know] <red>SUSCETTIBILE:<yellow> "
      .. table.concat(entry.susceptible, " ") .. "\n")
  end
  if entry.immune and #entry.immune > 0 then
    cecho("<yellow>[Know] <cyan>IMMUNE:<white> "
      .. table.concat(entry.immune, " ") .. "\n")
  end
  if entry.resistant and #entry.resistant > 0 then
    cecho("<yellow>[Know] <green>RESISTENTE:<white> "
      .. table.concat(entry.resistant, " ")
      .. " <grey>(esclusi tipi già immune)\n")
  end
  local hr = NebbieDash.knowHitrollThreshold(entry)
  if hr ~= nil then
    cecho(string.format(
      "<yellow>[Know] <orange>HITROLL:<white> armi +0..+%d → 0 danni; serve arma +%d o superiore.\n",
      hr, hr + 1))
  end
end

-- Evidenziazioni live sulle righe del cast know monster (text_highlights).
function NebbieDash.onKnowHighlightLevelLine()
  if NebbieDash.textHighlights == false then return end
  local text = line or (type(getCurrentLine) == "function" and getCurrentLine()) or ""
  text = NebbieDash.stripColors(text)
  local lev = text:match("guerriero del (%d+)%^")
  if not lev then return end
  -- Solo "51^" (livello), non tutta la riga.
  NebbieDash.hlColorSpan(lev .. "^", 255, 255, 0, 0, 0, 128)
end

function NebbieDash.onKnowHighlightSusceptibleLine()
  if NebbieDash.textHighlights == false then return end
  local text = line or (type(getCurrentLine) == "function" and getCurrentLine()) or ""
  text = NebbieDash.stripColors(text)
  local span = text:match("(e' suscettibile a .+)$")
  if not span then return end
  -- Molto evidente: giallo su rosso.
  NebbieDash.hlColorSpan(span, 255, 255, 0, 180, 0, 0)
end

function NebbieDash.onKnowHighlightResistantLine()
  if NebbieDash.textHighlights == false then return end
  local text = line or (type(getCurrentLine) == "function" and getCurrentLine()) or ""
  text = NebbieDash.stripColors(text)
  local span = text:match("(e' resistente a .+)$")
  if not span then return end
  NebbieDash.hlColorSpan(span, 200, 255, 200, 0, 80, 0)
end

function NebbieDash.onKnowHighlightImmuneLine()
  if NebbieDash.textHighlights == false then return end
  local text = line or (type(getCurrentLine) == "function" and getCurrentLine()) or ""
  text = NebbieDash.stripColors(text)
  local span = text:match("(e' immune a .+)$")
  if not span then return end
  NebbieDash.hlColorSpan(span, 255, 255, 255, 0, 60, 160)
end

function NebbieDash.finishKnowArchiveCapture()
  local cap = NebbieDash._knowCapture
  NebbieDash._knowCapture = nil
  if NebbieDash._knowLineTrig then
    pcall(disableTrigger, NebbieDash._knowLineTrig)
  end
  if not cap then return end
  local parsed = NebbieDash.parseKnowMonsterFull(cap.lines)
  if not parsed then return end
  NebbieDash.upsertKnowRecord(parsed, cap.character, cap.source)
  NebbieDash.echoKnowMonsterSummary(parsed)
end

function NebbieDash.knowDbEntryCount()
  local n = 0
  for _ in pairs((NebbieDash.knowDb and NebbieDash.knowDb.entries) or {}) do
    n = n + 1
  end
  return n
end

function NebbieDash.searchKnowDb(query)
  query = (query or ""):lower():match("^%s*(.-)%s*$") or ""
  local results = {}
  for _, entry in pairs((NebbieDash.knowDb and NebbieDash.knowDb.entries) or {}) do
    if query == "" then
      table.insert(results, entry)
    else
      local hay = table.concat({
        entry.monsterName or "",
        entry.race or "",
        entry.hateRace or "",
        entry.hateClass or "",
        table.concat(entry.susceptible or {}, " "),
        table.concat(entry.resistant or {}, " "),
        table.concat(entry.immune or {}, " "),
        entry.damageDice or "",
        entry.lastCharacter or "",
      }, " "):lower()
      if hay:find(query, 1, true) then
        table.insert(results, entry)
      end
    end
  end
  table.sort(results, function(a, b)
    return (a.monsterName or "") < (b.monsterName or "")
  end)
  return results
end

function NebbieDash.listKnowDbByRace(raceQuery)
  raceQuery = (raceQuery or ""):lower():match("^%s*(.-)%s*$") or ""
  local results = {}
  for _, entry in pairs((NebbieDash.knowDb and NebbieDash.knowDb.entries) or {}) do
    local race = (entry.race or ""):lower()
    if raceQuery == "" or race == raceQuery or race:find(raceQuery, 1, true) then
      table.insert(results, entry)
    end
  end
  table.sort(results, function(a, b)
    return (a.monsterName or "") < (b.monsterName or "")
  end)
  return results
end

function NebbieDash.formatKnowDbEntry(entry)
  if not entry then return {} end
  local resistant = NebbieDash.filterKnowResistantByImmune(entry.resistant, entry.immune)
  local lines = {}
  table.insert(lines, string.format("<yellow>%s<white> — razza <cyan>%s",
    entry.monsterName or "?", entry.race or "?"))
  if entry.warriorLevel ~= nil then
    table.insert(lines, string.format("  <yellow>livello ~%d", entry.warriorLevel))
  end
  local stats = {}
  if entry.exp ~= nil then table.insert(stats, "exp~" .. tostring(entry.exp)) end
  if entry.hits ~= nil then table.insert(stats, "hp~" .. tostring(entry.hits)) end
  if entry.attacks ~= nil then table.insert(stats, "att " .. tostring(entry.attacks)) end
  if entry.damageDice then table.insert(stats, "dmg " .. entry.damageDice) end
  if #stats > 0 then
    table.insert(lines, "  <grey>approx:<white> " .. table.concat(stats, ", "))
  end
  if entry.hateRace and entry.hateRace ~= "" then
    table.insert(lines, "  <grey>odia razza:<white> " .. entry.hateRace)
  end
  if entry.hateClass and entry.hateClass ~= "" then
    table.insert(lines, "  <grey>odia classe:<white> " .. entry.hateClass)
  end
  if entry.susceptible and #entry.susceptible > 0 then
    table.insert(lines, "  <red>SUSCETTIBILE:<yellow> "
      .. table.concat(entry.susceptible, " "))
  end
  if entry.immune and #entry.immune > 0 then
    table.insert(lines, "  <cyan>IMMUNE:<white> " .. table.concat(entry.immune, " "))
  end
  if resistant and #resistant > 0 then
    table.insert(lines, "  <green>RESISTENTE:<white> " .. table.concat(resistant, " "))
  end
  local hr = NebbieDash.knowHitrollThreshold(entry)
  if hr ~= nil then
    table.insert(lines, string.format(
      "  <orange>HITROLL:<white> +0..+%d inutili; serve arma +%d+",
      hr, hr + 1))
  end
  local when = entry.lastAt and os.date("%Y-%m-%d %H:%M", entry.lastAt) or "?"
  local src = entry.lastSource and (" (" .. entry.lastSource .. ")") or ""
  table.insert(lines, string.format(
    "  <grey>ultimo know:<white> %s%s <grey>@ %s",
    tostring(entry.lastCharacter or "?"), src, when))
  return lines
end

function NebbieDash.cmdKnowDb(argStr)
  argStr = (argStr or ""):match("^%s*(.-)%s*$") or ""
  local mode, rest = argStr:match("^(%S+)%s+(.-)%s*$")
  if not mode then
    mode, rest = argStr, ""
  end
  mode = (mode or ""):lower()

  if argStr == "" or mode == "help" or mode == "?" then
    cecho("<green>[NebbieDash] Archivio know monster: <white>" ..
      tostring(NebbieDash.knowDbEntryCount()) ..
      "<green> mostri in <white>" .. NebbieDash.knowDbPath() .. "\n")
    cecho("<grey>Uso: <yellow>nknowdb <query><grey> | <yellow>nknowdb race <razza><grey> | <yellow>nknowdbreload\n")
    cecho("<grey>Si aggiorna automaticamente a ogni cast 'know monster' riuscito (NPC).\n")
    return
  end

  local results
  if mode == "race" then
    results = NebbieDash.listKnowDbByRace(rest)
  else
    results = NebbieDash.searchKnowDb(argStr)
  end

  if not results or #results == 0 then
    cecho("<orange>[NebbieDash] Nessun know monster in archivio per <white>" .. argStr .. "\n")
    return
  end
  local limit = 40
  cecho("<green>[NebbieDash] Know monster: <white>" .. tostring(#results) ..
    ( #results > limit and (" (mostra primi " .. limit .. ")") or "" ) .. "\n")
  for i, entry in ipairs(results) do
    if i > limit then break end
    for _, lineTxt in ipairs(NebbieDash.formatKnowDbEntry(entry)) do
      cecho(lineTxt .. "\n")
    end
  end
end

function NebbieDash.cmdReloadKnowDb()
  NebbieDash.loadKnowDb()
  cecho("<green>[NebbieDash] Know DB ricaricato: <white>" ..
    tostring(NebbieDash.knowDbEntryCount()) ..
    "<green> mostri (<white>" .. NebbieDash.knowDbPath() .. "<green>).\n")
end

-- ---------------------------------------------------------------------------
-- Evidenziazioni testo (portate da dadomud): gemme/metalli + allarmi combat/dig.
-- Solo colore / testo aggiuntivo / suono opzionale — nessuna automazione dig.
-- Preferenza: text_highlights = on|off. Suoni: nebbie-dash-sounds.txt
-- ---------------------------------------------------------------------------
NebbieDash.textHighlights = true

-- Liste da AutoColor_Gemme / AutoColor_Metalli (dadomud).
NebbieDash.AUTO_COLOR_GEMS = {
  { pattern = "Una pietra di rubino",       r = 255, g = 45,  b = 85,  descrizione = "WP: Burn Hands | EQ: Resi Fire" },
  { pattern = "Una pietra di zaffiro",      r = 46,  g = 95,  b = 255, descrizione = "WP: Chill | EQ: Resi cold" },
  { pattern = "Una pietra di ametista",     r = 178, g = 102, b = 255, descrizione = "WP: Magic Miss | EQ: Resi Energy" },
  { pattern = "Una pietra di granato",      r = 192, g = 41,  b = 60,  descrizione = "WP: +1 Hit&Dam | EQ: AC -10" },
  { pattern = "Una pietra di smeraldo",     r = 46,  g = 204, b = 113, descrizione = "WP: Acid | EQ: Resi Acid" },
  { pattern = "Una pietra d'opale",         r = 232, g = 232, b = 245, descrizione = "Scrying (x2)" },
  { pattern = "Una pietra di topazio",      r = 255, g = 179, b = 0,   descrizione = "WP: Shock. Grasp | EQ: Resi Elec" },
  { pattern = "Una pietra di diamante",     r = 255, g = 255, b = 255, descrizione = "Artifact" },
  { pattern = "Una pietra di agata",        r = 210, g = 105, b = 30,  descrizione = "WP: Poison | EQ: Immu Poison" },
  { pattern = "Una pietra di lapislazzuli", r = 76,  g = 111, b = 255, descrizione = "+5 Mana Reg" },
  { pattern = "Una pietra di spinello blu", r = 76,  g = 111, b = 255, descrizione = "-2 SF" },
}

NebbieDash.AUTO_COLOR_METALS = {
  { pattern = "Una pepita di rame",      r = 200, g = 113, b = 55  },
  { pattern = "Una pepita di stagno",    r = 191, g = 196, b = 201 },
  { pattern = "Una pepita di mithril",   r = 174, g = 238, b = 238 },
  { pattern = "Una pepita di platino",   r = 229, g = 228, b = 226 },
  { pattern = "Una pepita d'adamantite", r = 138, g = 43,  b = 226 },
  { pattern = "Una pepita d'oro",        r = 255, g = 215, b = 0   },
  { pattern = "Una pepita di piombo",    r = 92,  g = 98,  b = 112 },
  { pattern = "Del minerale ferroso",    r = 183, g = 65,  b = 14  },
  { pattern = "Una pietra di carbone",   r = 110, g = 110, b = 110 },
}

function NebbieDash.soundsPath()
  return NebbieDash.configPath("nebbie-dash-sounds.txt")
end

function NebbieDash.ensureSoundsFile()
  local path = NebbieDash.soundsPath()
  if type(io.exists) == "function" and io.exists(path) then return end
  NebbieDash.ensureConfigDir()
  local f = io.open(path, "w")
  if not f then return end
  f:write(
    "# NebbieDash — percorsi suono opzionali (vuoto = silenzioso)\n" ..
    "# Dopo modifiche: npreferencesreload oppure ntriggers\n" ..
    "# Esempio Windows: C:/Users/tu/.config/mudlet/profiles/ndashboard/sounds/humber.mp3\n" ..
    "humber =\n" ..
    "dig_done =\n" ..
    "sanc_gone =\n" ..
    "aura_loss =\n"
  )
  f:close()
end

function NebbieDash.loadSoundsConfig()
  NebbieDash.migrateConfigFileIfNeeded("nebbie-dash-sounds.txt")
  NebbieDash.ensureSoundsFile()
  NebbieDash.sounds = NebbieDash.sounds or {
    humber = "",
    dig_done = "",
    sanc_gone = "",
    aura_loss = "",
  }
  local path = NebbieDash.soundsPath()
  if type(io.exists) ~= "function" or not io.exists(path) then return end
  local f = io.open(path, "r")
  if not f then return end
  for line in f:lines() do
    local key, val = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
    if key and not key:match("^#") then
      val = (val or ""):gsub("%s*#.*$", ""):match("^%s*(.-)%s*$") or ""
      if NebbieDash.sounds[key] ~= nil then
        NebbieDash.sounds[key] = val
      end
    end
  end
  f:close()
end

function NebbieDash.playHighlightSound(key)
  local path = NebbieDash.sounds and NebbieDash.sounds[key]
  if not path or path == "" then return end
  if type(io.exists) == "function" and not io.exists(path) then return end
  if type(playSoundFile) == "function" then
    pcall(playSoundFile, path)
  end
end

function NebbieDash.hlColorSpan(text, r, g, b, br, bg, bb)
  if type(selectString) ~= "function" or not text or text == "" then return end
  selectString(text, 1)
  if type(setFgColor) == "function" then setFgColor(r, g, b) end
  if br and type(setBgColor) == "function" then setBgColor(br, bg, bb) end
  if type(resetFormat) == "function" then resetFormat() end
end

function NebbieDash.hlColorWholeLine(r, g, b, br, bg, bb)
  local text = line or (type(getCurrentLine) == "function" and getCurrentLine()) or ""
  text = NebbieDash.stripColors(text)
  if text == "" then return end
  NebbieDash.hlColorSpan(text, r, g, b, br, bg, bb)
end

function NebbieDash.onAutoColorGem(pattern, r, g, b, descrizione)
  if NebbieDash.textHighlights == false then return end
  local text = line or (type(getCurrentLine) == "function" and getCurrentLine()) or ""
  local needle = pattern
  if type(selectString) == "function" then
    local ok = selectString(needle, 1)
    if ok == false or ok == 0 then
      -- fallback: prova a colorare comunque la riga se contiene il pattern
      if not text:find(needle, 1, true) then return end
      selectString(needle, 1)
    end
    if type(setFgColor) == "function" then setFgColor(r, g, b) end
    if type(resetFormat) == "function" then resetFormat() end
  end
  if descrizione and descrizione ~= "" and type(decho) == "function" then
    decho("<128,128,128> [" .. descrizione .. "]")
  end
end

function NebbieDash.onAutoColorMetal(pattern, r, g, b)
  if NebbieDash.textHighlights == false then return end
  if type(selectString) == "function" then
    selectString(pattern, 1)
    if type(setFgColor) == "function" then setFgColor(r, g, b) end
    if type(resetFormat) == "function" then resetFormat() end
  end
end

function NebbieDash.onHighlightPerditaAura()
  if NebbieDash.textHighlights == false then return end
  local text = line or (type(getCurrentLine) == "function" and getCurrentLine()) or ""
  text = NebbieDash.stripColors(text)
  local nome = text:match("^L'aura bianca che avvolgeva il corpo di (.+) si spegne%.%s*$")
  if not nome then return end
  NebbieDash.hlColorSpan(text, 255, 255, 0)
  NebbieDash.hlColorSpan(nome, 255, 0, 0, 255, 255, 0)
  if type(echo) == "function" then
    echo("\n")
    if type(setFgColor) == "function" then setFgColor(255, 0, 0) end
    if type(setBgColor) == "function" then setBgColor(255, 255, 0) end
    echo("RESANK " .. nome .. "\n")
    if type(resetFormat) == "function" then resetFormat() end
  end
  NebbieDash.playHighlightSound("aura_loss")
end

function NebbieDash.onHighlightPerditaAuraDispel()
  if NebbieDash.textHighlights == false then return end
  local text = line or (type(getCurrentLine) == "function" and getCurrentLine()) or ""
  text = NebbieDash.stripColors(text)
  local nome = text:match("^L'aura di luce Divina che avvolge (.+) scompare%.%s*$")
  if not nome then return end
  NebbieDash.hlColorSpan(text, 255, 255, 0)
  NebbieDash.hlColorSpan(nome, 255, 0, 0, 255, 255, 0)
  if type(echo) == "function" then
    echo("\n")
    for _ = 1, 3 do
      if type(setFgColor) == "function" then setFgColor(255, 0, 0) end
      if type(setBgColor) == "function" then setBgColor(255, 255, 0) end
      echo("RESANK " .. nome .. "\n")
      if type(resetFormat) == "function" then resetFormat() end
    end
  end
  NebbieDash.playHighlightSound("aura_loss")
end

function NebbieDash.onHighlightDisarmOkAltri()
  if NebbieDash.textHighlights == false then return end
  local text = line or (type(getCurrentLine) == "function" and getCurrentLine()) or ""
  text = NebbieDash.stripColors(text)
  local nome = text:match("^Con una mossa d'arti marziali (%w+) disorienta l'avversario")
  if not nome then return end
  NebbieDash.hlColorWholeLine(0, 255, 0)
  if type(moveCursorEnd) == "function" then moveCursorEnd() end
  if type(decho) == "function" then
    decho("\n<0,150,0:255,255,255>Grande " .. nome .. "! bel disarm! <r>\n")
  end
end

function NebbieDash.onHighlightDisarmFailAltri()
  if NebbieDash.textHighlights == false then return end
  local text = line or (type(getCurrentLine) == "function" and getCurrentLine()) or ""
  text = NebbieDash.stripColors(text)
  local nome = text:match("^(%w+) tenta una elegante mossa d'arti marziali, ma finisce rovinosamente a terra%.")
  if not nome then return end
  NebbieDash.hlColorSpan(text, 255, 0, 0)
  if type(moveCursorEnd) == "function" then moveCursorEnd() end
  if type(decho) == "function" then
    for _ = 1, 3 do
      if type(moveCursorEnd) == "function" then moveCursorEnd() end
      decho("\n<255,255,0:255,0,0> Mannaggia " .. nome .. "! Rotoli come un birillo! <r>\n")
    end
  end
end

function NebbieDash.onHighlightSancWarning()
  if NebbieDash.textHighlights == false then return end
  NebbieDash.hlColorWholeLine(255, 0, 0, 255, 255, 255)
end

function NebbieDash.onHighlightSancGone()
  if NebbieDash.textHighlights == false then return end
  NebbieDash.hlColorWholeLine(255, 255, 255, 255, 0, 0)
  NebbieDash.playHighlightSound("sanc_gone")
end

function NebbieDash.onHighlightWieldSlot()
  if NebbieDash.textHighlights == false then return end
  -- Solo la stringa "<impugnato>", non il nome dell'arma a seguire.
  NebbieDash.hlColorSpan("<impugnato>", 0, 0, 255, 0, 170, 0)
end

function NebbieDash.onHighlightHumber()
  if NebbieDash.textHighlights == false then return end
  -- Stile "humber" (rosso su giallo). Stesso testo di humberin in dadomud;
  -- qui solo evidenziazione + suono, niente swap armi automatico.
  NebbieDash.hlColorWholeLine(255, 0, 0, 255, 255, 0)
  NebbieDash.playHighlightSound("humber")
end

function NebbieDash.onHighlightDigDone()
  if NebbieDash.textHighlights == false then return end
  NebbieDash.hlColorWholeLine(24, 202, 53, 255, 255, 255)
  NebbieDash.playHighlightSound("dig_done")
end

function NebbieDash.teardownTextHighlightTriggers()
  for _, id in ipairs(NebbieDash._hlTrigIds or {}) do
    if id then pcall(function() killTrigger(id) end) end
  end
  NebbieDash._hlTrigIds = {}
end

function NebbieDash.installTextHighlightTriggers()
  NebbieDash.teardownTextHighlightTriggers()
  NebbieDash._hlTrigIds = {}
  if NebbieDash.textHighlights == false then return end
  local function add(id)
    if id then table.insert(NebbieDash._hlTrigIds, id) end
  end

  for _, voce in ipairs(NebbieDash.AUTO_COLOR_GEMS) do
    local pat, r, g, b, desc = voce.pattern, voce.r, voce.g, voce.b, voce.descrizione
    add(tempTrigger(pat, string.format(
      "NebbieDash.onAutoColorGem(%q,%d,%d,%d,%q)", pat, r, g, b, desc)))
  end
  for _, voce in ipairs(NebbieDash.AUTO_COLOR_METALS) do
    local pat, r, g, b = voce.pattern, voce.r, voce.g, voce.b
    add(tempTrigger(pat, string.format(
      "NebbieDash.onAutoColorMetal(%q,%d,%d,%d)", pat, r, g, b)))
  end

  add(tempRegexTrigger(
    "^L'aura bianca che avvolgeva il corpo di (.+) si spegne\\.$",
    [[NebbieDash.onHighlightPerditaAura()]]))
  add(tempRegexTrigger(
    "^L'aura di luce Divina che avvolge (.+) scompare\\.$",
    [[NebbieDash.onHighlightPerditaAuraDispel()]]))
  add(tempRegexTrigger(
    "^Con una mossa d'arti marziali (\\w+) disorienta l'avversario",
    [[NebbieDash.onHighlightDisarmOkAltri()]]))
  add(tempRegexTrigger(
    "^(\\w+) tenta una elegante mossa d'arti marziali, ma finisce rovinosamente a terra\\.",
    [[NebbieDash.onHighlightDisarmFailAltri()]]))
  add(tempTrigger(
    "L'aura bianca che ti circonda inizia a diventare meno intensa.",
    [[NebbieDash.onHighlightSancWarning()]]))
  add(tempTrigger(
    "L'aura bianca che ti circondava svanisce.",
    [[NebbieDash.onHighlightSancGone()]]))
  add(tempTrigger("<impugnato>", [[NebbieDash.onHighlightWieldSlot()]]))
  add(tempTrigger(
    "ACCIDENTI!!! Qualcosa si muove nel punto in cui hai scavato!",
    [[NebbieDash.onHighlightHumber()]]))
  add(tempTrigger(
    "Qui non si riesce piu' a scavare, il filone sembra esaurito!",
    [[NebbieDash.onHighlightDigDone()]]))
  -- Know monster: livello / susc / resi / immune (vedi echoKnowMonsterSummary).
  add(tempTrigger("combatte piu' o meno come un guerriero del",
    [[NebbieDash.onKnowHighlightLevelLine()]]))
  add(tempTrigger("e' suscettibile a ",
    [[NebbieDash.onKnowHighlightSusceptibleLine()]]))
  add(tempTrigger("e' resistente a ",
    [[NebbieDash.onKnowHighlightResistantLine()]]))
  add(tempTrigger("e' immune a ",
    [[NebbieDash.onKnowHighlightImmuneLine()]]))
  -- Annotazioni look stanza accanto al nome mob già in archivio know.
  add(tempTrigger(" e' qui", [[NebbieDash.onKnowRoomPresenceLine()]]))
  add(tempTrigger(" sono qui", [[NebbieDash.onKnowRoomPresenceLine()]]))
  add(tempTrigger(" vola qui", [[NebbieDash.onKnowRoomPresenceLine()]]))
  add(tempTrigger(" giace qui", [[NebbieDash.onKnowRoomPresenceLine()]]))
end

function NebbieDash.resolveWeaponTargetFromArg(data, argStr)
  argStr = (argStr or ""):match("^%s*(.-)%s*$")
  argStr = argStr:gsub("^['\"]", ""):gsub("['\"]$", "")
  if argStr == "" then return nil end
  local needle = argStr:lower()
  local best, bestLen = nil, 0
  for _, w in ipairs(data.weapons or {}) do
    local kw = (w.keyword or ""):lower()
    local dn = (w.displayName or ""):lower()
    if kw == needle or dn == needle then return w end
    if kw:find(needle, 1, true) or dn:find(needle, 1, true) then
      local score = math.max(#needle, #kw)
      if score > bestLen then best, bestLen = w, score end
    end
    if NebbieDash.keywordsOverlap(kw, needle) or NebbieDash.keywordsOverlap(dn, needle) then
      if #kw > bestLen then best, bestLen = w, #kw end
    end
  end
  if best then
    best.userKeyword = argStr
    return best
  end
  return { keyword = argStr, displayName = argStr, userKeyword = argStr }
end

function NebbieDash.runWeaponSwap(target)
  local name = NebbieDash.currentChar
  if not name or not target then return false end
  if NebbieDash._weaponSwapBusy then
    cecho("<orange>[NebbieDash] Cambio arma gia' in corso.\n")
    return false
  end
  local data = NebbieDash.getCharData(name)
  NebbieDash.loadItemKeywords()
  local currentKeyword = NebbieDash.currentWieldedKeyword(data)
  local resolvedKw = NebbieDash.resolveWeaponSwapKeyword(target)
  if currentKeyword ~= "" and resolvedKw ~= "" and NebbieDash.keywordsOverlap(currentKeyword, resolvedKw) then
    cecho("<orange>[NebbieDash] Stai gia' impugnando " .. (target.displayName or resolvedKw) .. ".\n")
    return false
  end
  local steps, err = NebbieDash.buildWeaponSwapSteps(data, target)
  if not steps then
    if err == "no_backpack" then
      cecho("<orange>[NebbieDash] Nessuno zaino rilevato (slot 'sulla schiena') — esegui <yellow>neq<orange> prima.\n")
    end
    return false
  end
  local gen = NebbieDash.beginWeaponSwapGuard(data)
  NebbieDash.runCommandSequence(steps, NebbieDash.weaponSwapDelay)
  -- Timeout generoso: le risposte MUD (soprattutto rem/wear zaino) possono
  -- arrivare dopo l'ultimo send; altrimenti un rem in ritardo svuota la schiena.
  local timeout = (NebbieDash.weaponSwapDelay or 0.5) * #steps + 4.0
  tempTimer(timeout, function()
    NebbieDash.endWeaponSwapGuard(gen, true)
  end)
  return true
end

function NebbieDash.cmdUsa(argStr)
  local name = NebbieDash.currentChar
  if not name then
    cecho("<orange>[NebbieDash] Nessun personaggio rilevato — attendi il prompt o usa nchar.\n")
    return
  end
  argStr = (argStr or ""):match("^%s*(.-)%s*$")
  if argStr == "" then
    cecho("<orange>[NebbieDash] Uso: usa <parola-chiave> (es. usa redentore)\n")
    return
  end
  local data = NebbieDash.getCharData(name)
  local target = NebbieDash.resolveWeaponTargetFromArg(data, argStr)
  target.userKeyword = argStr
  NebbieDash.runWeaponSwap(target)
end

-- Legacy: indice pannello armi rimosso — usa cmdUsa con keyword.
function NebbieDash.cmdSwapWeapon(idx)
  local name = NebbieDash.currentChar
  if not name then return end
  local data = NebbieDash.getCharData(name)
  local target = data.weapons and data.weapons[idx]
  if target then NebbieDash.runWeaponSwap(target) end
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
  return NebbieDash.configPath("nebbie-hunger-macros.txt")
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

-- Parola chiave stabile per {zaino} nelle macro fame/sete (rem/get/put/wear).
function NebbieDash.macroBackpackKeywordFromPhrase(phrase, isOverride)
  if not phrase or phrase == "" then return "" end
  if isOverride then return phrase end
  local kw = NebbieDash.pickItemCommandKeyword(phrase, false, {})
  if kw and kw ~= "" then return kw end
  return NebbieDash.lastKeyword(phrase)
end

function NebbieDash.refreshHungerBackKeywordFromEq(data, force)
  if not data or not data.eqUpdated then return end
  if not force and data.hungerBackKeyword and data.hungerBackKeyword ~= "" then return end
  local phrase, isOverride = NebbieDash.findBackpackKeywords(data)
  local kw = NebbieDash.macroBackpackKeywordFromPhrase(phrase, isOverride)
  if kw ~= "" then
    data.hungerBackKeyword = kw
  end
end

function NebbieDash.resolveMacroBackpackKeyword(data)
  if not data then return "" end
  if data.hungerBackKeyword and data.hungerBackKeyword ~= "" then
    return data.hungerBackKeyword
  end
  local phrase, isOverride = NebbieDash.findBackpackKeywords(data)
  if phrase == "" then return "" end
  local kw = NebbieDash.macroBackpackKeywordFromPhrase(phrase, isOverride)
  if kw ~= "" then
    data.hungerBackKeyword = kw
    NebbieDash.saveStore()
  end
  return kw
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
  local backKw = NebbieDash.macroBackpackKeywordFromPhrase(backPhrase, backOverride)
  local wieldKw = ""
  if wieldConfirmed then
    local wieldItem = nil
    for _, row in ipairs(NebbieDash.buildEquipRows(data)) do
      if not row.empty and row.location == "impugnato" then
        wieldItem = row.item
        break
      end
    end
    if wieldItem then
      local resolved, isOv = NebbieDash.resolveItemKeywords(wieldItem)
      wieldKw = NebbieDash.macroBackpackKeywordFromPhrase(resolved, isOv)
    else
      wieldKw = NebbieDash.macroBackpackKeywordFromPhrase(wieldPhrase, false)
    end
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
  return NebbieDash.configPath("nebbie-item-keywords.txt")
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
    "# **cambio arma** (alias usa), zaino sulla schiena.\n" ..
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
  local userKw = (target.userKeyword or ""):match("^%s*(.-)%s*$")
  if userKw ~= "" then
    local ov = NebbieDash.findItemKeywordOverride(userKw)
    if ov and ov ~= "" then return ov end
    local disp = (target.displayName or ""):match("^%s*(.-)%s*$")
    if disp ~= "" and disp:lower():find(userKw:lower(), 1, true) then
      local fromDisp = select(1, NebbieDash.resolveItemKeywords(disp))
      if fromDisp ~= "" then return fromDisp end
    end
    if userKw:find("%s") then return userKw end
    return userKw
  end
  local disp = (target.displayName or target.keyword or ""):match("^%s*(.-)%s*$")
  if disp ~= "" then
    local fromDisp, isOverride = NebbieDash.resolveItemKeywords(disp)
    if fromDisp ~= "" then return fromDisp end
  end
  local idKw = (target.keyword or ""):match("^%s*(.-)%s*$")
  if idKw ~= "" then
    local fromId, isOverrideId = NebbieDash.resolveItemKeywords(idKw)
    if isOverrideId and fromId ~= "" then return fromId end
    if target.type then return idKw end
  end
  return idKw
end

function NebbieDash.runHungerMacro()
  local name = NebbieDash.currentChar
  if not name then return end
  if NebbieDash._hungerMacroBusy then
    NebbieDash._hungerMacroPending = true
    return
  end
  local macro = NebbieDash.hungerMacros[name]
  if not macro then
    cecho("<orange>[NebbieDash] Nessuna macro fame/sete configurata per " .. name ..
      " — scrivila in " .. NebbieDash.hungerMacrosPath() .. " poi digita <yellow>nhungermacros<orange>.\n")
    return
  end
  local data = NebbieDash.getCharData(name)
  local backpackKeyword = NebbieDash.resolveMacroBackpackKeyword(data)
  if backpackKeyword == "" then
    cecho("<orange>[NebbieDash] Fame/sete: slot «sulla schiena» vuoto o equip non sincronizzato — <yellow>neq<orange> poi riprova.\n")
    return
  end
  local substituted = macro:gsub("{zaino}", backpackKeyword)
  local steps = NebbieDash.expandMacroSteps(substituted)
  if #steps == 0 then return end
  NebbieDash._hungerMacroBusy = true
  NebbieDash._hungerMacroBusySince = os.time()
  local delay = NebbieDash.speedwalkDelay or 0.5
  for i, cmd in ipairs(steps) do
    tempTimer(delay * (i - 1), function() send(cmd, false) end)
  end
  tempTimer(delay * (#steps - 1) + 1.0, function()
    NebbieDash._hungerMacroBusy = false
    NebbieDash._hungerMacroBusySince = nil
    if NebbieDash._hungerMacroPending then
      NebbieDash._hungerMacroPending = false
      tempTimer(0.35, function() NebbieDash.runHungerMacro() end)
    end
  end)
end

-- Fame e sete arrivano spesso su due righe consecutive: un solo avvio macro (debounce
-- breve), non un cooldown di secondi che blocca la fame successiva nella stessa sessione.
function NebbieDash.onHungerThirstLine()
  if not NebbieDash.autoFeed then return end
  if NebbieDash._hungerDebounceTimer and type(killTimer) == "function" then
    pcall(killTimer, NebbieDash._hungerDebounceTimer)
  end
  NebbieDash._hungerDebounceTimer = tempTimer(0.1, function()
    NebbieDash._hungerDebounceTimer = nil
    NebbieDash.runHungerMacro()
  end)
end

function NebbieDash.enforceTriggerHygiene()
  -- Stesso sessione, nessun update: a volte restano attivi trigger "catch-all" (^)
  -- (eq/attrib/batch) o il lock fame bloccato — tappa il resto o sembra tutto morto.
  if not NebbieDash._eqCapture and NebbieDash._eqLineTrig then
    pcall(disableTrigger, NebbieDash._eqLineTrig)
  end
  if not NebbieDash._attribCapture and NebbieDash._attribLineTrig then
    pcall(disableTrigger, NebbieDash._attribLineTrig)
  end
  if not NebbieDash._identCapture and NebbieDash._identLineTrig then
    pcall(disableTrigger, NebbieDash._identLineTrig)
  end
  if not NebbieDash._knowCapture and NebbieDash._knowLineTrig then
    pcall(disableTrigger, NebbieDash._knowLineTrig)
  end
  if not NebbieDash._batch or not NebbieDash._batch.active then
    NebbieDash.batchDisableLineCapture()
  end
  if not NebbieDash._groupCheckActive then
    if NebbieDash._groupSoloTrig then pcall(disableTrigger, NebbieDash._groupSoloTrig) end
    if NebbieDash._groupHeaderTrig then pcall(disableTrigger, NebbieDash._groupHeaderTrig) end
  end
  if NebbieDash._eqCapture and NebbieDash._eqCaptureStartedAt then
    if os.time() - NebbieDash._eqCaptureStartedAt > 12 then
      NebbieDash.finishEqCapture()
    end
  end
  if NebbieDash._attribCapture and NebbieDash._attribCaptureStartedAt then
    if os.time() - NebbieDash._attribCaptureStartedAt > 12 then
      NebbieDash.finishAttribCapture()
    end
  end
  if NebbieDash._identCapture and NebbieDash._identCapture.startedAt then
    if os.time() - NebbieDash._identCapture.startedAt > 12 then
      NebbieDash.finishIdentArchiveCapture()
    end
  end
  if NebbieDash._knowCapture and NebbieDash._knowCapture.startedAt then
    if os.time() - NebbieDash._knowCapture.startedAt > 12 then
      NebbieDash.finishKnowArchiveCapture()
    end
  end
  if NebbieDash._hungerMacroBusy and NebbieDash._hungerMacroBusySince then
    if os.time() - NebbieDash._hungerMacroBusySince > 30 then
      NebbieDash._hungerMacroBusy = false
      NebbieDash._hungerMacroBusySince = nil
    end
  end
end

function NebbieDash.cmdReinstallTriggers()
  NebbieDash.installTriggers()
  cecho("<green>[NebbieDash] Trigger reinstallati (" .. (NebbieDash.version or "?") .. ").\n")
end

-- Mudlet non elimina i Key del package quando cambiano nome (es. 1.15.47 num/nav → 1.15.48).
-- Restano duplicati in cima all'albero Keys e sotto nebbie-complete-dashboard-package.
function NebbieDash.killKeysByName(name)
  if not name or name == "" then return 0 end
  local removed = 0
  if type(findItems) == "function" then
    local ok, ids = pcall(function() return findItems(name, "key", true) end)
    if ok and type(ids) == "table" then
      for _, id in ipairs(ids) do
        if type(disableKey) == "function" then pcall(function() disableKey(id) end) end
        if type(killKey) == "function" then pcall(function() killKey(id) end) end
        removed = removed + 1
      end
    end
  end
  if type(exists) == "function" and type(killKey) == "function" then
    local tries = 0
    while (exists(name, "key") or 0) > 0 and tries < 16 do
      pcall(function() killKey(name) end)
      tries = tries + 1
      removed = removed + 1
    end
  end
  return removed
end

function NebbieDash.purgeLegacyKeypadKeys(silent)
  local dirs = { "look", "north", "south", "east", "west", "up", "down" }
  local total = 0
  for _, d in ipairs(dirs) do
    total = total + NebbieDash.killKeysByName("nebbie-keypad " .. d .. " num")
    total = total + NebbieDash.killKeysByName("nebbie-keypad " .. d .. " nav")
  end
  if total > 0 and not silent then
    cecho("<yellow>[NebbieDash] Rimossi " .. total ..
      " tasti keypad legacy (duplicati num/nav da versioni ≤1.15.47).\n")
  end
  return total
end

function NebbieDash.cmdReinstallKeys()
  local n = NebbieDash.purgeLegacyKeypadKeys(false)
  if n == 0 then
    cecho("<grey>[NebbieDash] Nessun tasto legacy num/nav da rimuovere.\n")
  end
  cecho("<cyan>[NebbieDash] Tastierino <white>numerico<cyan> (Nebbie Keypad): 2/4/6/8 movimento, 5 look, 9/3 su/giù — <white>non<grey> le frecce della tastiera.\n")
  cecho("<grey>Num Lock <white>ON<grey>. Dopo aggiornamento: disattiva eventuali key «nav» vecchie in Mudlet → Keys.\n")
  cecho("<grey>Shortcut spell da command line (anche tasti numerici): file <white>nebbie-spell-shortcuts.txt<grey> — <yellow>nspellaliasesreload<grey>.\n")
  cecho("<grey>Reinstalla da: <white>" .. (NebbieDash.PACKAGE_UPDATE_URL or "?") .. "\n")
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
    if NebbieDash._autoLootDelayTimer and type(killTimer) == "function" then
      pcall(killTimer, NebbieDash._autoLootDelayTimer)
      NebbieDash._autoLootDelayTimer = nil
    end
  else
    cecho("<orange>[NebbieDash] Uso: nautoloot <on|off> (attuale: " ..
      ((NebbieDash.autoLoot ~= false) and "on" or "off") .. ")\n")
    return
  end
  NebbieDash.prefs = NebbieDash.prefs or {}
  NebbieDash.prefs.auto_loot = NebbieDash.autoLoot and true or false
  NebbieDash.savePreferencesFile()
  cecho("<green>[NebbieDash] Loot automatico dopo ogni combattimento: " ..
    ((NebbieDash.autoLoot ~= false) and "on" or "off") .. " <grey>(salvato).\n")
end

-- Riga di conferma loot riuscito ("C'erano N monete.").
function NebbieDash.onLootLine()
  local text = line or (type(getCurrentLine) == "function" and getCurrentLine()) or ""
  local amount = NebbieDash.parseLootCoinAmount(text)
  if not amount then return end
  -- Debounce: stesso importo entro 1.2s (doppio trigger / echo) → una sola volta.
  local now = os.clock()
  if NebbieDash._lastLootAmount == amount
      and NebbieDash._lastLootAt
      and (now - NebbieDash._lastLootAt) < 1.2 then
    return
  end
  NebbieDash._lastLootAmount = amount
  NebbieDash._lastLootAt = now
  cecho("<green>[NebbieDash] Bottino: " .. amount .. " monete.\n")
  if NebbieDash.autoSplit ~= false then
    NebbieDash.startSplitFlow(amount)
  end
end

-- Invia i due comandi di loot noti (cadavere normale + pile of bones).
function NebbieDash.cmdLoot()
  local now = os.clock()
  -- Se un flusso precedente e' rimasto appeso (>2s), sblocca.
  if NebbieDash._lootFlowActive then
    local started = NebbieDash._lootFlowStartedAt or 0
    if (now - started) < 2.0 then
      return
    end
    NebbieDash._lootFlowActive = false
  end
  NebbieDash._lootFlowActive = true
  NebbieDash._lootFlowStartedAt = now
  NebbieDash._lootFlowGen = (NebbieDash._lootFlowGen or 0) + 1
  local gen = NebbieDash._lootFlowGen
  if NebbieDash._lootPileTimer and type(killTimer) == "function" then
    pcall(killTimer, NebbieDash._lootPileTimer)
    NebbieDash._lootPileTimer = nil
  end
  send("get all.coin corp", false)
  NebbieDash._lootPileTimer = tempTimer(0.5, function()
    if NebbieDash._lootFlowGen ~= gen then return end
    NebbieDash._lootPileTimer = nil
    send("get all.coin pile", false)
  end)
  -- Safety: sblocca sempre, anche se i timer intermedi falliscono.
  tempTimer(2.2, function()
    if NebbieDash._lootFlowGen == gen then
      NebbieDash._lootFlowActive = false
    end
  end)
end

-- Memoria gruppo senza spam "group": dopo un fallimento "sei solo" non
-- riprova finche' non vediamo un segnale di gruppo reale.
function NebbieDash.onSplitSoloFailLine()
  local text = NebbieDash.stripColors(
    line or (type(getCurrentLine) == "function" and getCurrentLine()) or "")
  if not text:find("Ma cosa vuoi dividere che sei solo", 1, true) then return end
  NebbieDash._groupKnown = false
end

function NebbieDash.onSplitSuccessLine()
  local text = NebbieDash.stripColors(
    line or (type(getCurrentLine) == "function" and getCurrentLine()) or "")
  if not text:match("^Hai diviso ") then return end
  NebbieDash._groupKnown = true
end

function NebbieDash.armSplitWatchdog(gen)
  tempTimer(NebbieDash.captureTimeoutSec, function()
    if NebbieDash._groupCheckGen == gen and NebbieDash._groupCheckActive then
      NebbieDash.finishSplitFlow(false)
    end
  end)
end

-- Autosplit: split diretto; se siamo soli (_groupKnown=false) salta.
-- Dopo un errore MUD "sei solo" memorizza e non ripete a ogni cadavere.
function NebbieDash.startSplitFlow(amount)
  if not amount or amount < 1 then return end
  if NebbieDash.autoSplit == false then return end
  if NebbieDash._groupKnown == false then
    return
  end
  local now = os.clock()
  if NebbieDash._lastSplitAmount == amount
      and NebbieDash._lastSplitAt
      and (now - NebbieDash._lastSplitAt) < 1.2 then
    return
  end
  NebbieDash._lastSplitAmount = amount
  NebbieDash._lastSplitAt = now
  send("split " .. tostring(amount), false)
  cecho("<green>[NebbieDash] Split automatico: " .. amount .. " monete.\n")
end

function NebbieDash.finishSplitFlow(grouped)
  NebbieDash._groupCheckActive = false
  if NebbieDash._groupSoloTrig then pcall(disableTrigger, NebbieDash._groupSoloTrig) end
  if NebbieDash._groupHeaderTrig then pcall(disableTrigger, NebbieDash._groupHeaderTrig) end
  local amount = NebbieDash._pendingSplitAmount
  NebbieDash._pendingSplitAmount = nil
  if grouped and amount then
    NebbieDash._groupKnown = true
    send("split " .. tostring(amount), false)
    cecho("<green>[NebbieDash] Split automatico: " .. amount .. " monete.\n")
  elseif grouped == false then
    NebbieDash._groupKnown = false
  end
end

function NebbieDash.onGroupSoloLine()
  local text = line or (type(getCurrentLine) == "function" and getCurrentLine()) or ""
  if NebbieDash.isGroupSoloLine(text) then
    NebbieDash._groupKnown = false
  end
  if not NebbieDash._groupCheckActive then return end
  if not NebbieDash.isGroupSoloLine(text) then return end
  NebbieDash.finishSplitFlow(false)
end

function NebbieDash.onGroupHeaderLine()
  local text = line or (type(getCurrentLine) == "function" and getCurrentLine()) or ""
  if NebbieDash.isGroupHeaderLine(text) then
    NebbieDash._groupKnown = true
  end
  if not NebbieDash._groupCheckActive then return end
  if not NebbieDash.isGroupHeaderLine(text) then return end
  NebbieDash.finishSplitFlow(true)
end

function NebbieDash.cmdSetAutoSplit(argStr)
  argStr = (argStr or ""):match("^%s*(.-)%s*$"):lower()
  if argStr == "on" then
    NebbieDash.autoSplit = true
    NebbieDash._groupKnown = nil
  elseif argStr == "off" then
    NebbieDash.autoSplit = false
  else
    cecho("<orange>[NebbieDash] Uso: nautosplit <on|off> (attuale: " ..
      ((NebbieDash.autoSplit ~= false) and "on" or "off") .. ")\n")
    return
  end
  NebbieDash.prefs = NebbieDash.prefs or {}
  NebbieDash.prefs.auto_split = NebbieDash.autoSplit and true or false
  NebbieDash.savePreferencesFile()
  cecho("<green>[NebbieDash] Split automatico dopo loot: " ..
    ((NebbieDash.autoSplit ~= false) and "on" or "off") .. " <grey>(salvato).\n")
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
  return NebbieDash.configPath("nebbie-batch-commands.txt")
end

function NebbieDash.batchItemsPath()
  return NebbieDash.configPath("nebbie-batch-items.csv")
end

function NebbieDash.identBatchCommandsPath()
  return NebbieDash.configPath("nebbie-ident-batch-commands.txt")
end

function NebbieDash.identBatchResultsPath()
  return NebbieDash.configPath("nebbie-ident-results-" .. os.date("%Y-%m-%d") .. ".csv")
end

function NebbieDash.batchLogPath(nomeToon)
  local date = os.date("%Y-%m-%d")
  return NebbieDash.configPath((nomeToon or "unknown") .. "-" .. date .. ".txt")
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
  return NebbieDash.configPath((nomeToon or "unknown") .. "-" .. (dateStr or os.date("%Y-%m-%d")) .. ".verify.txt")
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
    local logPath = NebbieDash.batchLogPath(toon)
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
    NebbieDash._promptTrig, NebbieDash._promptImmTrig, NebbieDash._promptImmTrig2,
    NebbieDash._eqOpenTrig, NebbieDash._attribOpenTrig,
    NebbieDash._eqLineTrig, NebbieDash._attribLineTrig, NebbieDash._lootLineTrig,
    NebbieDash._lootLineTrig2, NebbieDash._groupSoloTrig, NebbieDash._groupHeaderTrig,
    NebbieDash._splitSoloFailTrig, NebbieDash._splitSuccessTrig,
    NebbieDash._combatEndTrig,
    NebbieDash._combatEndTrig2,
    NebbieDash._fallTrig, NebbieDash._disarmTrig, NebbieDash._hungerTrig, NebbieDash._thirstTrig,
    NebbieDash._wieldTrig, NebbieDash._identifyObjTrig, NebbieDash._identifyDmgTrig,
    NebbieDash._identKnowledgeTrig, NebbieDash._identSourceSpellTrig, NebbieDash._identSourceScrollTrig,
    NebbieDash._identLineTrig, NebbieDash._identGiveTrig, NebbieDash._identDropTrig,
    NebbieDash._knowRaceTrig, NebbieDash._knowSourceSpellTrig, NebbieDash._knowLineTrig,
    NebbieDash._stopUsingTrig, NebbieDash._wearBackTrig, NebbieDash._wearBackTrig2,
  }
  for _, id in ipairs(ids) do
    if id then pcall(function() killTrigger(id) end) end
  end
  for _, id in ipairs(NebbieDash._spellExpiryTrigs or {}) do
    if id then pcall(function() killTrigger(id) end) end
  end
  NebbieDash._spellExpiryTrigs = {}
  NebbieDash.teardownChatTriggers()
  NebbieDash.teardownTextHighlightTriggers()
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
  -- Prompt immortale (Sirio ecc.): "Nome R### [....]>>"
  -- tempRegexTrigger = PCRE (NON Lua): \] \s  — il vecchio "%]%s*>>%s*$" non
  -- matchava MAI, quindi Sirio restava "nessun personaggio" senza nchar.
  NebbieDash._promptImmTrig = tempRegexTrigger("\\]\\s*>>\\s*$", [[NebbieDash.onPromptLine()]])
  -- Cintura: substring su "]>>" (formati senza spazi tra ] e >>).
  NebbieDash._promptImmTrig2 = tempTrigger("]>>", [[NebbieDash.onPromptLine()]])
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
  -- Memoria gruppo da risposta split (sempre attivi, costo trascurabile):
  --   Ma cosa vuoi dividere che sei solo.
  --   Hai diviso N monete...
  NebbieDash._splitSoloFailTrig = tempTrigger("Ma cosa vuoi dividere che sei solo",
    [[NebbieDash.onSplitSoloFailLine()]])
  NebbieDash._splitSuccessTrig = tempTrigger("Hai diviso ", [[NebbieDash.onSplitSuccessLine()]])
  -- Trigger gruppo attivi solo durante un eventuale controllo group legacy.
  -- Substring + validazione in handler (stripColors, pattern server reale):
  --   But you are a member of no group?!
  --   $c0015Your group "nome" consists of:
  --   $c0015Your group consists of:   (senza nome gruppo — prima non matchava)
  NebbieDash._groupSoloTrig = tempTrigger("But you are a member of no group", [[NebbieDash.onGroupSoloLine()]])
  NebbieDash._groupHeaderTrig = tempTrigger("Your group", [[NebbieDash.onGroupHeaderLine()]])
  NebbieDash._combatEndTrig = tempTrigger("La tua parte di esperienza", [[NebbieDash.onCombatEndLine()]])
  NebbieDash._combatEndTrig2 = tempTrigger("La tua esperienza e' aumentata di", [[NebbieDash.onCombatEndLine()]])
  NebbieDash._fallTrig = tempTrigger("Inciampi e cadi per terra.", [[NebbieDash.onFallLine()]])
  -- Shield largo: stessa riga "Ti disarmano e ..." per vola/sfugge (handler sceglie get+wield vs solo wield).
  NebbieDash._disarmTrig = tempTrigger("Ti disarmano e", [[NebbieDash.onDisarmLine()]])
  NebbieDash._hungerTrig = tempRegexTrigger("^Hai Fame\\.", [[NebbieDash.onHungerThirstLine()]])
  NebbieDash._thirstTrig = tempRegexTrigger("^Hai sete\\.", [[NebbieDash.onHungerThirstLine()]])
  -- Elenco armi (vedi sezione dedicata sopra): "Impugni " per popolare la
  -- lista da solo ad ogni wield; le due righe di `identify` per rilevarne il
  -- tipo di danno SOLO quando l'utente esegue quel comando di sua iniziativa.
  NebbieDash._wieldTrig = tempTrigger("Impugni ", [[NebbieDash.onWieldLine()]])
  NebbieDash._stopUsingTrig = tempTrigger("Smetti di usare ", [[NebbieDash.onStopUsingLine()]])
  -- PCRE (non Lua): punto = \.  e whitespace = \s
  NebbieDash._wearBackTrig = tempRegexTrigger("^Ti metti .+ sulle spalle\\.\\s*$", [[NebbieDash.onWearBackLine()]])
  -- Fallback substring se il regex fallisce su varianti spaziature.
  NebbieDash._wearBackTrig2 = tempTrigger("sulle spalle.", [[NebbieDash.onWearBackLine()]])
  NebbieDash._identifyObjTrig = tempTrigger("Tipo di Oggetto", [[NebbieDash.onIdentifyObjectLine()]])
  NebbieDash._identifyDmgTrig = tempTrigger("Tipo di danno:", [[NebbieDash.onIdentifyDamageLine()]])
  -- Archivio identify condiviso: start su "La conoscenza…"; fonte spell/scroll
  -- opzionale; catch-all (^) solo durante la cattura (disabilitato a riposo).
  NebbieDash._identKnowledgeTrig = tempTrigger("La conoscenza ti pervade:",
    [[NebbieDash.onIdentKnowledgeLine()]])
  NebbieDash._identSourceSpellTrig = tempTrigger("Pronunci le parole, 'identify'",
    [[NebbieDash.onIdentSourceSpellLine()]])
  NebbieDash._identSourceScrollTrig = tempTrigger("pergamena di identificazione",
    [[NebbieDash.onIdentSourceScrollLine()]])
  NebbieDash._identLineTrig = tempRegexTrigger("^", [[NebbieDash.onIdentArchiveLine()]])
  if NebbieDash._identLineTrig then pcall(disableTrigger, NebbieDash._identLineTrig) end
  -- Possesso: give → altro PG; drop → terra + richiesta nidentdb hold.
  NebbieDash._identGiveTrig = tempTrigger("Dai ", [[NebbieDash.onIdentGiveLine()]])
  NebbieDash._identDropTrig = tempTrigger("Posi ", [[NebbieDash.onIdentDropLine()]])
  -- Archivio know monster: start su "e' di razza"; catch-all solo in cattura.
  NebbieDash._knowRaceTrig = tempTrigger("e' di razza ", [[NebbieDash.onKnowMonsterRaceLine()]])
  NebbieDash._knowSourceSpellTrig = tempTrigger("Pronunci le parole, 'know monster'",
    [[NebbieDash.onKnowSourceSpellLine()]])
  NebbieDash._knowLineTrig = tempRegexTrigger("^", [[NebbieDash.onKnowArchiveLine()]])
  if NebbieDash._knowLineTrig then pcall(disableTrigger, NebbieDash._knowLineTrig) end
  -- Scadenza spell (vedi SPELL_EXPIRY_PATTERNS sopra): un trigger per riga,
  -- shield su substring esatta fornita dall'utente per ognuna.
  NebbieDash._spellExpiryTrigs = {}
  for _, entry in ipairs(NebbieDash.SPELL_EXPIRY_PATTERNS) do
    local id = tempTrigger(entry.text, string.format("NebbieDash.onSpellExpiredLine(%q)", entry.spell))
    table.insert(NebbieDash._spellExpiryTrigs, id)
  end
  NebbieDash.installTextHighlightTriggers()
  NebbieDash.installChatTriggers()
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
    registerAnonymousEventHandler("sysInstallPackage", "NebbieDash.onInstallPackageEvent")
    registerAnonymousEventHandler("sysUninstallPackage", "NebbieDash.onUninstallPackageEvent")
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
function NebbieDash.migrateSharedConfigFiles()
  NebbieDash.ensureConfigDir()
  local files = {
    "nebbie-complete-dashboard-package-chars.lua",
    "nebbie-dash-ui.lua",
    "nebbie-spell-shortcuts.txt",
    "nebbie-cast-spells.txt",
    "nebbie-speedwalks.txt",
    "nebbie-hunger-macros.txt",
    "nebbie-item-keywords.txt",
    "nebbie-batch-commands.txt",
    "nebbie-batch-items.csv",
    "nebbie-ident-batch-commands.txt",
    "nebbie-dash-preferences.txt",
    "nebbie-dash-sounds.txt",
    "nebbie-ident-db.lua",
    "nebbie-know-db.lua",
  }
  for _, f in ipairs(files) do
    NebbieDash.migrateConfigFileIfNeeded(f)
  end
  NebbieDash.ensureDefaultConfigFiles()
end

function NebbieDash.boot()
  local now = os.time()
  if NebbieDash._mainLoaded and NebbieDash._lastBootTime and (now - NebbieDash._lastBootTime) < 2 then
    return
  end
  NebbieDash._lastBootTime = now
  NebbieDash.migrateSharedConfigFiles()
  NebbieDash.loadStore()
  NebbieDash.loadIdentDb()
  NebbieDash.loadKnowDb()
  NebbieDash.loadUiStore()
  NebbieDash.loadPreferences()
  NebbieDash.loadSoundsConfig()
  NebbieDash.prefs.sidebar_mode = "dock"
  NebbieDash.sidebarMode = "dock"
  NebbieDash.loadSpeedwalks()
  NebbieDash.loadSpellCastConfig()
  NebbieDash.loadHungerMacros()
  NebbieDash.loadItemKeywords()
  NebbieDash.loadBatchCommands()
  NebbieDash.loadBatchItems()
  NebbieDash.installTriggers()
  NebbieDash.purgeLegacyKeypadKeys(true)
  if NebbieDash._upgradeFromVer then
    NebbieDash.teardownGui()
  end
  NebbieDash.destroyLegacyGuiWindows()
  NebbieDash.initGUI()
  NebbieDash.initHelpButton()
  if NebbieDash.chatEnabled ~= false then
    NebbieDash.initChatWindow()
  end
  NebbieDash._mainLoaded = true
  NebbieDash.ensurePackageDownloadHandlers()
  NebbieDash.ensurePackageUpdateEventHandler()
  if NebbieDash._upgradeFromVer then
    cecho("<yellow>[NebbieDash] Aggiornamento v" .. NebbieDash._upgradeFromVer ..
      " → v" .. NebbieDash.version .. ".\n")
    cecho("<grey>[NebbieDash] Prossimi aggiornamenti: <yellow>npackageupdate<grey>. "
      .. "Se la barra e' nera: <yellow>nfix<grey>.\n")
    NebbieDash._upgradeFromVer = nil
  end
  cecho("<green>[NebbieDash] v" .. NebbieDash.version .. " pronto (" ..
    tostring(NebbieDash.effectiveSidebarMode()) .. " sidebar). Usa <yellow>nresync<green> dopo il login.\n")
  NebbieDash.printPackageVersionHint()
end

function NebbieDash.runFix()
  NebbieDash._lastBootTime = nil
  NebbieDash.teardownGui()
  NebbieDash.boot()
  cecho("<green>[NebbieDash] nfix completato.\n")
end
