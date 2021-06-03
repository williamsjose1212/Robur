if Player.CharName ~= "Ezreal" then return end

module("Simple Ezreal", package.seeall, log.setup)
clean.module("Simple Ezreal", clean.seeall, log.setup)

local CoreEx = _G.CoreEx
local Libs = _G.Libs

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

local Ezreal = {}
local qMana = 0
local wMana = 0
local eMana = 0
local rMana = 0
local overkill = 0

Ezreal.Q = SpellLib.Skillshot({
  Slot = SpellSlots.Q,
  Range = 1300,
  Delay = 0.25,
  Speed = 2000,
  Radius = 60,
  Collisions = {Heroes = true, Minions = true, WindWall = true },
  Type = "Linear",
  UseHitbox = true,
  Key = "Q"
})

Ezreal.W = SpellLib.Skillshot({
  Slot = SpellSlots.W,
  Range = 1300,
  Delay = 0.25,
  Speed = 1700,
  Radius = 60,
  Collisions = {Heroes = true, WindWall = true },
  UseHitbox = true,
  Key = "W"
})

Ezreal.E = SpellLib.Skillshot({
  Slot = SpellSlots.E,
  Range = 475,
  Delay = 0.25,
  Key = "E"
})

Ezreal.R = SpellLib.Skillshot({
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

Ezreal.TargetSelector = nil
Ezreal.Logic = {}

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
  if Ezreal.Q:IsReady() then
    qMana = Ezreal.Q:GetManaCost()
  else
    qMana = 0
  end
  if Ezreal.W:IsReady() then
    wMana = Ezreal.W:GetManaCost()
  else
    wMana = 0
  end
  if Ezreal.E:IsReady() then
    eMana = Ezreal.E:GetManaCost()
  else
    eMana = 0
  end
  if Ezreal.R:IsReady() then
    rMana = Ezreal.R:GetManaCost()
  else
    rMana = 0
  end
  return false
end

function Utils.GetTargets(Spell)
  return {TS:GetTarget(Spell.Range,true)}
end

function Utils.GetTargetsRange(Range)
  return {TS:GetTarget(Range,false)}
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

function Ezreal.Logic.Combo()
  local MenuValueQ = Menu.Get("Combo.Q")
  local MenuValueW = Menu.Get("Combo.W")
  local MenuValueE = Menu.Get("Combo.E")
  if MenuValueQ and Ezreal.Q:IsReady() and Player.Mana > rMana + qMana then
    for k, enemy in pairs(Utils.GetTargets(Ezreal.Q)) do
      local qPred = Ezreal.Q:GetPrediction(enemy)
      if not Ezreal.W:IsReady() or not MenuValueW or not Ezreal.W:CanCast(enemy) then
        if qPred ~= nil and qPred.HitChanceEnum >= HitChanceEnum.High and Utils.IsValidTarget(enemy) then
          if Ezreal.Q:Cast(qPred.CastPosition) then return true end
        end
      end
    end
  end
  if MenuValueW and Ezreal.W:IsReady() and Player.Mana > rMana + wMana + eMana then
    for k, enemy in pairs(Utils.GetTargets(Ezreal.W)) do
      local wPred = Ezreal.W:GetPrediction(enemy)
      if wPred ~= nil and wPred.HitChanceEnum >= HitChanceEnum.High and Utils.IsValidTarget(enemy) then
        if Ezreal.W:Cast(wPred.CastPosition) then return true end
      end
    end
  end
  if MenuValueE and Ezreal.E:IsReady() and not IsInTurret and (Player.Health/Player.MaxHealth)*100 > 40 and Game.GetTime() - overkill > 0.2  then
    for k, enemy in pairs(ObjectManager.GetNearby("enemy", "heroes")) do
      if Utils.IsValidTarget(enemy) and enemy:Distance(Renderer.GetMousePos()) + 300 < Player:Distance(enemy.Position) and Player:Distance(enemy.Position) > Orbwalker.GetTrueAutoAttackRange() and Player:Distance(enemy.Position) <= 1300 then
        local dashPos = Vector(Player.Position,Renderer.GetMousePos(),Ezreal.E.Range)
        if Utils.CountEnemiesInRange(dashPos, 900) < 3 then
          local dmg = 0
          if Player:Distance(enemy.Position) <= 950 then
            dmg = DamageLib.GetAutoAttackDamage(enemy) + Ezreal.E:GetDamage(enemy)
          end
          if Ezreal.Q:IsReady() and Player.Mana > qMana + eMana then
            local qPred = Ezreal.Q:GetPrediction(enemy)
            if qPred ~= nil and qPred.HitChanceEnum >= HitChanceEnum.High then
              dmg = Ezreal.Q:GetDamage(enemy)
            end
          end
          if Ezreal.W:IsReady() and Player.Mana > qMana + eMana + wMana then
            dmg = dmg + Ezreal.W:GetDamage(enemy)
          end
          if dmg > enemy.Health and Utils.ValidUlt(enemy) then
            if Ezreal.E:Cast(dashPos) then return true end
          end
        end
      end
    end
  end
  return false
end

function Ezreal.Logic.Harass()
  if Menu.Get("ManaSlider") >= Player.ManaPercent * 100 then return false end
  local MenuValueQ = Menu.Get("Harass.Q")
  local MenuValueW = Menu.Get("Harass.W")
  if MenuValueQ and Ezreal.Q:IsReady() and Player.Mana > qMana + wMana then
    for k, enemy in pairs(Utils.GetTargets(Ezreal.Q)) do
      local qPred = Ezreal.Q:GetPrediction(enemy)
      if not Ezreal.W:IsReady() or not MenuValueW or not Ezreal.W:CanCast(enemy) then
        if qPred ~= nil and qPred.HitChanceEnum >= HitChanceEnum.High and Utils.IsValidTarget(enemy) then
          if Ezreal.Q:Cast(qPred.CastPosition) then return true end
        end
      end
    end
  end
  if MenuValueW and Ezreal.W:IsReady() and Player.Mana > wMana + qMana then
    for k, enemy in pairs(Utils.GetTargets(Ezreal.W)) do
      local wPred = Ezreal.W:GetPrediction(enemy)
      if wPred ~= nil and wPred.HitChanceEnum >= HitChanceEnum.High and Utils.IsValidTarget(enemy) then
        if Ezreal.W:Cast(wPred.CastPosition) then return true end
      end
    end
  end
  return false
end

function Ezreal.Logic.Waveclear()
  if Menu.Get("WaveClear.Q") and Ezreal.Q:IsReady() and Player.Mana > qMana then
    local minionsQ = {}
    local monstersQ = {}
    for k, v in pairs(ObjectManager.GetNearby("enemy", "minions")) do
      local minion = v.AsAI
      local minionInRange = minion and minion.MaxHealth > 6 and Ezreal.Q:IsInRange(minion)
      local shouldIgnoreMinion = minion and (Orbwalker.IsLasthitMinion(minion) or Orbwalker.IsIgnoringMinion(minion))
      if minionInRange and not shouldIgnoreMinion and minion.IsTargetable  and Utils.IsValidTarget(minion) then
        table.insert(minionsQ, minion)
        table.sort(minionsQ, function(a, b) return a.MaxHealth > b.MaxHealth end)
      end
    end
    for k, v in pairs(ObjectManager.GetNearby("neutral", "minions")) do
      local minion = v.AsAI
      local minionInRange = minion and minion.MaxHealth > 6 and Ezreal.Q:IsInRange(minion)
      local shouldIgnoreMinion = minion and (Orbwalker.IsLasthitMinion(minion) or Orbwalker.IsIgnoringMinion(minion))
      if minionInRange and not shouldIgnoreMinion and minion.IsTargetable  and Utils.IsValidTarget(minion) then
        table.insert(monstersQ, minion)
        table.sort(monstersQ, function(a, b) return a.MaxHealth > b.MaxHealth end)
      end
    end
    for k, minion in pairs(minionsQ) do
      local qPred = Prediction.GetPredictedPosition(minion, Ezreal.Q, Player.Position)
      if qPred ~= nil and qPred.HitChanceEnum >= HitChanceEnum.Low and Player:Distance(minion.Position) >= Orbwalker.GetTrueAutoAttackRange() and Menu.Get("ManaSliderLane") <= Player.ManaPercent * 100 then
        local delay = (Player:Distance(minion.Position)/ Ezreal.Q.Speed + Ezreal.Q.Delay)*1000
        local hpPred = HPred.GetHealthPrediction(minion,delay,false)
        local hpPred2 = HPred.GetHealthPrediction(minion,0.25,false)
        if hpPred > 0 and hpPred2 < Ezreal.Q:GetDamage(minion) then
          if Ezreal.Q:Cast(qPred.CastPosition) then return true end
        end
      end
      if qPred ~= nil and qPred.HitChanceEnum >= HitChanceEnum.Low and not Orbwalker.CanAttack() and Player:Distance(minion.Position) <= Orbwalker.GetTrueAutoAttackRange() and Menu.Get("ManaSliderLane") <= Player.ManaPercent * 100 then
        local delay = (Player:Distance(minion.Position)/ Ezreal.Q.Speed + Ezreal.Q.Delay)*1000
        local hpPred = HPred.GetHealthPrediction(minion,delay,false)
        if hpPred > 20 then
          if hpPred < Ezreal.Q:GetDamage(minion)*0.6 then
            if Ezreal.Q:Cast(qPred.CastPosition) then return true end
          elseif (minion.Health/minion.MaxHealth)*100 > 80 then
            if Ezreal.Q:Cast(qPred.CastPosition) then return true end
          end
        end
      end
    end
    for k, minion in pairs(monstersQ) do
      local qPred = Prediction.GetPredictedPosition(minion, Ezreal.Q, Player.Position)
      if qPred ~= nil and qPred.HitChanceEnum >= HitChanceEnum.Low then
        if Ezreal.Q:Cast(qPred.CastPosition) then return true end
      end
    end
  end
  return false
end

function Ezreal.Logic.Auto()
  for k, hero in pairs(ObjectManager.GetNearby("enemy", "heroes")) do
    local enemy = hero.AsAI
    if Ezreal.Q:IsReady() and Player.Mana > qMana and Ezreal.Q:IsInRange(enemy) then
      local enemy = hero.AsAI
      local delay = (Player:Distance(enemy.Position)/ Ezreal.Q.Speed + Ezreal.Q.Delay)*1000
      local hpPred = HPred.GetHealthPrediction(enemy,delay,false)
      if hpPred < Ezreal.Q:GetDamage(enemy) + Ezreal.W:GetDamage(enemy) and Utils.IsValidTarget(enemy) then
        overkill = Game.GetTime()
      end
    end
    if Ezreal.W:IsReady() and Player.Mana > wMana and Ezreal.W:IsInRange(enemy) then
      local delay = (Player:Distance(enemy.Position)/ Ezreal.W.Speed + Ezreal.W.Delay)*1000
      local hpPred = HPred.GetHealthPrediction(enemy,delay,false)
      if hpPred < Ezreal.W:GetDamage(enemy) and Utils.IsValidTarget(enemy) then
        overkill = Game.GetTime()
      end
    end
    if Menu.Get("KSq") and Ezreal.Q:IsReady() and Player.Mana > qMana and Ezreal.Q:IsInRange(enemy) then
      local delay = (Player:Distance(enemy.Position)/ Ezreal.Q.Speed + Ezreal.Q.Delay)*1000
      local hpPred = HPred.GetHealthPrediction(enemy,delay,false)
      if hpPred < Ezreal.Q:GetDamage(enemy) + Ezreal.W:GetDamage(enemy) then
        local qPred = Ezreal.Q:GetPrediction(enemy)
        if	qPred ~= nil and qPred.HitChanceEnum >= HitChanceEnum.Medium and Utils.IsValidTarget(enemy) then
          if Ezreal.Q:Cast(qPred.CastPosition) then return true end
        end
      end
    end
  end
  for k, enemy in pairs(Utils.GetTargetsRange(4000)) do
    local target = enemy.AsAI
    if Menu.Get("CastR") and Ezreal.R:IsReady() and Player.Mana > rMana then
      local rPred = Ezreal.R:GetPrediction(target)
      if rPred ~= nil and Utils.IsValidTarget(target) then
        if Ezreal.R:Cast(rPred.CastPosition) then return true end
      end
    end
    if Menu.Get("AutoR") and Ezreal.R:IsReady() and Player.Mana > rMana and Utils.CountHeroes(Player,800,"enemy") == 0  and Game.GetTime() - overkill > 0.5  and not IsInTurret then
      local delay = (Player:Distance(target.Position)/ Ezreal.R.Speed + Ezreal.R.Delay)*1000
      local hpPred = HPred.GetHealthPrediction(target,delay,false)
      local rPred = Ezreal.R:GetPrediction(target)
      if rPred ~= nil and rPred.HitChanceEnum >= HitChanceEnum.Medium and hpPred < Ezreal.R:GetDamage(target) and Utils.CountHeroes(target,500,"ally") == 0 and Utils.IsValidTarget(target) and Utils.ValidUlt(target) then
        if Ezreal.R:Cast(rPred.CastPosition) then return true end
      end
    end
    if Menu.Get("AutoRcc") and Ezreal.R:IsReady() and Player.Mana > rMana and not IsInTurret then
      if not target.CanMove and Player:Distance(target.Position) <= 3000 and Utils.IsValidTarget(target) and Utils.CountHeroes(Player,800,"enemy") == 0 then
        if Ezreal.R:Cast(target.Position) then return true end
      end
    end
  end
  if Menu.Get("AutoRhit") and Ezreal.R:IsReady() and Player.Mana > rMana and not IsInTurret then
    local enemies = {}
    for k, enemy in pairs(ObjectManager.Get("enemy", "heroes")) do
      local target = enemy.AsHero
      local pos = target:FastPrediction(Game.GetLatency() + Ezreal.R.Delay)
      if Utils.IsValidTarget(target) and Player:Distance(target.Position) <= 3000 then
        table.insert(enemies, target.Position)
      end
    end
    local rCastPos, hitCount = Ezreal.R:GetBestLinearCastPos(enemies,Ezreal.R.Radius)
    if rCastPos ~= nil and hitCount >= Menu.Get("HitcountR") and Utils.CountHeroes(Player,1200,"enemy") == 0 then
      if Ezreal.R:Cast(rCastPos) then return true end
    end
  end
  return false
end

function Ezreal.OnDraw()
  if Player.IsVisible and Player.IsOnScreen and not Player.IsDead then
    local Pos = Player.Position
    local spells = {Ezreal.Q,Ezreal.W,Ezreal.E,Ezreal.R}
    for k, v in pairs(spells) do
      if Menu.Get("Drawing."..v.Key..".Enabled", true) then
        if Renderer.DrawCircle3D(Pos, v.Range, 30, 3, Menu.Get("Drawing."..v.Key..".Color")) then return true end
      end
    end
  end
  return false
end

function Ezreal.OnUpdate()
  if not Utils.IsGameAvailable() then return false end
  local OrbwalkerMode = Orbwalker.GetMode()
  for k, v in pairs(ObjectManager.GetNearby("enemy", "turrets")) do
    local turret = v.AsAI
    if turret ~= nil and Player:Distance(turret.Position) <= 750 then
      IsInTurret = true
    else
      IsInTurret = false
    end
  end
  local OrbwalkerLogic = Ezreal.Logic[OrbwalkerMode]
  if OrbwalkerLogic then
    if OrbwalkerLogic() then return true end
  end
  if Ezreal.Logic.Auto() then return true end
  if Utils.SetMana() then return true end
  return false
end

function Ezreal.LoadMenu()
  local function EzrealMenu()
    Menu.ColumnLayout("Casting", "Casting", 2, true, function ()
    Menu.ColoredText("Combo", 0xB65A94FF, true)
    Menu.ColoredText("> Q", 0x0066CCFF, false)
    Menu.Checkbox("Combo.Q", "Use Q", true)
    Menu.ColoredText("> W", 0x0066CCFF, false)
    Menu.Checkbox("Combo.W", "Use W", true)
    Menu.ColoredText("> E", 0x0066CCFF, false)
    Menu.Checkbox("Combo.E", "Use E KS", false)
    Menu.Keybind("CastR", "Semi [R] Cast", string.byte('T'))
    Menu.ColoredText("Harass", 0x118AB2FF, true)
    Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
    Menu.Slider("ManaSlider","for Q",80,0,100)
    Menu.ColoredText("> Q", 0x0066CCFF, false)
    Menu.Checkbox("Harass.Q", "Use Q", true)
    Menu.ColoredText("> W", 0x0066CCFF, false)
    Menu.Checkbox("Harass.W", "Use W", true)
    Menu.ColoredText("WaveClear/JungleClear", 0xEF476FFF, true)
    Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
    Menu.Slider("ManaSliderLane","",35,0,100)
    Menu.ColoredText("> Q", 0x0066CCFF, false)
    Menu.Checkbox("WaveClear.Q", "Use Q", true)
    Menu.ColoredText("Misc", 0xB65A94FF, true)
    Menu.ColoredText("> Q", 0x0066CCFF, false)
    Menu.Checkbox("KSq", "Auto KS Q", true)
    Menu.ColoredText("> R", 0x0066CCFF, false)
    Menu.Checkbox("AutoR", "Auto R KS", true)
    Menu.Checkbox("AutoRcc", "Auto R cc", true)
    Menu.Checkbox("AutoRhit", "Auto R HitCount", true)
    Menu.Slider("HitcountR", "HitCount", 3, 1, 5)
    Menu.Separator()
    Menu.ColoredText("Drawing", 0xB65A94FF, true)
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
  if Menu.RegisterMenu("Simple Ezreal", "Simple Ezreal", EzrealMenu) then return true end
  return false
end

function OnLoad()
  Ezreal.LoadMenu()
  for EventName, EventId in pairs(Events) do
    if Ezreal[EventName] then
      EventManager.RegisterCallback(EventId, Ezreal[EventName])
    end
  end
  return true
end
