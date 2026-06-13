-- Usage: luajit run_stats.lua <items.json> <passives.json>
-- Печатает JSON со статами в stdout. ВАЖНО: запускать с cwd = <engine>/src,
-- т.к. HeadlessWrapper и Launch.lua резолвят пути относительно src/.

local itemsPath    = assert(arg[1], "arg1: путь к items JSON")
local passivesPath = assert(arg[2], "arg2: путь к passives JSON")

local function readFile(p)
  local f = assert(io.open(p, "r"), "не открыть "..p)
  local s = f:read("*a"); f:close(); return s
end

-- Поднять headless-движок (выставляет глобали loadBuildFromJSON, mainObject)
dofile("HeadlessWrapper.lua")

local itemsJSON    = readFile(itemsPath)
local passivesJSON = readFile(passivesPath)

loadBuildFromJSON(itemsJSON, passivesJSON)

local build = mainObject.main.modes["BUILD"]
local out = build.output

-- Минимальный безопасный вывод (ключи могут отличаться — уточняем в Task 6)
local function n(k) return out[k] or 0 end
print(string.format(
  '{"TotalDPS":%s,"Life":%s,"EnergyShield":%s,"Mana":%s}',
  tostring(n("TotalDPS")), tostring(n("Life")),
  tostring(n("EnergyShield")), tostring(n("Mana"))
))
