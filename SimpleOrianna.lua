if Player.CharName ~= "Orianna" then return end

module("Simple Orianna", package.seeall, log.setup)
clean.module("Simple Orianna", clean.seeall, log.setup)
local CoreEx = _G.CoreEx
local Libs = _G.Libs
local ScriptName, Version = "SimpleOrianna", "1.0.0"
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
local BestCoveringRectangle = Geometry.BestCoveringRectangle
local next = next
local Orianna = {}
local qMana = 0
local wMana = 0
local eMana = 0
local rMana = 0
local iTick = 0
local Combo,Harass,Laneclear,None = false,false,false, false
local eOnGround = {}
local qFive = {}
local Qobj = {}
local fullQ = false
local eIsOn = false
local BallPos = Vector(0,0,0)
Orianna.Q = SpellLib.Skillshot({
  Slot = SpellSlots.Q,
  Range = 895,
  Delay = 0.05,
  Speed = 1400,
  Radius = 70,
  Type = "Circular",
  Key = "Q"
})

Orianna.W = SpellLib.Active({
  Slot = SpellSlots.W,
  Range = 225,
  Key = "W"
})

Orianna.E = SpellLib.Targeted({
  Slot = SpellSlots.E,
  Range = 1120,
  Key = "E"
})

Orianna.R = SpellLib.Active({
  Slot = SpellSlots.R,
  Range = 400,
  Radius = 415,
  Delay = 0.4,
  Speed = math_huge,
  Key = "R"
})

Orianna.QR = SpellLib.Skillshot({
  Slot = SpellSlots.Q,
  Range = 800,
  Delay = 0.5,
  Speed = 1400,
  Radius = 415,
  Type = "Circular",
  Key = "Q"
})

local Utils = {}
local lastQ = 0

function Utils.IsGameAvailable()
  return not (
  Game.IsChatOpen()  or
  Game.IsMinimized() or
  Player.IsDead
  )
end

function Utils.SetMana()
  if Orianna.Q:IsReady() then
    qMana = Orianna.Q:GetManaCost()
  elseif (Player.Health/Player.MaxHealth) * 100 < 20 then
    qMana = 0
  else
    qMana = 0
  end
  if Orianna.W:IsReady() then
    wMana = Orianna.W:GetManaCost()
  elseif (Player.Health/Player.MaxHealth) * 100 < 20 then
    wMana = 0
  else
    wMana = 0
  end
  if Orianna.E:IsReady() then
    eMana = Orianna.E:GetManaCost()
  elseif (Player.Health/Player.MaxHealth) * 100 < 20 then
    eMana = 0
  else
    eMana = 0
  end
  if Orianna.R:IsReady() then
    rMana = Orianna.R:GetManaCost()
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
    local OriannaUlt = TargetAi:GetBuff("chronoshift")

    if KindredUlt or TryndUlt or KayleUlt or OriannaUlt  or TargetAi.IsZombie or TargetAi.IsDead then
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

function Utils.GetPriorityMinion(pos, type, maxRange)
  local minionFocus = nil
  for k, v in pairs(ObjectManager.GetNearby(type, "minions")) do
    local minion = v.AsMinion
    if not minion.IsJunglePlant and minion.IsValid and not minion.IsDead and minion.IsTargetable and minion:Distance(pos) < maxRange then
      if minionFocus == nil then
        minionFocus = minion
      elseif minionFocus.IsEpicMinion then
        minionFocus = minion
      elseif not minionFocus.IsEpicMinion and minionFocus.IsEliteMinion then
        minionFocus = minion
      elseif not minionFocus.IsEpicMinion and not minionFocus.IsEliteMinion then
        if minion.Health < minionFocus.Health or minionFocus:Distance(pos) > minion:Distance(pos) then
          minionFocus = minion
        end
      end
    end
  end
  return minionFocus
end

function Utils.LinearCastMinionPos(pos, type, maxRange,spell,width)
  local minions = {}
  local res = {hitCount = 0, spellPos = Vector(0,0,0) }
  for k, v in pairs(ObjectManager.GetNearby(type, "minions")) do
    local minion = v.AsMinion
    if not minion.IsJunglePlant and minion.IsValid and not minion.IsDead and minion.IsTargetable and minion:Distance(pos) < maxRange then
      table.insert(minions, minion.Position)
    end
  end
  res.spellPos, res.hitCount = spell:GetBestLinearCastPos(minions,width)
  return res
end

