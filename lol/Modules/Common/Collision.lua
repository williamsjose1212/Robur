module("CollisionLib", package.seeall, log.setup)
clean.module("CollisionLib", clean.seeall, log.setup)

--[[
    First Release By Thorn @ 24.Aug.2020

    _G.Libs.CollisionLib
        .SearchWall(startPos, endPos, width, speed, delay) --TODO: Add Trundle, Ornn, Anivia etc
        .SearchHeroes(startPos, endPos, width, speed, delay, maxResults, allyOrEnemy)
        .SearchMinions(startPos, endPos, width, speed, delay, maxResults, allyOrEnemy)
        .SearchYasuoWall(startPos, endPos, width, speed, delay, maxResults, allyOrEnemy)
]]

local min, max, ceil = math.min, math.max, math.ceil
local insert, remove = table.insert, table.remove
local find = string.find

local _SDK = _G.CoreEx
local Console, ObjManager, EventManager, Geometry, Input, Renderer, Enums, Game = _SDK.Console, _SDK.ObjectManager, _SDK.EventManager, _SDK.Geometry, _SDK.Input, _SDK.Renderer, _SDK.Enums, _SDK.Game

---@class CollisionLib
local Collision = {}
local YasuoWalls = {}
local extraColDist = 25

---@param startPos Vector
---@param endPos Vector
---@param width number
---@param speed number
---@param delay number
---@param maxResults integer
---@param allyOrEnemy '"ally"'|'"enemy"'
function Collision.SearchWall(startPos, endPos, width, speed, delay)
    local dist = startPos:Distance(endPos)
    local dir = (endPos - startPos):Normalized()
    local perp = dir:Perpendicular():Normalized() * width * 0.5

    for i = 0, ceil(dist / 25) do
        local pos = startPos + (dir * min(25 * i, dist))
        if pos:IsWall() then
            return {Result = true, Positions = {pos}, Objects = {}}
        elseif width >= 50 then
            if (pos + perp):IsWall() then
                return {Result = true, Positions = {pos + perp}, Objects = {}}
            elseif (pos - perp):IsWall() then
                return {Result = true, Positions = {pos - perp}, Objects = {}}
            end
        end
    end
    return {Result = false, Positions = {}, Objects = {}}
end

function Collision.SearchHeroes(startPos, endPos, width, speed, delay, maxResults, allyOrEnemy, handlesToIgnore)
    local res = {Result = false, Positions = {}, Objects = {}}
    if not maxResults then maxResults = 1 end
    if type(handlesToIgnore) ~= "table" then handlesToIgnore = {} end
    if type(allyOrEnemy) ~= "string" or allyOrEnemy ~= "ally" then allyOrEnemy = "enemy" end

    local dist = startPos:Distance(endPos)
    local spellPath = Geometry.Path(startPos, endPos)
    for k, obj in pairs(ObjManager.Get(allyOrEnemy, "heroes")) do
        if not handlesToIgnore[k] then
            local hero = obj.AsHero
            local pos = hero and hero:FastPrediction(delay/1000 + hero:EdgeDistance(startPos)/speed)

            if pos and pos:Distance(startPos) < dist and hero.IsTargetable then
                local isOnSegment, pointSegment, pointLine = pos:ProjectOn(startPos, endPos)
                local lineDist = pointSegment:Distance(pos)
                if isOnSegment and lineDist < (hero.BoundingRadius + width*0.5 + extraColDist) then
                    res.Result = true
                    insert(res.Positions, pos:Extended(pointSegment, lineDist):SetHeight(startPos.y))
                    insert(res.Objects, hero)
                    if #res.Positions >= maxResults then break end
                end
            end
        end
    end
    return res
end

---@param startPos Vector
---@param endPos Vector
---@param width number
---@param speed number
---@param delay number
---@param maxResults integer
---@param allyOrEnemy '"ally"'|'"enemy"'
function Collision.SearchMinions(startPos, endPos, width, speed, delay, maxResults, allyOrEnemy, handlesToIgnore)
    if not maxResults then maxResults = 1 end
    if type(handlesToIgnore) ~= "table" then handlesToIgnore = {} end    
    if type(allyOrEnemy) ~= "string" or allyOrEnemy ~= "ally" then allyOrEnemy = "enemy" end

    local res = {Result = false, Positions = {}, Objects = {}}    
    local dist = startPos:Distance(endPos)

    local minionList = {ObjManager.Get(allyOrEnemy, "minions")}
    if allyOrEnemy == "enemy" then minionList[2] = ObjManager.Get("neutral", "minions") end

    for k, minions in ipairs(minionList) do
        for k, obj in pairs(minions) do        
            if not handlesToIgnore[k] then        
                local minion = obj.AsAI
                
                if minion and minion.Position:Distance(startPos) < dist and minion.IsTargetable and minion.MaxHealth > 5 then
                    local pos = minion:FastPrediction(delay/1000 + minion:EdgeDistance(startPos) / speed)            
                    local isOnSegment, pointSegment, pointLine = pos:ProjectOn(startPos, endPos)
                    local lineDist = pointSegment:Distance(pos)
                    if isOnSegment and lineDist < (minion.BoundingRadius + width*0.5 + extraColDist) then
                        res.Result = true
                        insert(res.Positions, pos:Extended(pointSegment, lineDist):SetHeight(startPos.y))
                        insert(res.Objects, minion)
                        if #res.Positions >= maxResults then break end
                    end
                end
            end
        end
    end    
       
    return res
