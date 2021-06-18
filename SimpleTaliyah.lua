if Player.CharName ~= "Taliyah" then return end

module("Simple Taliyah", package.seeall, log.setup)
clean.module("Simple Taliyah", clean.seeall, log.setup)
local CoreEx = _G.CoreEx
local Libs = _G.Libs
local ScriptName, Version = "SimpleTaliyah", "1.0.0"
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
local Taliyah = {}
local qMana = 0
local wMana = 0
local eMana = 0
local rMana = 0
local overkill = 0
local eOnGround = {}
local qFive = {}
local Qobj = {}
local fullQ = false
local eIsOn = false
Taliyah.Q = SpellLib.Skillshot({
  Slot = SpellSlots.Q,
  Range = 1000,
  Delay = 0.25,
  Speed = 3600,
  Radius = 100,
  Collisions = {Heroes = true, Minions = true, WindWall = true },
  Type = "Linear",
  UseHitbox = true,
  Key = "Q"
})

Taliyah.W = SpellLib.Skillshot({
  Slot = SpellSlots.W,
  Range = 900,
  Delay = 1,
  Radius = 200,
  Type = "Circular",
  Key = "W"
})

Taliyah.E = SpellLib.Skillshot({
  Slot = SpellSlots.E,
  Range = 800,
  Radius = 450,
  Collisions = {Wall = true},
  Delay = 0.25,
  Type = "Cone",
  Key = "E"
})

Taliyah.R = SpellLib.Skillshot({
  Slot = SpellSlots.R,
  Range = 4000,
  Delay = 1,
  Radius = 160,
  Speed = 2000,
  Type = "Linear",
  Collisions = {WindWall = true },
  UseHitbox = true,
  Key = "R"
})

Taliyah.TargetSelector = nil
Taliyah.Logic = {}

local Utils = {}
local IsInTurret = false

function Utils.IsGameAvailable()
  return not (
  Game.IsChatOpen()  or
  Game.IsMinimized() or
  Player.IsDead
  )
end

function Utils.SetMana()
  if (Player.Health/Player.MaxHealth) * 100 < 20 then
    qMana = 0
    wMana = 0
    eMana = 0
    rMana = 0
    return true
  end
  if Taliyah.Q:IsReady() then
    qMana = Taliyah.Q:GetManaCost()
  else
    qMana = 0
  end
  if Taliyah.W:IsReady() then
    wMana = Taliyah.W:GetManaCost()
  else
    wMana = 0
  end
  if Taliyah.E:IsReady() then
    eMana = Taliyah.E:GetManaCost()
  else
    eMana = 0
  end
  if Taliyah.R:IsReady() then
    rMana = Taliyah.R:GetManaCost()
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
    local ZileanUlt = TargetAi:GetBuff("chronoshift")

    if KindredUlt or TryndUlt or KayleUlt or ZileanUlt  or TargetAi.IsZombie or TargetAi.IsDead then
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
  for k, v in pairs(ObjectManager.GetNearby("enemy", "heroes")) do
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
  for k, v in pairs(ObjectManager.GetNearby(type, "minions")) do
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
  for k, v in pairs(t or ObjectManager.Get("enemy", "heroes")) do
    local hero = v.AsHero
    if hero and hero.IsTargetable and hero:Distance(pos) < range then
      res = res + 1
    end
  end
  return res
end

function Utils.CountHeroes(pos,Range,type)
  local num = 0
  for k, v in pairs(ObjectManager.Get(type, "heroes")) do
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

function Utils.GetDamage(target)
  local dmg = 0
  if Taliyah.Q:IsReady() then
    dmg = dmg + Taliyah.Q:GetDamage(target)
  end
  if Taliyah.W:IsReady() then
    dmg = dmg + Taliyah.W:GetDamage(target) + Taliyah.Q:GetDamage(target)
  end
  if Taliyah.E:IsReady() then
    dmg = dmg + Taliyah.E:GetDamage(target) + Taliyah.Q:GetDamage(target)
  end
  return dmg
end

