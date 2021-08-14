if Player.CharName ~= "Ornn" then return end

module("Simple Ornn", package.seeall, log.setup)
clean.module("Simple Ornn", clean.seeall, log.setup)
local CoreEx = _G.CoreEx
local Libs = _G.Libs
local ScriptName, Version = "SimpleOrnn", "1.0.0"
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
local Ornn = {}
local qMana = 0
local wMana = 0
local eMana = 0
local rMana = 0
local iTick = 0
local Combo,Harass,Laneclear,None = false,false,false, false
local qPillar = {}
local rWave = {}

Ornn.Q = SpellLib.Skillshot({
  Slot = SpellSlots.Q,
  Range = 800,
  Delay = 0.25,
  Speed = math_huge,
  Radius = 50,
  Type = "Linear",
  Key = "Q"
})

Ornn.W = SpellLib.Skillshot({
  Slot = SpellSlots.W,
  Range = 500,
  Delay = 0.0,
  Speed = math_huge,
  Radius = 175,
  Type = "Circular",
  Key = "W"
})

Ornn.E = SpellLib.Skillshot({
  Slot = SpellSlots.E,
  Range = 800,
  Radius = 150,
  Delay = 0.35,
  Speed = 1600,
  Type = "Circular",
  Key = "E"
})

Ornn.R = SpellLib.Skillshot({
  Slot = SpellSlots.R,
  Range = 2550,
  Radius = 340,
  Delay = 0.5,
  Type = "Linear",
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
  if Ornn.Q:IsReady() then
    qMana = Ornn.Q:GetManaCost()
  elseif (Player.Health/Player.MaxHealth) * 100 < 20 then
    qMana = 0
  else
    qMana = 0
  end
  if Ornn.W:IsReady() then
    wMana = Ornn.W:GetManaCost()
  elseif (Player.Health/Player.MaxHealth) * 100 < 20 then
    wMana = 0
  else
    wMana = 0
  end
  if Ornn.E:IsReady() then
    eMana = Ornn.E:GetManaCost()
  elseif (Player.Health/Player.MaxHealth) * 100 < 20 then
    eMana = 0
  else
    eMana = 0
  end
  if Ornn.R:IsReady() then
    rMana = Ornn.R:GetManaCost()
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
    local OrnnUlt = TargetAi:GetBuff("chronoshift")

    if KindredUlt or TryndUlt or KayleUlt or OrnnUlt  or TargetAi.IsZombie or TargetAi.IsDead then
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

function Ornn.LogicQ()
  local target = TS:GetTarget(Ornn.Q.Range)
  if Utils.IsValidTarget(target) then
    if (Combo and Player.Mana > wMana + qMana and not Ornn.UltCharge()) or (Harass and Menu.Get("ManaSlider") <= Player.ManaPercent * 100 and Menu.Get("qHarass") and not Ornn.UltCharge()) then
      local qPred = Ornn.Q:GetPrediction(target)
      if not Utils.CanMove(target) then
        if Ornn.Q:Cast(target.Position) then return true end
      elseif qPred and qPred.HitChanceEnum >= HitChanceEnum.VeryHigh then
        if Ornn.Q:Cast(qPred.CastPosition) then return true end
      end
    end
  end
  if Laneclear and Player.Mana > qMana + wMana + eMana + rMana and Menu.Get("qLastHit") then
    local minionsQ = {}
    for k, v in pairs(ObjectManager.GetNearby("enemy", "minions")) do
      local minion = v.AsAI
      local minionInRange = minion and minion.MaxHealth > 6 and Ornn.Q:IsInRange(minion)
      local shouldIgnoreMinion = minion and (Orbwalker.IsLasthitMinion(minion) or Orbwalker.IsIgnoringMinion(minion))
      if minionInRange and not shouldIgnoreMinion and minion.IsTargetable  and Utils.IsValidTarget(minion) then
        table.insert(minionsQ, minion)
        table.sort(minionsQ, function(a, b) return a.MaxHealth > b.MaxHealth end)
      end
    end
    for k, minion in pairs(minionsQ) do
      local qPred = Ornn.Q:GetPrediction(minion)
      local delay = (Player:Distance(minion.Position)/Ornn.Q.Speed + Ornn.Q.Delay)
      local hpPred = HPred.GetHealthPrediction(minion,delay,false)
      if qPred and hpPred > 0 and hpPred < Ornn.GetDamageQ(minion) then
        if Ornn.Q:Cast(qPred.CastPosition) then return true end
      end
    end
  end
  return false
end

function Ornn.LogicW()
  local target = TS:GetTarget(Ornn.W.Range)
  if Utils.IsValidTarget(target) and not Utils.HasBuff(target,"OrnnVulnerableDebuff") and not Ornn.UltCharge() and (Player:Distance(target.Position) <= Orbwalker.GetTrueAutoAttackRange(Player)+Player.BoundingRadius or (target.Health/target.MaxHealth) * 100 < 30) then
    if (Combo and Player.Mana > wMana) or ((Harass or Laneclear) and Menu.Get("ManaSlider") <= Player.ManaPercent * 100) then
      local wPred = Ornn.W:GetPrediction(target)
      if not Utils.CanMove(target) then
        if Ornn.W:Cast(target.Position) then return true end
      elseif wPred and wPred.HitChanceEnum >= HitChanceEnum.VeryHigh then
        if Ornn.W:Cast(wPred.CastPosition) then return true end
      end
    end
  end
  return false
end

function Ornn.LogicE()
  local target = TS:GetTarget(Ornn.E.Range)
  if Utils.IsValidTarget(target) then
    if (Combo and Player.Mana > wMana + eMana and not Ornn.UltCharge()) or (Harass and Menu.Get("ManaSlider") <= Player.ManaPercent * 100 and not Utils.IsUnderTurret(target) and not Ornn.UltCharge()) then
      local ePred = Ornn.E:GetPrediction(target)
      if ePred and ePred.HitChanceEnum >= HitChanceEnum.VeryHigh then
        local tPos = ePred.TargetPosition
        for k,v in pairs(qPillar) do
          if tPos:Distance(v.Position) < 360 and Player:Distance(v.Position) <= Ornn.E.Range then
            if Ornn.E:Cast(v.Position) then return true end
          end
        end
        if Ornn.NearWall(target,tPos) and not Harass then
          if Ornn.E:Cast(Ornn.NearWall(target,tPos)) then return true end
        end
        if Ornn.GetDamageE(target) + Ornn.GetDamageW(target) > target.Health and Utils.CountEnemiesInRange(tPos, 900) < 3 and not Utils.IsUnderTurret(target) then
          if Ornn.E:Cast(ePred.CastPosition) then return true end
        end
      end
    end
  end
  return false
end

function Ornn.NearWall(target,pos)
  local distW = Ornn.E.Radius
  local eCircle = Geometry.Circle(pos, distW)
  local eCirclePoints = eCircle:GetPoints(10)
  local ePoints = {}

  for i,point in ipairs(eCirclePoints) do
    local dist = point:Distance(pos)
    if point:IsWall() and point:Distance(Player.Position) < Ornn.E.Range and dist < 360 then
      table.insert(ePoints, point)
    end
  end

  local ePos = nil
  for i,ePoint in ipairs(ePoints) do
    if ePos then
      local distEPos = ePos:Distance(pos)
      local dist = ePoint:Distance(pos)

      if dist < distEPos then
        ePos = ePoint
      end
    else
      ePos = ePoint
    end
  end

  if ePos then
    return ePos
  end
  return nil

end

function Ornn.UltCharge()
  local spellRName = Player:GetSpell(SpellSlots.R).Name
  if spellRName == "OrnnRCharge" then
    return true
  else
    return false
  end
end

function Ornn.LogicR()
  local enemies = {}
  for k, enemy in pairs(ObjectManager.GetNearby("enemy", "heroes")) do
    local target = enemy.AsHero
    local pos = target:FastPrediction(Game.GetLatency())
    if Utils.IsValidTarget(target) and Player:Distance(pos) < Ornn.R.Range then
      table.insert(enemies, pos)
    end
  end
  local target = TS:GetTarget(Ornn.R.Range)
  if Utils.IsValidTarget(target) then
    local rPred = Ornn.R:GetPrediction(target)
    local rPos , hitCount = Ornn.R:GetBestLinearCastPos(enemies)
    if Utils.CountHeroes(Player,1200,"ally") > 1 and Menu.Get("autoRaoe") then
      if not Ornn.UltCharge() and rPred  and  hitCount > 2 then
        if Ornn.R:Cast(target) then return true end
      end
    end
    for k,v in pairs(rWave) do
      if Player:Distance(v.Position) <= 400 then
        if Ornn.UltCharge() and hitCount > 0 and hitCount < 2 and rPred  then
          if Ornn.R:Cast(rPred.CastPosition) then return true end
        elseif Ornn.UltCharge() and hitCount >= 2 and rPred then
          if Ornn.R:Cast(rPos) then return true end
        end
      end
    end
  end
  return false
end

function Ornn.GetDamageQ(target)
  local playerAI = Player.AsAI
  local dmgQ = -5 + 25 * Player:GetSpell(SpellSlots.Q).Level
  local bonusDmg = playerAI.TotalAD * 1.1
  local totalDmg = dmgQ+bonusDmg

  return DamageLib.CalculatePhysicalDamage(Player, target, totalDmg)
end

function Ornn.GetDamageW(target)
  local playerAI = Player.AsAI
  local percentW = 11 + 1 * Player:GetSpell(SpellSlots.W).Level
  local dmgW = target.MaxHealth*(percentW/100)

  return DamageLib.CalculateMagicalDamage(Player, target, dmgW)
end

function Ornn.GetDamageE(target)
  local playerAI = Player.AsAI
  local dmgE = 35 + 45 * Player:GetSpell(SpellSlots.E).Level
  local bonusDmg = (playerAI.BonusArmor * 0.4)+(playerAI.BonusSpellBlock * 0.4)
  local totalDmg = dmgE+bonusDmg

  return DamageLib.CalculatePhysicalDamage(Player, target, totalDmg)
end

function Ornn.OnProcessSpell(sender,spell)
  if sender.IsHero and sender.IsEnemy and Player.Mana > wMana and Ornn.W:IsReady() and Player:Distance(sender.Position) < Ornn.W.Range and (not spell.IsBasicAttack or spell.IsSpecialAttack) then
    if  Utils.CanHit(Player,spell) then
      if Ornn.W:Cast(sender.Position) then return true end
    end
    if spell.Target and spell.Target.IsMe then
      if Ornn.W:Cast(sender.Position) then return true end
    end
  end
  return false
end
function Ornn.OnInterruptibleSpell(source, spell, danger, endT, canMove)
  if source.IsEnemy and Menu.Get("autoQ") and Ornn.Q:IsReady() and Player:Distance(source.Position) < Ornn.Q.Range and Utils.IsValidTarget(source) then
    if Ornn.Q:Cast(source.Position) then return true end
  end
  return false
end

function Ornn.OnCreateObject(obj)
  if obj ~= nil and obj.IsValid and obj.IsVisible and obj.Name == "Ornn_Base_Q_tar" then
    if table.insert(qPillar,obj) then return true end
  end
  if obj ~= nil and obj.IsValid and obj.IsVisible and obj.Name == "OrnnRWave" then
    if table.insert(rWave,obj) then return true end
  end
  return false
end

function Ornn.OnDeleteObject(obj)
  if obj ~= nil and obj.IsValid and obj.IsVisible and obj.Name == "Ornn_Base_Q_tar" then
    if table.remove(qPillar,Utils.tablefind(qPillar,obj)) then return true end
  end
  if obj ~= nil and obj.IsValid and obj.IsVisible and obj.Name == "OrnnRWave" then
    if table.remove(rWave,Utils.tablefind(rWave,obj))  then return true end
  end
  return false
end

function Ornn.OnDraw()
  if Player.IsVisible and Player.IsOnScreen and not Player.IsDead then
    local Pos = Player.Position
    local spells = {Ornn.Q}
    for k, v in ipairs(spells) do
      if Menu.Get("Drawing."..v.Key..".Enabled", true) then
        if Renderer.DrawCircle3D(Pos, v.Range, 30, 3, Menu.Get("Drawing."..v.Key..".Color")) then return true end
      end
    end
  end
  return false
end

function Ornn.OnDrawDamage(target, dmgList)
  if Menu.Get("DrawDmg") then
    if Ornn.Q:IsReady() then
      table.insert(dmgList, Ornn.GetDamageQ(target))
    end
    if Ornn.W:IsReady() then
      table.insert(dmgList, Ornn.GetDamageW(target))
    end
    if Ornn.E:IsReady() then
      table.insert(dmgList, Ornn.GetDamageE(target))
    end
  end
end

function Ornn.OnUpdate()
  if not Utils.IsGameAvailable() then return false end
  for k,v in pairs(qPillar) do
    if not v.IsValid then
      qPillar[k]=nil
    end
  end
  for k,v in pairs(rWave) do
    if not v.IsValid then
      rWave[k]=nil
    end
  end
  if Utils.NoLag(0) then
    if Utils.SetMana() then return true end
  end
  if Utils.NoLag(1) and Ornn.R:IsReady() and Menu.Get("autoR") then
    if Ornn.LogicR() then return true end
  end
  if Utils.NoLag(2) and Ornn.E:IsReady() and Menu.Get("autoE") and not Orbwalker.IsWindingUp() then
    if Ornn.LogicE() then return true end
  end
  if Utils.NoLag(3) and Ornn.Q:IsReady() and Menu.Get("autoQ") and not Orbwalker.IsWindingUp() then
    if Ornn.LogicQ() then return true end
  end
  if Utils.NoLag(4) and Ornn.W:IsReady() and Menu.Get("autoW") and not Orbwalker.IsWindingUp() then
    if Ornn.LogicW() then return true end
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

function Ornn.LoadMenu()
  local function OrnnMenu()
    Menu.ColumnLayout("Casting", "Casting", 2, true, function ()
    Menu.ColoredText("> Q", 0xB65A94FF, true)
    Menu.Checkbox("autoQ", "Auto Q", true)
    Menu.Checkbox("qHarass", "Q Harass", true)
    Menu.Checkbox("qLastHit", "Q LastHit", true)
    Menu.ColoredText("> W", 0x118AB2FF, true)
    Menu.Checkbox("autoW", "Auto W", true)
    Menu.ColoredText("> E", 0x0066CCFF, true)
    Menu.Checkbox("autoE", "Auto E", true)
    Menu.ColoredText("> R", 0xB65A94FF, true)
    Menu.Checkbox("autoR", "Auto recast R", true)
    Menu.Checkbox("autoRaoe", "Auto R aoe", true)
    Menu.ColoredText("Misc", 0xB65A94FC, true)
    Menu.ColoredText("Harass Mana Percent limit", 0xFFD700FF, true)
    Menu.Slider("ManaSlider","",50,0,100)
    Menu.Separator()
    Menu.ColoredText("Drawing", 0xB65A94FF, true)
    Menu.Checkbox("Drawing.Q.Enabled","Draw [Q] Range",true)
    Menu.ColorPicker("Drawing.Q.Color", "Draw [Q] Color", 0x118AB2FF)
    Menu.Checkbox("DrawDmg", "Draw Damage", true)
    end)
  end
  if Menu.RegisterMenu("Simple Ornn", "Simple Ornn", OrnnMenu) then return true end
  return false
end

function OnLoad()
  Ornn.LoadMenu()
  for EventName, EventId in pairs(Events) do
    if Ornn[EventName] then
      EventManager.RegisterCallback(EventId, Ornn[EventName])
    end
  end
  return true
end
