if Player.CharName ~= "Ivern" then return end

module("Simple Ivern", package.seeall, log.setup)
clean.module("Simple Ivern", clean.seeall, log.setup)

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

local Ivern = {}
local qMana = 0
local wMana = 0
local eMana = 0
local rMana = 0
local ivernBush = {}
local LastCastT = {[SpellSlots.R] = 0}
local Daisy = {}

Ivern.Q = SpellLib.Skillshot({
  Slot = SpellSlots.Q,
  Range = 1100,
  Speed = 1300,
  Radius = 80,
  Delay = 0.25,
  Collisions = {Heroes = true, Minions = true, WindWall = true },
  Type = "Linear",
  UseHitbox = true,
  Key = "Q"
})

Ivern.W = SpellLib.Skillshot({
  Slot = SpellSlots.W,
  Range = 1600,
  Speed = 1000,
  Radius = 100,
  Delay = 0.25,
  Type = "Circular",
  Key = "W"
})

Ivern.E = SpellLib.Targeted({
  Slot = SpellSlots.E,
  Range = 750,
  Key = "E"
})

Ivern.R = SpellLib.Skillshot({
  Slot = SpellSlots.R,
  Range = 350,
  Key = "R",
})

Ivern.TargetSelector = nil
Ivern.Logic = {}

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
  if Ivern.Q:IsReady() then
    qMana = Ivern.Q:GetManaCost()
  else
    qMana = 0
  end
  if Ivern.W:IsReady() then
    wMana = Ivern.W:GetManaCost()
  else
    wMana = 0
  end
  if Ivern.E:IsReady() then
    eMana = Ivern.E:GetManaCost()
  else
    eMana = 0
  end
  if Ivern.R:IsReady() then
    rMana = Ivern.R:GetManaCost()
  else
    rMana = 0
  end
  return false
end

function Utils.GetTargets(Spell)
  return TS:GetTargets(Spell.Range,true)
end

function Utils.IsValidTarget(Target)
  return Target and Target.IsTargetable and Target.IsAlive
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

function Utils.ivernPet()
  local spellRName = Player:GetSpell(SpellSlots.R).Name
  if spellRName == "IvernRRecast" then
    return true
  else
    return false
  end
end

function Utils.daisyFollow()
  if not Utils.ivernPet() then return false end
  local tick = os_clock()
  local OrbwalkerMode = Orbwalker.GetMode()
  if Ivern.R:IsReady() then
    local target = Orbwalker.GetLastTarget()
    if OrbwalkerMode == "nil" and target == nil then
      if LastCastT[SpellSlots.R] + 0.75 < tick then
        LastCastT[SpellSlots.R] = tick
        if Input.Cast(SpellSlots.R,Player) then return true end
      end
    end
    if target == nil then
      for k, enemy in pairs(Utils.GetTargets(Ivern.Q)) do
        target = enemy
      end
    end
    if target ~= nil and target:Distance(Player.Position) <= 1000 then
      if LastCastT[SpellSlots.R] + 0.75 < tick then
        LastCastT[SpellSlots.R] = tick
        if Input.Cast(SpellSlots.R,target.Position) then return true end
      end
    end
  end
  return false
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

