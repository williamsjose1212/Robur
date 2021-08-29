local module                    = _G.module
local package                   = _G.package
local log                       = _G.log
local clean                     = _G.clean

module("MadLib", package.seeall, log.setup)
clean.module("MadLib", clean.seeall, log.setup)

-- API
local Player                    = _G.Player
local _Core                     = _G.CoreEx
local _Libs                     = _G.Libs

-- CoreEx
local Game                      = _Core.Game
local ObjectManager             = _Core.ObjectManager

-- Libs
local Menu                      = _Libs.NewMenu
local Orbwalker                 = _Libs.Orbwalker
local TS                        = _Libs.TargetSelector()

-- Lua Globals
local next                     = _G.next
local sort                     = _G.table.sort

-- Mad Lib
local MadLib = {}
MadLib.Common = {}
MadLib.Player = {}
MadLib.GameObjects = {}

-- Common

---@return boolean
function MadLib.Common.IsGameNotAvailable()
    return Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead
end

---@param id string
---@return boolean
function MadLib.Common.GetMenuValue(id)
    local menuValue = Menu.Get(id, true)
    if menuValue then
        return menuValue
    end
    return false
end

---@param id string
---@return boolean|number
function MadLib.Common.GetKeyMenuValue(id)
    local menuValue = Menu.GetKey(id, true)
    if menuValue then
        return menuValue
    end
    return false
end

-- Player

---@param menuValue string
---@param spell table
---@return boolean
function MadLib.Player.HasNeededMana(menuValue, spell)
    local manaManager = MadLib.Common.GetMenuValue(menuValue)
    local manaNeeded = manaManager + (spell:GetManaCost() / Player.MaxMana * 100)
    local manaPercent = Player.ManaPercent * 100

    return manaPercent > manaNeeded
end

---@return number
function MadLib.Player.GetAutoAttackRange()
    return Orbwalker.GetTrueAutoAttackRange(Player)
end

-- GameObjects

