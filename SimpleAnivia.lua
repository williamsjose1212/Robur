if Player.CharName ~= "Anivia" then return end

module("Simple Anivia", package.seeall, log.setup)
clean.module("Simple Anivia", clean.seeall, log.setup)
local CoreEx = _G.CoreEx
local Libs = _G.Libs
local ScriptName, Version = "SimpleAnivia", "1.0.0"
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
local Anivia = {}
local qMana = 0
local wMana = 0
local eMana = 0
local rMana = 0
local iTick = 0
local Combo,Harass,Laneclear,None = false,false,false, false
local Qobj = {}
local Robj = {}

Anivia.Q = SpellLib.Skillshot({
  Slot = SpellSlots.Q,
  Range = 1000,
  Delay = 0.25,
  Speed = 870,
  Radius = 220,
  Type = "Linear",
  Key = "Q"
})

Anivia.Q2 = SpellLib.Active({
  Slot = SpellSlots.Q,
  Range = 230,
  Key = "R"
})

Anivia.W = SpellLib.Skillshot({
  Slot = SpellSlots.W,
  Range = 950,
  Delay = 0.6,
  Radius = 1,
  Type = "Circular",
  Key = "W"
})

Anivia.E = SpellLib.Targeted({
  Slot = SpellSlots.E,
  Range = 600,
  Key = "E"
})

