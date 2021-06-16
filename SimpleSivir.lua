if Player.CharName ~= "Sivir" then return end

module("Simple Sivir", package.seeall, log.setup)
clean.module("Simple Sivir", clean.seeall, log.setup)

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
local HPred = Libs.HealthPred
local TS = Libs.TargetSelector()
local DashLib = Libs.DashLib

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

local Sivir = {}
local qMana = 0
local wMana = 0
local eMana = 0
local rMana = 0

Sivir.Q = SpellLib.Skillshot({
  Slot = SpellSlots.Q,
  Range = 1200,
  Delay = 0.250,
  Speed = 1350,
  Radius = 90,
  Collisions = {WindWall = true},
  Type = "Linear",
  Key = "Q"
})

Sivir.W = SpellLib.Active({
  Slot = SpellSlots.W,
  Key = "W"
})

Sivir.E = SpellLib.Active({
  Slot = SpellSlots.E,
  Key = "E"
})

Sivir.R = SpellLib.Active({
  Slot = SpellSlots.R,
  Range = 800,
  Key = "R",
})

Sivir.TargetSelector = nil
Sivir.Logic = {}

local Utils = {}

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
  if Sivir.Q:IsReady() then
    qMana = Sivir.Q:GetManaCost()
  else
    qMana = 0
  end
  if Sivir.W:IsReady() then
    wMana = Sivir.W:GetManaCost()
  else
    wMana = 0
  end
  if Sivir.E:IsReady() then
    eMana = Sivir.E:GetManaCost()
  else
    eMana = 0
  end
  if Sivir.R:IsReady() then
    rMana = Sivir.R:GetManaCost()
  else
    rMana = 0
  end
  return false
end

function Utils.GetTargets(Spell)
  return TS:GetTargets(Spell.Range,true)
end

function Utils.GetTargetsRange(Range)
  return {TS:GetTarget(Range,true)}
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

function Sivir.Logic.Combo()
  local MenuValueQ = Menu.Get("Combo.Q")
  local MenuValueW = Menu.Get("Combo.W")
  local MenuValueR = Menu.Get("Combo.R")
  for k, enemy in pairs(Utils.GetTargets(Sivir.Q)) do
    if Sivir.Q:IsReady() and MenuValueQ then
      local predQ = Sivir.Q:GetPrediction(enemy)
      if predQ ~= nil and predQ.HitChanceEnum >= HitChanceEnum.Medium and Sivir.Q:IsInRange(enemy) and Sivir.Q:GetDamage(enemy)*2.0 > enemy.Health then
        if Sivir.Q:Cast(predQ.CastPosition) then return true end
      elseif predQ ~= nil and predQ.HitChanceEnum >= HitChanceEnum.Medium and Sivir.Q:IsInRange(enemy) and Player.Mana > rMana + qMana then
        if Sivir.Q:Cast(predQ.CastPosition) then return true end
      end
    end
  end
  for _, v in pairs(ObjectManager.GetNearby("enemy","heroes")) do
    local enemy = v.AsHero
    if Sivir.R:IsReady() and MenuValueR and not enemy.IsZombie and Player:Distance(enemy) <= 800 then
      if Utils.Count(Sivir.R) > 2 then
        if Sivir.R:Cast() then return true end
      elseif DamageLib.GetAutoAttackDamage(enemy)*2 > enemy.Health and not Sivir.Q:IsReady() and Utils.Count(Sivir.R) < 3 and Player:Distance(enemy) > 500 then
        if Sivir.R:Cast() then return true end
      end
    end
  end
  return false
end

function Sivir.Logic.Harass()
  if Menu.Get("ManaSlider") >= Player.ManaPercent * 100 then return false end
  local MenuValueQ = Menu.Get("Harass.Q")
  local MenuValueW = Menu.Get("Harass.W")
  for k, enemy in pairs(Utils.GetTargets(Sivir.Q)) do
    if Sivir.Q:IsReady() and MenuValueQ then
      local predQ = Prediction.GetPredictedPosition(enemy, Sivir.Q, Player.Position)
      if predQ ~= nil and predQ.HitChanceEnum >= HitChanceEnum.Medium and Sivir.Q:IsInRange(enemy) and Sivir.Q:GetDamage(enemy)*2.0 > enemy.Health then
        if Sivir.Q:Cast(predQ.CastPosition) then return true end
      elseif predQ ~= nil and predQ.HitChanceEnum >= HitChanceEnum.High and Sivir.Q:IsInRange(enemy) then
        if Sivir.Q:Cast(predQ.CastPosition) then return true end
      end
    end
  end
  return false
