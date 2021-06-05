if Player.CharName ~= "Morgana" then return end

module("Simple Morgana", package.seeall, log.setup)
clean.module("Simple Morgana", clean.seeall, log.setup)

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

local Morgana = {}
local qMana = 0
local wMana = 0
local eMana = 0
local rMana = 0
local spellslist = {}

Morgana.Q = SpellLib.Skillshot({
  Slot = SpellSlots.Q,
  Range = 1300,
  Delay = 0.250,
  Speed = 1200,
  Radius = 140,
  Collisions = { Heroes = true, Minions = true, WindWall = true },
  Type = "Linear",
  UseHitbox = true,
  Key = "Q"
})

Morgana.W = SpellLib.Skillshot({
  Slot = SpellSlots.W,
  Range = 1000,
  Delay = 0.500,
  Radius = 275,
  Type = "Circular",
  Key = "W"
})

Morgana.E = SpellLib.Targeted({
  Slot = SpellSlots.E,
  Range = 800,
  Key = "E"
})

Morgana.R = SpellLib.Active({
  Slot = SpellSlots.R,
  Range = 600,
  Delay = 0.350,
  Key = "R"
})

Morgana.TargetSelector = nil
Morgana.Logic = {}

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
  if Morgana.Q:IsReady() then
    qMana = Morgana.Q:GetManaCost()
  else
    qMana = 0
  end
  if Morgana.W:IsReady() then
    wMana = Morgana.W:GetManaCost()
  else
    wMana = 0
  end
  if Morgana.E:IsReady() then
    eMana = Morgana.E:GetManaCost()
  else
    eMana = 0
  end
  if Morgana.R:IsReady() then
    rMana = Morgana.R:GetManaCost()
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

function Morgana.Logic.Combo()
  local MenuValueQ = Menu.Get("Combo.Q")
  local MenuValueW = Menu.Get("Combo.W")
  local MenuValueR = Menu.Get("Combo.R")
  for k, enemy in pairs(Utils.GetTargets(Morgana.Q)) do
    if Morgana.Q:IsReady() and MenuValueQ then
      local predQ = Morgana.Q:GetPrediction(enemy)
      if predQ ~= nil and predQ.HitChanceEnum >= HitChanceEnum.High and Morgana.Q:IsInRange(enemy) then
        if Morgana.Q:Cast(predQ.CastPosition) then return true end
      end
    end
    if Morgana.W:IsReady() and MenuValueW and not enemy.IsZombie then
      local predW = Morgana.W:GetPrediction(enemy)
      if predW ~= nil and Morgana.W:GetDamage(enemy) >= enemy.Health and Morgana.W:IsInRange(enemy) and predW.HitChanceEnum >= HitChanceEnum.VeryHigh then
        if Morgana.W:Cast(predW.CastPosition) then return true end
      elseif predW ~= nil and not Morgana.Q:IsReady() and Player.Mana > qMana+wMana+eMana+rMana and Morgana.W:IsInRange(enemy) and predW.HitChanceEnum >= HitChanceEnum.VeryHigh then
        if Morgana.W:Cast(predW.CastPosition) then return true end
      elseif predW ~= nil and not Menu.Get("AutoWcc") and not enemy.CanMove and predW.HitChanceEnum == HitChanceEnum.Immobile and Morgana.W:IsInRange(predW.CastPosition) then
        if Morgana.W:Cast(predW.CastPosition) then return true end
      end
    end
    if Morgana.R:IsReady() and MenuValueR and not enemy.IsZombie then
      local predH = HPred.GetHealthPrediction(enemy,1,true)
      if Morgana.R:GetDamage(enemy)*3 >= enemy.Health and predH > enemy.Level * 10 then
        if Morgana.R:Cast() then return true end
      end
      if Utils.Count(Morgana.R) >= Menu.Get("Combo.HitcountR") then
        if Morgana.R:Cast() then return true end
      end
    end
  end
  return false
end

