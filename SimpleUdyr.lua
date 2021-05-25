if Player.CharName ~= "Udyr" then return end

module("Simple Udyr", package.seeall, log.setup)
clean.module("Simple Udyr", clean.seeall, log.setup)

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
local HitChance = Enums.HitChance

local Nav = CoreEx.Nav

local Udyr = {}

local loaded = false

Udyr.Q = SpellLib.Active({
  Slot = SpellSlots.Q,
  Key = "Q"
})

Udyr.W = SpellLib.Active({
  Slot = SpellSlots.W,
  Key = "W"
})

Udyr.E = SpellLib.Active({
  Slot = SpellSlots.E,
  Range = 800,
  Key = "E"
})

Udyr.R = SpellLib.Active({
  Slot = SpellSlots.R,
  Key = "R"
})

Udyr.TargetSelector = nil
Udyr.Logic = {}

local Utils = {}

function Utils.IsGameAvailable()
  return not (
  Game.IsChatOpen()  or
  Game.IsMinimized() or
  Player.IsDead
  )
end

function Utils.GetTargets(Spell)
  return {TS:GetTarget(Spell.Range,true)}
end

function Utils.IsValidTarget(Target)
  return Target and Target.IsTargetable and Target.IsAlive
end

function Utils.GetTargetsRange(Range)
  return {TS:GetTarget(Range,true)}
end

function Utils.CountPhoenixStance()
  local phoenixBuff = Player:GetBuff("UdyrPhoenixStance")
  if phoenixBuff then
    return phoenixBuff.Count
  end
  return 0
end

function Utils.CountMonkey()
  local monkeyBuff = Player:GetBuff("UdyrMonkeyAgilityBuff")
  if monkeyBuff then
    return monkeyBuff.Count
  end
  return 0
end
function Utils.GetMonkeyBuffTimer()
  local monkeyBuff = Player:GetBuff("UdyrMonkeyAgilityBuff")
  if monkeyBuff then
    return monkeyBuff.EndTime
  end
  return 0
end
function Utils.GetStance()
  if Player:GetBuff("UdyrTigerStance") then
    return 1
  end
  if Player:GetBuff("UdyrTurtleStance") then
    return 2
  end
  if Player:GetBuff("UdyrBearStance") then
    return 3
  end
  if Player:GetBuff("UdyrPhoenixStance") then
    return 4
  end
  return 0
end

function Utils.HasStun(target)
  local TargetAi = target.AsAI
  if TargetAi and TargetAi.IsValid then
    local UdyrStun = TargetAi:GetBuff("UdyrBearStunCheck")
    if UdyrStun then
      return true
    end
  end
  return false
end

function Utils.HasPhoenixAoe()
  local PhoenixAoe = Player:GetBuff("UdyrPhoenixActivation")
  if PhoenixAoe then
    return true
  end
  return false
end

function Utils.HasBear()
  local BearStun = Player:GetBuff("udyrbearactivation")
  if BearStun then
    return true
  end
  return false
end

function Udyr.Logic.Combo()
  local MenuValueQ = Menu.Get("Combo.Q")
  local MenuValueW = Menu.Get("Combo.W")
  local MenuValueE = Menu.Get("Combo.E")
  local MenuValueR = Menu.Get("Combo.R")
  local delay =  0.10 + Game.GetLatency()/1000
  local incomingDamage = HPred.GetDamagePrediction(Player,delay,true)
  if Orbwalker.TimeSinceLastAttackOrder() <= 0.75 then return false end
  for _, v in pairs(ObjectManager.GetNearby("enemy", "heroes")) do
    local enemy = v.AsAI
    if MenuValueE and Udyr.E:IsReady() and not Utils.HasStun(enemy) then
      if Udyr.E:Cast() then return true end
    end
    if Player:Distance(enemy) <= 250 then
      if MenuValueQ and Udyr.Q:IsReady() and (Utils.HasStun(enemy) or Udyr.R:GetLevel() == 0) and not Utils.HasPhoenixAoe() then
        if Udyr.Q:Cast() then return true end
      end
      if MenuValueR and not Utils.HasPhoenixAoe() and Udyr.R:IsReady() and (Utils.HasStun(enemy) or Udyr.Q:GetLevel() == 0)  then
        if Udyr.R:Cast() then return true end
      end
    end
    if MenuValueW and Udyr.W:IsReady() and (incomingDamage/Player.MaxHealth) * 100 >= 10 and not Utils.HasBear() then
      if Udyr.W:Cast() then return true end
    end
  end
  return false
