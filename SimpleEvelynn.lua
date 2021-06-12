if Player.CharName ~= "Evelynn" then return end

module("Simple Evelynn", package.seeall, log.setup)
clean.module("Simple Evelynn", clean.seeall, log.setup)

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

local Evelynn = {}
local qMana = 0
local wMana = 0
local eMana = 0
local rMana = 0
local isq2 = false
local overkill = 0

Evelynn.Q = SpellLib.Skillshot({
  Slot = SpellSlots.Q,
  Range = 800,
  Delay = 0.25,
  Speed = 2400,
  Radius = 60,
  Collisions = {Heroes = true, Minions = true, WindWall = true },
  Type = "Linear",
  UseHitbox = true,
  Key = "Q"
})

Evelynn.Q2 = SpellLib.Skillshot({
  Slot = SpellSlots.Q,
  Range = 550, --500
  Key = "Q"
})

Evelynn.W = SpellLib.Targeted({
  Slot = SpellSlots.W,
  Range = 1200,
  Key = "W"
})

Evelynn.E = SpellLib.Targeted({
  Slot = SpellSlots.E,
  Range = 325, --210
  Key = "E"
})

Evelynn.R = SpellLib.Skillshot({
  Slot = SpellSlots.R,
  Range = 500, --550 --530
  Delay = 0.35,
  Radius = 350,
  Speed = 1300,
  Type = "Circular",
  Key = "R",
})

Evelynn.TargetSelector = nil
Evelynn.Logic = {}

local Utils = {}
local LastW = 0

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
    eMana = 0
    rMana = 0
    return true
  end
  if Evelynn.Q:IsReady() then
    qMana = Evelynn.Q:GetManaCost()
  else
    qMana = 0
  end
  if Evelynn.W:IsReady() then
    wMana = Evelynn.W:GetManaCost()
  else
    wMana = 0
  end
  if Evelynn.E:IsReady() then
    eMana = Evelynn.E:GetManaCost()
  else
    eMana = 0
  end
  if Evelynn.R:IsReady() then
    rMana = Evelynn.R:GetManaCost()
  else
    rMana = 0
  end
  return false
end

function Utils.GetTargets(Spell)
  return TS:GetTargets(Spell.Range,true)
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

function Utils.WaitForW(enemy)
  if not Menu.Get("Combo.WaitW") then return false end
  local target = enemy.AsAI
  if target ~= nil and target.IsValid then
    local eveWbuff = target:GetBuff("EvelynnW")
    if eveWbuff ~= nil and eveWbuff.EndTime - Game.GetTime() > 2.5 then
      return true
    end
  end
  return false
end

function Utils.IsValidTarget(Target)
  return Target and Target.IsTargetable and Target.IsAlive
end

