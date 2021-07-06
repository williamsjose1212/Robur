if Player.CharName ~= "Aphelios" then return end

module("Simple Aphelios", package.seeall, log.setup)
clean.module("Simple Aphelios", clean.seeall, log.setup)
local CoreEx = _G.CoreEx
local Libs = _G.Libs
local ScriptName, Version = "SimpleAphelios", "1.0.0"
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
local Aphelios = {}
local qMana = 0
local wMana = 0
local eMana = 0
local rMana = 0
local iTick = 0
local Combo,Harass,Laneclear,None = false,false,false,false
local target = nil
local OutRange = false
local CloseRange = false
local LowHp = false
local BeforeAA = false
local w1,w2,w3,w4,w5 = true,true,true,true,true
local q1Ready,q2Ready,q3Ready,q4Ready,q5Ready = false,false,false,false,false
local r1Ready,r2Ready,r3Ready,r4Ready,r5Ready = false,false,false,false,false
local range = 0
local CalibrumOff = "ApheliosOffHandBuffCalibrum"
local CalibrumOn = "ApheliosCalibrumManager"
local SeverumOff = "ApheliosOffHandBuffSeverum"
local SeverumOn = "ApheliosSeverumManager"
local GravitumOff = "ApheliosOffHandBuffGravitum"
local GravitumOn = "ApheliosGravitumManager"
local InfernumOff = "ApheliosOffHandBuffInfernum"
local InfernumOn = "ApheliosInfernumManager"
local CrescendumOff = "ApheliosOffHandBuffCrescendum"
local CrescendumOn = "ApheliosCrescendumManager"
local CalibrumDebuff = "aphelioscalibrumbonusrangedebuff"
local GravitumDebuff = "ApheliosGravitumDebuff"
local lastCalibrum = 0
local lastSeverum = 0
local lastGravitum = 0
local lastInfernum = 0
local lastCrescendum = 0

Aphelios.Q1 = SpellLib.Skillshot({
  Slot = SpellSlots.Q,
  Range = 1450,
  Delay = 0.4,
  Speed = 1850,
  Collisions = {Minions = true, WindWall = true },
  Radius = 100,
  Type = "Linear",
  Key = "Q"
})

Aphelios.Q2 = SpellLib.Active({
  Slot = SpellSlots.Q,
  Range = 550,
  Delay = 0.25,
  Key = "Q"
})

Aphelios.Q3 = SpellLib.Active({
  Slot = SpellSlots.Q,
  Range = math_huge,
  Key = "Q"
})

Aphelios.Q4 = SpellLib.Skillshot({
  Slot = SpellSlots.Q,
  Range = 650,
  Delay = 0.4,
  Radius = 300,
  Type = "Linear",
  Key = "Q"
})

Aphelios.Q5 = SpellLib.Skillshot({
  Slot = SpellSlots.Q,
  Range = 475,
  Delay = 1.0,
  Radius = 500,
  Type = "Circular",
  Key = "Q"
})

Aphelios.W = SpellLib.Active({
  Slot = SpellSlots.W,
  Key = "W"
})

Aphelios.R1 = SpellLib.Skillshot({
  Slot = SpellSlots.R,
  Range = 1300,
  Delay = 0.6,
  Speed = 2000,
  Radius = 150,
  Type = "Linear",
  Key = "R"
})