function Morgana.Logic.Harass()
  if Menu.Get("ManaSlider") >= Player.ManaPercent * 100 then return false end
  local MenuValueQ = Menu.Get("Harass.Q")
  local MenuValueW = Menu.Get("Harass.W")
  for k, enemy in pairs(Utils.GetTargets(Morgana.Q)) do
    if Morgana.Q:IsReady() and MenuValueQ then
      local predQ = Morgana.Q:GetPrediction(enemy)
      if predQ ~= nil and predQ.HitChanceEnum >= HitChanceEnum.VeryHigh and Morgana.Q:IsInRange(enemy) then
        if Morgana.Q:Cast(predQ.CastPosition) then return true end
      end
    end
    if Morgana.W:IsReady() and MenuValueW and not enemy.IsZombie then
      local predW = Morgana.W:GetPrediction(enemy)
      if predW ~= nil and Morgana.W:GetDamage(enemy) >= enemy.Health and Morgana.W:IsInRange(enemy) and predW.HitChanceEnum >= HitChanceEnum.VeryHigh then
        if Morgana.W:Cast(predW.CastPosition) then return true end
      elseif predW ~= nil and Morgana.W:IsInRange(predW.CastPosition) and predW.HitChanceEnum >= HitChanceEnum.VeryHigh then
        if Morgana.W:Cast(predW.CastPosition) then return true end
      elseif predW ~= nil and not Menu.Get("AutoWcc") and not enemy.CanMove and predW.HitChanceEnum == HitChanceEnum.Immobile and Morgana.W:IsInRange(predW.CastPosition) then
        if Morgana.W:Cast(predW.CastPosition) then return true end
      end
    end
  end
  return false
end

function Morgana.Logic.Waveclear()
  local MenuValueQ = Menu.Get("WaveClear.Q")
  local MenuValueW = Menu.Get("WaveClear.W")
  local Cannons = {}
  local otherMinions = {}
  local JungleMinions = {}
  for k, v in pairs(ObjectManager.GetNearby("enemy", "minions")) do
    local minion = v.AsMinion
    local pos = minion:FastPrediction(Game.GetLatency()+ Morgana.W.Delay)
    if minion.IsTargetable and (minion.IsSiegeMinion or minion.IsSuperMinion) and Morgana.W:IsInRange(minion) then
      table.insert(Cannons, pos)
    end
    if minion.IsTargetable and minion.IsLaneMinion and Morgana.W:IsInRange(minion) then
      table.insert(otherMinions, pos)
    end
    if Morgana.W:IsReady() and  MenuValueW then
      local cannonsPos, hitCount1 = Morgana.W:GetBestCircularCastPos(Cannons, Morgana.W.Radius)
      local laneMinionsPos, hitCount2 = Morgana.W:GetBestCircularCastPos(otherMinions, Morgana.W.Radius)

      if cannonsPos ~= nil and laneMinionsPos ~= nil and Menu.Get("ManaSliderLane") <= Player.ManaPercent * 100 then
        if hitCount1 >= 1 then
          if Morgana.W:Cast(cannonsPos) then return true end
        end
      end
      if laneMinionsPos ~= nil and Menu.Get("ManaSliderLane") <= Player.ManaPercent * 100 then
        if hitCount2 >= 3 then
          if Morgana.W:Cast(laneMinionsPos) then return true end
        end
      end
    end
  end
  for k, v in pairs(ObjectManager.GetNearby("neutral", "minions")) do
    local minion = v.AsMinion
    local pos = minion:FastPrediction(Game.GetLatency()+ Morgana.W.Delay)
    if Morgana.W:IsInRange(minion) and minion.IsTargetable and not minion.IsJunglePlant then
      table.insert(JungleMinions, pos)
      local predQ = Prediction.GetPredictedPosition(minion, Morgana.Q, Player.Position)
      if predQ ~= nil and Morgana.Q:IsReady() and MenuValueQ and predQ.HitChanceEnum >= HitChanceEnum.VeryHigh  then
        if Morgana.Q:Cast(predQ.CastPosition) then return true end
      end
    end
    if Morgana.W:IsReady() and  MenuValueW then
      local JungleMinionPos, hitCount3 = Morgana.W:GetBestCircularCastPos(JungleMinions, Morgana.W.Radius)
      if JungleMinionPos ~= nil then
        if hitCount3 >= 1 then
          if Morgana.W:Cast(JungleMinionPos) then return true end
        end
      end
    end
  end
  return false
end

function Morgana.Logic.Auto()
  if Menu.Get("AutoQcc") then
    for k, v in pairs(ObjectManager.GetNearby("enemy", "heroes")) do
      local enemy = v.AsHero
      if not enemy.CanMove and Morgana.Q:IsReady() and Morgana.Q:IsInRange(enemy) then
        if Morgana.Q:CastOnHitChance(enemy,Enums.HitChance.Immobile) then return true end
      end
    end
  end
  if Menu.Get("AutoWcc") then
    for k, v in pairs(ObjectManager.GetNearby("enemy", "heroes")) do
      local enemy = v.AsHero
      if not enemy.CanMove and Morgana.W:IsReady() and Morgana.W:IsInRange(enemy) then
        if Morgana.W:CastOnHitChance(enemy,Enums.HitChance.Immobile) then return true end
      end
    end
  end
  return false