---@param team string "all", "ally", "enemy", "neutral", "no_team"
---@param range integer
---@param pos Vector
---@return table<Handle_t, GameObject>
function MadLib.GameObjects.GetMinions(team, range, pos)
    team = team or "enemy"
    range = range or 3000
    pos = pos or Player.Position
    local table = ObjectManager.Get(team, "minions")

    local minionTable = {}
    for _, minion in pairs(table) do
        minion = minion.AsAI
        if minion.IsTargetable then
            local dist = pos:Distance(minion.Position)
            if dist < range then
                minionTable[#minionTable+1] = minion
            end
        end
    end
    return minionTable
end

---@param team string "all", "ally", "enemy", "neutral", "no_team"
---@param range integer
---@param pos Vector
---@return GameObject[]
function MadLib.GameObjects.GetNearbyMinions(team, range, pos)
    team = team or "enemy"
    range = range or 1500

    if range > 1500 then
        range = 1500
    end

    pos = pos or Player.Position
    local table = ObjectManager.GetNearby(team, "minions")

    local minionTable = {}
    for _, minion in ipairs(table) do
        minion = minion.AsAI
        if minion.IsTargetable then
            local dist = pos:Distance(minion.Position)
            if dist < range then
                minionTable[#minionTable+1] = minion
            end
        end
    end
    return minionTable
end

---@param mode string "ascending", "descending"
---@param team string "ally", "enemy"
---@param range integer
---@param pos Vector
---@return GameObject[]
function MadLib.GameObjects.GetMinionsByHealth(mode, team, range, pos)
    local minions = MadLib.GameObjects.GetMinions(team, range, pos)
    if next(minions) == nil then return {} end

    if mode == "ascending" then
        sort(minions, function (a, b)
            return a.Health < b.Health
        end)
    elseif mode == "descending" then
        sort(minions, function (a, b)
            return a.Health > b.Health
        end)
    end
    return minions
end

---@param mode string "ascending", "descending"
---@param team string "ally", "enemy"
---@param range integer
---@param pos Vector
---@return GameObject[]
function MadLib.GameObjects.GetNearbyMinionsByHealth(mode, team, range, pos)
    local minions = MadLib.GameObjects.GetNearbyMinions(team, range, pos)
    if next(minions) == nil then return {} end

    if mode == "ascending" then
        sort(minions, function (a, b)
            return a.Health < b.Health
        end)
    elseif mode == "descending" then
        sort(minions, function (a, b)
            return a.Health > b.Health
        end)
    end
    return minions
end

---@param mode string "ascending", "descending"
---@param team string "ally", "enemy"
---@param range integer
---@param pos Vector
---@return GameObject[]
function MadLib.GameObjects.GetNearbyMinionsByDistance(mode, team, range, pos)
    local minions = MadLib.GameObjects.GetNearbyMinions(team, range, pos)
    if next(minions) == nil then return {} end

    if mode == "ascending" then
        sort(minions, function (a, b)
            return a.Position:Distance(pos) < b.Position:Distance(pos)
        end)
    elseif mode == "descending" then
        sort(minions, function (a, b)
            return a.Position:Distance(pos) > b.Position:Distance(pos)
        end)
    end
    return minions
end

---@param range integer
---@param pos Vector
---@return table<Handle_t, GameObject>
function MadLib.GameObjects.GetEnemies(range, pos)
    range = range or 3000
    pos = pos or Player.Position
    local table = ObjectManager.Get("enemy", "heroes")

    local enemyTable = {}
    for _, enemy in pairs(table) do
        enemy = enemy.AsAI
        if enemy.IsTargetable then
            local dist = pos:Distance(enemy.Position)
            if dist < range then
                enemyTable[#enemyTable+1] = enemy
            end
        end
    end
    return enemyTable
end

---@param range integer
---@param pos Vector
---@return GameObject[]
function MadLib.GameObjects.GetNearbyEnemies(range, pos)
    range = range or 1500

    if range > 1500 then
        range = 1500
    end

    pos = pos or Player.Position
    local table = ObjectManager.GetNearby("enemy", "heroes")

    local enemyTable = {}
    for _, enemy in ipairs(table) do
        enemy = enemy.AsAI
        if enemy.IsTargetable then
            local dist = pos:Distance(enemy.Position)
            if dist < range then
                enemyTable[#enemyTable+1] = enemy
            end
        end
    end
    return enemyTable
end


---@param mode string "ascending", "descending"
---@param range number
---@param pos Vector
---@return GameObject[]
function MadLib.GameObjects.GetNearbyEnemiesByDistance(mode, range, pos)
    mode = mode or "ascending"
    range = range or 1500
    pos = pos or Player.Position

    local table = MadLib.GameObjects.GetNearbyEnemies(range, pos)
    if next(table) == nil then return {} end

    if mode == "ascending" then
        sort(table, function (a, b)
            return a:Distance(pos) < b:Distance(pos)
        end)
    elseif mode == "descending" then
        sort(table, function (a, b)
            return a:Distance(pos) > b:Distance(pos)
        end)
    end
    return table
end

---@param mode string "ascending", "descending"
---@param range number
---@param pos Vector
---@param checkMissileBlocks boolean
---@return AIHeroClient[]
function MadLib.GameObjects.GetTargetsByDistance(mode, range, pos, checkMissileBlocks)
    mode = mode or "ascending"
    range = range or nil
    pos = pos or Player.Position
    checkMissileBlocks = checkMissileBlocks or nil

    local targets = TS:GetTargets(range, checkMissileBlocks)
    if next(targets) == nil then return {} end

    if mode == "ascending" then
        sort(targets, function (a, b)
            return a:Distance(pos) < b:Distance(pos)
        end)
    elseif mode == "descending" then
        sort(targets, function (a, b)
            return a:Distance(pos) > b:Distance(pos)
        end)
    end
    return targets
end

---@param pos Vector
---@param team string "ally", "enemy"
---@return boolean
function MadLib.GameObjects.IsPosUnderTurret(pos, team)
    for _, turret in ipairs(ObjectManager.GetNearby(team, "turrets")) do
        if turret.IsDead then return end
        if pos:Distance(turret.Position) <= 900 then
            return true
        end
    end
    return false
end

return MadLib