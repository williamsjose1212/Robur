if Player.CharName ~= "Nunu" then return end

module("Simple Nunu", package.seeall, log.setup)
clean.module("Simple Nunu", clean.seeall, log.setup)
local CoreEx = _G.CoreEx
local Libs = _G.Libs
local ScriptName, Version = "SimpleNunu", "1.0.0"
--CoreEx.AutoUpdate("https://github.com/SamuelLachance/Robur/" .. ScriptName ..".lua", Version)
local Menu = Libs.NewMenu
local Prediction = Libs.Prediction
local Orbwalker = Libs.Orbwalker
local CollisionLib = Libs.CollisionLib
local DamageLib = Libs.DamageLib
local ImmobileLib = Libs.ImmobileLib
local SpellLib = Libs.Spell
local TargetSelector = Libs.TargetSelector
local TS = Libs.TargetSelector()
local HPred = Libs.HealthPred
local DashLib = Libs.DashLib
local os_clock = _G.os.clock
local math_abs = _G.math.abs
local math_huge = _G.math.huge
local math_min = _G.math.min
local math_deg = _G.math.deg
local math_sin = _G.math.sin
local math_cos = _G.math.cos
local math_acos = _G.math.acos
local math_pi = _G.math.pi
local math_pi2 = 0.01745329251
local ObjectManager = CoreEx.ObjectManager
local EventManager = CoreEx.EventManager
local Input = CoreEx.Input
local Enums = CoreEx.Enums
local Game = CoreEx.Game
local Geometry = CoreEx.Geometry
local Renderer = CoreEx.Renderer
local Vector = CoreEx.Geometry.Vector
local SpellSlots = Enums.SpellSlots
local SpellStates = Enums.SpellStates
local BuffTypes = Enums.BuffTypes
local Events = Enums.Events
local HitChanceEnum = Enums.HitChance
local Nav = CoreEx.Nav

local next = next
local Nunu = {}
local qMana = 0
local wMana = 0
local eMana = 0
local rMana = 0
local iTick = 0
local Combo,Harass,Laneclear,None = false,false,false, false
local Qobj = {}
local Robj = {}

Nunu.Q = SpellLib.Targeted({
  Slot = SpellSlots.Q,
  Range = 150,
  Key = "Q"
})

Nunu.W = SpellLib.Active({
  Slot = SpellSlots.W,
  Key = "W"
})

Nunu.E = SpellLib.Skillshot({
  Slot = SpellSlots.E,
  Range = 695,
  Delay = 0.0,
  Speed = math_huge,
  Key = "E"
})

Nunu.R = SpellLib.Active({
  Slot = SpellSlots.R,
  Range = 300,
  Delay = 1.8,
  Radius = 600,
  Key = "R"
})

local Utils = {}

function Utils.IsGameAvailable()
  return not (
  Game.IsChatOpen()  or
  Game.IsMinimized() or
  Player.IsDead
  )
end

function Utils.SetMana()
  if Nunu.Q:IsReady() then
    qMana = Nunu.Q:GetManaCost()
  elseif (Player.Health/Player.MaxHealth) * 100 < 20 then
    qMana = 0
  else
    qMana = 0
  end
  if Nunu.W:IsReady() then
    wMana = Nunu.W:GetManaCost()
  elseif (Player.Health/Player.MaxHealth) * 100 < 20 then
    wMana = 0
  else
    wMana = 0
  end
  if Nunu.E:IsReady() then
    eMana = Nunu.E:GetManaCost()
  elseif (Player.Health/Player.MaxHealth) * 100 < 20 then
    eMana = 0
  else
    eMana = 0
  end
  if Nunu.R:IsReady() then
    rMana = Nunu.R:GetManaCost()
  elseif (Player.Health/Player.MaxHealth) * 100 < 20 then
    rMana = 0
  else
    rMana = 0
  end
  return false
end

function Utils.GetTargets(Spell)
  return TS:GetTargets(Spell.Range,true)
end

function Utils.GetTargetsRange(Range)
  return TS:GetTargets(Range,false)
end

function Utils.ValidUlt(target)
  local TargetAi = target.AsAI
  if TargetAi and TargetAi.IsValid then
    local KindredUlt = TargetAi:GetBuff("kindredrnodeathbuff")
    local TryndUlt = TargetAi:GetBuff("undyingrage") --idk if  HasUndyingBuff() do the same thing
    local KayleUlt = TargetAi:GetBuff("judicatorintervention") -- still this name ?
    local NunuUlt = TargetAi:GetBuff("chronoshift")

    if KindredUlt or TryndUlt or KayleUlt or NunuUlt  or TargetAi.IsZombie or TargetAi.IsDead then
      return false
    end
  end
  return true
end

function Utils.HasBuffType(unit,buffType)
  local ai = unit.AsAI
  if ai.IsValid then
    for i = 0, ai.BuffCount do
      local buff = ai:GetBuff(i)
      if buff and buff.IsValid and buff.BuffType == buffType then
        return true
      end
    end
  end
  return false
end