Anivia.R = SpellLib.Skillshot({
  Slot = SpellSlots.R,
  Range = 750,
  Delay = 0.5,
  Radius = 400,
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
  if Anivia.Q:IsReady() then
    qMana = Anivia.Q:GetManaCost()
  elseif (Player.Health/Player.MaxHealth) * 100 < 20 then
    qMana = 0
  else
    qMana = 0
  end
  if Anivia.W:IsReady() then
    wMana = Anivia.W:GetManaCost()
  elseif (Player.Health/Player.MaxHealth) * 100 < 20 then
    wMana = 0
  else
    wMana = 0
  end
  if Anivia.E:IsReady() then
    eMana = Anivia.E:GetManaCost()
  elseif (Player.Health/Player.MaxHealth) * 100 < 20 then
    eMana = 0
  else
    eMana = 0
  end
  if Anivia.R:IsReady() then
    rMana = Anivia.R:GetManaCost()
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
    local AniviaUlt = TargetAi:GetBuff("chronoshift")

    if KindredUlt or TryndUlt or KayleUlt or AniviaUlt  or TargetAi.IsZombie or TargetAi.IsDead then
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

function Anivia.LogicQ()
  local target = TS:GetTarget(Anivia.Q.Range)
  if Utils.IsValidTarget(target) and Anivia.Q:GetToggleState() == 1 then
    if Combo and Player.Mana > eMana + qMana then
      local qPred = Anivia.Q:GetPrediction(target)
      if qPred and qPred.HitChanceEnum >= HitChanceEnum.High then
        if Anivia.Q:Cast(qPred.CastPosition) then return true end
      end
    elseif Harass and Player.Mana > rMana + eMana + qMana + wMana then
      local qPred = Anivia.Q:GetPrediction(target)
      if qPred and qPred.HitChanceEnum >= HitChanceEnum.High then
        if Anivia.Q:Cast(qPred.CastPosition) then return true end
      end
    else
      local qDamage = Anivia.Q:GetDamage(target)
      local eDamage = Anivia.E:GetDamage(target)
      if qDamage > target.Health then
        local qPred = Anivia.Q:GetPrediction(target)
        if qPred and qPred.HitChanceEnum >= HitChanceEnum.High then
          if Anivia.Q:Cast(qPred.CastPosition) then return true end
        end
      elseif qDamage + eDamage > target.Health and Player.Mana > qMana + wMana then
        local qPred = Anivia.Q:GetPrediction(target)
        if qPred and qPred.HitChanceEnum >= HitChanceEnum.High then
          if Anivia.Q:Cast(qPred.CastPosition) then return true end
        end
      end
    end
    if None and Player.Mana > rMana + eMana then
      for k, enemy in ipairs(Utils.GetTargets(Anivia.Q)) do
        if Utils.IsValidTarget(enemy) and not Utils.CanMove(enemy) then
          if Anivia.Q:Cast(enemy.Position) then return true end
        end
      end
    end
  end
  return false
end

function Anivia.LogicW()
  if Combo and Player.Mana > rMana + eMana + wMana then
    local target = TS:GetTarget(Anivia.W.Range)
    for k, v in pairs(Qobj) do
      if Utils.IsValidTarget(target) and target:Distance(v.Position) < 350 then
        local pred = Anivia.W:GetPrediction(target)
        if pred and target:Distance(pred.CastPosition) > 100 then
          local pos = Player.Position:Extended(target.Position,Player:Distance(target.Position)+180)
          if  Player:Distance(pos) < Anivia.W.Range then
            if Anivia.W:Cast(pos) then return true end
          end
        end
      end
    end
    if Utils.IsValidTarget(target) and Player:Distance(target.Position) < Anivia.R.Range then
      local pred = Anivia.W:GetPrediction(target)
      if pred then
        local vec = Vector(pred.CastPosition.x - Player.Position.x,0,pred.CastPosition.z - Player.Position.z)
        local castBehind = pred.CastPosition + vec:Normalize()*125
        if Anivia.W:Cast(castBehind) then return true end
      end
    end
    if Utils.IsValidTarget(target) and (Player.Health/Player.MaxHealth)*100 < 40 then
      local pred = Anivia.W:GetPrediction(target)
      if pred then
        local pos = Player.Position:Extended(target.Position,Player:Distance(target.Position)-180)
        if Player:Distance(pos) < Anivia.W.Range then
          if Anivia.W:Cast(pos) then return true end
        end
      end
    end
  end
  return false
end

function Anivia.LogicE()
  local target = TS:GetTarget(Anivia.E.Range)
  if Utils.IsValidTarget(target) then
    local qCd = Anivia.Q:GetSpellData().RemainingCooldown
    local rCd = Anivia.R:GetSpellData().RemainingCooldown
    if Player.Level < 7 then
      rCd = 10
    end
    local eDmg = Anivia.E:GetDamage(target)
    if eDmg > target.Health then
      if Anivia.E:Cast(target) then return true end
    end
    if Utils.HasBuff(target,"aniviachilled") or (qCd >  Anivia.E:GetSpellData().RemainingCooldown - 1 and rCd > Anivia.E:GetSpellData().RemainingCooldown - 1) then
      if eDmg * 3 > target.Health then
        if Anivia.E:Cast(target) then return true end
      elseif Combo and (Utils.HasBuff(target,"aniviachilled") or Player.Mana > rMana + eMana) then
        if Anivia.E:Cast(target) then return true end
      elseif Harass and Player.Mana > rMana + eMana + qMana + wMana and not Utils.IsUnderTurret(Player) and Menu.Get("ManaSlider") <= Player.ManaPercent * 100 then
        if Anivia.E:Cast(target) then return true end
      end
    elseif Combo and Anivia.R:IsReady() and Player.Mana > rMana + eMana and next(Qobj) == nil then
      if Input.Cast(SpellSlots.R,target.Position) then return true end
    end
  end
  if not None and not Combo then
    if Anivia.FarmE() then return true end
  end
  return false
end

function Anivia.FarmE()
  if Menu.Get("laneE") then
    local minionsE = {}
    for k, v in pairs(ObjectManager.GetNearby("enemy", "minions")) do
      local minion = v.AsAI
      local minionInRange = minion and minion.MaxHealth > 6 and Anivia.E:IsInRange(minion)
      local shouldIgnoreMinion = minion and (Orbwalker.IsLasthitMinion(minion) or Orbwalker.IsIgnoringMinion(minion))
      if minionInRange and not shouldIgnoreMinion and minion.IsTargetable  and Utils.IsValidTarget(minion) then
        table.insert(minionsE, minion)
        table.sort(minionsE, function(a, b) return a.MaxHealth > b.MaxHealth end)
      end
    end
    for k, minion in pairs(minionsE) do
      local eDmg = Anivia.E:GetDamage(minion)*2
      if minion.Health < eDmg and Utils.HasBuff(minion,"aniviachilled") then
        if Anivia.E:Cast(minion) then return true end
      elseif minion.Health < Anivia.E:GetDamage(minion) and Player.Mana > rMana + eMana + qMana + wMana  then
        if Anivia.E:Cast(minion) then return true end
      end
    end
  end
  return false
end
function Anivia.LogicR()
  if next(Robj) == nil then
    local target = TS:GetTarget(Anivia.R.Range)
    if Utils.IsValidTarget(target) then
      local rDmg = Anivia.R:GetDamage(target)
      local eDmg = Anivia.E:GetDamage(target)
      if rDmg > target.Health then
        if Input.Cast(SpellSlots.R,target.Position) then return true end
      elseif Player.Mana > rMana + eMana and eDmg*2 + rDmg > target.Health then
        if Input.Cast(SpellSlots.R,target.Position) then return true end
      end
      if Combo and Player.Mana > rMana + eMana + qMana + wMana then
        if Input.Cast(SpellSlots.R,target.Position) then return true end
      end
    end
    if Menu.Get("laneR") and Laneclear then
      local points = {}
      local minions = ObjectManager.GetNearby("enemy", "minions")
      for i, minion in pairs(minions) do
        local minion = minion.AsAI
        if minion then
          local predPos = minion:FastPrediction(0.25)
          local dist = predPos:Distance(Player.Position)
          if dist <= Anivia.R.Range then
            points[#points + 1] = predPos
          end
        end
      end
      local bestPos, hitCount = Geometry.BestCoveringCircle(points, Anivia.R.Radius) --Anivia.R:GetBestCircularCastPos(minionsR, Anivia.R.Radius)
      if bestPos and hitCount >= 3 and Menu.Get("ManaSliderLane") <= Player.ManaPercent * 100 then
        if Input.Cast(SpellSlots.R,bestPos) then return true end
      end
    end
  elseif Menu.Get("laneR") then
    local points = {}
    local minions = ObjectManager.GetNearby("enemy", "minions")
    local monsters = ObjectManager.GetNearby("neutral", "minions")
    for i, minion in pairs(minions) do
      local minion = minion.AsAI
      if minion then
        local predPos = minion:FastPrediction(0.25)
        local dist = predPos:Distance(Player.Position)
        if dist <= Anivia.R.Range then
          points[#points + 1] = predPos
        end
      end
    end
    for i, monster in pairs(monsters) do
      local minion = monster.AsAI
      if minion then
        local predPos = minion:FastPrediction(0.25)
        local dist = predPos:Distance(Player.Position)
        if dist <= Anivia.R.Range then
          points[#points + 1] = predPos
        end
      end
    end
    local bestPos, hitCount = Geometry.BestCoveringCircle(points, Anivia.R.Radius) --Anivia.R:GetBestCircularCastPos(points, Anivia.R.Radius)
    if hitCount > 0 then
      if Menu.Get("ManaSliderLane") >= Player.ManaPercent * 100 then
        if Input.Cast(SpellSlots.R) then return true end
      end
    else
      if Input.Cast(SpellSlots.R) then return true end
    end
  else
    for k, v in pairs(Robj) do
      if not None and Utils.CountEnemiesInRange(Robj.Position, 470) == 0 or Player.Mana < eMana + qMana then
        if Input.Cast(SpellSlots.R) then return true end
      end
    end
  end
  return false
end

function Anivia.Jungle()
  if Laneclear then
    if Utils.CountMinionsInRange(Anivia.E.Range, "neutral") > 0 then
      local monsters = {}
      for k, v in pairs(ObjectManager.GetNearby("neutral", "minions")) do
        local minion = v.AsAI
        local minionInRange = minion and minion.MaxHealth > 6 and Anivia.E:IsInRange(minion)
        local shouldIgnoreMinion = minion and (Orbwalker.IsLasthitMinion(minion) or Orbwalker.IsIgnoringMinion(minion))
        if minionInRange and not shouldIgnoreMinion and minion.IsTargetable  and Utils.IsValidTarget(minion) then
          table.insert(monsters, minion)
          table.sort(monsters, function(a, b) return a.MaxHealth < b.MaxHealth end)
        end
      end
      for k, minion in pairs(monsters) do
        if Anivia.Q:IsReady() and Menu.Get("jungleQ") then
          if next(Qobj) ~= nil then
            for k, v in pairs(Qobj) do
              if Anivia.Q:GetToggleState() == 2 and minion:Distance(v.Position) < 230 then
                if Anivia.Q2:Cast() then return true end
              end
            end
          elseif Anivia.Q:GetToggleState() == 1 then
            if Anivia.Q:Cast(minion.Position) then return true end
          end
        end
        if Anivia.R:IsReady() and Menu.Get("jungleR") and next(Robj) == nil then
          if Input.Cast(SpellSlots.R,minion.Position) then return true end
        end
        if Anivia.E:IsReady() and Menu.Get("jungleE") and Utils.HasBuff(minion,"aniviachilled") then
          if Anivia.E:Cast(minion) then return true end
        end
      end
    end
  end
  return false
end

function Anivia.OnInterruptibleSpell(source, spell, danger, endT, canMove)
  if source.IsEnemy and Menu.Get("autoWI") and Anivia.W:IsReady() and Player:Distance(source.Position) < Anivia.W.Range and Utils.IsValidTarget(source) then
    if Anivia.W:Cast(source) then return true end
  end
  return false
end

function Anivia.OnGapclose(source,dash)
  if source.IsEnemy and source.IsHero and Utils.IsValidTarget(source) then
    if Menu.Get("autoQG") and Anivia.Q:IsReady() and Anivia.Q:GetToggleState() == 1 then
      if Player:Distance(source.Position) <= 300 then
        if Anivia.Q:Cast(source) then return true end
      end
    elseif Menu.Get("autoWG") and Anivia.W:IsReady() then
      if Player:Distance(source.Position) < Anivia.W.Range then
        if Anivia.W:Cast(source) then return true end
      end
    end
  end
  return false
end

function Anivia.OnCreateObject(obj)
  if obj ~= nil and obj.IsValid and obj.IsMissile and obj.AsMissile.Caster.AsHero == Player then
    if obj.Name == "FlashFrostSpell" then
      if table.insert(Qobj,obj) then return true end
    end
  end
  if obj ~= nil and obj.IsValid and string.find(obj.Name,"R_indicator_ring") and string.find(obj.Name,"Anivia")  then
    if table.insert(Robj,obj) then return true end
  end
  return false
end

function Anivia.OnDeleteObject(obj)
  if obj ~= nil and obj.IsValid and obj.IsMissile and obj.AsMissile.Caster.AsHero == Player then
    if obj.Name == "FlashFrostSpell" then
      if table.remove(Qobj,Utils.tablefind(Qobj,obj)) then return true end
    end
  end
  if obj ~= nil and obj.IsValid and string.find(obj.Name,"R_indicator_ring") and string.find(obj.Name,"Anivia")  then
    if table.remove(Robj,Utils.tablefind(Robj,obj)) then return true end
  end
  return false
end

function Anivia.OnPreAttack(args)
  if Menu.Get("comboAA") and Anivia.E:IsReady() and args.Target.IsHero then
    args.Process = false
    if args.Process == false then return true end
  else
    args.Process = true
    if args.Process == true then return true end
  end
  return false
end

function Anivia.OnDraw()
  if Player.IsVisible and Player.IsOnScreen and not Player.IsDead then
    local Pos = Player.Position
    local spells = {Anivia.Q,Anivia.W,Anivia.E,Anivia.R}
    for k, v in ipairs(spells) do
      if Menu.Get("Drawing."..v.Key..".Enabled", true) then
        if Renderer.DrawCircle3D(Pos, v.Range, 30, 3, Menu.Get("Drawing."..v.Key..".Color")) then return true end
      end
    end
  end
  return false
end
function Anivia.OnUpdate()
  if not Utils.IsGameAvailable() then return false end
  for k,v in pairs(Qobj) do
    if not v.IsValid then
      Qobj[k]=nil
    end
  end
  for k,v in pairs(Robj) do
    if not v.IsValid then
      Robj[k]=nil
    end
  end
  for k, v in pairs(Qobj) do
    for k, enemy in pairs(ObjectManager.GetNearby("enemy", "heroes")) do
      if Anivia.Q:IsReady() and Anivia.Q:GetToggleState() == 2 and enemy:Distance(v.Position) < 230 then
        if Anivia.Q2:Cast() then return true end
      end
    end
  end
  if Utils.NoLag(0) then
    if Utils.SetMana() then return true end
  end
  if Utils.NoLag(1) and Anivia.R:IsReady() and Menu.Get("autoR") then
    if Anivia.LogicR() then return true end
  end
  if Utils.NoLag(2) and Anivia.W:IsReady() and Menu.Get("autoW") then
    if Anivia.LogicW() then return true end
  end
  if Utils.NoLag(3) and Anivia.Q:IsReady() and Menu.Get("autoQ") then
    if Anivia.LogicQ() then return true end
  end
  if Utils.NoLag(4) then
    if Anivia.E:IsReady() and Menu.Get("autoE") then
      if Anivia.LogicE() then return true end
    end
    if Anivia.Jungle() then return true end
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

function Anivia.LoadMenu()
  local function AniviaMenu()
    Menu.ColumnLayout("Casting", "Casting", 2, true, function ()
    Menu.ColoredText("> Q", 0xB65A94FF, true)
    Menu.Checkbox("autoQ", "Auto Q", true)
    Menu.Checkbox("autoQG", "Q Gapclose", true)
    Menu.Checkbox("harassQ", "Harass Q", true)
    Menu.Checkbox("jungleQ", "Jungle Q", true)
    Menu.ColoredText("> W", 0x118AB2FF, true)
    Menu.Checkbox("autoW", "Auto W", true)
    Menu.Checkbox("autoWG", "W Gaplose", false)
    Menu.Checkbox("autoWI", "W Interrupt", true)
    Menu.ColoredText("> E", 0x0066CCFF, true)
    Menu.Checkbox("autoE", "Auto E", true)
    Menu.ColoredText("Harass Mana Percent limit", 0xFFD700FF, true)
    Menu.Slider("ManaSlider","",50,0,100)
    Menu.Checkbox("laneE", "Farm E", true)
    Menu.Checkbox("jungleE", "Jungle E", true)
    Menu.ColoredText("> R", 0xB65A94FF, true)
    Menu.Checkbox("autoR", "Auto R", true)
    Menu.Checkbox("laneR", "Farm R", true)
    Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
    Menu.Slider("ManaSliderLane","",35,0,100)
    Menu.Checkbox("jungleR", "Jungle R", true)
    Menu.ColoredText("Misc", 0xB65A94FC, true)
    Menu.Checkbox("comboAA", "Disable AA when E", true)
    Menu.Separator()
    Menu.ColoredText("Drawing", 0xB65A94FF, true)
    Menu.Checkbox("Drawing.Status",   "Draw Harass Status",true)
    Menu.Checkbox("Drawing.Q.Enabled",   "Draw [Q] Range",true)
    Menu.ColorPicker("Drawing.Q.Color", "Draw [Q] Color", 0x118AB2FF)
    Menu.Checkbox("Drawing.E.Enabled",   "Draw [E] Range",false)
    Menu.ColorPicker("Drawing.E.Color", "Draw [E] Color", 0x118AB2FF)
    Menu.Checkbox("Drawing.R.Enabled",   "Draw [R] Range",false)
    Menu.ColorPicker("Drawing.R.Color", "Draw [R] Color", 0x118AB2FF)
    end)
  end
  if Menu.RegisterMenu("Simple Anivia", "Simple Anivia", AniviaMenu) then return true end
  return false
end

function OnLoad()
  Anivia.LoadMenu()
  for EventName, EventId in pairs(Events) do
    if Anivia[EventName] then
      EventManager.RegisterCallback(EventId, Anivia[EventName])
    end
  end
  return true
end
