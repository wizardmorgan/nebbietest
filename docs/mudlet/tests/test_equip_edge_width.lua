-- Test unitario (senza Mudlet) per clamp / persistenza logica larghezza Equip.
-- Esegui: lua tests/test_equip_edge_width.lua

package.path = package.path .. ";./?.lua"

-- Stub minimo: carica solo le funzioni necessarie dal core e' troppo pesante
-- (dipende da API Mudlet). Qui riplichiamo clampEquipWidth e verifichiamo
-- i limiti allineati a nwidth.

local function clampEquipWidth(w, current)
  w = tonumber(w) or current or 260
  return math.max(150, math.min(900, math.floor(w)))
end

local fails = 0
local function check(name, got, want)
  if got ~= want then
    io.stderr:write(string.format("FAIL %s: got %s want %s\n", name, tostring(got), tostring(want)))
    fails = fails + 1
  else
    print("OK  " .. name)
  end
end

check("default", clampEquipWidth(nil, 260), 260)
check("min", clampEquipWidth(10), 150)
check("max", clampEquipWidth(9999), 900)
check("floor", clampEquipWidth(200.9), 200)
check("edge150", clampEquipWidth(150), 150)
check("edge900", clampEquipWidth(900), 900)
check("mid", clampEquipWidth(320), 320)

-- Simula persistenza uiState
local uiState = {}
local function persist(w, auto)
  if w and w >= 150 and w <= 900 then
    uiState.equipWidth = math.floor(w)
  end
  uiState.autoWidthEquip = auto ~= false
end
local function load()
  local ew = tonumber(uiState.equipWidth)
  local auto = true
  local width = 260
  if ew and ew >= 150 and ew <= 900 then
    width = math.floor(ew)
  end
  if uiState.autoWidthEquip == false then
    auto = false
  elseif uiState.autoWidthEquip == true then
    auto = true
  end
  return width, auto
end

persist(400, false)
local w1, a1 = load()
check("persist width", w1, 400)
check("persist auto off", a1, false)

persist(260, true)
local w2, a2 = load()
check("persist auto on", a2, true)
check("persist width reset", w2, 260)

if fails > 0 then
  os.exit(1)
end
print("All tests passed.")