function Utils.Count(range)
  local num = 0
  for k, v in ipairs(ObjectManager.GetNearby("enemy", "heroes")) do
    local hero = v.AsHero
    if hero and hero.IsTargetable and hero:Distance(Player.Position) < range then
      num = num + 1
    end
  end
  return num
end

function Utils.hasValue(tab,val)
  for index, value in ipairs(tab) do
    if value == val then
      return true
    end
  end
  return false
end

function Utils.tablefind(tab,el)
  for index, value in pairs(tab) do
    if value == el then
      return index
    end
  end
end

function Utils.CountMinionsInRange(range, type)
  local amount = 0
  for k, v in ipairs(ObjectManager.GetNearby(type, "minions")) do
    local minion = v.AsMinion
    if not minion.IsJunglePlant and minion.IsValid and not minion.IsDead and minion.IsTargetable and
    Player:Distance(minion) < range then
      amount = amount + 1
    end
  end
  return amount
end

function Utils.CountHeroes(pos,range,team)
  local num = 0
  for k, v in pairs(ObjectManager.Get(team, "heroes")) do
    local hero = v.AsHero
    if hero.IsValid and not hero.IsDead and hero.IsTargetable and hero:Distance(pos) < range then
      num = num + 1
    end
  end
  return num
end

function Utils.IsValidTarget(Target)
  return Target and Target.IsTargetable and Target.IsAlive
end

function Utils.GetAngle(v1, v2)
  return math_deg(math_acos(v1 * v2 / (v1:Len() * v2:Len())))
end

function Utils.IsFacing(p1,p2)
  local v = p1.Position - p2.Position
  local dir = p1.AsAI.Direction
  local angle = 180 - Utils.GetAngle(v, dir)
  if math_abs(angle) < 80 then
    return true
  end
  return false
end

function Utils.HasBuff(target,buffname)
  local TargetAi = target.AsAI
  if TargetAi and TargetAi.IsValid then
    local hBuff= TargetAi:GetBuff(buffname)
    if hBuff then
      return true
    end
  end
  return false
end

function Utils.CanHit(target,spell)
  if Utils.IsValidTarget(target) then
    local pred = target:FastPrediction(spell.CastDelay)
    if pred == nil then return false end
    if spell.LineWidth > 0 then
      local powCalc = (spell.LineWidth + hero.BoundingRadius)^2
      if (pred:LineDistance(spell.StartPos,spell.EndPos,true) <= powCalc) or (target.Position:LineDistance(spell.StartPos,spell.EndPos,true) <= powCalc) then
        return true
      end
    elseif target:Distance(spell.EndPos) < 50 + target.BoundingRadius or pred:Distance(spell.EndPos) < 50 + target.BoundingRadius then
      return true
    end
  end
  return false
end

function Utils.Sqrd(num)
  return num*num
end

function Utils.IsUnderTurret(target)
  local TurretRange = 562500
  local turrets = ObjectManager.GetNearby("enemy", "turrets")
  for _, turret in ipairs(turrets) do
    if turret.IsDead then return false end
    if target.Position:DistanceSqr(turret) < TurretRange + Utils.Sqrd(target.BoundingRadius) / 2 then
      return true
    end
  end
  return false
end

function Utils.CanMove(target)
  if Utils.HasBuffType(target,BuffTypes.Charm) or Utils.HasBuffType(target,BuffTypes.Snare) or target.MoveSpeed < 50 or Utils.HasBuffType(target,BuffTypes.Stun) or Utils.HasBuffType(target,BuffTypes.Suppression) or Utils.HasBuffType(target,BuffTypes.Taunt) or Utils.HasBuffType(target,BuffTypes.Fear) or Utils.HasBuffType(target,BuffTypes.Knockup) or Utils.HasBuffType(target,BuffTypes.Knockback) then
    return false
  else
    return true
  end
end

function Utils.NoLag(tick)
  if (iTick == tick) then
    return true
  else
    return false
  end
end

function Utils.ValidMinion(minion)
  return minion and minion.IsTargetable and minion.MaxHealth > 6
end

function Nunu.LogicQ()
  local target = TS:GetTarget(Nunu.Q.Range,false)
  local minionsQ = {}
  for k, v in pairs(ObjectManager.GetNearby("neutral", "minions")) do
    local minion = v.AsAI
    if Utils.ValidMinion(minion) and Player:Distance(minion.Position) < Nunu.Q.Range then
      table.insert(minionsQ, minion)
      table.sort(minionsQ, function(a, b) return a.MaxHealth < b.MaxHealth end)
    end
  end
  if Utils.IsValidTarget(target) and Player.Mana > qMana + rMana then
    if Nunu.Q:Cast(target) then return true end
  elseif Utils.IsValidTarget(target) and Nunu.Q:GetDamage(target) >= target.Health then
    if Nunu.Q:Cast(target) then return true end
  end
  if Laneclear or (Player.Health/Player.MaxHealth) * 100 < 50 then
    for k, v in pairs(ObjectManager.GetNearby("enemy", "minions")) do
      local minion = v.AsAI
      if Utils.ValidMinion(minion) and Player:Distance(minion.Position) < Nunu.Q.Range then
        if Nunu.Q:Cast(minion) then return true end
      end
    end
    for k, monster in pairs(minionsQ) do
      if Nunu.Q:Cast(monster) then return true end
    end
  end
  return false
