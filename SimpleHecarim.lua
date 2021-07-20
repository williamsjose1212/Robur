if Player.CharName ~= "Hecarim" then return end

module("Simple Hecarim", package.seeall, log.setup)
clean.module("Simple Hecarim", clean.seeall, log.setup)
local CoreEx = _G.CoreEx
local Libs = _G.Libs
local ScriptName, Version = "SimpleHecarim", "1.0.0"
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
local Hecarim = {}
local qMana = 0
local wMana = 0
local eMana = 0
local rMana = 0
local iTick = 0
local Combo,Harass,Laneclear,None = false,false,false, false
local Qobj = {}
local Robj = {}

Hecarim.Q = SpellLib.Active({
  Slot = SpellSlots.Q,
  Range = 355,
  Key = "Q"
})

Hecarim.W = SpellLib.Active({
  Slot = SpellSlots.W,
  Range = 500,
  Key = "W"
})

Hecarim.E = SpellLib.Active({
  Slot = SpellSlots.E,
  Key = "E"
})

Hecarim.R = SpellLib.Skillshot({
  Slot = SpellSlots.R,
  Range = 1000,
  Delay = 0.0,
  Radius = 250,
  Speed = 1100,
  Type = "Circular",
  Key = "R"
})

Hecarim.R1 = SpellLib.Skillshot({
  Slot = SpellSlots.R,
  Range = 1000,
  Delay = 0.0,
  Radius = 250,
  Speed = 1100,
  Type = "Linear",
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
  if Hecarim.Q:IsReady() then
    qMana = Hecarim.Q:GetManaCost()
  elseif (Player.Health/Player.MaxHealth) * 100 < 20 then
    qMana = 0
  else
    qMana = 0
  end
  if Hecarim.W:IsReady() then
    wMana = Hecarim.W:GetManaCost()
  elseif (Player.Health/Player.MaxHealth) * 100 < 20 then
    wMana = 0
  else
    wMana = 0
  end
  if Hecarim.E:IsReady() then
    eMana = Hecarim.E:GetManaCost()
  elseif (Player.Health/Player.MaxHealth) * 100 < 20 then
    eMana = 0
  else
    eMana = 0
  end
  if Hecarim.R:IsReady() then
    rMana = Hecarim.R:GetManaCost()
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
    local HecarimUlt = TargetAi:GetBuff("chronoshift")

    if KindredUlt or TryndUlt or KayleUlt or HecarimUlt  or TargetAi.IsZombie or TargetAi.IsDead then
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

function Hecarim.GetQDmg(target)
  local playerAI = Player.AsAI
  local count = 0
  local buff = playerAI:GetBuff("hecarimrapidslash2")
  if buff then
    count = buff.Count
  end
  local dmgQ = 23 + 37 * Player:GetSpell(SpellSlots.Q).Level
  local bonusDmg = playerAI.BonusAD * 0.85
  local stackDmg =  (( 2 + playerAI.BonusAD * 0.03 ) /100) * count

  local totalDmg = (dmgQ + bonusDmg) + (dmgQ + bonusDmg) * stackDmg

  return DamageLib.CalculatePhysicalDamage(Player, target, totalDmg)
end

function Hecarim.LogicQ()
  local target = TS:GetTarget(Hecarim.Q.Range,false)
  if Utils.IsValidTarget(target) and Player.Mana > qMana + rMana then
    if Hecarim.Q:Cast() then return true end
  elseif Utils.IsValidTarget(target) and Hecarim.GetQDmg(target) >= target.Health then
    if Hecarim.Q:Cast() then return true end
  end
  if Laneclear then
    for k, v in pairs(ObjectManager.GetNearby("enemy", "minions")) do
      local minion = v.AsAI
      if Utils.ValidMinion(minion) and Player:Distance(minion.Position) < Hecarim.Q.Range then
        if Hecarim.Q:Cast() then return true end
      end
    end
    for k, v in pairs(ObjectManager.GetNearby("neutral", "minions")) do
      local minion = v.AsAI
      if Utils.ValidMinion(minion) and Player:Distance(minion.Position) < Hecarim.Q.Range then
        if Hecarim.Q:Cast() then return true end
      end
    end
  end
  return false
end

function Hecarim.LogicW()
  local target = TS:GetTarget(Hecarim.W.Range,false)
  if Utils.IsValidTarget(target) and Player.Mana > wMana + rMana and (Player.Health/Player.MaxHealth) * 100 < 95 then
    if Hecarim.W:Cast() then return true end
  end
  if Laneclear then
    for k, v in pairs(ObjectManager.GetNearby("enemy", "minions")) do
      local minion = v.AsAI
      if Utils.ValidMinion(minion) and Player:Distance(minion.Position) < Hecarim.W.Range then
        if Hecarim.W:Cast() then return true end
      end
    end
    if Menu.Get("jungleW") then
      for k, v in pairs(ObjectManager.GetNearby("neutral", "minions")) do
        local minion = v.AsAI
        if Utils.ValidMinion(minion) and Player:Distance(minion.Position) < Hecarim.W.Range then
          if Hecarim.W:Cast() then return true end
        end
      end
    end
  end
  return false
end

function Hecarim.LogicE()
  if Combo then
    if Hecarim.E:Cast() then return true end
  end
  return false
end

function Hecarim.LogicR()
  local enemies = {}
  for k, enemy in pairs(ObjectManager.GetNearby("enemy", "heroes")) do
    local target = enemy.AsHero
    local pos = target:FastPrediction(Game.GetLatency())
    if Utils.IsValidTarget(target) and Player:Distance(pos) < Hecarim.R.Range then
      table.insert(enemies, pos)
    end
  end
  if Utils.IsValidTarget(TS:GetTarget(Hecarim.R.Range,false)) then
    local rPred1 = Hecarim.R:GetPrediction(TS:GetTarget(Hecarim.R.Range,false))
    local rPosC , hitCount1 = Hecarim.R:GetBestCircularCastPos(enemies)
    local rPred2 = Hecarim.R1:GetPrediction(TS:GetTarget(Hecarim.R.Range,false))
    local rPosL , hitCount2 = Hecarim.R1:GetBestLinearCastPos(enemies)

    if Menu.Get("CastR") then
      if rPred1 and hitCount1 > 0 and hitCount1 < 2 and rPred1.HitChanceEnum >= HitChanceEnum.Medium then
        if Hecarim.R:Cast(rPred1.CastPosition) then return true end
      elseif rPred1 and hitCount1 >= 2 and rPred1.HitChanceEnum >= HitChanceEnum.Medium then
        if Hecarim.R:Cast(rPosC) then return true end
      end
      if rPred2 and hitCount2 > 0 and hitCount2 < 2 and rPred2.HitChanceEnum >= HitChanceEnum.Medium then
        if Hecarim.R:Cast(rPred1.CastPosition) then return true end
      elseif rPred2 and hitCount2 >= 2 and rPred2.HitChanceEnum >= HitChanceEnum.Medium then
        if Hecarim.R:Cast(rPosL) then return true end
      end
    end
    if Menu.Get("autoR") and Utils.IsValidTarget(TS:GetTarget(Hecarim.R.Range,false)) then
      if rPred1 and hitCount1 >= 3 and rPred1.HitChanceEnum >= HitChanceEnum.Medium and Utils.CountHeroes(rPosC,1000,"ally") > 1 then
        if Hecarim.R:Cast(rPosC) then return true end
      end
      if rPred2 and hitCount2 >= 3 and rPred2.HitChanceEnum >= HitChanceEnum.Medium and Utils.CountHeroes(rPosL,1000,"ally") > 1 then
        if Hecarim.R:Cast(rPosL) then return true end
      end
    end
  end
  return false
end

function Hecarim.OnUpdate()
  if not Utils.IsGameAvailable() then return false end
  if Utils.NoLag(0) then
    if Utils.SetMana() then return true end
  end
  if Utils.NoLag(1) and Hecarim.R:IsReady() then
    if Hecarim.LogicR() then return true end
  end
  if Utils.NoLag(2) and Hecarim.Q:IsReady() and Menu.Get("autoQ") then
    if Hecarim.LogicQ() then return true end
  end
  if Utils.NoLag(3) and Hecarim.W:IsReady() and Menu.Get("autoW") and not Orbwalker.IsWindingUp() then
    if Hecarim.LogicW() then return true end
  end
  if Utils.NoLag(4) and Hecarim.E:IsReady() and Menu.Get("autoE") and Player.Mana > eMana + rMana then
    if Hecarim.LogicE() then return true end
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
  if iTick > 4 then
    iTick = 0
  end
  return false
end

function Hecarim.OnDrawDamage(target, dmgList)
  if Menu.Get("DrawDmg") then
    if Hecarim.Q:IsReady() then
      table.insert(dmgList, Hecarim.GetQDmg(target))
    end
    if Hecarim.W:IsReady() then
      table.insert(dmgList, Hecarim.W:GetDamage(target))
    end
    if Hecarim.E:IsReady() then
      table.insert(dmgList, Hecarim.E:GetDamage(target))
    end
    if Hecarim.R:IsReady() then
      table.insert(dmgList, Hecarim.R:GetDamage(target))
    end
  end
end

function Hecarim.LoadMenu()
  local function HecarimMenu()
    Menu.ColumnLayout("Casting", "Casting", 2, true, function ()
    Menu.ColoredText("> Q", 0xB65A94FF, true)
    Menu.Checkbox("autoQ", "Auto Q", true)
    Menu.ColoredText("> W", 0x118AB2FF, true)
    Menu.Checkbox("autoW", "Auto W", true)
    Menu.Checkbox("jungleW", "Jungle W", false)
    Menu.ColoredText("> E", 0x0066CCFF, true)
    Menu.Checkbox("autoE", "Auto E", false)
    Menu.ColoredText("> R", 0xB65A94FF, true)
    Menu.Checkbox("autoR", "Auto R Aoe", true)
    Menu.Keybind("CastR", "Semi [R] Cast", string.byte('T'))
    Menu.ColoredText("Misc", 0xB65A94FC, true)
    Menu.Checkbox("DrawDmg", "Draw Damage", true)
    end)
  end
  if Menu.RegisterMenu("Simple Hecarim", "Simple Hecarim", HecarimMenu) then return true end
  return false
end

function OnLoad()
  Hecarim.LoadMenu()
  for EventName, EventId in pairs(Events) do
    if Hecarim[EventName] then
      EventManager.RegisterCallback(EventId, Hecarim[EventName])
    end
  end
  return true
end