end

function Udyr.Logic.Harass()
  local MenuValueQ = Menu.Get("Harass.Q")
  local MenuValueW = Menu.Get("Harass.W")
  local MenuValueE = Menu.Get("Harass.E")
  local MenuValueR = Menu.Get("Harass.R")
  local delay =  0.10 + Game.GetLatency()/1000
  local incomingDamage = HPred.GetDamagePrediction(Player,delay,true)
  if Orbwalker.TimeSinceLastAttackOrder() <= 0.75 then return false end
  for _, v in pairs(ObjectManager.GetNearby("enemy", "heroes")) do
    local enemy = v.AsAI
    if MenuValueE and Udyr.E:IsReady() and not Utils.HasStun(enemy) then
      if Udyr.E:Cast() then return true end
    end
    if Player:Distance(enemy) <= 250 then
      if MenuValueQ and Udyr.Q:IsReady() and (Utils.HasStun(enemy) or Udyr.R:GetLevel() == 0) and not Utils.HasPhoenixAoe() and not Utils.HasBear() then
        if Udyr.Q:Cast() then return true end
      end
      if MenuValueR and not Utils.HasPhoenixAoe() and Udyr.R:IsReady() and (Utils.HasStun(enemy) or Udyr.Q:GetLevel() == 0) and not Utils.HasBear()  then
        if Udyr.R:Cast() then return true end
      end
    end
    if MenuValueW and Udyr.W:IsReady() and (incomingDamage/Player.MaxHealth) * 100 >= 10 and not Utils.HasBear() then
      if Udyr.W:Cast() then return true end
    end
  end
  return false
end

function Udyr.Logic.Waveclear()
  local MenuValueQ = Menu.Get("WaveClear.Q")
  local MenuValueW = Menu.Get("WaveClear.W")
  local MenuValueE = Menu.Get("WaveClear.E")
  local MenuValueR = Menu.Get("WaveClear.R")
  local delay =  0.10 + Game.GetLatency()/1000
  local incomingDamage = HPred.GetDamagePrediction(Player,delay,true)
  if Orbwalker.TimeSinceLastAttackOrder() <= 0.75 then return false end
  for k, v in pairs(ObjectManager.GetNearby("enemy", "minions")) do
    local minion = v.AsMinion
    if Player:Distance(minion) <= 250 and Menu.Get("ManaSliderLane") <= Player.ManaPercent * 100 then
      if MenuValueQ and Udyr.Q:IsReady() then
        if Udyr.Q:Cast() then return true end
      end
      if MenuValueR and not Utils.HasPhoenixAoe() and Udyr.R:IsReady()  then
        if Udyr.R:Cast() then return true end
      end
    end
    if MenuValueW and Udyr.W:IsReady() and (incomingDamage/Player.MaxHealth) * 100 >= 10 and Menu.Get("ManaSliderLane") <= Player.ManaPercent * 100 and not Utils.HasBear() and not Utils.HasPhoenixAoe()  then
      if Udyr.W:Cast() then return true end
    end
  end
  for k, v in pairs(ObjectManager.GetNearby("neutral", "minions")) do
    local minion = v.AsMinion
    if Player:Distance(minion) <= 250 and minion.IsTargetable and not minion.IsJunglePlant then
      if MenuValueQ and Udyr.Q:IsReady()  and not Utils.HasPhoenixAoe()then
        if Udyr.Q:Cast() then return true end
      end
      if MenuValueR and Udyr.R:IsReady() and (not Utils.HasPhoenixAoe() or Udyr.Q:GetLevel() == 0) and not Utils.HasBear() then
        if Udyr.R:Cast() then return true end
      end
      if MenuValueW and Udyr.W:IsReady() and not Udyr.R:IsReady() and (not Utils.HasPhoenixAoe() or Udyr.Q:GetLevel() == 0) then
        if Udyr.W:Cast() then return true end
      end
    end
    if Player:Distance(minion) <= 600 and minion.IsTargetable and not minion.IsJunglePlant then
      if MenuValueE and Udyr.E:IsReady() then
        if not Udyr.R:IsReady() and not Udyr.Q:IsReady() and not Utils.HasPhoenixAoe() then
          if Udyr.E:Cast() then return true end
        end
        if minion.IsScuttler then
          if Udyr.E:Cast() then return true end
        end
      end
    end
  end
  return false
end