function Utils.CircularCastMinionPos(pos, type, maxRange,spell,width)
  local minions = {}
  local res = {hitCount = 0, spellPos = Vector(0,0,0)}
  for k, v in pairs(ObjectManager.GetNearby(type, "minions")) do
    local minion = v.AsMinion
    if not minion.IsJunglePlant and minion.IsValid and not minion.IsDead and minion.IsTargetable and minion:Distance(pos) < maxRange then
      table.insert(minions, minion.Position)
    end
  end
  res.spellPos, res.hitCount = spell:GetBestCircularCastPos(minions,width)
  return res
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

function Utils.SearchHeroes(startPos, endPos, width, speed, delay, minResults, allyOrEnemy, handlesToIgnore)
  local res = {Result = false, Positions = {}, Objects = {}}
  if type(handlesToIgnore) ~= "table" then handlesToIgnore = {} end
  if type(allyOrEnemy) ~= "string" or allyOrEnemy ~= "ally" then allyOrEnemy = "enemy" end

  local dist = startPos:Distance(endPos)
  local spellPath = Geometry.Path(startPos, endPos)
  for k, obj in pairs(ObjectManager.Get(allyOrEnemy, "heroes")) do
    if not handlesToIgnore[k] then
      local hero = obj.AsHero
      local pos = hero:FastPrediction(delay/1000 + hero:EdgeDistance(startPos)/speed)

      if pos:Distance(startPos) < dist and hero.IsTargetable then
        local isOnSegment, pointSegment, pointLine = pos:ProjectOn(startPos, endPos)
        local lineDist = pointSegment:Distance(pos)
        if isOnSegment and lineDist < (hero.BoundingRadius + width*0.5 + 25) then
          table.insert(res.Positions, pos:Extended(pointSegment, lineDist):SetHeight(startPos.y))
          table.insert(res.Objects, hero)
          if #res.Positions < minResults then
            res.Result = false
          else
            res.Result = true
          end
        end
      end
    end
  end
  return res
end

function Utils.CanHit(target,spell)
  if Utils.IsValidTarget(target) then
    local pred = target:FastPrediction(spell.CastDelay)
    if pred == nil then return false end
    if spell.LineWidth > 0 then
      local powCalc = (spell.LineWidth + target.BoundingRadius)^2
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
  if Utils.HasBuffType(target,BuffTypes.Charm) or Utils.HasBuffType(target,BuffTypes.Snare) or Utils.HasBuffType(target,BuffTypes.Stun) or Utils.HasBuffType(target,BuffTypes.Suppression) or Utils.HasBuffType(target,BuffTypes.Taunt) or Utils.HasBuffType(target,BuffTypes.Fear) or Utils.HasBuffType(target,BuffTypes.Knockup) or Utils.HasBuffType(target,BuffTypes.Knockback) then
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

function Utils.CanKill(target,delay,dmg)
  local predHp = HPred.GetHealthPrediction(target,delay,false)
  local incomingDamage = HPred.GetDamagePrediction(target,1,false)
  if incomingDamage > target.Health then return false end
  if predHp < dmg then
    return true
  end
  return false
end

function Orianna.CountEnemiesInRangeDelay(pos,range,delay)
  local count = 0
  local enemies = TS:GetTargets(1500)
  for k, target in pairs(enemies) do
    if Utils.IsValidTarget(target) then
      local pred = target:FastPrediction(delay)
      if pos:Distance(pred) < range then
        count = count + 1
      end
    end
  end
  return count
end

function Orianna.LogicQ()
  local target = TS:GetTarget(Orianna.Q.Range)
  if Utils.IsValidTarget(target) then
    local qDmg = DamageLib.CalculateMagicalDamage(Player, target, 30+30*Player.Level+0.5*Player.TotalAP)
    local wDmg = DamageLib.CalculateMagicalDamage(Player, target, 15+45*Player.Level+0.7*Player.TotalAP)
    local qPred = Orianna.Q:GetPrediction(target)
    if qDmg + wDmg > target.Health and qPred then
      if Orianna.Q:Cast(qPred.CastPosition) then return true end
    elseif Combo and Player.Mana > rMana + qMana - 10 and qPred and qPred.HitChanceEnum >= HitChanceEnum.High then
      if Orianna.Q:Cast(qPred.CastPosition) then return true end
    elseif Harass and Player.Mana > rMana + qMana + eMana + wMana and Menu.Get("qHarass") and qPred and qPred.HitChanceEnum >= HitChanceEnum.VeryHigh then
      if Orianna.Q:Cast(qPred.CastPosition) then return true end
    end
  elseif not Utils.IsValidTarget(target) and Menu.Get("autoW") and Player.Mana > Player.MaxMana * 0.95 then
    if Orianna.W:IsReady() and Utils.HasBuff(Player,"orianaghostself") then
      if Orianna.W:Cast() then return true end
    elseif Orianna.E:IsReady() and not Utils.HasBuff(Player,"orianaghostself") then
      if Orianna.E:Cast(Player) then return true end
    end
  end
  return false