function Taliyah.Logic.Combo()
  local MenuValueQ = Menu.Get("Combo.Q")
  local MenuValueW = Menu.Get("Combo.W")
  local MenuValueE = Menu.Get("Combo.E")
  if MenuValueW and Taliyah.W:IsReady() and Player.Mana > wMana + eMana then
    for k, enemy in ipairs(Utils.GetTargets(Taliyah.W)) do
      local hpPred = HPred.GetHealthPrediction(enemy,0.25,false)
      local incomingDamage = HPred.GetDamagePrediction(Player,1,false)
      local enemies = Utils.CountHeroes(Player,700,"enemy")
      local wPred = Taliyah.W:GetPrediction(enemy)
      local wPredPos , wHitCount = Taliyah.W:GetBestCircularCastPos(Utils.GetTargets(Taliyah.W),Taliyah.W.Radius)
      if wPred ~= nil and Utils.IsValidTarget(enemy) and wPred.HitChanceEnum >= HitChanceEnum.Low and (Taliyah.E:IsReady() or Utils.GetDamage(enemy) > hpPred or Player.Health - incomingDamage < enemies * Player.Level * 15 or eIsOn or Taliyah.E:GetLevel() == 0 or wHitCount > 1 )  and Player:Distance(enemy.Position) > 420 then
        if wPred.TargetPosition:Distance(wPred.CastPosition) <= 400 then
          if Input.Cast(SpellSlots.W,Player.Position,wPred.CastPosition) then return true end
        end
      elseif wPred ~= nil and Utils.IsValidTarget(enemy) and wPred.HitChanceEnum >= HitChanceEnum.Low and (Taliyah.E:IsReady() or Utils.GetDamage(enemy) > hpPred or Player.Health - incomingDamage < enemies * Player.Level * 15 or eIsOn or Taliyah.E:GetLevel() == 0 or wHitCount > 1) and Player:Distance(enemy.Position) < 420 then
        if wPred.TargetPosition:Distance(wPred.CastPosition) <= 400 then
          if Input.Cast(SpellSlots.W,-Player.Direction,wPred.CastPosition) then return true end
        end
      end
    end
  end
  if MenuValueE and Taliyah.E:IsReady() and (not Taliyah.W:IsReady() or Taliyah.W:GetLevel() == 0) and Player.Mana > eMana then
    for k, enemy in ipairs(Utils.GetTargetsRange(950)) do
      local ePred = Taliyah.E:GetPrediction(enemy)
      if ePred ~= nil and ePred.HitChanceEnum >= HitChanceEnum.High and Utils.IsValidTarget(enemy) and Player.Position:DistanceSqr(enemy) < (Taliyah.E.Range+100)*(Taliyah.E.Range+100) then
        if Input.Cast(SpellSlots.E, ePred.TargetPosition) then return true end
      end
    end
  end
  if MenuValueQ and Taliyah.Q:IsReady() and Player.Mana > qMana then
    for k, enemy in ipairs(Utils.GetTargets(Taliyah.Q)) do
      local qPred = Taliyah.Q:GetPrediction(enemy)
      if fullQ or not Menu.Get("Combo.FullQ") or  Utils.GetDamage(enemy) >= enemy.Health then
        if qPred ~= nil and qPred.HitChanceEnum >= HitChanceEnum.Medium and Utils.IsValidTarget(enemy) then
          if Taliyah.Q:Cast(qPred.CastPosition) then return true end
        end
      end
    end
  end
  return false
end

function Taliyah.Logic.Harass()
  if Menu.Get("ManaSlider") >= Player.ManaPercent * 100 then return false end
  local MenuValueQ = Menu.Get("Harass.Q")
  if MenuValueQ and Taliyah.Q:IsReady() and Player.Mana > qMana then
    for k, enemy in ipairs(Utils.GetTargets(Taliyah.Q)) do
      local qPred = Taliyah.Q:GetPrediction(enemy)
      if fullQ or not Menu.Get("Harass.FullQ") then
        if qPred ~= nil and qPred.HitChanceEnum >= HitChanceEnum.High and Utils.IsValidTarget(enemy) then
          if Taliyah.Q:Cast(qPred.CastPosition) then return true end
        end
      end
    end
  end
  return false