end

---@param startPos Vector
---@param endPos Vector
---@param width number
---@param speed number
---@param delay number
---@param maxResults integer @Stop Searching When Reach This Many Collisions
---@param allyOrEnemy '"ally"'|'"enemy"'
function Collision.SearchYasuoWall(startPos, endPos, width, speed, delay, maxResults, allyOrEnemy)
    local res = {Result = false, Positions = {}, Objects = {}}
    if not maxResults then maxResults = 1 end
    local searchTeam = Player.TeamId
    if type(allyOrEnemy) ~= "string" or allyOrEnemy ~= "ally" then searchTeam = (300 - searchTeam) end

    local GameTime = Game.GetTime()
    local perp = (endPos-startPos):Perpendicular():Normalized() * width/2
    local spellPaths = {
        Geometry.Path(startPos, endPos),
        Geometry.Path(startPos + perp, endPos + perp),
        Geometry.Path(startPos - perp, endPos - perp)
    }
    for _, wallData in ipairs(YasuoWalls) do
        local Particle = wallData.Particle
        if Particle and wallData.Caster.TeamId == searchTeam then
            local wallPos = Particle.Position            
            local wallDir = (wallPos - wallData.StartPos):Normalized()
            
            local wallPos2 = Particle.Position + wallDir * 50
            local wallPerp = wallDir:Perpendicular():Normalized() * (350 + 50 * wallData.Level) * 0.5

            local wallPaths = {
                Geometry.Path((wallPos + wallPerp):SetHeight(wallPos.y), (wallPos - wallPerp):SetHeight(wallPos.y)),
                Geometry.Path((wallPos2 + wallPerp):SetHeight(wallPos.y), (wallPos2 - wallPerp):SetHeight(wallPos.y))
            }

            for k, wallPath in ipairs(wallPaths) do
                local timeSinceCast = GameTime - wallData.StartTime
                for __, spellPath in ipairs(spellPaths) do
                    local intersection = spellPath:Intersects(wallPath)
                    if intersection then                        
                        local timeToReach = delay/1000 + wallPos:Distance(intersection)/speed
                        
                        if timeSinceCast + timeToReach <= 4 then
                            res.Result = true
                            local _, segmentPoint = intersection:ProjectOn(startPos, endPos)
                            insert(res.Positions, segmentPoint)
                            insert(res.Objects, Particle)
                            if #res.Positions >= maxResults then break end
                        end
                    end
                end
            end            
        end
    end
    return res
end

---@param Obj GameObject
---@param Spell SpellCast
local function Helpers_OnProcessSpell(Obj, Spell)
    local hero = Obj.AsHero
    local spellData = Spell.SpellData
    if hero and spellData and Spell.Name == "YasuoW" then
        insert(YasuoWalls, {
                Caster = Obj,                
                Level = spellData.Level,
                StartPos = Spell.StartPos,
                StartTime = Game.GetTime(),
            }
        )
    end
end

---@param Obj GameObject
local function Helpers_OnCreateObject(Obj)
    if #YasuoWalls > 0 and find(Obj.Name, "_W_windwall") and not find(Obj.Name, "activate") then
        YasuoWalls[#YasuoWalls].Particle = Obj
    end
end

---@param Obj GameObject
local function Helpers_OnDeleteObject(Obj)
    for k, v in ipairs(YasuoWalls) do
        local particle = v.Particle
        if particle and particle == Obj then
            remove(YasuoWalls, k)
            return
        end
    end
end

local function Init()
    for k, v in pairs(ObjManager.Get("all", "heroes")) do
        local hero = v.AsHero
        if hero and hero.CharName == "Yasuo" then
            EventManager.RegisterCallback(Enums.Events.OnProcessSpell, Helpers_OnProcessSpell)
            EventManager.RegisterCallback(Enums.Events.OnCreateObject, Helpers_OnCreateObject)
            EventManager.RegisterCallback(Enums.Events.OnDeleteObject, Helpers_OnDeleteObject)
            break
        end
    end    
end
Init()

if not rawget(_G, "Libs") then _G.Libs = {} end
_G.Libs.CollisionLib = Collision
return Collision