function Evelynn.Logic.Combo()
  local MenuValueQ = Menu.Get("Combo.Q")
  local MenuValueW = Menu.Get("Combo.W")
  local MenuValueE = Menu.Get("Combo.E")
  local MenuValueR = Menu.Get("Combo.R")
  local target = nil
  if MenuValueQ and Player.Mana > qMana and Evelynn.Q:IsReady() then
    if not isq2 then
      target = Utils.GetTargets(Evelynn.Q)
    else
      target = Utils.GetTargets(Evelynn.Q2)
    end
    if target == nil then return false end

    for k, enemy in pairs(target) do
      if Utils.WaitForW(enemy) then return false end
      if isq2 and Utils.IsValidTarget(enemy) then
        if Evelynn.Q2:Cast(enemy) then return true end
      else
        local qPred = Evelynn.Q:GetPrediction(enemy)
        if qPred ~= nil and Utils.IsValidTarget(enemy) and qPred.HitChanceEnum >= HitChanceEnum.Medium and (not Evelynn.W:IsReady() or Player.Mana < qMana + eMana + rMana or Player:Distance(enemy.Position) < 600 ) and Game.GetTime() - LastW > 1  then
          if Evelynn.Q:Cast(qPred.CastPosition) then return true end
        end
      end
    end
  end
  if MenuValueE and Player.Mana > eMana and Evelynn.E:IsReady() then
    for k, enemy in pairs(Utils.GetTargets(Evelynn.E)) do
      if Utils.WaitForW(enemy) then return false end
      if Utils.IsValidTarget(enemy) then
        if Evelynn.E:Cast(enemy) then return true end
      end
    end
  end
  if MenuValueW and Player.Mana > qMana + eMana + rMana and Evelynn.W:IsReady() then
    for k, enemy in pairs(Utils.GetTargetsRange(800)) do
      if Evelynn.Q:IsReady() then
        if isq2 and Player:Distance(enemy.Position) < Evelynn.Q2.Range then
          return false
        elseif not isq2 and Player:Distance(enemy.Position) < 600 then
          return false
        end
      end
      local bonusdmg = 1
      if enemy.Health/enemy.MaxHealth * 100 < 30 then
        bonusdmg = 2.4
      end
      if Evelynn.R:IsReady() and enemy.Health < Evelynn.R:GetDamage(enemy)*bonusdmg and Player:Distance(enemy.Position) < Evelynn.R.Range then return false end
      if Evelynn.E:IsReady() and Player:Distance(enemy.Position) < Evelynn.E.Range then return false end
      if Utils.IsValidTarget(enemy) then
        if Evelynn.W:Cast(enemy) then return true end
      end
    end
  end
  if MenuValueR and Player.Mana > rMana and Evelynn.R:IsReady() and Game.GetTime() - overkill > 0.3 then
    for k, enemy in pairs(Utils.GetTargets(Evelynn.R)) do
      local rPred = Evelynn.R:GetPrediction(enemy)
      local delay = (Player:Distance(enemy.Position)/ Evelynn.R.Speed + Evelynn.R.Delay)*1000
      local hpPred = HPred.GetHealthPrediction(enemy,delay,false)
      local bonusdmg = 1
      if enemy.Health/enemy.MaxHealth * 100 < 30 then
        bonusdmg = 2.4
      end
      if rPred ~= nil and hpPred < Evelynn.R:GetDamage(enemy)*bonusdmg and Utils.ValidUlt(enemy) and rPred.HitChanceEnum >= HitChanceEnum.High  and Utils.IsValidTarget(enemy) then
        if Evelynn.R:Cast(rPred.CastPosition) then return true end
      end
      if (Player.Health/Player.MaxHealth) * 100 < 60 then
        local incomingDamage = HPred.GetDamagePrediction(Player,1,true)
        local enemies = Utils.CountHeroes(Player,700,"enemy")
        if rPred ~= nil and incomingDamage > 0 and Player.Health - incomingDamage < enemies * Player.Level * 15 then
          if Evelynn.R:Cast(rPred.CastPosition) then return true end
        elseif rPred ~= nil and incomingDamage > 0 and Player.Health - incomingDamage < Player.Level * 10 then
          if Evelynn.R:Cast(rPred.CastPosition) then return true end
        end
      end
    end
  end
  return false
end

function Evelynn.Logic.Harass()
  if Menu.Get("ManaSlider") >= Player.ManaPercent * 100 then return false end
  local MenuValueQ = Menu.Get("Harass.Q")
  local MenuValueW = Menu.Get("Harass.W")
  local MenuValueE = Menu.Get("Harass.E")
  local target = nil
  if MenuValueQ and Player.Mana > qMana and Evelynn.Q:IsReady() then
    if not isq2 then
      target = Utils.GetTargets(Evelynn.Q)
    else
      target = Utils.GetTargets(Evelynn.Q2)
    end
    if target == nil then return false end

    for k, enemy in pairs(target) do
      if Utils.WaitForW(enemy) then return false end
      if isq2 then
        if Evelynn.Q2:Cast(enemy) then return true end
      else
        local qPred = Evelynn.Q:GetPrediction(enemy)
        if qPred ~= nil and qPred.HitChanceEnum >= HitChanceEnum.High then
          if Evelynn.Q:Cast(qPred.CastPosition) then return true end
        end
      end
    end
  end
  if MenuValueE and Player.Mana > eMana and Evelynn.E:IsReady() then
    for k, enemy in pairs(Utils.GetTargets(Evelynn.E)) do
      if Utils.WaitForW(enemy) then return false end
      if Evelynn.E:Cast(enemy) then return true end
    end
  end
  if MenuValueW and Player.Mana > qMana + eMana + rMana and Evelynn.W:IsReady() then
    for k, enemy in pairs(Utils.GetTargetsRange(800)) do
      if Evelynn.Q:IsReady() then
        if isq2 and Player:Distance(enemy.Position) < Evelynn.Q2.Range then
          return false
        elseif not isq2 and Player:Distance(enemy.Position) < 600 then
          return false
        end
      end
      if Evelynn.R:IsReady() and enemy.Health < Evelynn.R:GetDamage(enemy) and Player:Distance(enemy.Position) < Evelynn.R.Range then return false end
      if Evelynn.E:IsReady() and Player:Distance(enemy.Position) < Evelynn.E.Range then return false end
      if Evelynn.W:Cast(enemy) then return true end
    end
  end

  return false