end

function Morgana.OnProcessSpell(sender,spell)
  if sender.IsHero and sender.IsEnemy and Menu.Get("AutoE") then
    for _, v in pairs(ObjectManager.GetNearby("ally","heroes")) do
      local hero = v.AsHero
      if Menu.Get("1" .. hero.CharName) and  Morgana.E:IsInRange(hero) and Player:Distance(spell.EndPos) <= Morgana.E.Range then
        local pred = hero:FastPrediction(Game.GetLatency()+ spell.CastDelay)
        if spell.LineWidth > 0 then
          local powCalc = (spell.LineWidth + hero.BoundingRadius)^2
          if (Vector(pred):LineDistance(Vector(spell.StartPos),Vector(spell.EndPos),true) <= powCalc) or (Vector(hero.Position):LineDistance(Vector(spell.StartPos),Vector(spell.EndPos),true) <= powCalc) and Morgana.E:IsReady() then
            if Utils.hasValue(spellslist,spell.Name) then
              if Morgana.E:Cast(hero) then return true end
            end
          end
        elseif hero:Distance(spell.EndPos) < 50 + hero.BoundingRadius or pred:Distance(spell.EndPos) < 50 + hero.BoundingRadius and Morgana.E:IsReady() then
          if Utils.hasValue(spellslist,spell.Name) then
            if Morgana.E:Cast(hero) then return true end
          end
        end
      end
      if spell.Target and spell.Target.IsHero and spell.Target.IsAlly and Morgana.E:IsInRange(spell.Target.AsHero) and Menu.Get("1" .. spell.Target.AsHero.CharName) and Morgana.E:IsReady() then
        if Utils.hasValue(spellslist,spell.Name) then
          if Morgana.E:Cast(spell.Target.AsHero) then return true end
        end
      end
    end
  end
  return false
end

function Morgana.OnBuffGain(obj,buffInst)
  if obj.IsHero and obj.IsAlly then
    if buffInst.BuffType == Enums.BuffTypes.Poison  and Menu.Get("AutoE") and Morgana.E:IsReady() and Morgana.E:IsInRange(obj.AsHero) and  Menu.Get("1" .. obj.AsHero.CharName) then
      if Morgana.E:Cast(obj.AsHero) then return true end
    end
  end
  return false
end

function Morgana.OnInterruptibleSpell(source, spell, danger, endT, canMove)
  if source.IsEnemy and Menu.Get("AutoRI") and Morgana.R:IsReady() and danger > 2 and Player:Distance(source.Position) <= Morgana.R.Range then
    if Morgana.R:Cast() then return true end
  end
  return false
end