end

function Taliyah.Logic.Waveclear()
  if Player.Mana > qMana then
    local minionsQ = {}
    local monstersQ = {}
    for k, v in pairs(ObjectManager.GetNearby("enemy", "minions")) do
      local minion = v.AsAI
      local minionInRange = minion and minion.MaxHealth > 6 and Taliyah.Q:IsInRange(minion)
      local shouldIgnoreMinion = minion and (Orbwalker.IsLasthitMinion(minion) or Orbwalker.IsIgnoringMinion(minion))
      if minionInRange and not shouldIgnoreMinion and minion.IsTargetable  and Utils.IsValidTarget(minion) then
        table.insert(minionsQ, minion)
        table.sort(minionsQ, function(a, b) return a.MaxHealth > b.MaxHealth end)
      end
    end
    for k, v in pairs(ObjectManager.GetNearby("neutral", "minions")) do
      local minion = v.AsAI
      local minionInRange = minion and minion.MaxHealth > 6 and Taliyah.Q:IsInRange(minion)
      local shouldIgnoreMinion = minion and (Orbwalker.IsLasthitMinion(minion) or Orbwalker.IsIgnoringMinion(minion))
      if minionInRange and not shouldIgnoreMinion and minion.IsTargetable  and Utils.IsValidTarget(minion) then
        table.insert(monstersQ, minion)
        table.sort(monstersQ, function(a, b) return a.MaxHealth < b.MaxHealth end)
      end
    end
    for k, minion in pairs(minionsQ) do
      if not minion.IsAI then return false end
      local qPred = Prediction.GetPredictedPosition(minion, Taliyah.Q, Player.Position)
      local wPredPos, hitCountW = Taliyah.W:GetBestCircularCastPos(minionsQ,Taliyah.W.Radius)
      local ePredPos , hitCountE = Taliyah.E:GetBestCircularCastPos(minionsQ,Taliyah.E.Radius)
      if qPred ~= nil and qPred.HitChanceEnum >= HitChanceEnum.Low and Player:Distance(minion.Position) >= Orbwalker.GetTrueAutoAttackRange() and Menu.Get("ManaSliderLane") <= Player.ManaPercent * 100 and Menu.Get("WaveClear.Q") and Taliyah.Q:IsReady() then
        local delay = (Player:Distance(minion.Position)/ Taliyah.Q.Speed + Taliyah.Q.Delay)*1000
        local hpPred = HPred.GetHealthPrediction(minion,delay,false)
        local hpPred2 = HPred.GetHealthPrediction(minion,0.25,false)
        if hpPred > 0 and minion.Health < Taliyah.Q:GetDamage(minion) then
          if Taliyah.Q:Cast(qPred.CastPosition) then return true end
        end
      end
      if qPred ~= nil and qPred.HitChanceEnum >= HitChanceEnum.Low and not Orbwalker.CanAttack() and Menu.Get("ManaSliderLane") <= Player.ManaPercent * 100 and Menu.Get("WaveClear.Q") and Taliyah.Q:IsReady() then
        local delay = (Player:Distance(minion.Position)/ Taliyah.Q.Speed + Taliyah.Q.Delay)*1000
        local hpPred = HPred.GetHealthPrediction(minion,delay,false)
        if hpPred > 20 then
          if minion.Health < Taliyah.Q:GetDamage(minion) then
            if Taliyah.Q:Cast(qPred.CastPosition) then return true end
          elseif (minion.Health/minion.MaxHealth)*100 > 80 and hpPred > Taliyah.Q:GetDamage(minion) and Menu.Get("WaveClear.Qpush") and fullQ and Taliyah.Q:IsReady() then
            if Taliyah.Q:Cast(qPred.CastPosition) then return true end
          end
        end
      end
      if wPredPos ~= nil and Menu.Get("ManaSliderLane") <= Player.ManaPercent * 100 and Menu.Get("WaveClear.W") and hitCountW >= 4 and Taliyah.W:IsReady() and Player.Mana > wMana + eMana and Taliyah.W:IsInRange(minion) then
        if Input.Cast(SpellSlots.W,Player.Position,wPredPos) then return true end
      end
      if ePredPos ~= nil and Menu.Get("ManaSliderLane") <= Player.ManaPercent * 100 and Menu.Get("WaveClear.E") and hitCountW >= 4 and not Taliyah.W:IsReady() and Player.Mana > wMana + eMana and Taliyah.E:IsInRange(minion) then
        if Taliyah.E:Cast(ePredPos) then return true end
      end
    end
    for k, minion in pairs(monstersQ) do
      if not minion.IsAI then return false end
      local wPredPos, hitCountW = Taliyah.W:GetBestCircularCastPos(monstersQ,Taliyah.W.Radius)
      local ePredPos , hitCountE = Taliyah.E:GetBestCircularCastPos(monstersQ,Taliyah.E.Radius)
      if wPredPos ~= nil and Menu.Get("JungleClear.W") and hitCountW >= 1 and Taliyah.W:IsReady() and (Taliyah.E:IsReady() or Taliyah.E:GetLevel() == 0) and Player.Mana > wMana + eMana + qMana and Taliyah.W:IsInRange(minion) then
        if Input.Cast(SpellSlots.W,Player.Position,wPredPos) then return true end
      end
      if ePredPos ~= nil and Menu.Get("JungleClear.E") and hitCountW >= 1 and not Taliyah.W:IsReady() and Taliyah.E:IsReady() and Player.Mana > wMana + eMana + qMana and Taliyah.E:IsInRange(minion) then
        if Taliyah.E:Cast(ePredPos) then return true end
      end
      if Menu.Get("JungleClear.Q") and Taliyah.Q:IsReady() and Player.Mana > qMana and fullQ then
        if Taliyah.Q:Cast(minion.Position) then return true end
      end
    end
  end
  return false