end
function Evelynn.Logic.Waveclear()
  if Menu.Get("WaveClear.Q") and Menu.Get("ManaSliderLane") <= Player.ManaPercent * 100 and Evelynn.Q:IsReady() and Player.Mana > qMana then
    local minionsQ = {}
    for k, v in pairs(ObjectManager.GetNearby("enemy", "minions")) do
      local minion = v.AsAI
      local minionInRange = nil
      if not isq2 then
        minionInRange = minion and minion.MaxHealth > 6 and Evelynn.Q:IsInRange(minion)
      else
        minionInRange = minion and minion.MaxHealth > 6 and Evelynn.Q2:IsInRange(minion)
      end
      if minionInRange and minion.IsTargetable then
        table.insert(minionsQ, minion)
        table.sort(minionsQ, function(a, b) return a.MaxHealth > b.MaxHealth end)
      end
    end
    for k, minion in pairs(minionsQ) do
      if isq2 then
        if Evelynn.Q2:Cast(minion) then return true end
      else
        local qPred = Evelynn.Q:GetPrediction(minion)
        if qPred ~= nil then
          if Evelynn.Q:Cast(qPred.CastPosition) then return true end
        end
      end
    end
  end
  if Menu.Get("WaveClear.Q") and Evelynn.Q:IsReady() and Player.Mana > qMana then
    for k, v in pairs(ObjectManager.GetNearby("neutral", "minions")) do
      local minion = v.AsMinion
      if minion.IsTargetable and not minion.IsJunglePlant and Evelynn.Q:IsInRange(minion) then
        if isq2 then
          if Evelynn.Q2:Cast(minion) then return true end
        else
          local qPred = Evelynn.Q:GetPrediction(minion)
          if qPred ~= nil then
            if Evelynn.Q:Cast(qPred.CastPosition) then return true end
          end
        end
      end
    end
  end
  if Menu.Get("WaveClear.E") and Evelynn.E:IsReady() and Player.Mana > eMana + qMana then
    for k, v in pairs(ObjectManager.GetNearby("neutral", "minions")) do
      local minion = v.AsMinion
      if minion.IsTargetable and not minion.IsJunglePlant and Evelynn.E:IsInRange(minion) then
        if Evelynn.E:Cast(minion) then return true end
      end
    end
  end
  return false
end

function Evelynn.Logic.Auto()
  for k, hero in pairs(ObjectManager.GetNearby("enemy", "heroes")) do
    local enemy = hero.AsAI
    if Evelynn.Q:IsReady() or Evelynn.Q2:IsReady() and Player.Mana > qMana and Evelynn.Q2:IsInRange(enemy) then
      local enemy = hero.AsAI
      local delay = (Player:Distance(enemy.Position)/ Evelynn.Q.Speed + Evelynn.Q.Delay)*1000
      local hpPred = HPred.GetHealthPrediction(enemy,delay,false)
      if hpPred < Evelynn.Q:GetDamage(enemy)*3 and Utils.IsValidTarget(enemy) then
        overkill = Game.GetTime()
      end
    end
    if Evelynn.E:IsReady() and Player.Mana > eMana and Evelynn.E:IsInRange(enemy) then
      local delay = (Player:Distance(enemy.Position)/ Evelynn.E.Delay)*1000
      local hpPred = HPred.GetHealthPrediction(enemy,delay,false)
      if hpPred < Evelynn.E:GetDamage(enemy) and Utils.IsValidTarget(enemy) then
        overkill = Game.GetTime()
      end
    end
  end
  if Menu.Get("CastR") and Evelynn.R:IsReady() and Player.Mana > rMana then
    for k, enemy in pairs(Utils.GetTargets(Evelynn.R)) do
      local rPred = Evelynn.R:GetPrediction(enemy)
      if rPred ~= nil then
        if Evelynn.R:Cast(enemy) then return true end
      end
    end
  end
  if Menu.Get("AutoR") and Evelynn.R:IsReady() and Player.Mana > rMana then
    local enemies = {}
    for k, enemy in pairs(ObjectManager.Get("enemy", "heroes")) do
      local target = enemy.AsHero
      local pos = target:FastPrediction(Game.GetLatency() + Evelynn.R.Delay)
      if Utils.IsValidTarget(target) and Player:Distance(target.Position) <= 550 then
        table.insert(enemies, target.Position)
      end
    end
    local rCastPos, hitCount = Evelynn.R:GetBestCircularCastPos(enemies,Evelynn.R.Radius)
    if rCastPos ~= nil and hitCount >= Menu.Get("HitcountR") then
      if Evelynn.R:Cast(rCastPos) then return true end
    end
  end
  if Player.Mana > rMana and Evelynn.R:IsReady() and Menu.Get("AutoRKS") then
    for k, enemy in pairs(ObjectManager.GetNearby("enemy","heroes")) do
      local rPred = Evelynn.R:GetPrediction(enemy)
      local delay = (Player:Distance(enemy.Position)/ Evelynn.R.Speed + Evelynn.R.Delay)*1000
      local hpPred = HPred.GetHealthPrediction(enemy,delay,false)
      local bonusdmg = 1
      if enemy.Health/enemy.MaxHealth * 100 < 30 then
        bonusdmg = 2.4
      end
      if rPred ~= nil and hpPred < Evelynn.R:GetDamage(enemy)*bonusdmg and Utils.ValidUlt(enemy) and rPred.HitChanceEnum >= HitChanceEnum.High and Evelynn.R:IsInRange(enemy) and Utils.IsValidTarget(enemy) then
        if Evelynn.R:Cast(rPred.CastPosition) then return true end
      end
    end
  end
  return false