function Ivern.Logic.Combo()
  local MenuValueQ = Menu.Get("Combo.Q")
  local MenuValueW = Menu.Get("Combo.W")
  local MenuValueR = Menu.Get("Combo.R")
  local next = next
  for k, enemy in pairs(Utils.GetTargets(Ivern.Q)) do
    if Ivern.Q:IsReady() and MenuValueQ and Player.Mana >= qMana then
      local predQ = Ivern.Q:GetPrediction(enemy)
      if predQ ~= nil then
        if not Player:GetBuff("ivernqallyjump") and predQ.HitChanceEnum >= HitChanceEnum.High then
          if Ivern.Q:Cast(predQ.CastPosition) then return true end
        elseif not Player:GetBuff("ivernqallyjump") and predQ.HitChanceEnum >= HitChanceEnum.Low and enemy.AsHero.Health/enemy.AsHero.MaxHealth *100 <= 35 then
          if Ivern.Q:Cast(predQ.CastPosition) then return true end
        end
      end
    end
  end
  for k, enemy in pairs(ObjectManager.GetNearby("enemy", "heroes")) do
    if Ivern.W:IsReady() and MenuValueW and Player.Mana > qMana + wMana*2 + rMana + eMana then
      for _, ally in pairs(ObjectManager.GetNearby("ally", "heroes")) do
        local incomingDamage = HPred.GetDamagePrediction(ally,2,true)
        if next(ivernBush) and not Orbwalker.IsWindingUp() then
          for key, value in pairs(ivernBush) do
            if Ivern.W:IsInRange(ally) and not Nav.IsGrass(ally.Position) and value:Distance(ally.Position) > 300 and (incomingDamage >= ally.AsHero.Health * 0.4 or not ally.CanMove) and ally:Distance(enemy.Position) < 700 then
              local predW = Ivern.W:GetPrediction(ally)
              if predW ~= nil and predW.HitChanceEnum >= HitChanceEnum.Low then
                if Ivern.W:Cast(predW.CastPosition) then return true end
              end
            end
            if not Player:GetBuff("ivernwpassive") and not Nav.IsGrass(Player.Position) and value:Distance(Player.Position) > 300 and Player:Distance(enemy.Position) <= 325 then
              if Ivern.W:Cast(Player) then return true end
            end
          end
        elseif not next(ivernBush) and not Orbwalker.IsWindingUp() then
          if Ivern.W:IsInRange(ally) and not Nav.IsGrass(ally.Position) and (incomingDamage >= ally.AsHero.Health * 0.4 or not ally.CanMove) and ally:Distance(enemy.Position) < 700 then
            local predW = Ivern.W:GetPrediction(ally)
            if predW ~= nil and predW.HitChanceEnum >= HitChanceEnum.Low then
              if Ivern.W:Cast(predW.CastPosition) then return true end
            end
          end
          if not Player:GetBuff("ivernwpassive") and not Nav.IsGrass(Player.Position) and Player:Distance(enemy.Position) <= 325 then
            if Ivern.W:Cast(Player) then return true end
          end
        end
      end
    end
    if Ivern.R:IsReady() and MenuValueR and Player.Mana >= qMana + rMana + eMana and not Utils.ivernPet() then
      if Player:Distance(enemy.Position) <= Ivern.R.Range + 50 or (not enemy.CanMove and Player:Distance(enemy.Position) <= 750) then
        if Ivern.R:Cast(enemy.Position) then return true end
      end
    end
  end
  return false
end

function Ivern.Logic.Harass()
  if Menu.Get("ManaSlider") >= Player.ManaPercent * 100 then return false end
  local MenuValueQ = Menu.Get("Harass.Q")
  local MenuValueW = Menu.Get("Harass.W")
  for k, enemy in pairs(Utils.GetTargets(Ivern.Q)) do
    if Ivern.Q:IsReady() and MenuValueQ and Player.Mana >= qMana then
      local predQ = Ivern.Q:GetPrediction(enemy)
      if predQ ~= nil then
        if not Player:GetBuff("ivernqallyjump") and predQ.HitChanceEnum >= HitChanceEnum.High  then
          if Ivern.Q:Cast(predQ.CastPosition) then return true end
        end
      end
    end
  end
  for k, enemy in pairs(ObjectManager.GetNearby("enemy", "heroes")) do
    if Ivern.W:IsReady() and MenuValueW and Player.Mana > qMana + wMana*2 + rMana + eMana then
      for _, ally in pairs(ObjectManager.GetNearby("ally", "heroes")) do
        local incomingDamage = HPred.GetDamagePrediction(ally,2,true)
        if next(ivernBush) and not Orbwalker.IsWindingUp() then
          for key, value in pairs(ivernBush) do
            if Ivern.W:IsInRange(ally) and not Nav.IsGrass(ally.Position) and value:Distance(ally.Position) > 300 and (incomingDamage >= ally.AsHero.Health * 0.4 or not ally.CanMove) and ally:Distance(enemy.Position) < 700 then
              local predW = Ivern.W:GetPrediction(ally)
              if predW ~= nil and predW.HitChanceEnum >= HitChanceEnum.Low then
                if Ivern.W:Cast(predW.CastPosition) then return true end
              end
            end
            if not Player:GetBuff("ivernwpassive") and not Nav.IsGrass(Player.Position) and value:Distance(Player.Position) > 300 and Player:Distance(enemy.Position) <= 325 then
              if Ivern.W:Cast(Player) then return true end
            end
          end
        elseif not next(ivernBush) and not Orbwalker.IsWindingUp() then
          if Ivern.W:IsInRange(ally) and not Nav.IsGrass(ally.Position) and (incomingDamage >= ally.AsHero.Health * 0.4 or not ally.CanMove) and ally:Distance(enemy.Position) < 700 then
            local predW = Ivern.W:GetPrediction(ally)
            if predW ~= nil and predW.HitChanceEnum >= HitChanceEnum.Low then
              if Ivern.W:Cast(predW.CastPosition) then return true end
            end
          end
          if not Player:GetBuff("ivernwpassive") and not Nav.IsGrass(Player.Position) and Player:Distance(enemy.Position) <= 325 then
            if Ivern.W:Cast(Player) then return true end
          end
        end
      end
    end
  end
  return false