end

function Taliyah.Logic.Auto()
  local walkPos = Taliyah.CalculatePos()
  if Menu.Get("Misc.LockQ") and walkPos ~= nil and next(Qobj) ~= nil then
    if Player:Distance(walkPos) < 500 and not Nav.IsWall(walkPos) and Player:Distance(walkPos) > 30 then
      if Input.MoveTo(walkPos) then return true end
    end
  end
  return false
end

function Taliyah.OnGapclose(source,dash)
  if source.IsEnemy and source.IsHero and Menu.Get("Misc.GapcloseE") and Taliyah.E:IsReady() and not dash.IsBlink and Player.Mana > eMana then
    local paths = dash:GetPaths()
    local endPos = paths[#paths].EndPos
    local startPos = paths[#paths].StartPos
    for k, enemy in ipairs(Utils.GetTargetsRange(950)) do
      local ePred = Taliyah.E:GetPrediction(enemy)
      if Player:Distance(endPos) <= 450 then
        if Taliyah.E:Cast(ePred.TargetPosition) then return true end
      end
    end
  end
  return false
end

function Taliyah.CalculatePos()
  for k, enemy in ipairs(Utils.GetTargets(Taliyah.Q)) do
    for k, v in pairs(Qobj) do
      if v ~= nil and v.IsValid and Utils.IsValidTarget(enemy) then
        local fPos = v.AsMissile.EndPos
        if Player:Distance(fPos) > Player:Distance(enemy.Position) then
          if enemy:Distance(fPos) < Taliyah.Q.Range and enemy:Distance(fPos) > 50 then
            local cursorTargetPos = enemy:Distance(Player.Position:Extended(Renderer.GetMousePos(),100))
            local lub = fPos:Extended(enemy.Position,cursorTargetPos + enemy:Distance(fPos))
            if Player:Distance(lub) < 1000 and Utils.CountEnemiesInRange(lub,400) < 2 then
              return lub
            end
          end
        end
      end
    end
  end
  return nil
end

function Taliyah.OnInterruptibleSpell(source, spell, danger, endT, canMove)
  if source.IsEnemy and Menu.Get("Misc.AutoWI") and Taliyah.W:IsReady() and danger > 2 and Player:Distance(source.Position) <= Taliyah.W.Range then
    if Input.Cast(SpellSlots.W,Player.Position,source.Position) then return true end
  end
  return false
end

function Taliyah.OnCastStop(sender, spell)
  if sender.IsMe and spell.Name == "TaliyahWVC" and Menu.Get("Misc.AutoE") then
    if Taliyah.E:IsReady() and Player.Mana > eMana then
      for k, enemy in ipairs(Utils.GetTargetsRange(1500)) do
        local ePred = Taliyah.E:GetPrediction(enemy)
        if ePred ~= nil and Utils.IsValidTarget(enemy) then
          local ePredTP = ePred.TargetPosition
          if Input.Cast(SpellSlots.E, ePredTP) then return true end
        end
      end
    end
  end
  return false
end

function Taliyah.OnCreateObject(obj)
  if obj ~= nil and obj.IsValid and obj.IsMissile and obj.AsMissile.Caster.AsHero == Player then
    if obj.Name == "TaliyahQMis" then
      if table.insert(Qobj,obj) then return true end
    end
  end
  if obj ~= nil and obj.IsValid and obj.IsVisible and obj.Name == "Taliyah_Base_E_Mines" then
    if table.insert(eOnGround,obj) then return true end
  end
  if obj ~= nil and obj.IsValid and obj.IsVisible and obj.Name == "Taliyah_Base_Q_aoe_bright" then
    if table.insert(qFive,obj) then return true end
  end
  return false
end

function Taliyah.OnDeleteObject(obj)
  if obj ~= nil and obj.IsValid and obj.IsMissile and obj.AsMissile.Caster.AsHero == Player then
    if obj.Name == "TaliyahQMis" then
      if table.remove(Qobj,Utils.tablefind(Qobj,obj)) then return true end
    end
  end
  if obj ~= nil and obj.IsValid and obj.IsVisible and obj.Name == "Taliyah_Base_E_Timeout" then
    if table.remove(eOnGround,Utils.tablefind(Qobj,obj)) then return true end
  end
  if obj ~= nil and obj.IsValid and obj.IsVisible and obj.Name == "Taliyah_Base_Q_aoe_bright" then
    if table.remove(qFive,Utils.tablefind(Qobj,obj)) then return true end
  end
  return false
end

function Taliyah.OnDraw()
  if Player.IsVisible and Player.IsOnScreen and not Player.IsDead then
    local Pos = Player.Position
    local spells = {Taliyah.Q,Taliyah.W,Taliyah.E,Taliyah.R}
    for k, v in pairs(spells) do
      if Menu.Get("Drawing."..v.Key..".Enabled", true) then
        if Renderer.DrawCircle3D(Pos, v.Range, 30, 3, Menu.Get("Drawing."..v.Key..".Color")) then return true end
      end
    end
  end
  return false
end

function Taliyah.OnUpdate()
  if not Utils.IsGameAvailable() then return false end
  local OrbwalkerMode = Orbwalker.GetMode()
  for k,v in pairs(Qobj) do
    if not v.IsValid then
      Qobj[k]=nil
    end
  end
  for k,v in pairs(eOnGround) do
    if not v.IsValid then
      eOnGround[k]=nil
    end
  end
  for k,v in pairs(qFive) do
    if not v.IsValid then
      qFive[k]=nil
    end
  end
  for k, v in pairs(qFive) do
    if v.IsValid then
      fullQ = false
    else
      fullQ = true
    end
  end
  for k, v in pairs(eOnGround) do
    if v.IsValid then
      eIsOn = true
    else
      eIsOn = false
    end
  end
  if next(qFive) == nil then
    fullQ = true
  end
  if next(eOnGround) == nil then
    eIsOn = false
  end
  local OrbwalkerLogic = Taliyah.Logic[OrbwalkerMode]
  if OrbwalkerLogic then
    if OrbwalkerLogic() then return true end
  end
  if Taliyah.Logic.Auto() then return true end
  if Utils.SetMana() then return true end
  return false
end

function Taliyah.LoadMenu()
  local function TaliyahMenu()
    Menu.ColumnLayout("Casting", "Casting", 2, true, function ()
    Menu.ColoredText("Combo", 0xB65A94FF, true)
    Menu.ColoredText("> Q", 0x0066CCFF, false)
    Menu.Checkbox("Combo.Q", "Use Q", true)
    Menu.Checkbox("Combo.FullQ", "Only with full Q", true)
    Menu.ColoredText("> W", 0x0066CCFF, false)
    Menu.Checkbox("Combo.W", "Use W", true)
    Menu.ColoredText("> E", 0x0066CCFF, false)
    Menu.Checkbox("Combo.E", "Use E", true)
    Menu.ColoredText("Harass", 0x118AB2FF, true)
    Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
    Menu.Slider("ManaSlider","percent",50,0,100)
    Menu.ColoredText("> Q", 0x0066CCFF, false)
    Menu.Checkbox("Harass.Q", "Use Q", true)
    Menu.Checkbox("Harass.FullQ", "Only with full Q", true)
    Menu.ColoredText("WaveClear", 0xEF476FFF, true)
    Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
    Menu.Slider("ManaSliderLane","",50,0,100)
    Menu.ColoredText("> Q", 0x0066CCFF, false)
    Menu.Checkbox("WaveClear.Q", "Use Q", true)
    Menu.Checkbox("WaveClear.Qpush", "Use Q to push", true)
    Menu.ColoredText("> W", 0x0066CCFF, false)
    Menu.Checkbox("WaveClear.W", "Use W", true)
    Menu.ColoredText("> E", 0x0066CCFF, false)
    Menu.Checkbox("WaveClear.E", "Use E", true)
    Menu.ColoredText("JungleClear", 0xEF472FEF, true)
    Menu.ColoredText("> Q", 0x0066CCFF, false)
    Menu.Checkbox("JungleClear.Q", "Use Q", true)
    Menu.ColoredText("> W", 0x0066CCFF, false)
    Menu.Checkbox("JungleClear.W", "Use W", true)
    Menu.ColoredText("> E", 0x0066CCFF, false)
    Menu.Checkbox("JungleClear.E", "Use E", true)
    Menu.ColoredText("Misc", 0xB65A94FF, true)
    Menu.Checkbox("Misc.LockQ", "Auto Soft Lock Q", true)
    Menu.Checkbox("Misc.AutoE", "Auto E on W", true)
    Menu.Checkbox("Misc.GapcloseE", "Auto E Gapclose", true)
    Menu.Checkbox("Misc.AutoWI", "Auto W Interupt", true)
    Menu.Separator()
    Menu.ColoredText("Drawing", 0xB65A94FF, true)
    Menu.Checkbox("Drawing.Status",   "Draw Harass Status",true)
    Menu.Checkbox("Drawing.Q.Enabled",   "Draw [Q] Range",true)
    Menu.ColorPicker("Drawing.Q.Color", "Draw [Q] Color", 0x118AB2FF)
    Menu.Checkbox("Drawing.E.Enabled",   "Draw [E] Range",false)
    Menu.ColorPicker("Drawing.E.Color", "Draw [E] Color", 0x118AB2FF)
    Menu.Checkbox("Drawing.W.Enabled",   "Draw [W] Range",false)
    Menu.ColorPicker("Drawing.W.Color", "Draw [W] Color", 0x118AB2FF)
    Menu.Checkbox("Drawing.R.Enabled",   "Draw [R] Range",false)
    Menu.ColorPicker("Drawing.R.Color", "Draw [R] Color", 0x118AB2FF)
    end)
  end
  if Menu.RegisterMenu("Simple Taliyah", "Simple Taliyah", TaliyahMenu) then return true end
  return false
end

function OnLoad()
  Taliyah.LoadMenu()
  for EventName, EventId in pairs(Events) do
    if Taliyah[EventName] then
      EventManager.RegisterCallback(EventId, Taliyah[EventName])
    end
  end
  return true
end