end


function Nunu.LogicE()
  local target = TS:GetTarget(Nunu.E.Range,false)
  local minionsE = {}
  for k, v in pairs(ObjectManager.GetNearby("neutral", "minions")) do
    local minion = v.AsAI
    if Utils.ValidMinion(minion) and Player:Distance(minion.Position) < Nunu.E.Range then
      table.insert(minionsE, minion)
      table.sort(minionsE, function(a, b) return a.MaxHealth < b.MaxHealth end)
    end
  end
  if not None then
    if Utils.IsValidTarget(target) then
      local ePred = Nunu.E:GetPrediction(target)
      if Player.Mana > qMana + eMana + rMana then
        if ePred and ePred.HitChanceEnum >= HitChanceEnum.Medium then
          if Nunu.E:Cast(ePred.CastPosition) then return true end
        end
      elseif not Nunu.Q:IsReady() and Nunu.E:GetDamage(target)*3 >= target.Health then
        if ePred and ePred.HitChanceEnum >= HitChanceEnum.Medium then
          if Nunu.E:Cast(ePred.CastPosition) then return true end
        end
      end
    end
  end
  if Laneclear then
    for k, v in pairs(ObjectManager.GetNearby("enemy", "minions")) do
      local minion = v.AsAI
      if Utils.ValidMinion(minion) and Player:Distance(minion.Position) < Nunu.E.Range then
        if Nunu.E:Cast(minion.Position) then return true end
      end
    end
    for k, v in pairs(minionsE) do
      local ePred1 = Nunu.E:GetPrediction(v)
      if ePred1 then
        if Nunu.E:Cast(v.Position) then return true end
      end
    end
  end
  return false
end

function Nunu.OnUpdate()
  if not Utils.IsGameAvailable() then return false end
  if Utils.HasBuff(Player,"nunuW") then return false end
  if Nunu.R:GetToggleState() == 2 then
    Orbwalker.BlockMove(true)
    Orbwalker.BlockAttack(true)
  else
    Orbwalker.BlockMove(false)
    Orbwalker.BlockAttack(false)
  end
  if Utils.NoLag(0) then
    if Utils.SetMana() then return true end
  end
  if Utils.NoLag(1) and Nunu.Q:IsReady() and Menu.Get("autoQ") and not Utils.HasBuff(Player,"nunurshield") then
    if Nunu.LogicQ() then return true end
  end
  if Utils.NoLag(2) and Nunu.E:IsReady() and Menu.Get("autoE") and Player.Mana > eMana + rMana and not Utils.HasBuff(Player,"nunurshield") then
    if Nunu.LogicE() then return true end
  end

  local OrbwalkerMode = Orbwalker.GetMode()
  if OrbwalkerMode == "Combo" then
    Combo = true
  else
    Combo = false
  end
  if OrbwalkerMode == "Harass" then
    Harass = true
  else
    Harass = false
  end
  if OrbwalkerMode == "Waveclear" or OrbwalkerMode == "Lasthit" or OrbwalkerMode == "Harass" then
    Laneclear = true
  else
    Laneclear = false
  end
  if OrbwalkerMode == "nil" then
    None = true
  else
    None = false
  end
  iTick = iTick + 1
  if iTick > 2 then
    iTick = 0
  end
  return false
end

function Nunu.OnDrawDamage(target, dmgList)
  if Menu.Get("DrawDmg") then
    if Nunu.Q:IsReady() then
      table.insert(dmgList, Nunu.Q:GetDamage(target))
    end
    if Nunu.W:IsReady() then
      table.insert(dmgList, Nunu.W:GetDamage(target))
    end
    if Nunu.E:IsReady() then
      table.insert(dmgList, Nunu.E:GetDamage(target)*4)
    end
    if Nunu.R:IsReady() then
      table.insert(dmgList, Nunu.R:GetDamage(target))
    end
  end
end

function Nunu.LoadMenu()
  local function NunuMenu()
    Menu.ColumnLayout("Casting", "Casting", 2, true, function ()
    Menu.ColoredText("> Q", 0xB65A94FF, true)
    Menu.Checkbox("autoQ", "Auto Q", true)
    Menu.ColoredText("> E", 0x0066CCFF, true)
    Menu.Checkbox("autoE", "Auto E", true)
    Menu.ColoredText("Misc", 0xB65A94FC, true)
    Menu.Checkbox("DrawDmg", "Draw Damage", true)
    end)
  end
  if Menu.RegisterMenu("Simple Nunu", "Simple Nunu", NunuMenu) then return true end
  return false
end

function OnLoad()
  Nunu.LoadMenu()
  for EventName, EventId in pairs(Events) do
    if Nunu[EventName] then
      EventManager.RegisterCallback(EventId, Nunu[EventName])
    end
  end
  return true
end