end

function Orianna.LogicW()
  local enemies = TS:GetTargets(1500)
  for k, target in pairs(enemies) do
    if Utils.IsValidTarget(target) then
      if BallPos:Distance(target.Position) < 250 and Orianna.W:GetDamage(target) > target.Health then
        if Orianna.W:Cast() then return true end
      end
      if Orianna.CountEnemiesInRangeDelay(BallPos,Orianna.W.Range,0) > 0 and Player.Mana > rMana + wMana then
        if Orianna.W:Cast() then return true end
      end
      if not Combo and not Harass and Player.Mana > Player.MaxMana * 0.95 and Utils.HasBuff(Player,"orianaghostself") then
        if Orianna.W:Cast() then return true end
      end
    end
  end
  return false
end

function Orianna.LogicE()
  local target = TS:GetTarget(1300)
  if Player.Mana > eMana + rMana then
    for _, v in ipairs(ObjectManager.GetNearby("ally","heroes")) do
      local ally = v.AsHero
      local incomingDamage = HPred.GetDamagePrediction(ally,0.5,false)
      if Orianna.E:IsInRange(ally) and Menu.Get("1" .. ally.CharName) then
        if incomingDamage >= ally.Health * 0.15 then
          if Orianna.E:Cast(ally) then return true end
        end
        if Orianna.CountEnemiesInRangeDelay(BallPos,100,0.1) > 0 then
          if Orianna.E:Cast(ally) then return true end
        end
      end
    end
  end
  if Combo and Player.Mana > eMana + rMana and not Orianna.W:IsReady() then
    if Utils.IsValidTarget(target) then
      local castArea = target:Distance(Player.Position) * (Player.Position - target.Position) : Normalized() + target.Position
      if Orianna.E:Cast(Player) then return true end
    end
  end
  return false
end

function Orianna.LogicR()
  local enemies = {}
  for k, enemy in pairs(ObjectManager.GetNearby("enemy", "heroes")) do
    local target = enemy.AsHero
    local pos = target:FastPrediction(Orianna.QR.Delay)
    if Utils.IsValidTarget(target) and Player:Distance(pos) < 1200 then
      table.insert(enemies, pos)
    end
  end
  local targets = TS:GetTargets(1500)
  for k, target in pairs(targets) do
    if Utils.IsValidTarget(target) then
      if BallPos:Distance(target.Position) < Orianna.R.Radius and BallPos:Distance(target.Position) < Orianna.R.Radius then
        if Menu.Get("rKS") and Utils.CanKill(target,Orianna.R.Delay,Orianna.GetDamage(target)) then
          if Orianna.R:Cast() then return true end
        end
        if Menu.Get("rLifeSaver") and Player.Health < Utils.CountHeroes(Player.Position,800,"enemy") * Player.Level * 20 and Player:Distance(BallPos) > target:Distance(Player.Position) then
          if Orianna.R:Cast() then return true end
        end
      end
    end
  end
  if Orianna.Q:IsReady() and Player.Mana > qMana + rMana then
    local qrPos , hitCount = Orianna.QR:GetBestCircularCastPos(enemies)
    if hitCount >= Menu.Get("rCount") then
      local target = TS:GetTarget(Orianna.Q.Range)
      if Utils.IsValidTarget(target) then
        local qPred = Orianna.Q:GetPrediction(target)
        if qPred then
          if Orianna.Q:Cast(qrPos) then return true end
        end
      end
    end
  end
  return false
end