Aphelios.R2 = SpellLib.Skillshot({
  Slot = SpellSlots.R,
  Range = 1300,
  Delay = 0.6,
  Speed = 2000,
  Radius = 150,
  Type = "Circular",
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
  if Aphelios.Q:IsReady() then
    qMana = Aphelios.Q:GetManaCost()
  elseif (Player.Health/Player.MaxHealth) * 100 < 20 then
    qMana = 0
  else
    qMana = 0
  end
  if Aphelios.W:IsReady() then
    wMana = Aphelios.W:GetManaCost()
  elseif (Player.Health/Player.MaxHealth) * 100 < 20 then
    wMana = 0
  else
    wMana = 0
  end
  if Aphelios.E:IsReady() then
    eMana = Aphelios.E:GetManaCost()
  elseif (Player.Health/Player.MaxHealth) * 100 < 20 then
    eMana = 0
  else
    eMana = 0
  end
  if Aphelios.R:IsReady() then
    rMana = Aphelios.R:GetManaCost()
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
    local ApheliosUlt = TargetAi:GetBuff("chronoshift")

    if KindredUlt or TryndUlt or KayleUlt or ApheliosUlt  or TargetAi.IsZombie or TargetAi.IsDead then
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

function Utils.CountEnemiesInRange(pos, range, t)
  local res = 0
  for k, v in ipairs(t or ObjectManager.Get("enemy", "heroes")) do
    local hero = v.AsHero
    if hero and hero.IsTargetable and hero:Distance(pos) < range then
      res = res + 1
    end
  end
  return res
end

function Utils.CountHeroes(pos,Range,type)
  local num = 0
  for k, v in ipairs(ObjectManager.Get(type, "heroes")) do
    local hero = v.AsHero
    if hero and hero.IsTargetable and hero:Distance(pos.Position) < Range then
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

function Aphelios.PlayerLevel()
  if Player.Level == nil then
    return 0
  end
  if Player.Level >= 13 then
    return 7
  end
  if Player.Level >= 11 then
    return 6
  end
  if Player.Level >= 9 then
    return 5
  end
  if Player.Level >= 7 then
    return 4
  end
  if Player.Level >= 5 then
    return 3
  end
  if Player.Level >= 3 then
    return 2
  end
  if Player.Level > 1 then
    return 1
  end
  return 0
end

function Aphelios.CheckCd()
  if Player.Level == 1 or Player.Mana < 60 then return end
  if (Game.GetTime() - lastCalibrum > Aphelios.GetQ1CD()) or Aphelios.Q1:IsReady() then
    q1Ready = true
  else
    q1Ready = false
  end
  if (Game.GetTime() - lastSeverum > Aphelios.GetQ2CD()) or Aphelios.Q2:IsReady() then
    q2Ready = true
  else
    q2Ready = false
  end
  if (Game.GetTime() - lastGravitum > Aphelios.GetQ3CD()) or Aphelios.Q3:IsReady() then
    q3Ready = true
  else
    q3Ready = false
  end
  if (Game.GetTime() - lastInfernum > Aphelios.GetQ4CD()) or Aphelios.Q4:IsReady() then
    q4Ready = true
  else
    q4Ready = false
  end
  if (Game.GetTime() - lastCrescendum > Aphelios.GetQ5CD()) or Aphelios.Q5:IsReady() then
    q5Ready = true
  else
    q5Ready = false
  end
  return false
end

function Aphelios.GetQ1CD()
  if Player.Level == 1 then
    return math_huge
  end
  local list = {math_huge,10,9.67,9.33,9,8.67,8.33,8}

  return list[Aphelios.PlayerLevel()] - list[Aphelios.PlayerLevel()]*Player.PercentCooldownMod
end

function Aphelios.GetQ2CD()
  if Player.Level == 1 then
    return math_huge
  end
  local list = {math_huge,10,9.67,9.33,9,8.67,8.33,8}

  return list[Aphelios.PlayerLevel()] - list[Aphelios.PlayerLevel()]*Player.PercentCooldownMod
end
function Aphelios.GetQ3CD()
  if Player.Level == 1 then
    return math_huge
  end
  local list = {math_huge,12,11.67,11.33,11,10.67,10.33,10}

  return list[Aphelios.PlayerLevel()] - list[Aphelios.PlayerLevel()]*Player.PercentCooldownMod
end

function Aphelios.GetQ4CD()
  if Player.Level == 1 then
    return math_huge
  end
  local list = {math_huge,9,8.5,8,7.5,7,6.5,6}

  return list[Aphelios.PlayerLevel()] - list[Aphelios.PlayerLevel()]*Player.PercentCooldownMod
end

function Aphelios.GetQ5CD()
  if Player.Level == 1 then
    return math_huge
  end
  local list = {math_huge,9,8.5,8,7.5,7,6.5,6}

  return list[Aphelios.PlayerLevel()] - list[Aphelios.PlayerLevel()]*Player.PercentCooldownMod
end

function Aphelios.CheckMode()
  if Utils.HasBuff(Player,CalibrumOn) then
    range = Orbwalker.GetTrueAutoAttackRange(Player)-100
  else
    range = Orbwalker.GetTrueAutoAttackRange(Player)
  end
  target = TS:GetTarget(Orbwalker.GetTrueAutoAttackRange(Player)+600)
  if Utils.IsValidTarget(TS:GetTarget(range/1.5)) and (Player.Health/Player.MaxHealth) * 100 >= 40 and not LowHp then
    CloseRange = true
  else
    CloseRange = false
  end

  if Utils.IsValidTarget(target) and Player:Distance(target.Position) > range and not CloseRange then
    OutRange = true
  else
    OutRange = false
  end
  if Utils.IsValidTarget(TS:GetTarget(range)) and (Player.Health/Player.MaxHealth) * 100 < 40 and not CloseRange and not OutRange then
    LowHp = true
  else
    LowHp = false
  end
  return false
end

function Aphelios.CheckR()
  if Player.Level == 1 or Player.Mana < 100 then return end
  if Utils.HasBuff(Player,CalibrumOff) or Utils.HasBuff(Player,CalibrumOn) then
    r1Ready = true
  else
    r1Ready = false
  end
  if Utils.HasBuff(Player,SeverumOff) or Utils.HasBuff(Player,SeverumOn) then
    r2Ready = true
  else
    r2Ready = false
  end
  if Utils.HasBuff(Player,GravitumOff) or Utils.HasBuff(Player,GravitumOn) then
    r3Ready = true
  else
    r3Ready = false
  end
  if Utils.HasBuff(Player,InfernumOff) or Utils.HasBuff(Player,InfernumOn) then
    r4Ready = true
  else
    r4Ready = false
  end
  if Utils.HasBuff(Player,CrescendumOff) or Utils.HasBuff(Player,CrescendumOn) then
    r5Ready = true
  else
    r5Ready = false
  end
  return false
end

function Aphelios.CheckGun()
  for k, v in pairs(ObjectManager.Get("enemy", "heroes")) do
    local enemy = v.AsAI
    if Utils.IsValidTarget(enemy) then
      if Utils.HasBuff(Player,CalibrumOn) then
        if Aphelios.Q1:IsInRange(enemy) then
          local qPred = Aphelios.Q1:GetPrediction(enemy)
          if qPred and qPred.HitChanceEnum >= HitChanceEnum.High and q1Ready then
            w1 = false
          else
            w1 = true
          end
        end
      end
      if Utils.HasBuff(Player,SeverumOn) then
        if Aphelios.Q2:IsInRange(enemy) and q2Ready then
          w2 = false
        else
          w2 = true
        end
      end
      if Utils.HasBuff(Player,GravitumOn) then
        if Aphelios.Q3:IsInRange(enemy) and q3Ready and Utils.HasBuff(enemy,GravitumDebuff) then
          w3 = false
        else
          w3 = true
        end
      end
      if Utils.HasBuff(Player,InfernumOn) then
        if Aphelios.Q4:IsInRange(enemy) and q4Ready then
          w4 = false
        else
          w4 = true
        end
      end
      if Utils.HasBuff(Player,CrescendumOn) then
        if Player:Distance(enemy.Position) <= Aphelios.Q5.Range+200 and q5Ready then
          w5 = false
        else
          w5 = true
        end
      end
    end
  end
  return false
end

function Aphelios.LogicW()
  local qTarget = TS:GetTarget(Aphelios.Q1.Range+500)
  if None then return false end
  if Utils.IsValidTarget(qTarget) then
    if qTarget:Distance(Player.Position) > range then
      if q1Ready and Utils.HasBuff(Player,CalibrumOff) then
        local qPred = Aphelios.Q1:GetPrediction(qTarget)
        if qPred and qPred.HitChanceEnum >= HitChanceEnum.High and q1Ready then
          if Utils.HasBuff(Player,SeverumOn) and not Aphelios.Q2:IsInRange(qTarget) or not q2Ready then
            if Aphelios.W:Cast() then return true end
          end
          if Utils.HasBuff(Player,GravitumOn) and (not Aphelios.Q3:IsInRange(qTarget) and not Utils.HasBuff(qTarget,GravitumDebuff)) or not q3Ready then
            if Aphelios.W:Cast() then return true end
          end
          if Utils.HasBuff(Player,InfernumOn) and not Aphelios.Q4:IsInRange(qTarget) or not q4Ready then
            if Aphelios.W:Cast() then return true end
          end
          if Utils.HasBuff(Player,CrescendumOn) and not Utils.IsValidTarget(TS:GetTarget(600)) or not q5Ready then
            if Aphelios.W:Cast() then return true end
          end
        end
      end
    end
    if qTarget:Distance(Player.Position) <= range then
      if q2Ready and Utils.HasBuff(Player,SeverumOff) then
        if Utils.HasBuff(Player,CalibrumOn) then
          local qPred = Aphelios.Q1:GetPrediction(qTarget)
          if (not qPred or qPred.HitChanceEnum < HitChanceEnum.High) or not q1Ready then
            if Aphelios.W:Cast() then return true end
          end
        end
        if Utils.HasBuff(Player,GravitumOn) and (not Aphelios.Q3:IsInRange(qTarget) and not Utils.HasBuff(qTarget,GravitumDebuff)) or not q3Ready then
          if Aphelios.W:Cast() then return true end
        end
        if Utils.HasBuff(Player,InfernumOn) and not Aphelios.Q4:IsInRange(qTarget) or not q4Ready then
          if Aphelios.W:Cast() then return true end
        end
        if Utils.HasBuff(Player,CrescendumOn) and not Utils.IsValidTarget(TS:GetTarget(600)) or not q5Ready then
          if Aphelios.W:Cast() then return true end
        end
      end
      if q3Ready and Utils.HasBuff(Player,GravitumOff) and not Utils.HasBuff(qTarget,GravitumDebuff) then
        if Utils.HasBuff(Player,CalibrumOn) then
          local qPred = Aphelios.Q1:GetPrediction(qTarget)
          if (not qPred or qPred.HitChanceEnum < HitChanceEnum.High) or not q1Ready then
            if Aphelios.W:Cast() then return true end
          end
        end
        if Utils.HasBuff(Player,SeverumOn) and not Aphelios.Q2:IsInRange(qTarget) or not q2Ready then
          if Aphelios.W:Cast() then return true end
        end
        if Utils.HasBuff(Player,InfernumOn) and not Aphelios.Q4:IsInRange(qTarget) or not q4Ready then
          if Aphelios.W:Cast() then return true end
        end
        if Utils.HasBuff(Player,CrescendumOn) and not Utils.IsValidTarget(TS:GetTarget(600)) or not q5Ready then
          if Aphelios.W:Cast() then return true end
        end
      end
      if q4Ready and Utils.HasBuff(Player,InfernumOff) then
        if Utils.HasBuff(Player,CalibrumOn) then
          local qPred = Aphelios.Q1:GetPrediction(qTarget)
          if (not qPred or qPred.HitChanceEnum < HitChanceEnum.High) or not q1Ready then
            if Aphelios.W:Cast() then return true end
          end
        end
        if Utils.HasBuff(Player,SeverumOn) and not Aphelios.Q2:IsInRange(qTarget) or not q2Ready then
          if Aphelios.W:Cast() then return true end
        end
        if Utils.HasBuff(Player,GravitumOn) and (not Aphelios.Q3:IsInRange(qTarget) and not Utils.HasBuff(qTarget,GravitumDebuff)) or not q3Ready then
          if Aphelios.W:Cast() then return true end
        end
        if Utils.HasBuff(Player,CrescendumOn) and not Utils.IsValidTarget(TS:GetTarget(600)) or not q5Ready then
          if Aphelios.W:Cast() then return true end
        end
      end
      if q5Ready and Utils.HasBuff(Player,CrescendumOff) then
        if Utils.HasBuff(Player,CalibrumOn) then
          local qPred = Aphelios.Q1:GetPrediction(qTarget)
          if (not qPred or qPred.HitChanceEnum < HitChanceEnum.High) or not q1Ready then
            if Aphelios.W:Cast() then return true end
          end
        end
        if Utils.HasBuff(Player,SeverumOn) and not Aphelios.Q2:IsInRange(qTarget) or not q2Ready then
          if Aphelios.W:Cast() then return true end
        end
        if Utils.HasBuff(Player,InfernumOn) and not Aphelios.Q4:IsInRange(qTarget) or not q4Ready then
          if Aphelios.W:Cast() then return true end
        end
        if Utils.HasBuff(Player,GravitumOn) and (not Aphelios.Q3:IsInRange(qTarget) and not Utils.HasBuff(qTarget,GravitumDebuff)) or not q3Ready then
          if Aphelios.W:Cast() then return true end
        end
      end
    end
  end
  if OutRange then
    if Utils.HasBuff(Player,CalibrumOff) then
      if Utils.HasBuff(Player,SeverumOn) and w2 then
        if Aphelios.W:Cast() then return true end
      end
      if Utils.HasBuff(Player,GravitumOn) and w3 then
        if Aphelios.W:Cast() then return true end
      end
      if Utils.HasBuff(Player,InfernumOn) and w4 then
        if Aphelios.W:Cast() then return true end
      end
      if Utils.HasBuff(Player,CrescendumOn) and w5 then
        if Aphelios.W:Cast() then return true end
      end
    end
    if Utils.HasBuff(Player,SeverumOff) then
      if Utils.HasBuff(Player,InfernumOn) and w4 then
        if Aphelios.W:Cast() then return true end
      end
      if Utils.HasBuff(Player,CrescendumOn) and w5 then
        if Aphelios.W:Cast() then return true end
      end
    end
    if Utils.HasBuff(Player,GravitumOff) then
      if Utils.HasBuff(Player,SeverumOn) and w2 then
        if Aphelios.W:Cast() then return true end
      end
      if Utils.HasBuff(Player,InfernumOn) and w4 then
        if Aphelios.W:Cast() then return true end
      end
      if Utils.HasBuff(Player,CrescendumOn) and w5 then
        if Aphelios.W:Cast() then return true end
      end
    end
    if Utils.HasBuff(Player,InfernumOff) then
      if Utils.HasBuff(Player,CrescendumOn) and w5 then
        if Aphelios.W:Cast() then return true end
      end
    end
  end
  if LowHp then
    if Utils.HasBuff(Player,SeverumOff) then
      if Utils.HasBuff(Player,CalibrumOn) and w1 then
        if Aphelios.W:Cast() then return true end
      end
      if Utils.HasBuff(Player,GravitumOn) and w3 then
        if Aphelios.W:Cast() then return true end
      end
      if Utils.HasBuff(Player,InfernumOn) and w4 then
        if Aphelios.W:Cast() then return true end
      end
      if Utils.HasBuff(Player,CrescendumOn) and w5 then
        if Aphelios.W:Cast() then return true end
      end
    end
    if Utils.HasBuff(Player,GravitumOff) then
      if Utils.HasBuff(Player,CalibrumOn) and w1 then
        if Aphelios.W:Cast() then return true end
      end
      if Utils.HasBuff(Player,InfernumOn) and w4 then
        if Aphelios.W:Cast() then return true end
      end
      if Utils.HasBuff(Player,CrescendumOn) and w5 then
        if Aphelios.W:Cast() then return true end
      end
    end
    if Utils.HasBuff(Player,CrescendumOff) then
      if Utils.HasBuff(Player,InfernumOn) and w4 then
        if Aphelios.W:Cast() then return true end
      end
      if Utils.HasBuff(Player,CalibrumOn) and w1 then
        if Aphelios.W:Cast() then return true end
      end
    end
    if Utils.HasBuff(Player,InfernumOff) then
      if Utils.HasBuff(Player,CalibrumOn) and w1 then
        if Aphelios.W:Cast() then return true end
      end
    end
  end
  if CloseRange then
    if Utils.HasBuff(Player,CrescendumOff) then
      if Utils.HasBuff(Player,CalibrumOn) and w1 then
        if Aphelios.W:Cast() then return true end
      end
      if Utils.HasBuff(Player,SeverumOn) and w2 then
        if Aphelios.W:Cast() then return true end
      end
      if Utils.HasBuff(Player,GravitumOn) and w3 then
        if Aphelios.W:Cast() then return true end
      end
      if Utils.HasBuff(Player,InfernumOn) and w4 then
        if Aphelios.W:Cast() then return true end
      end
    end
    if Utils.HasBuff(Player,GravitumOff) then
      if Utils.HasBuff(Player,CalibrumOn) and w1 then
        if Aphelios.W:Cast() then return true end
      end
      if Utils.HasBuff(Player,SeverumOn) and w2 then
        if Aphelios.W:Cast() then return true end
      end
      if Utils.HasBuff(Player,InfernumOn) and w4 then
        if Aphelios.W:Cast() then return true end
      end
    end
    if Utils.HasBuff(Player,SeverumOff) then
      if Utils.HasBuff(Player,CalibrumOn) and w1 then
        if Aphelios.W:Cast() then return true end
      end
      if Utils.HasBuff(Player,InfernumOn) and w4 then
        if Aphelios.W:Cast() then return true end
      end
    end
    if Utils.HasBuff(Player,InfernumOff) then
      if Utils.HasBuff(Player,CalibrumOn) and w1 then
        if Aphelios.W:Cast() then return true end
      end
    end
  end
  if target ~= nil and (Player.Health/Player.MaxHealth) * 100 >= 40 and target:Distance(Player.Position) > range/1.5 and Utils.IsValidTarget(TS:GetTarget(range)) then
    if Utils.HasBuff(Player,InfernumOff) then
      if Utils.HasBuff(Player,CalibrumOn) and w1 then
        if Aphelios.W:Cast() then return true end
      end
      if Utils.HasBuff(Player,SeverumOn) and w2 then
        if Aphelios.W:Cast() then return true end
      end
      if Utils.HasBuff(Player,GravitumOn) and w3 then
        if Aphelios.W:Cast() then return true end
      end
      if Utils.HasBuff(Player,CrescendumOn) and w5 then
        if Aphelios.W:Cast() then return true end
      end
    end
    if Utils.HasBuff(Player,CrescendumOff) then
      if Utils.HasBuff(Player,CalibrumOn) and w1 then
        if Aphelios.W:Cast() then return true end
      end
      if Utils.HasBuff(Player,SeverumOn) and w2 then
        if Aphelios.W:Cast() then return true end
      end
      if Utils.HasBuff(Player,GravitumOn) and w3 then
        if Aphelios.W:Cast() then return true end
      end
    end
    if Utils.HasBuff(Player,GravitumOff) then
      if Utils.HasBuff(Player,CalibrumOn) and w1 then
        if Aphelios.W:Cast() then return true end
      end
      if Utils.HasBuff(Player,SeverumOn) and w2 then
        if Aphelios.W:Cast() then return true end
      end
    end
    if Utils.HasBuff(Player,CalibrumOff) then
      if Utils.HasBuff(Player,SeverumOn) and w2 then
        if Aphelios.W:Cast() then return true end
      end
    end
  end
  return false
end

function Aphelios.LogicR()
  if not None then
    local rTarget = TS:GetTarget(1300,false)
    if Utils.IsValidTarget(rTarget) then
      if rTarget.Health <= Aphelios.R1:GetDamage(rTarget) then
        if r4Ready then
          local rPred = Aphelios.R1:GetPrediction(rTarget)
          if Utils.HasBuff(Player,InfernumOn) then
            if rPred and rPred.HitChanceEnum >= HitChanceEnum.Medium then
              if Aphelios.R1:Cast(rPred.CastPosition) then return true end
            end
          else
            if Aphelios.W:Cast() then
              if rPred and rPred.HitChanceEnum >= HitChanceEnum.Medium then
                if Aphelios.R1:Cast(rPred.CastPosition) then return true end
              end
            end
          end
        elseif r5Ready then
          local rPred = Aphelios.R2:GetPrediction(rTarget)
          if Utils.HasBuff(Player,CrescendumOn) then
            if rPred and rPred.HitChanceEnum >= HitChanceEnum.Medium then
              if Aphelios.R2:Cast(rPred.CastPosition) then return true end
            end
          else
            if Aphelios.W:Cast() then
              if rPred and rPred.HitChanceEnum >= HitChanceEnum.Medium then
                if Aphelios.R2:Cast(rPred.CastPosition) then return true end
              end
            end
          end
        elseif r1Ready then
          local rPred = Aphelios.R2:GetPrediction(rTarget)
          if Utils.HasBuff(Player,CalibrumOn) then
            if rPred and rPred.HitChanceEnum >= HitChanceEnum.Medium then
              if Aphelios.R2:Cast(rPred.CastPosition) then return true end
            end
          else
            if Aphelios.W:Cast() then
              if rPred and rPred.HitChanceEnum >= HitChanceEnum.Medium then
                if Aphelios.R2:Cast(rPred.CastPosition) then return true end
              end
            end
          end
        elseif r3Ready then
          local rPred = Aphelios.R2:GetPrediction(rTarget)
          if Utils.HasBuff(Player,GravitumOn) then
            if rPred and rPred.HitChanceEnum >= HitChanceEnum.Medium then
              if Aphelios.R2:Cast(rPred.CastPosition) then return true end
            end
          else
            if Aphelios.W:Cast() then
              if rPred and rPred.HitChanceEnum >= HitChanceEnum.Medium then
                if Aphelios.R2:Cast(rPred.CastPosition) then return true end
              end
            end
          end
        elseif r2Ready then
          local rPred = Aphelios.R2:GetPrediction(rTarget)
          if Utils.HasBuff(Player,SeverumOn) then
            if rPred and rPred.HitChanceEnum >= HitChanceEnum.Medium then
              if Aphelios.R2:Cast(rPred.CastPosition) then return true end
            end
          else
            if Aphelios.W:Cast() then
              if rPred and rPred.HitChanceEnum >= HitChanceEnum.Medium then
                if Aphelios.R2:Cast(rPred.CastPosition) then return true end
              end
            end
          end
        end
      end
      if Utils.IsValidTarget(TS:GetTarget(range,false)) then
        local rPos, hitCount = Aphelios.R2:GetBestCircularCastPos(TS:GetTargets(range,false))
        if Utils.Count(range) >= 3 or hitCount >= 2 then
          if r4Ready then
            local rPred = Aphelios.R2:GetPrediction(TS:GetTarget(range,false))
            if Utils.HasBuff(Player,InfernumOn) then
              if rPred and rPred.HitChanceEnum >= HitChanceEnum.Medium then
                if Aphelios.R2:Cast(rPos) then return true end
              end
            else
              if Aphelios.W:Cast() then
                if rPred then
                  if Aphelios.R2:Cast(rPos) then return true end
                end
              end
            end
          elseif r3Ready then
            local rPred = Aphelios.R2:GetPrediction(TS:GetTarget(range,false))
            if Utils.HasBuff(Player,GravitumOn) then
              if rPred and rPred.HitChanceEnum >= HitChanceEnum.Medium then
                if Aphelios.R2:Cast(rPos) then return true end
              end
            else
              if Aphelios.W:Cast() then
                if rPred and rPred.HitChanceEnum >= HitChanceEnum.Medium then
                  if Aphelios.R2:Cast(rPos) then return true end
                end
              end
            end
          elseif r5Ready then
            local rPred = Aphelios.R2:GetPrediction(TS:GetTarget(range,false))
            if Utils.HasBuff(Player,CrescendumOn) then
              if rPred and rPred.HitChanceEnum >= HitChanceEnum.Medium then
                if Aphelios.R2:Cast(rPos) then return true end
              end
            else
              if Aphelios.W:Cast() then
                if rPred and rPred.HitChanceEnum >= HitChanceEnum.Medium then
                  if Aphelios.R2:Cast(rPos) then return true end
                end
              end
            end
          elseif r1Ready then
            local rPred = Aphelios.R2:GetPrediction(TS:GetTarget(range,false))
            if Utils.HasBuff(Player,CalibrumOn) then
              if rPred and rPred.HitChanceEnum >= HitChanceEnum.Medium then
                if Aphelios.R2:Cast(rPos) then return true end
              end
            else
              if Aphelios.W:Cast() then
                if rPred and rPred.HitChanceEnum >= HitChanceEnum.Medium then
                  if Aphelios.R2:Cast(rPos) then return true end
                end
              end
            end
          else
            if rPred and rPred.HitChanceEnum >= HitChanceEnum.Medium then
              if Aphelios.R2:Cast(rPos) then return true end
            end
          end
        end
      end
      if r1Ready then
        if rTarget:Distance(Player.Position) >= range then
          local rDmg = Aphelios.R1:GetDamage(rTarget)
          if rDmg > 0 then
            if rTarget.Health <= rDmg + DamageLib.GetAutoAttackDamage(rTarget)*2 then
              local rPred = Aphelios.R1:GetPrediction(rTarget)
              if rPred and rPred.HitChanceEnum >= HitChanceEnum.Medium then
                if Utils.HasBuff(Player,CalibrumOn) then
                  if Aphelios.R1:Cast(rPred.CastPosition) then return true end
                else
                  if Aphelios.W:Cast() then
                    if Aphelios.R1:Cast(rPred.CastPosition) then return true end
                  end
                end
              end
            end
          end
        end
        if r2Ready and r3Ready then
          if rTarget.Health <= 40 then
            local rPred = Aphelios.R2:GetPrediction(rTarget)
            if rPred and rPred.HitChanceEnum >= HitChanceEnum.Medium then
              if Utils.HasBuff(Player,GravitumOn) then
                if Aphelios.R2:Cast(rPred.CastPosition) then return true end
              else
                if Aphelios.W:Cast() then
                  if Aphelios.R2:Cast(rPred.CastPosition) then return true end
                end
              end
            end
          end
        end
        if r4Ready then
          local rPos, hitCount = Aphelios.R2:GetBestCircularCastPos(TS:GetTargets(1300,false))
          local rPred = Aphelios.R2:GetPrediction(rTarget)
          if rPred and rPred.HitChanceEnum >= HitChanceEnum.Medium then
            if hitCount >= 1 then
              if rTarget.Health < DamageLib.GetAutoAttackDamage(rTarget) * hitCount + Aphelios.R2:GetDamage(rTarget) then
                if Utils.HasBuff(Player,InfernumOn) then
                  if Aphelios.R2:Cast(rPred.CastPosition) then return true end
                else
                  if Aphelios.W:Cast() then
                    if Aphelios.R2:Cast(rPred.CastPosition) then return true end
                  end
                end
              end
            end
            if hitCount >= 3 then
              if Utils.HasBuff(Player,InfernumOn) then
                if Aphelios.R2:Cast(rPos) then return true end
              else
                if Aphelios.W:Cast() then
                  if Aphelios.R2:Cast(rPos) then return true end
                end
              end
            end
          end
          if r5Ready then
            if Utils.Count(range) > 2 then
              local rPred = Aphelios.R2:GetPrediction(rTarget)
              if rPred and rPred.HitChanceEnum >= HitChanceEnum.Medium then
                if Utils.HasBuff(Player,CrescendumOn) then
                  if Aphelios.R2:Cast(rPred.CastPosition) then return true end
                else
                  if Aphelios.W:Cast() then
                    if Aphelios.R2:Cast(rPred.CastPosition) then return true end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
  return false
end

function Aphelios.LogicQ()
  local qTarget = TS:GetTarget(Aphelios.Q1.Range)
  if Utils.IsValidTarget(qTarget) then
    if Combo or (Harass or Laneclear and Menu.Get("ManaSlider") <= Player.ManaPercent * 100) then
      if Utils.HasBuff(Player,CalibrumOn) and q1Ready then
        local qPred = Aphelios.Q1:GetPrediction(qTarget)
        if qPred and qPred.HitChanceEnum >= HitChanceEnum.High then
          if Aphelios.Q1:Cast(qPred.CastPosition) then return true end
        end
      end
      if target ~= nil and Utils.HasBuff(Player,SeverumOn) and q2Ready and Utils.IsValidTarget(target) and Aphelios.Q2:IsInRange(target) then
        if Aphelios.Q2:Cast() then return true end
      end
      if Utils.HasBuff(Player,GravitumOn) and q3Ready then
        for k, v in pairs(ObjectManager.Get("enemy", "heroes")) do
          local enemy = v.AsAI
          if Utils.HasBuff(enemy,GravitumDebuff) and Aphelios.Q3:IsInRange(enemy) then
            if Aphelios.Q3:Cast() then return true end
          end
        end
      end
      if Utils.HasBuff(Player,InfernumOn) and q4Ready then
        local qPred = Aphelios.Q4:GetPrediction(qTarget)
        if qPred and Aphelios.Q4:IsInRange(qTarget) and qPred.HitChanceEnum >= HitChanceEnum.High then
          if Aphelios.Q4:Cast(qPred.CastPosition) then return true end
        end
      end
      if Utils.HasBuff(Player,CrescendumOn) and q5Ready then
        local qPred = Aphelios.Q5:GetPrediction(qTarget)
        if qPred and Aphelios.Q5:IsInRange(qTarget) and qPred.HitChanceEnum >= HitChanceEnum.Low then
          if Aphelios.Q5:Cast(qPred.CastPosition) then return true end
        end
      end
    end
  end
  return false
end

function Aphelios.Clear()
  if Laneclear and Menu.Get("ManaSliderLane") <= Player.ManaPercent * 100 and Menu.Get("laneclearQ") then
    for k, v in pairs(ObjectManager.GetNearby("neutral", "minions")) do
      local minion = v.AsAI
      if Utils.HasBuff(Player,CalibrumOn) and q1Ready then
        local qPred = Aphelios.Q1:GetPrediction(minion)
        if qPred then
          if Aphelios.Q1:Cast(minion.Position) then return true end
        end
      end
      if Utils.HasBuff(Player,SeverumOn) and q2Ready and Aphelios.Q2:IsInRange(minion) then
        if Aphelios.Q2:Cast() then return true end
      end
      if Utils.HasBuff(Player,GravitumOn) and q3Ready then
        if Utils.HasBuff(minion,GravitumDebuff) and Aphelios.Q3:IsInRange(minion) then
          if Aphelios.Q3:Cast() then return true end
        end
      end
      if Utils.HasBuff(Player,InfernumOn) and q4Ready then
        local qPred = Aphelios.Q4:GetPrediction(minion)
        local qPos , hitCount = Aphelios.Q4:GetBestCircularCastPos(ObjectManager.GetNearby("neutral", "minions"))
        if qPred and Aphelios.Q4:IsInRange(minion) and qPred.HitChanceEnum >= HitChanceEnum.Low and hitCount >= 2 then
          if Aphelios.Q4:Cast(qPos) then return true end
        end
      end
      if Utils.HasBuff(Player,CrescendumOn) and q5Ready then
        local qPred = Aphelios.Q5:GetPrediction(minion)
        local qPos , hitCount = Aphelios.Q5:GetBestCircularCastPos(ObjectManager.GetNearby("neutral", "minions"))
        if qPred and Aphelios.Q5:IsInRange(minion) and qPred.HitChanceEnum >= HitChanceEnum.Low and hitCount >= 1 then
          if Aphelios.Q5:Cast(qPos) then return true end
        end
      end
    end
    for k, v in pairs(ObjectManager.GetNearby("enemy", "minions")) do
      local minion = v.AsAI

      if Utils.HasBuff(Player,SeverumOn) and q2Ready and Aphelios.Q2:IsInRange(minion) then
        if Aphelios.Q2:Cast() then return true end
      end
      if Utils.HasBuff(Player,InfernumOn) and q4Ready then
        local qPred = Aphelios.Q4:GetPrediction(minion)
        local qPos , hitCount = Aphelios.Q4:GetBestCircularCastPos(ObjectManager.GetNearby("enemy", "minions"))
        if qPred and Aphelios.Q4:IsInRange(minion) and qPred.HitChanceEnum >= HitChanceEnum.Low and hitCount >= 2 then
          if Aphelios.Q4:Cast(qPos) then return true end
        end
      end
      if Utils.HasBuff(Player,CrescendumOn) and q5Ready then
        local qPred = Aphelios.Q5:GetPrediction(minion)
        local qPos , hitCount = Aphelios.Q5:GetBestCircularCastPos(ObjectManager.GetNearby("enemy", "minions"))
        if qPred and Aphelios.Q5:IsInRange(minion) and qPred.HitChanceEnum >= HitChanceEnum.Low and hitCount >= 1 then
          if Aphelios.Q5:Cast(qPos) then return true end
        end
      end
    end
  end
  return false
end

function Aphelios.OnBasicAttack(sender,attack)
  if sender.IsMe then
    BeforeAA = true
  else
    BeforeAA = false
  end
  return false
end

function Aphelios.OnProcessSpell(sender,spell)
  if sender.IsMe then
    if spell.Name == "ApheliosCalibrumQ" then
      lastCalibrum = Game.GetTime()
    end
    if spell.Name == "ApheliosSeverumQ" then
      lastSeverum = Game.GetTime()
    end
    if spell.Name == "ApheliosGravitumQ" then
      lastGravitum = Game.GetTime()
    end
    if spell.Name == "ApheliosInfernumQ" then
      lastInfernum = Game.GetTime()
    end
    if spell.Name == "ApheliosCrescendumQ" then
      lastCrescendum = Game.GetTime()
    end
  end
  return false
end

function Aphelios.OnUpdate()
  if not Utils.IsGameAvailable() then return false end
  if Utils.NoLag(0) then
    Aphelios.CheckCd()
    Aphelios.CheckR()
    Aphelios.CheckMode()
    Aphelios.CheckGun()
  end
  for k, v in pairs(ObjectManager.Get("enemy", "heroes")) do
    local enemy = v.AsAI
    if Utils.HasBuff(enemy,CalibrumDebuff) and enemy:Distance(Player.Position) < 1800 then
      if Input.Attack(enemy) then return true end
    end
  end
  if Utils.NoLag(1) and Aphelios.W:IsReady() and Menu.Get("autoW") and (not BeforeAA and not Orbwalker.IsWindingUp()) then
    if Aphelios.LogicW() then return true end
  end
  if Utils.NoLag(2) and Menu.Get("autoR") then
    if Aphelios.LogicR() then return true end
  end
  if Utils.NoLag(3) and Menu.Get("autoQ") and (not BeforeAA and not Orbwalker.IsWindingUp()) and Player.Level > 1 then
    if Aphelios.LogicQ() then return true end
  end
  if Utils.NoLag(4) then
    if Aphelios.Clear() then return true end
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
  if OrbwalkerMode == "Waveclear" then
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

function Aphelios.LoadMenu()
  local function ApheliosMenu()
    Menu.ColumnLayout("Casting", "Casting", 2, true, function ()
    Menu.ColoredText("> Q", 0xB65A94FF, true)
    Menu.Checkbox("autoQ", "Auto Q", true)
    Menu.Checkbox("harassQ", "Harass Q", true)
    Menu.Checkbox("laneclearQ", "Laneclear Q", true)
    Menu.Checkbox("jungleclearQ", "JungleClear Q", true)
    Menu.ColoredText("> W", 0x118AB2FF, true)
    Menu.Checkbox("autoW", "Auto W", true)
    Menu.ColoredText("> R", 0xB65A94FF, true)
    Menu.Checkbox("autoR", "Auto R", true)
    Menu.ColoredText("Misc", 0xB65A94FC, true)
    Menu.ColoredText("Harass Mana Percent limit", 0xFFD700FF, true)
    Menu.Slider("ManaSlider","",50,0,100)
    Menu.ColoredText("Waveclear Mana Percent limit", 0xFFD700FF, true)
    Menu.Slider("ManaSliderLane","",50,0,100)
    end)
  end
  if Menu.RegisterMenu("Simple Aphelios", "Simple Aphelios", ApheliosMenu) then return true end
  return false
end

function OnLoad()
  Aphelios.LoadMenu()
  for EventName, EventId in pairs(Events) do
    if Aphelios[EventName] then
      EventManager.RegisterCallback(EventId, Aphelios[EventName])
    end
  end
  return true
end
