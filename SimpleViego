if Player.CharName ~= "Viego" then return end

module("Simple Viego", package.seeall, log.setup)
clean.module("Simple Viego", clean.seeall, log.setup)
local CoreEx = _G.CoreEx
local Libs = _G.Libs
local ScriptName, Version = "SimpleViego", "1.0.0"
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
local Viego = {}
local qMana = 0
local wMana = 0
local eMana = 0
local rMana = 0
local iTick = 0
local Combo,Harass,Laneclear,None = false,false,false, false
Viego.Q = SpellLib.Skillshot({
  Slot = SpellSlots.Q,
  Range = 600,
  Delay = 0.4,
  Radius = 70,
  Speed = math_huge,
  Type = "Linear",
  Key = "Q"
})

Viego.W = SpellLib.Chargeable({
  Slot = SpellSlots.W,
  Range = 700,
  Delay = 0,
  Radius = 70,
  Speed = 1500,
  MinRange = 500,
  MaxRange = 900,
  FullChargeTime = 3,
  ChargeStartTime = 0,
  ChargeSentTime = 0,
  ReleaseSentTime = 0,
  Key = "W"
})

Viego.E = SpellLib.Active({
  Slot = SpellSlots.E,
  Range = 700,
  Key = "E"
})

Viego.R = SpellLib.Skillshot({
  Slot = SpellSlots.R,
  Range = 500,
  Delay = 0.6,
  Speed = math_huge,
  Radius = 270,
  Type = "Circular",
  Key = "R"
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
  if Viego.Q:IsReady() then
    qMana = Viego.Q:GetManaCost()
  elseif (Player.Health/Player.MaxHealth) * 100 < 20 then
    qMana = 0
  else
    qMana = 0
  end
  if Viego.W:IsReady() then
    wMana = Viego.W:GetManaCost()
  elseif (Player.Health/Player.MaxHealth) * 100 < 20 then
    wMana = 0
  else
    wMana = 0
  end
  if Viego.E:IsReady() then
    eMana = Viego.E:GetManaCost()
  elseif (Player.Health/Player.MaxHealth) * 100 < 20 then
    eMana = 0
  else
    eMana = 0
  end
  if Viego.R:IsReady() then
    rMana = Viego.R:GetManaCost()
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
    local ViegoUlt = TargetAi:GetBuff("chronoshift")

    if KindredUlt or TryndUlt or KayleUlt or ViegoUlt  or TargetAi.IsZombie or TargetAi.IsDead then
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
  for k, v in pairs(ObjectManager.GetNearby(type, "minions")) do
    local minion = v.AsMinion
    if not minion.IsJunglePlant and minion.IsValid and not minion.IsDead and minion.IsTargetable and minion:Distance(pos) < maxRange then
      table.insert(minions, minion.Position)
    end
  end
  local spellPos, hitCount1 = spell:GetBestCircularCastPos(minions,width)
  return spellPos
end
function Utils.Count(spell)
  local num = 0
  for k, v in ipairs(ObjectManager.GetNearby("enemy", "heroes")) do
    local hero = v.AsHero
    if hero and hero.IsTargetable and hero:Distance(Player.Position) < spell.Range then
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

function Utils.CanKill(target,spell,dmg)
  local predHp = HPred.GetHealthPrediction(target,spell.Delay,false)
  if predHp < dmg then
    return true
  end
  return false
end

function Viego.LogicQ()
  local target = TS:GetTarget(Viego.Q.Range)
  local target2 = TS:GetTargets(Viego.Q.Range)
  if Utils.IsValidTarget(target) then
    local predQ = Viego.Q:GetPrediction(target)
    if Combo and predQ and predQ.HitChanceEnum >= HitChanceEnum.High then
      if Viego.Q:Cast(predQ.CastPosition) then return true end
    end
    if Harass and predQ and predQ.HitChanceEnum >= HitChanceEnum.High and not Utils.IsUnderTurret(target) then
      if Viego.Q:Cast(predQ.CastPosition) then return true end
    end
  end
  for k, target in pairs(target2) do
    if Utils.IsValidTarget(target) then
      local predQ = Viego.Q:GetPrediction(target)
      if Utils.CanKill(target,Viego.Q,Viego.GetDamageW(target)+Viego.GetDamageQ(target)) and predQ and predQ.HitChanceEnum >= HitChanceEnum.High then
        if Viego.Q:Cast(predQ.CastPosition) then return true end
      end
      if not Utils.CanMove(target) then
        if Viego.Q:Cast(target.Position) then return true end
      end
    end
  end
  return false
end


function Viego.LogicW()
  local target = TS:GetTarget(900)
  if Utils.IsValidTarget(target) then
    local wPred = Viego.W:GetPrediction(target)
    if Combo and not Utils.HasBuff(Player,"ViegoW") then
      if Viego.W:StartCharging() then return true end
    end
    if Combo and wPred and wPred.HitChanceEnum >= HitChanceEnum.High and Player:Distance(target.Position) < Viego.GetRangeW() and Viego.W.IsCharging then
      if Input.Release(SpellSlots.W, wPred.CastPosition) then return true end
    end
  end
  return false
end

function Viego.LogicE()

  return false
end

function Viego.LogicR()
  local target2 = TS:GetTargets(Viego.R.Range+Viego.R.Radius)
  for k, target in pairs(target2) do
    if Utils.IsValidTarget(target) then
      local predR = Viego.R:GetPrediction(target)
      if Utils.CanKill(target,Viego.R,Viego.GetDamageR(target) + 3 * DamageLib.GetAutoAttackDamage(target) + Viego.GetDamageQ(target) + Viego.GetDamageW(target)) and predR and predR.HitChanceEnum >= HitChanceEnum.Low then
        if Viego.R:Cast(predR.CastPosition) then return true end
      end
    end
  end
  return false
end

function Viego.GetDamageQ(target)
  local playerAI = Player.AsAI
  local dmgQ = 10 + 15 * Player:GetSpell(SpellSlots.Q).Level
  local bonusDmg = playerAI.TotalAD * 0.6
  local totalDmg = dmgQ + bonusDmg

  if target.IsMinion then
    totalDmg = totalDmg + 10
  end

  return DamageLib.CalculatePhysicalDamage(Player, target, totalDmg)
end

function Viego.GetDamageW(target)
  local playerAI = Player.AsAI
  local dmgW = (80 + Player:GetSpell(SpellSlots.W).Level * 55) * Player.TotalAP

  return DamageLib.CalculateMagicalDamage(Player, target, dmgW)
end

function Viego.GetDamageR(target)
  local playerAI = Player.AsAI
  local dmgR = playerAI.TotalAD * 1.2
  local bonusDmg = 0.10 + (0.05 * Player:GetSpell(SpellSlots.R).Level +(math.floor(playerAI.BonusAD/100) * 0.03 )) * target.Health
  local totalDmg = dmgR + bonusDmg
  return DamageLib.CalculatePhysicalDamage(Player, target, totalDmg)
end

function Viego.Jungle()
  if Laneclear then
    local monsters = Utils.CountMinionsInRange(Viego.Q.Range, "neutral")
    local minions = Utils.CountMinionsInRange(Viego.Q.Range, "enemy")
    if minions > monsters then
      local minionFocus = Utils.GetPriorityMinion(Player.Position, "enemy", 600)
      if minionFocus == nil then return false end
      if Viego.Q:IsReady() and Menu.Get("qFarm") then
        if Viego.Q:Cast(Utils.LinearCastMinionPos(Player.Position, "enemy", 600,Viego.Q,125)) then return true end
      end
    else
      local minionFocus = Utils.GetPriorityMinion(Player.Position, "neutral", 600)
      if minionFocus == nil then return false end
      if minionFocus.IsEpicMinion then
        if Viego.Q:IsReady() and Menu.Get("qFarm") then
          if Viego.Q:Cast(minionFocus.Position) then return true end
        end
        if Viego.W:IsReady() and Menu.Get("wFarm") then
          if Viego.W:Cast(minionFocus.Position) then return true end
        end
      else
        if Viego.Q:IsReady() and Menu.Get("qFarm") then
          if Viego.Q:Cast(Utils.LinearCastMinionPos(Player.Position, "neutral", 600,Viego.Q,125)) then return true end
        elseif Viego.W:IsReady() and Menu.Get("wFarm") and (not Viego.Q:IsReady() or minionFocus.IsScuttler) then
          if Viego.W:Cast(minionFocus.Position) then return true end
        end
      end
    end
  end
  return false
end
-- function Viego.OnSpellCast(sender,spell)
-- if sender.IsMe and not spell.IsBasicAttack then
-- if printf(spell.MissileSpeed) then return true end
-- end
-- return false
-- end
function Viego.OnDraw()
  if Player.IsVisible and Player.IsOnScreen and not Player.IsDead then
    local Pos = Player.Position
    local spells = {Viego.R}
    for k, v in ipairs(spells) do
      if Menu.Get("Drawing."..v.Key..".Enabled", true) then
        if Renderer.DrawCircle3D(Pos, v.Range, 30, 3, Menu.Get("Drawing."..v.Key..".Color")) then return true end
      end
    end
  end
  return false
end

function Viego.GetRangeW()
  if not Viego.W.IsCharging then return Viego.W.MinRange end
  local mod = (Game.GetTime() - Game.GetLatency()/1000 - Viego.W.ChargeStartTime)/Viego.W.FullChargeTime
  return math.min(Viego.W.MaxRange, Viego.W.MinRange + (Viego.W.MaxRange - Viego.W.MinRange)*mod)
end

function Viego.OnDrawDamage(target, dmgList)
  if Menu.Get("DrawDmg") then
    table.insert(dmgList, Viego.GetDamageQ(target))
    table.insert(dmgList, Viego.GetDamageW(target))
    if Viego.R:IsReady() then
      table.insert(dmgList, Viego.GetDamageR(target))
    end
  end
end

function Viego.OnUpdate()
  if not Utils.IsGameAvailable() then return false end
  if Utils.NoLag(0) and Player:GetSpell(SpellSlots.Q).Name == "ViegoQ" then
    if Viego.Jungle() then return true end
  end
  if Combo and Player:GetSpell(SpellSlots.Q).Name ~= "ViegoQ" then
    local qData = Player:GetSpell(SpellSlots.Q)
    local wData = Player:GetSpell(SpellSlots.W)
    local eData = Player:GetSpell(SpellSlots.E)
    local qTarget = TS:GetTarget(qData.CastRange)
    local wTarget = TS:GetTarget(wData.CastRange)
    local eTarget = TS:GetTarget(eData.CastRange)
    if qData.CastRange == 0 then
      if Input.Cast(SpellSlots.Q) then return true end
    end
    if wData.CastRange == 0 then
      if Input.Cast(SpellSlots.W) then return true end
    end
    if eData.CastRange == 0 then
      if Input.Cast(SpellSlots.E) then return true end
    end
    if Utils.IsValidTarget(qTarget) and Utils.NoLag(2) then
      if qData.LineWidth > 0  and qData.LineWidth <= 200 then
        Viego.Q2 = SpellLib.Skillshot({
          Slot = SpellSlots.Q,
          Range = qData.CastRange,
          Delay = 0.4,
          Radius = qData.LineWidth,
          Speed = math_huge,
          Type = "Linear",
          Key = "Q"
        })
        local qPred = Viego.Q2:GetPrediction(qTarget)
        if Viego.Q2:IsReady() and qPred and qPred.HitChanceEnum >= HitChanceEnum.High then
          if Viego.Q2:Cast(qPred.CastPosition) then return true end
        end
      elseif qData.LineWidth > 200 and qData.RemainingCooldown == 0 then
        if Input.Cast(SpellSlots.Q,qTarget.Position) then return true end
      elseif qData.RemainingCooldown == 0 then
        if Input.Cast(SpellSlots.Q,qTarget) then return true end
      end
    end
    if Utils.IsValidTarget(wTarget) and Utils.NoLag(4) then
      local wPred = wTarget:FastPrediction(0.4)
      if Player:GetSpell(SpellSlots.W).Name == "TaliyahW" then
        if Input.Cast(SpellSlots.W,Player.Position,wPred) then return true end
      elseif wData.LineWidth > 0 and wData.LineWidth <= 200 then
        Viego.W2 = SpellLib.Skillshot({
          Slot = SpellSlots.W,
          Range = wData.CastRange,
          Delay = 0.4,
          Radius = wData.LineWidth,
          Speed = math_huge,
          Type = "Linear",
          Key = "W"
        })
        local wPred = Viego.W2:GetPrediction(wTarget)
        if Viego.W2:IsReady() and wPred and wPred.HitChanceEnum >= HitChanceEnum.High then
          if Viego.W2:Cast(wPred.CastPosition) then return true end
        end
      elseif wData.LineWidth > 200 and wData.RemainingCooldown == 0 then
        if Input.Cast(SpellSlots.W,wTarget.Position) then return true end
      elseif wData.RemainingCooldown == 0 then
        if Input.Cast(SpellSlots.W,wTarget) then return true end
      end
    end
    if Utils.IsValidTarget(eTarget) and Utils.NoLag(3) then
      if eData.LineWidth > 0 and eData.LineWidth <= 200 then
        Viego.E2 = SpellLib.Skillshot({
          Slot = SpellSlots.E,
          Range = eData.CastRange,
          Delay = 0.4,
          Radius = eData.LineWidth,
          Speed = math_huge,
          Type = "Linear",
          Key = "E"
        })
        local ePred = Viego.E2:GetPrediction(eTarget)
        if Viego.E2:IsReady() and ePred and ePred.HitChanceEnum >= HitChanceEnum.High then
          if Viego.E2:Cast(ePred.CastPosition) then return true end
        end
      elseif eData.LineWidth > 200 and eData.RemainingCooldown == 0 then
        if Input.Cast(SpellSlots.E,eTarget.Position) and Input.Cast(SpellSlots.E) then return true end
      elseif eData.RemainingCooldown == 0 then
        if Input.Cast(SpellSlots.E,eTarget) and Input.Cast(SpellSlots.E) then return true end
      end
    end
  end
  if Utils.NoLag(1) and Viego.R:IsReady() and Menu.Get("autoR") then
    if Viego.LogicR() then return true end
  end
  if Utils.NoLag(2) and Viego.Q:IsReady() and Player:GetSpell(SpellSlots.Q).Name == "ViegoQ" and Menu.Get("autoQ") then
    if Viego.LogicQ() then return true end
  end
  if Utils.NoLag(3) and Viego.E:IsReady() and Player:GetSpell(SpellSlots.Q).Name == "ViegoQ" and Menu.Get("autoE") then
    if Viego.LogicE() then return true end
  end
  if Utils.NoLag(4) and Viego.W:IsReady() and Menu.Get("autoW") and Player:GetSpell(SpellSlots.Q).Name == "ViegoQ" then
    if Viego.LogicW() then return true end
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
  if OrbwalkerMode == "Waveclear" or OrbwalkerMode == "Lasthit" then
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

function Viego.LoadMenu()
  local function ViegoMenu()
    Menu.ColumnLayout("Casting", "Casting", 2, true, function ()
    Menu.ColoredText("> Q", 0xB65A94FF, true)
    Menu.Checkbox("autoQ", "Auto Q", false)
    Menu.ColoredText("> W", 0x118AB2FF, true)
    Menu.Checkbox("autoW", "Auto W", true)
    Menu.ColoredText("> E", 0x0066CCFF, true)
    Menu.Checkbox("autoE", "Auto E", true)
    Menu.ColoredText("> R", 0xB65A94FF, true)
    Menu.Checkbox("autoR", "Auto R", true)
    Menu.ColoredText("Farm", 0xB65A94FF, true)
    Menu.Checkbox("qFarm", "Q Farm", true)
    Menu.Checkbox("wFarm", "W Farm", true)
    Menu.Separator()
    Menu.ColoredText("Drawing", 0xB65A94FF, true)
    Menu.Checkbox("Drawing.R.Enabled","Draw [R] Range",true)
    Menu.ColorPicker("Drawing.R.Color", "Draw [R] Color", 0x118AB2FF)
    Menu.Checkbox("DrawDmg", "Draw Damage", true)
    end)
  end
  if Menu.RegisterMenu("Simple Viego", "Simple Viego", ViegoMenu) then return true end
  return false
end

function OnLoad()
  Viego.LoadMenu()
  for EventName, EventId in pairs(Events) do
    if Viego[EventName] then
      EventManager.RegisterCallback(EventId, Viego[EventName])
    end
  end
  return true
end