end
function Ivern.Logic.Waveclear()
  if Menu.Get("WaveClear.Q") and Menu.Get("ManaSliderLane") <= Player.ManaPercent * 100 then
    local minionsQ = {}
    for k, v in pairs(ObjectManager.GetNearby("enemy", "minions")) do
      local minion = v.AsAI
      local minionInRange = minion and minion.MaxHealth > 6 and Ivern.Q:IsInRange(minion)
      local shouldIgnoreMinion = minion and (Orbwalker.IsLasthitMinion(minion) or Orbwalker.IsIgnoringMinion(minion))
      if minionInRange and not shouldIgnoreMinion and minion.IsTargetable then
        table.insert(minionsQ, minion)
        table.sort(minionsQ, function(a, b) return a.MaxHealth > b.MaxHealth end)
      end
    end
    for k, minion in pairs(minionsQ) do
      local qPred = Prediction.GetPredictedPosition(minion, Ivern.Q, Player.Position)
      if qPred and qPred.HitChanceEnum >= HitChanceEnum.VeryLow then
        local delay = (Player:Distance(minion.Position)/ Ivern.Q.Speed + Ivern.Q.Delay)*1000
        local hpPred = HPred.GetHealthPrediction(minion,delay,false)
        if hpPred > 0 and hpPred < Ivern.Q:GetDamage(minion)*0.5 then
          if Ivern.Q:Cast(minion.Position) then return true end
        end
      end
    end
  end
  return false
end

function Ivern.Logic.Auto()
  if Menu.Get("AutoQcc") then
    for k, v in pairs(ObjectManager.GetNearby("enemy", "heroes")) do
      local enemy = v.AsHero
      if not enemy.CanMove and Ivern.Q:IsReady() and Ivern.Q:IsInRange(enemy) and enemy.IsValid  and not Player:GetBuff("ivernqallyjump")then
        if Ivern.Q:CastOnHitChance(enemy,Enums.HitChance.Immobile) then return true end
      end
    end
  end
  if Menu.Get("AutoE") and Ivern.E:IsReady() and Player.Mana > eMana then
    for _, v in pairs(ObjectManager.GetNearby("ally","heroes")) do
      local ally = v.AsHero
      local incomingDamage = HPred.GetDamagePrediction(ally,2,false)
      if Ivern.E:IsInRange(ally) and Menu.Get("1" .. ally.CharName) and incomingDamage >= ally.Health * 0.20 then
        if Ivern.E:Cast(ally) then return true end
      end
      for k, enemy in pairs(ObjectManager.GetNearby("enemy", "heroes")) do
        if Ivern.E:IsInRange(ally) and Menu.Get("1" .. ally.CharName) and ally:Distance(enemy.AsHero.Position) < 400 then
          if Ivern.E:Cast(ally) then return true end
        end
      end
    end
    for k, v in pairs(Daisy) do
      if v ~= nil and v.IsValid and v.AsAI.Health > 0 then
        local incomingDamage = HPred.GetDamagePrediction(v.AsAI,2,false)
        if Ivern.E:IsInRange(v) and incomingDamage >= v.AsAI.Health * 0.2 then
          if Ivern.E:Cast(v) then return true end
        end
      end
    end
  end
  return false
end

function Ivern.OnProcessSpell(sender,spell)
  if sender.IsHero and sender.IsEnemy and Menu.Get("AutoE") and not spell.IsBasicAttack then
    for _, v in pairs(ObjectManager.GetNearby("ally","heroes")) do
      local ally = v.AsHero
      if Ivern.E:IsInRange(ally) and Player:Distance(spell.EndPos) <= Ivern.E.Range and Menu.Get("1" .. ally.CharName) then
        if  Utils.CanHit(ally,spell) and Player.Mana > eMana and Ivern.E:IsReady() then
          if Ivern.E:Cast(ally) then return true end
        end
      end
    end
  end
  return false