function Orianna.Farm()
  if Laneclear then
    local monsters = Utils.CountMinionsInRange(Orianna.Q.Range, "neutral")
    local minions = Utils.CountMinionsInRange(Orianna.Q.Range, "enemy")
    if minions > monsters and Player.Mana > qMana + wMana + eMana + rMana then
      local minionFocus = Utils.GetPriorityMinion(Player.Position, "enemy",Orianna.Q.Range)
      if minionFocus == nil then return false end
      local qDmg = DamageLib.CalculateMagicalDamage(Player, minionFocus, 30+30*Player.Level+0.5*Player.TotalAP)
      local hitCount = Utils.CircularCastMinionPos(Player.Position, "enemy",Orianna.Q.Range,Orianna.Q,175).hitCount
      local qPos = Utils.CircularCastMinionPos(Player.Position, "enemy", Orianna.Q.Range,Orianna.Q,175).spellPos
      if Orianna.Q:IsReady() and Menu.Get("qFarm") and Player:Distance(minionFocus) > Orbwalker.GetTrueAutoAttackRange() and minionFocus.Health < qDmg then
        if Orianna.Q:Cast(minionFocus.Position) then return true end
      end
      if Orianna.Q:IsReady() and hitCount >= 3 and Menu.Get("qFarm") and not Harass then
        if Orianna.Q:Cast(qPos) then return true end
      end
      if Orianna.W:IsReady() and hitCount >= 3 and Menu.Get("wFarm") and not Harass and  minionFocus:Distance(BallPos) <= Orianna.W.Range then
        if Orianna.W:Cast() then return true end
      end
    else
      local minionFocus = Utils.GetPriorityMinion(Player.Position, "neutral", Orianna.Q.Range)
      if minionFocus == nil then return false end
      if Orianna.Q:IsReady() and Player.Mana > qMana and Menu.Get("qFarm") then
        if Orianna.Q:Cast(Utils.CircularCastMinionPos(Player.Position, "enemy", Orianna.Q.Range,Orianna.Q,175).spellPos) then return true end
      end
      if Orianna.W:IsReady() and Menu.Get("wFarm") and not Harass and minionFocus:Distance(BallPos) <= Orianna.W.Range then
        if Orianna.W:Cast() then return true end
      end
    end
  end
  return false
end

function Orianna.OnProcessSpell(sender,spell)
  if sender.IsMe and spell.Name == "OrianaIzunaCommand" then
    BallPos = spell.EndPos
  end
  if sender.IsHero and sender.IsEnemy and Menu.Get("autoE") and Player.Mana > rMana + eMana and Orianna.E:IsReady() then
    for _, v in pairs(ObjectManager.GetNearby("ally","heroes")) do
      local ally = v.AsHero
      if Menu.Get("1" .. ally.CharName) and Orianna.E:IsInRange(ally) and Player:Distance(spell.EndPos) <= Orianna.E.Range then
        if Utils.CanHit(ally,spell) then
          if Orianna.E:Cast(ally) then return true end
        end
      end
      if spell.Target and spell.Target.IsHero and spell.Target.IsAlly and Orianna.E:IsInRange(spell.Target.AsHero) and Menu.Get("1" .. spell.Target.AsHero.CharName) then
        if Orianna.E:Cast(spell.Target.AsHero) then return true end
      end
    end
  end
  return false
end

function Orianna.OnInterruptibleSpell(source, spell, danger, endT, canMove)
  if source.IsEnemy and Menu.Get("OPTI") and Orianna.R:IsReady() and danger > 3  then
    if source:Distance(BallPos) <= Orianna.R.Radius then
      if Orianna.R:Cast() then return true end
    elseif Orianna.Q:IsReady() and Player.Mana > qMana + rMana and Utils.IsValidTarget(source) and Orianna.Q:IsInRange(source) then
      if Orianna.Q:Cast(source.Position) then return true end
    end
  end
  return false
end

function Orianna.GetDamage(target)
  local dmg = 0
  if Orianna.Q:IsReady()  and Orianna.Q:IsInRange(target) then
    dmg = dmg + DamageLib.CalculateMagicalDamage(Player, target, 30+30*Player.Level+0.5*Player.TotalAP)
  end
  if Orianna.W:IsReady() then
    dmg = dmg + DamageLib.CalculateMagicalDamage(Player, target, 15+45*Player.Level+0.7*Player.TotalAP)
  end
  if Player:Distance(target.Position) <= Orbwalker.GetTrueAutoAttackRange() then
    dmg = dmg + DamageLib.GetAutoAttackDamage(target,true)*2
  end
  if Orianna.R:IsReady() then
    dmg = dmg + DamageLib.CalculateMagicalDamage(Player, target, 125+75*Player.Level+0.8*Player.TotalAP)
  end
  return dmg
end

function Orianna.OnDrawDamage(target, dmgList)
  if Menu.Get("DrawDmg") then
    table.insert(dmgList, Orianna.GetDamage(target))
  end
end