end

function Sivir.Logic.Waveclear()
  local MenuValueQ = Menu.Get("WaveClear.Q")
  local MenuValueW = Menu.Get("WaveClear.W")
  local Cannons = {}
  local otherMinions = {}
  local JungleMinions = {}
  for k, v in pairs(ObjectManager.GetNearby("enemy", "minions")) do
    local minion = v.AsMinion
    local pos = minion:FastPrediction(Game.GetLatency()+ Sivir.Q.Delay)
    if minion.IsTargetable and (minion.IsSiegeMinion or minion.IsSuperMinion) and Sivir.Q:IsInRange(minion) then
      table.insert(Cannons, pos)
    end
    if minion.IsTargetable and minion.IsLaneMinion and Sivir.Q:IsInRange(minion) then
      table.insert(otherMinions, pos)
    end
    local cannonsPos, hitCount1 = Sivir.Q:GetBestLinearCastPos(Cannons, Sivir.Q.Radius)
    local laneMinionsPos, hitCount2 = Sivir.Q:GetBestLinearCastPos(otherMinions, Sivir.Q.Radius)
    if cannonsPos ~= nil and laneMinionsPos ~= nil and Menu.Get("ManaSliderLane") <= Player.ManaPercent * 100 and Sivir.Q:IsReady() and  MenuValueQ then
      if hitCount1 >= 1 then
        if Sivir.Q:Cast(cannonsPos) then return true end
      end
    end
    if laneMinionsPos ~= nil and Menu.Get("ManaSliderLane") <= Player.ManaPercent * 100 and Sivir.Q:IsReady() and  MenuValueQ then
      if hitCount2 >= 3 then
        if Sivir.Q:Cast(laneMinionsPos) then return true end
      end
    end
  end
  for k, v in pairs(ObjectManager.GetNearby("neutral", "minions")) do
    local minion = v.AsMinion
    local pos = minion:FastPrediction(Game.GetLatency()+ Sivir.Q.Delay)
    if Sivir.Q:IsInRange(minion) and minion.IsTargetable and not minion.IsJunglePlant then
      table.insert(JungleMinions, pos)
      local predQ = Prediction.GetPredictedPosition(minion, Sivir.Q, Player.Position)
      if predQ ~= nil and Sivir.Q:IsReady() and MenuValueQ and predQ.HitChanceEnum >= HitChanceEnum.VeryHigh  then
        if Sivir.Q:Cast(predQ.CastPosition) then return true end
      end
    end
    if Sivir.Q:IsReady() and  MenuValueQ then
      local JungleMinionPos, hitCount3 = Sivir.Q:GetBestLinearCastPos(JungleMinions, Sivir.Q.Radius)
      if JungleMinionPos ~= nil then
        if hitCount3 >= 1 then
          if Sivir.Q:Cast(JungleMinionPos) then return true end
        end
      end
    end
  end
  return false
end

function Sivir.Logic.Auto()
  if Menu.Get("AutoQcc") then
    for k, v in pairs(ObjectManager.GetNearby("enemy", "heroes")) do
      local enemy = v.AsHero
      if not enemy.CanMove and Sivir.Q:IsReady() and Sivir.Q:IsInRange(enemy) and enemy.IsValid then
        if Sivir.Q:CastOnHitChance(enemy,Enums.HitChance.Immobile) then return true end
      end
    end
  end
  return false
end

function Sivir.OnPostAttack(target)
  local OrbwalkerMode = Orbwalker.GetMode()
  if Sivir.W:IsReady() and Menu.Get("Combo.W") and OrbwalkerMode == "Combo" then
    if target.IsHero and not target.IsDead and target.IsValid then
      local delay =  0.10 + Game.GetLatency()/1000
      local incomingDamage = HPred.GetDamagePrediction(target,delay,true)
      if DamageLib.GetAutoAttackDamage(target)*3 > target.Health - incomingDamage then
        if Sivir.W:Cast() then return true end
      end
      if Player.Mana > rMana + wMana then
        if Sivir.W:Cast() then return true end
      end
    end
  end
  if Sivir.W:IsReady() and Menu.Get("Harass.W") and OrbwalkerMode == "Harass" then
    if target.IsHero and not target.IsDead and target.IsValid then
      if Player.Mana > rMana + wMana + qMana then
        if Sivir.W:Cast() then return true end
      end
    end
  end
  if Sivir.W:IsReady() and Menu.Get("WaveClear.W") and OrbwalkerMode == "Waveclear" then
    for k, v in pairs(ObjectManager.GetNearby("enemy", "minions")) do
      local minion = v.AsMinion
      if not minion.IsJunglePlant and minion.IsValid and not minion.IsDead and minion.IsTargetable and Menu.Get("ManaSliderLane") <= Player.ManaPercent * 100 and Player:Distance(minion) <= 500 and Utils.CountMinionsInRange(500, "enemy") > 2 then
        if Sivir.W:Cast() then return true end
      end
    end
  end
  return false