end

function Ivern.OnCreateObject(obj)
  if obj.Name == "IvernTotem" then
    if table.insert(ivernBush,obj) then return true end
  end
  if obj.Name == "IvernMinion" and obj.IsAlly and obj.IsValid then
    if table.insert(Daisy,obj) then return true end
  end
  return false
end

function Ivern.OnDeleteObject(obj)
  if obj.Name == "Ivern_Base_W_Brush.troy" then
    if table.remove(ivernBush,Utils.tablefind(ivernBush,obj)) then return true end
  end
  if obj.Name == "IvernMinion" and obj.IsAlly  then
    if table.remove(Daisy,Utils.tablefind(Daisy,obj)) then return true end
  end
  return false
end

function Ivern.OnGapclose(source,dash)
  if source.IsEnemy and source.IsHero and not dash.IsBlink then
    local paths = dash:GetPaths()
    local endPos = paths[#paths].EndPos
    if Player:Distance(endPos) <= 400 and Menu.Get("AutoQg") and Ivern.Q:IsReady() then
      local predQ = Ivern.Q:GetPrediction(source)
      if predQ.HitChanceEnum >= HitChanceEnum.Dashing then
        if Ivern.Q:CastOnHitChance(source,Enums.HitChance.VeryHigh) then return true end
      end
    end
  end
  return false
end

function Ivern.OnDraw()
  if Player.IsVisible and Player.IsOnScreen and not Player.IsDead then
    local Pos = Player.Position
    local spells = {Ivern.Q,Ivern.W,Ivern.E,Ivern.R}
    for k, v in pairs(spells) do
      if Menu.Get("Drawing."..v.Key..".Enabled", true) then
        if Renderer.DrawCircle3D(Pos, v.Range, 30, 3, Menu.Get("Drawing."..v.Key..".Color")) then return true end
      end
    end
  end
  return false
end

function Ivern.OnUpdate()
  if not Utils.IsGameAvailable() then return false end
  local OrbwalkerMode = Orbwalker.GetMode()
  local OrbwalkerLogic = Ivern.Logic[OrbwalkerMode]
  for k,v in pairs(ivernBush) do
    if not v.IsValid then
      ivernBush[k]=nil
    end
  end
  for k,v in pairs(Daisy) do
    if not v.IsValid then
      Daisy[k]=nil
    end
  end
  if OrbwalkerLogic then
    if OrbwalkerLogic() then return true end
  end
  if Menu.Get("daisyFollow") then
    if Utils.daisyFollow() then return true end
  end
  if Ivern.Logic.Auto() then return true end
  if Utils.SetMana() then return true end
  return false
end

function Ivern.LoadMenu()
  local function IvernMenu()
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
    Menu.ColoredText("WaveClear", 0xEF476FFF, true)
    Menu.ColoredText("> Q", 0x0066CCFF, false)
    Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
    Menu.Slider("ManaSliderLane","",35,0,100)
    Menu.Checkbox("WaveClear.Q", "Use Q for lasthit", true)
    Menu.NextColumn()
    Menu.ColoredText("Auto", 0xB65A94FF, true)
    Menu.Checkbox("AutoQcc", "Auto Q chain cc", true)
    Menu.Checkbox("AutoQg", "Auto Q on gapclose", true)
    Menu.Checkbox("daisyFollow", "Daisy Auto Controller", true)
    Menu.Checkbox("AutoE", "Auto E Shield", true)
    Menu.NewTree("EList","E ally whitelist", function()
    Menu.ColoredText("E Whitelist", 0x06D6A0FF, true)
    for _, Object in pairs(ObjectManager.Get("ally", "heroes")) do
      local Name = Object.AsHero.CharName
      Menu.Checkbox("1" .. Name, "Use on " .. Name, true)
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
  if Menu.RegisterMenu("Simple Ivern", "Simple Ivern", IvernMenu) then return true end
  return false
end

function OnLoad()
  Ivern.LoadMenu()
  for EventName, EventId in pairs(Events) do
    if Ivern[EventName] then
      EventManager.RegisterCallback(EventId, Ivern[EventName])
    end
  end
  return true
end
