-- Reproduction: late rem after wear clears «sulla schiena» because
-- onWearBackLine → endWeaponSwapGuard(false) nils the stash.
-- Does NOT manually re-inject stash (unlike the masked smoke test).

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
function killTrigger() end
function killTimer() end
function selectString() return true end
function setFgColor() end
function setBgColor() end
function resetFormat() end
function decho() end
function moveCursorEnd() end
function playSoundFile() end
function echo() end
function send() end
function tempTimer() return 1 end
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
function setLabelClickCallback() end
function setLabelToolTip() end
function moveLabel() end
function resizeLabel() end
function setLabelStyleSheet() end
function cechoLink() end
registerAnonymousEventHandler = function() end

local scriptDir = arg and arg[0] and arg[0]:match("^(.*)[/\\][^/\\]+$") or "."
dofile(scriptDir .. "/../nebbie-complete-dashboard-package-core.lua")

local function schienaRow(data)
  for _, row in ipairs(NebbieDash.buildEquipRows(data)) do
    if row.location == "sulla schiena" then return row end
  end
  return nil
end

local function dumpState(tag, data)
  local row = schienaRow(data)
  print(string.format(
    "[%s] busy=%s stash=%s schiena.empty=%s schiena.item=%s",
    tag,
    tostring(NebbieDash._weaponSwapBusy),
    tostring(NebbieDash._weaponSwapBackItem),
    tostring(row and row.empty),
    tostring(row and row.item)
  ))
end

-- Clear debug log
do
  local f = io.open("/tmp/nebbie-schiena-debug.log", "w")
  if f then f:close() end
end

NebbieDash.setCurrentCharacter("NomiyaMaki", true)
local data = NebbieDash.getCharData("NomiyaMaki")
data.eq = {
  [16] = { location = "impugnato", item = "La Flamberga di Boris" },
  [17] = { location = "sulla schiena", item = "Borsa Inesauribile dei Korred" },
}
data.eqUpdated = os.time()

print("=== Scenario A: wear ends guard and clears stash; late rem clears schiena ===")
local gen = NebbieDash.beginWeaponSwapGuard(data)
dumpState("after begin", data)

line = "Smetti di usare Borsa Inesauribile dei Korred."
NebbieDash.onStopUsingLine()
dumpState("after rem during busy", data)

line = "Ti metti Borsa Inesauribile dei Korred sulle spalle."
NebbieDash.onWearBackLine()
dumpState("after wear (guard ended)", data)

-- CRITICAL: do NOT re-inject stash — this is the real race
line = "Smetti di usare Borsa Inesauribile dei Korred."
NebbieDash.onStopUsingLine()
dumpState("after late rem", data)

NebbieDash.endWeaponSwapGuard(gen, true)
dumpState("after timeout restore", data)

local final = schienaRow(data)
local bug = final and final.empty
print(bug and "BUG REPRODUCED: schiena empty after late rem+timeout"
  or "NO BUG: schiena filled = " .. tostring(final and final.item))

print("")
print("=== Scenario B: wear message mismatch (hypothesis A) ===")
local data2 = NebbieDash.getCharData("NomiyaMaki")
data2.eq = {
  [16] = { location = "impugnato", item = "La Flamberga di Boris" },
  [17] = { location = "sulla schiena", item = "Borsa Inesauribile dei Korred" },
}
data2.eqUpdated = os.time()
local gen2 = NebbieDash.beginWeaponSwapGuard(data2)
line = "Smetti di usare Borsa Inesauribile dei Korred."
NebbieDash.onStopUsingLine()
-- Wrong TO_CHAR would fail parse
line = "Ti metti Borsa Inesauribile dei Korred sulla schiena."
NebbieDash.onWearBackLine()
dumpState("after wrong wear text", data2)
NebbieDash.endWeaponSwapGuard(gen2, true)
dumpState("after timeout (wrong wear)", data2)

print("")
print("=== Server TO_CHAR check (from act.obj_wear.cpp) ===")
print('Expected: act("Ti metti $p sulle spalle.", ..., TO_CHAR) for WEAR_BACK')
print("Regex: ^Ti metti (.+) sulle spalle%.%s*$")
print("Match sample:", ("Ti metti Borsa Inesauribile dei Korred sulle spalle."):match("^Ti metti (.+) sulle spalle%.%s*$"))

os.exit(bug and 1 or 0)