function Orianna.OnDraw()
  if Player.IsVisible and Player.IsOnScreen and not Player.IsDead then
    local Pos = Player.Position
    local spells = {Orianna.Q}
    for k, v in pairs(spells) do
      if Menu.Get("Drawing."..v.Key..".Enabled", true) then
        if Renderer.DrawCircle3D(Pos, v.Range, 30, 3, Menu.Get("Drawing."..v.Key..".Color")) then return true end
      end
    end
  end
  return false
end

function Orianna.OnCastSpellt(args)
  if args.Slot == SpellSlots.R and Menu.Get("rBlock") and Orianna.CountEnemiesInRangeDelay(BallPos,Orianna.R.Radius,Orianna.R.Delay) == 0 then
    args.Process = false
  end
  return false
end

function Orianna.OnUpdate()
  if not Utils.IsGameAvailable() then return false end
  for _, v in pairs(ObjectManager.GetNearby("ally","heroes")) do
    local ally = v.AsHero
    if Utils.HasBuff(ally,"orianaghostself") or Utils.HasBuff(ally,"orianaghost") then
      BallPos = ally.Position
    end
  end
  if Orianna.CountEnemiesInRangeDelay(BallPos,Orianna.R.Radius,Orianna.R.Delay) >= Menu.Get("rCount") and Orianna.R:IsReady() then
    if Orianna.R:Cast() then return true end
  end
  if Utils.NoLag(0)  then
    if Orianna.Farm() then return true end
  end
  if Utils.NoLag(1) and Orianna.Q:IsReady() and Menu.Get("autoQ") then
    if Orianna.LogicQ() then return true end
  end
  if Utils.NoLag(2) and Orianna.E:IsReady() and Menu.Get("autoE") then
    if Orianna.LogicE() then return true end
  end
  if Utils.NoLag(3) and Orianna.W:IsReady() and Menu.Get("autoW")  then
    if Orianna.LogicW() then return true end
  end
  if Utils.NoLag(4) and Orianna.R:IsReady() then
    if Orianna.LogicR() then return true end
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
  if OrbwalkerMode == "Waveclear" or OrbwalkerMode == "Lasthit" or OrbwalkerMode == "Harass"  then
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

function Orianna.LoadMenu()
  local function OriannaMenu()
    Menu.ColumnLayout("Casting", "Casting", 2, true, function ()
    Menu.ColoredText("> Q", 0xB65A94FF, true)
    Menu.Checkbox("autoQ", "Auto Q", true)
    Menu.Checkbox("qHarass", "Q Harass", true)
    Menu.ColoredText("> W", 0x118AB2FF, true)
    Menu.Checkbox("autoW", "Auto W", true)
    Menu.ColoredText("> E", 0xB65A94FF, true)
    Menu.Checkbox("autoE", "Auto E", true)
    Menu.ColoredText("E Whitelist", 0x06D6A0FF, true)
    for _, Object in pairs(ObjectManager.Get("ally", "heroes")) do
      local Name = Object.AsHero.CharName
      Menu.Checkbox("1" .. Name, "Use on " .. Name, true)
    end
    Menu.ColoredText("> R", 0xB65A94FF, true)
    Menu.Slider("rCount", "[R] HitCount", 3, 1, 5)
    Menu.Checkbox("rKS", "R KS", true)
    Menu.Checkbox("rLifeSaver", "auto R life saver", true)
    Menu.Checkbox("rBlock", "Block R if 0 hit", true)
    Menu.Checkbox("OPTI", "OnPossibleToInterrupt R", true)
    Menu.ColoredText("Farm", 0xB65A94FF, true)
    Menu.Checkbox("qFarm", "Q Farm", true)
    Menu.Checkbox("wFarm", "W Farm", true)
    Menu.Separator()
    Menu.ColoredText("Drawing", 0xB65A94FF, true)
    Menu.Checkbox("DrawDmg", "Draw Damage", true)
    Menu.Checkbox("Drawing.Q.Enabled",   "Draw [Q] Range",true)
    Menu.ColorPicker("Drawing.Q.Color", "Draw [Q] Color", 0x118AB2FF)
    end)
  end
  if Menu.RegisterMenu("Simple Orianna", "Simple Orianna", OriannaMenu) then return true end
  return false
end

function OnLoad()
  Orianna.LoadMenu()
  for EventName, EventId in pairs(Events) do
    if Orianna[EventName] then
      EventManager.RegisterCallback(EventId, Orianna[EventName])
    end
  end
  return true
end