end

function Sivir.OnProcessSpell(sender,spell)
  if sender.IsHero and sender.IsEnemy and Menu.Get("AutoE") and Sivir.E:IsReady() then
    if spell.Target and spell.Target.IsHero and spell.Target.IsMe and not spell.IsBasicAttack then
      if Sivir.E:Cast() then return true end
    end
  end
  return false
end

function Sivir.OnGapclose(source,dash)
  if source.IsEnemy and source.IsHero  and not dash.IsBlink then
    local paths = dash:GetPaths()
    local endPos = paths[#paths].EndPos
    if Player:Distance(endPos) <= 400 and Menu.Get("AutoRg") and Sivir.R:IsReady() then
      if Sivir.R:Cast() then return true end
    end
  end
  return false
end

function Sivir.OnDraw()
  if Player.IsVisible and Player.IsOnScreen and not Player.IsDead then
    local Pos = Player.Position
    local spells = {Sivir.Q,Sivir.W,Sivir.E,Sivir.R}
    for k, v in pairs(spells) do
      if Menu.Get("Drawing."..v.Key..".Enabled", true) then
        if Renderer.DrawCircle3D(Pos, v.Range, 30, 3, Menu.Get("Drawing."..v.Key..".Color")) then return true end
      end
    end
  end
  return false
end

function Sivir.OnUpdate()
  if not Utils.IsGameAvailable() then return false end
  local OrbwalkerMode = Orbwalker.GetMode()

  local OrbwalkerLogic = Sivir.Logic[OrbwalkerMode]

  if OrbwalkerLogic then
    if OrbwalkerLogic() then return true end
  end
  if Sivir.Logic.Auto() then return true end
  if Utils.SetMana() then return true end
  return false
end

function Sivir.LoadMenu()
  local function SivirMenu()
    Menu.ColumnLayout("Casting", "Casting", 2, true, function ()
    Menu.ColoredText("Combo", 0xB65A94FF, true)
    Menu.ColoredText("> Q", 0x0066CCFF, false)
    Menu.Checkbox("Combo.Q", "Use Q", true)
    Menu.ColoredText("> W", 0x0066CCFF, false)
    Menu.Checkbox("Combo.W", "Use W", true)
    Menu.ColoredText("> R", 0x0066CCFF, false)
    Menu.Checkbox("Combo.R", "Use R", true)
    Menu.ColoredText("Harass", 0x118AB2FF, true)
    Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
    Menu.Slider("ManaSlider","for Q",50,0,100)
    Menu.ColoredText("> Q", 0x0066CCFF, false)
    Menu.Checkbox("Harass.Q", "Use Q", true)
    Menu.ColoredText("> W", 0x0066CCFF, false)
    Menu.Checkbox("Harass.W", "Use W", true)
    Menu.ColoredText("WaveClear/JungleClear", 0xEF476FFF, true)
    Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
    Menu.Slider("ManaSliderLane","",45,0,100)
    Menu.ColoredText("> Q", 0x0066CCFF, false)
    Menu.Checkbox("WaveClear.Q", "Use Q", true)
    Menu.ColoredText("> W", 0x0066CCFF, false)
    Menu.Checkbox("WaveClear.W", "Use W", false)
    Menu.NextColumn()
    Menu.ColoredText("Auto", 0xB65A94FF, true)
    Menu.Checkbox("AutoQcc", "Auto Q on cc", true)
    Menu.Checkbox("AutoRg", "Auto R on gapclose", true)
    Menu.Checkbox("AutoE", "Auto E Shield Targeted spells", true)
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
  if Menu.RegisterMenu("Simple Sivir", "Simple Sivir", SivirMenu) then return true end
  return false
end

function OnLoad()
  Sivir.LoadMenu()
  for EventName, EventId in pairs(Events) do
    if Sivir[EventName] then
      EventManager.RegisterCallback(EventId, Sivir[EventName])
    end
  end
  return true
end