end
function Evelynn.OnProcessSpell(sender,spell)
  if sender.IsMe and spell.Name == "EvelynnWApplyMark" and Menu.Get("Combo.WaitW") then
    LastW = Game.GetTime()
  end
  return false
end
function Evelynn.OnDraw()
  if Player.IsVisible and Player.IsOnScreen and not Player.IsDead then
    local Pos = Player.Position
    local spells = {Evelynn.Q,Evelynn.W,Evelynn.E,Evelynn.R}
    for k, v in pairs(spells) do
      if Menu.Get("Drawing."..v.Key..".Enabled", true) then
        if Renderer.DrawCircle3D(Pos, v.Range, 30, 3, Menu.Get("Drawing."..v.Key..".Color")) then return true end
      end
    end
  end
  return false
end

function Evelynn.OnPreAttack(args)
  if Utils.WaitForW(args.Target) then
    args.Process = false
    if args.Process == false then return true end
  end
  return false
end

function Evelynn.OnUpdate()
  if not Utils.IsGameAvailable() then return false end
  local OrbwalkerMode = Orbwalker.GetMode()

  if Player:GetSpell(SpellSlots.Q).Name == "EvelynnQ2" then
    isq2 = true
  else
    isq2 = false
  end

  local OrbwalkerLogic = Evelynn.Logic[OrbwalkerMode]
  if OrbwalkerLogic then
    if OrbwalkerLogic() then return true end
  end
  if Evelynn.Logic.Auto() then return true end
  if Utils.SetMana() then return true end
  return false
end

function Evelynn.LoadMenu()
  local function EvelynnMenu()
    Menu.ColumnLayout("Casting", "Casting", 2, true, function ()
    Menu.ColoredText("Combo", 0xB65A94FF, true)
    Menu.ColoredText("> Q", 0x0066CCFF, false)
    Menu.Checkbox("Combo.Q", "Use Q", true)
    Menu.ColoredText("> W", 0x0066CCFF, false)
    Menu.Checkbox("Combo.W", "Use W", true)
    Menu.Checkbox("Combo.WaitW", "Wait for W", true)
    Menu.ColoredText("> E", 0x0066CCFF, false)
    Menu.Checkbox("Combo.E", "Use E", true)
    Menu.ColoredText("> R", 0x0066CCFF, false)
    Menu.Checkbox("Combo.R", "Use R", true)
    Menu.Keybind("CastR", "Semi [R] Cast", string.byte('T'))
    Menu.ColoredText("Harass", 0x118AB2FF, true)
    Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
    Menu.Slider("ManaSlider","for Q",50,0,100)
    Menu.ColoredText("> Q", 0x0066CCFF, false)
    Menu.Checkbox("Harass.Q", "Use Q", true)
    Menu.ColoredText("> W", 0x0066CCFF, false)
    Menu.Checkbox("Harass.W", "Use W", false)
    Menu.ColoredText("> E", 0x0066CCFF, false)
    Menu.Checkbox("Harass.E", "Use E", true)
    Menu.ColoredText("WaveClear/JungleClear", 0xEF476FFF, true)
    Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
    Menu.Slider("ManaSliderLane","",35,0,100)
    Menu.ColoredText("> Q", 0x0066CCFF, false)
    Menu.Checkbox("WaveClear.Q", "Use Q", true)
    Menu.ColoredText("> E", 0x0066CCFF, false)
    Menu.Checkbox("WaveClear.E", "Use Q", true)
    Menu.ColoredText("Misc", 0xB65A94FF, true)
    Menu.Checkbox("AutoR", "Auto R HitCount", true)
    Menu.Slider("HitcountR", "HitCount", 3, 1, 5)
    Menu.Checkbox("AutoRKS", "Auto R KS", false)
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
  if Menu.RegisterMenu("Simple Evelynn", "Simple Evelynn", EvelynnMenu) then return true end
  return false
end

function OnLoad()
  Evelynn.LoadMenu()
  for EventName, EventId in pairs(Events) do
    if Evelynn[EventName] then
      EventManager.RegisterCallback(EventId, Evelynn[EventName])
    end
  end
  return true
end