function Udyr.Logic.Flee()
  if Menu.Get("FlyBear") then
    local BuffEndTime = Utils.GetMonkeyBuffTimer()
    if Udyr.E:IsReady() then
      if Udyr.E:Cast() then return true end
    end
    if Utils.CountMonkey() < 3 or BuffEndTime > (Game.GetTime() + BuffEndTime)/2 then
      if Udyr.Q:IsReady() then
        if Udyr.Q:Cast() then return true end
      elseif Udyr.W:IsReady() then
        if Udyr.W:IsReady() then return true end
      end
    end
  end
  return false
end

function Udyr.Logic.Auto()
  local delay =  0.10 + Game.GetLatency()/1000
  local incomingDamage = HPred.GetDamagePrediction(Player,delay,true)
  if Menu.Get("AutoW") and Udyr.W:IsReady() and (incomingDamage/Player.MaxHealth) * 100 >= 20 then
    if Udyr.W:Cast() then return true end
  end
  return false
end

function Udyr.OnInterruptibleSpell(source, spell, danger, endT, canMove)
  if source.IsEnemy and Menu.Get("AutoEI") and Udyr.E:IsReady() and danger > 2 and Player:Distance(source.Position) <= 250 then
    if Udyr.E:Cast() then return true end
  end
  return false
end
function Udyr.OnUpdate()
  if not Utils.IsGameAvailable() then return false end

  local OrbwalkerMode = Orbwalker.GetMode()

  local OrbwalkerLogic = Udyr.Logic[OrbwalkerMode]

  if OrbwalkerLogic then
    if OrbwalkerLogic() then return true end
  end

  if Udyr.Logic.Auto() then return true end
  return false
end

function Udyr.LoadMenu()
  local function UdyrMenu()
    Menu.ColumnLayout("Casting", "Casting", 2, true, function ()
    Menu.ColoredText("Combo", 0xB65A94FF, true)
    Menu.ColoredText("> Q", 0x0066CCFF, false)
    Menu.Checkbox("Combo.Q", "Use Q", true)
    Menu.ColoredText("> W", 0x0066CCFF, false)
    Menu.Checkbox("Combo.W", "Use W", true)
    Menu.ColoredText("> E", 0x0066CCFF, false)
    Menu.Checkbox("Combo.E", "Use E", true)
    Menu.ColoredText("> R", 0x0066CCFF, false)
    Menu.Checkbox("Combo.R", "Use R", true)
    Menu.ColoredText("Harass", 0x118AB2FF, true)
    Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
    Menu.Slider("ManaSlider","",50,0,100)
    Menu.ColoredText("> Q", 0x0066CCFF, false)
    Menu.Checkbox("Harass.Q", "Use Q", true)
    Menu.ColoredText("> W", 0x0066CCFF, false)
    Menu.Checkbox("Harass.W", "Use W", true)
    Menu.ColoredText("> E", 0x0066CCFF, false)
    Menu.Checkbox("Harass.E", "Use E", true)
    Menu.ColoredText("> R", 0x0066CCFF, false)
    Menu.Checkbox("Harass.R", "Use R", true)
    Menu.ColoredText("WaveClear/JungleClear", 0xEF476FFF, true)
    Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
    Menu.Slider("ManaSliderLane","",45,0,100)
    Menu.ColoredText("> Q", 0x0066CCFF, false)
    Menu.Checkbox("WaveClear.Q", "Use Q", true)
    Menu.ColoredText("> W", 0x0066CCFF, false)
    Menu.Checkbox("WaveClear.W", "Use W", true)
    Menu.ColoredText("> E", 0x0066CCFF, false)
    Menu.Checkbox("WaveClear.E", "Use E", true)
    Menu.ColoredText("> R", 0x0066CCFF, false)
    Menu.Checkbox("WaveClear.R", "Use R", true)
    Menu.NextColumn()
    Menu.ColoredText("Misc", 0xB65A94FF, true)
    Menu.Checkbox("AutoEI", "Auto E Interupt", true)
    Menu.Checkbox("AutoW", "Auto Shield big damage", true)
    Menu.Checkbox("FlyBear", "Fly like a bear", true)
    end)
  end
  if loaded == false then
    Menu.RegisterMenu("SimpleUdyr", "SimpleUdyr", UdyrMenu)
    loaded = true
  end
end

function OnLoad()
  Udyr.LoadMenu()
  for EventName, EventId in pairs(Events) do
    if Udyr[EventName] then
      EventManager.RegisterCallback(EventId, Udyr[EventName])
    end
  end
  return true
end