function Morgana.OnGapclose(source,dash)
  if source.IsEnemy and source.IsHero  and not dash.IsBlink then
    local paths = dash:GetPaths()
    local endPos = paths[#paths].EndPos
    local predQ = Prediction.GetPredictedPosition(source.AsHero, Morgana.Q, Player.Position)
    if Player:Distance(endPos) <= 600 and Menu.Get("AutoQg") and Morgana.Q:IsReady() and predQ.HitChanceEnum >= HitChanceEnum.VeryHigh then
      if Morgana.Q:Cast(predQ.CastPosition) then return true end
    end
    if Player:Distance(source.Position) <= Morgana.R.Range and Menu.Get("AutoRg") and Morgana.R:IsReady() then
      if Morgana.R:Cast() then return true end
    end
  end
  return false
end

function Morgana.OnDraw()
  if Player.IsVisible and Player.IsOnScreen and not Player.IsDead then
    local Pos = Player.Position
    local spells = {Morgana.Q,Morgana.W,Morgana.E,Morgana.R}
    for k, v in pairs(spells) do
      if Menu.Get("Drawing."..v.Key..".Enabled", true) then
        if Renderer.DrawCircle3D(Pos, v.Range, 30, 3, Menu.Get("Drawing."..v.Key..".Color")) then return true end
      end
    end
  end
  return false
end

function Morgana.OnUpdate()
  if not Utils.IsGameAvailable() then return false end
  local OrbwalkerMode = Orbwalker.GetMode()

  local OrbwalkerLogic = Morgana.Logic[OrbwalkerMode]

  if OrbwalkerLogic then
    if OrbwalkerLogic() then return true end
  end
  if Morgana.Logic.Auto() then return true end
  if Utils.SetMana() then return true end
  return false
end

function Morgana.LoadMenu()
  local function MorganaMenu()
    Menu.ColumnLayout("Casting", "Casting", 2, true, function ()
    Menu.ColoredText("Combo", 0xB65A94FF, true)
    Menu.ColoredText("> Q", 0x0066CCFF, false)
    Menu.Checkbox("Combo.Q", "Use Q", true)
    Menu.ColoredText("> W", 0x0066CCFF, false)
    Menu.Checkbox("Combo.W", "Use W", true)
    Menu.ColoredText("> R", 0x0066CCFF, false)
    Menu.Checkbox("Combo.R", "Use R", true)
    Menu.Slider("Combo.HitcountR", "[R] HitCount", 2, 1, 5)
    Menu.ColoredText("Harass", 0x118AB2FF, true)
    Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
    Menu.Slider("ManaSlider","",50,0,100)
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
    Menu.Checkbox("AutoQcc", "Auto Q chain cc", true)
    Menu.Checkbox("AutoWcc", "Auto W on cc", true)
    Menu.Checkbox("AutoQg", "Auto Q Gapclose", true)
    Menu.Checkbox("AutoRg", "Auto R Gapclose", true)
    Menu.Checkbox("AutoRI", "Auto R Interupt", true)
    Menu.Checkbox("AutoE", "Auto E Shield", true)
    Menu.NewTree("EList","E ally whitelist", function()
    Menu.ColoredText("E Whitelist", 0x06D6A0FF, true)
    for _, Object in pairs(ObjectManager.Get("ally", "heroes")) do
      local Name = Object.AsHero.CharName
      Menu.Checkbox("1" .. Name, "Use on " .. Name, true)
    end
    end)
    Menu.NewTree("EListSpells","E spells whitelist", function()
    Menu.ColoredText("E SpellsWhitelist", 0x06D6A0FF, true)
    for _, Object in pairs(ObjectManager.Get("enemy", "heroes")) do
      local hero = Object.AsHero
      local Name = Object.AsHero.CharName
      Menu.NewTree(Name,Name, function()
      Menu.Checkbox("Q" .. Name, "Use for " .. Name .. "Q", true)
      Menu.Checkbox("W" .. Name, "Use for " .. Name .. "W", true)
      Menu.Checkbox("E" .. Name, "Use for " .. Name .. "E", true)
      Menu.Checkbox("R" .. Name, "Use for " .. Name .. "R", true)
      end)
      local spellQName = hero:GetSpell(SpellSlots.Q).Name
      local spellWName = hero:GetSpell(SpellSlots.W).Name
      local spellEName = hero:GetSpell(SpellSlots.E).Name
      local spellRName = hero:GetSpell(SpellSlots.R).Name
      if Menu.Get("Q"..Name) then
        table.insert(spellslist,spellQName)
      elseif not Menu.Get("Q"..Name) and Utils.hasValue(spellslist,spellQName) then
        table.remove(spellslist,Utils.tablefind(spellslist,spellQName))
      end
      if Menu.Get("W"..Name) then
        table.insert(spellslist,spellWName)
      elseif not Menu.Get("W"..Name) and Utils.hasValue(spellslist,spellWName) then
        table.remove(spellslist,Utils.tablefind(spellslist,spellWName))
      end
      if Menu.Get("E"..Name) then
        table.insert(spellslist,spellEName)
      elseif not Menu.Get("E"..Name) and Utils.hasValue(spellslist,spellEName) then
        table.remove(spellslist,Utils.tablefind(spellslist,spellEName))
      end
      if Menu.Get("R"..Name) then
        table.insert(spellslist,spellRName)
      elseif not Menu.Get("R"..Name) and Utils.hasValue(spellslist,spellRName) then
        table.remove(spellslist,Utils.tablefind(spellslist,spellRName))
      end
    end
    end)
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
  if Menu.RegisterMenu("Simple Morgana", "Simple Morgana", MorganaMenu) then return true end
  return false
end

function OnLoad()
  Morgana.LoadMenu()
  for EventName, EventId in pairs(Events) do
    if Morgana[EventName] then
      EventManager.RegisterCallback(EventId, Morgana[EventName])
    end
  end
  return true
end
