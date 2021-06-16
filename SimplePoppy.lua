if Player.CharName ~= "Poppy" then return end

module("Samipote Poppy", package.seeall, log.setup)
clean.module("Samipote Poppy", clean.seeall, log.setup)

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

local Poppy = {}

local loaded = false

Poppy.Q = SpellLib.Skillshot({
  Slot = SpellSlots.Q,
  Range = 430,
  Delay = 0.25,
  Speed = 1700,
  Radius = 100,
  Type = "Linear",
  Key = "Q"
})

Poppy.W = SpellLib.Active({
  Slot = SpellSlots.W,
  Range = 400,
  Delay = 0,
  Type = "Circular",
  Key = "W"
})

Poppy.E = SpellLib.Targeted({
  Slot = SpellSlots.E,
  Range = 525,
  Key = "E"
})

Poppy.R = SpellLib.Skillshot({
  Slot = SpellSlots.R,
  Range = 455,
  Speed = 2000,
  Radius = 180,
  Delay = 0.350,
  MaxRange = 1700,
  Key = "R"
})

Poppy.TargetSelector = nil
Poppy.Logic = {}

local Utils = {}

function Utils.IsGameAvailable()
  return not (
  Game.IsChatOpen()  or
  Game.IsMinimized() or
  Player.IsDead
  )
end

function Utils.GetTargets(Spell)
  return TS:GetTargets(Spell.Range,true)
end

function Utils.IsValidTarget(Target)
  return Target and Target.IsTargetable and Target.IsAlive
end

function Utils.CanStun(target)
  local targetStun = target.AsHero
  if targetStun ~= nil and targetStun.IsValid then
    local FinalPosition = targetStun.Position + (Vector(targetStun.Position) - Player.Position):Normalized() * (300 +targetStun.BoundingRadius)
    if (Nav.IsWall(FinalPosition)) then
      return true
    end
  end
  return false
end

function Utils.GetTargetsRange(Range)
  return TS:GetTargets(Range,true)
end

function Poppy.Logic.Combo()
  local _Q = Poppy.Q:GetSpellData()
  if Poppy.Q:IsReady() and Menu.Get("Combo.Q") then
    for k,v in pairs(Utils.GetTargets(Poppy.Q)) do
      local predQ = Poppy.Q:GetPrediction(v)
      if predQ ~= nil and predQ.HitChanceEnum >= HitChanceEnum.Medium and Utils.IsValidTarget(v) then
        if Poppy.Q:Cast(predQ.CastPosition)then return true end
      end
    end
  end
  if Poppy.E:IsReady() and Menu.Get("Combo.E") then
    for k,v in pairs(Utils.GetTargets(Poppy.E)) do
      local predHp = HPred.GetHealthPrediction(v,2,true)
      if Utils.IsValidTarget(v) and Poppy.E:IsInRange(v) then
        if Utils.CanStun(v) then
          if Poppy.E:Cast(v) then return true end
        elseif Poppy.Q:GetDamage(v) * 2.5 >= predHp and (Poppy.Q:IsReady() or _Q.RemainingCooldown < 3.0) then
          if Poppy.E:Cast(v) then return true end
        elseif Poppy.E:GetDamage(v) * 1.5 >= predHp then
          if Poppy.E:Cast(v) then return true end
        end
      end
    end
  end
  if Poppy.W:IsReady() and Menu.Get("Combo.W") then
    for k,v in pairs(Utils.GetTargetsRange(900)) do
      if Utils.IsValidTarget(v) and Player:Distance(v) <= Menu.Get("ActiveRange") then
        if Poppy.W:Cast() then return true end
      end
    end
  end
  if Poppy.R:IsReady() and Menu.Get("Combo.R") then
    for k,v in pairs(Utils.GetTargets(Poppy.R)) do
      local predHp = HPred.GetHealthPrediction(v,2,true)
      local predR = Poppy.R:GetPrediction(v)
      if Utils.IsValidTarget(v) and Poppy.R:IsInRange(v) then
        if not v.CanMove then
          Poppy.R:CastOnHitChance(v,Enums.HitChance.Immobile)
          if  Orbwalker.MoveTo(nil) then return true end
        elseif Poppy.Q:GetDamage(v) * 2.5 >= predHp and predR ~= nil and predR.HitChance >= 0.60 then
          Poppy.R:Cast(predR.CastPosition)
          if Orbwalker.MoveTo(nil) then return true end
        end
      end
    end
  end
  return false
end

function Poppy.Logic.Harass()
  if Menu.Get("ManaSlider") >= Player.ManaPercent * 100 then return false end
  if Poppy.Q:IsReady() and Menu.Get("Harass.Q") then
    for k,v in pairs(Utils.GetTargets(Poppy.Q)) do
      local predQ = Poppy.Q:GetPrediction(v)
      if predQ ~= nil and predQ ~= nil and predQ.HitChanceEnum >= HitChanceEnum.Medium and Utils.IsValidTarget(v) then
        if Poppy.Q:Cast(predQ.CastPosition)then return true end
      end
    end
  end
  if Poppy.E:IsReady() and Menu.Get("Harass.E") then
    for k,v in pairs(Utils.GetTargets(Poppy.E)) do
      local predHp = HPred.GetHealthPrediction(v,2,true)
      if Utils.IsValidTarget(v) and Poppy.E:IsInRange(v) then
        if Utils.CanStun(v) then
          if Poppy.E:Cast(v) then return true end
        elseif Poppy.Q:GetDamage(v) * 2.5 >= predHp and Poppy.Q:IsReady() then
          if Poppy.E:Cast(v) then return true end
        end
      end
    end
  end
  return false
end

function Poppy.Logic.Waveclear()
  local MenuValueQ = Menu.Get("WaveClear.Q")
  local Cannons = {}
  local otherMinions = {}
  local JungleMinions = {}
  for k, v in pairs(ObjectManager.GetNearby("enemy", "minions")) do
    local minion = v.AsMinion
    local pos = minion:FastPrediction(Game.GetLatency()+ Poppy.Q.Delay)
    if Poppy.Q:IsInRange(minion) and minion.IsTargetable and (minion.IsSiegeMinion or minion.IsSuperMinion) then
      table.insert(Cannons, pos)
    elseif Poppy.Q:IsInRange(minion) and minion.IsTargetable and minion.IsLaneMinion then
      table.insert(otherMinions, pos)
    end
    if Poppy.Q:IsReady() and  MenuValueQ then
      local cannonsPos, hitCount1 = Poppy.Q:GetBestLinearCastPos(Cannons, Poppy.Q.Radius)
      local laneMinionsPos, hitCount2 = Poppy.Q:GetBestLinearCastPos(otherMinions, Poppy.Q.Radius)

      if cannonsPos ~= nil and laneMinionsPos ~= nil and Menu.Get("ManaSliderLane") <= Player.ManaPercent * 100 then
        if hitCount1 >= 1 then
          if Poppy.Q:Cast(cannonsPos) then return true end
        end
      end
      if laneMinionsPos ~= nil and Menu.Get("ManaSliderLane") <= Player.ManaPercent * 100 then
        if hitCount2 >= 2 then
          if Poppy.Q:Cast(laneMinionsPos) then return true end
        end
      end
    end
  end
  for k, v in pairs(ObjectManager.GetNearby("neutral", "minions")) do
    local minion = v.AsMinion
    local pos = minion:FastPrediction(Game.GetLatency()+ Poppy.Q.Delay)
    if Poppy.Q:IsInRange(minion) and minion.IsTargetable and not minion.IsJunglePlant then
      table.insert(JungleMinions, pos)
      if Poppy.E:IsReady() and Menu.Get("WaveClear.E") then
        if Poppy.E:Cast(minion) then return true end
      end
    end
    if Poppy.Q:IsReady() and  MenuValueQ then
      local JungleMinionPos, hitCount3 = Poppy.Q:GetBestLinearCastPos(JungleMinions, Poppy.Q.Radius)
      if JungleMinionPos ~= nil then
        if hitCount3 >= 1 then
          if Poppy.Q:Cast(JungleMinionPos) then return true end
        end
      end
    end
  end
  return false
end

function Poppy.Logic.Auto()
  if Menu.Get("AutoE") and Poppy.E:IsReady() then
    for _, enemy in pairs(ObjectManager.GetNearby("enemy", "heroes")) do
      if enemy then
        Target = enemy.AsHero
        local predHp = HPred.GetHealthPrediction(Target,2,true)
        if Utils.IsValidTarget(Target) and Poppy.E:IsInRange(Target) then
          if Utils.CanStun(Target) then
            if Poppy.E:Cast(Target) then return true end
          elseif Poppy.E:GetDamage(Target) >= predHp then
            if Poppy.E:Cast(Target) then return true end
          end
        end
      end
    end
  end
  return false
end


function Poppy.OnGapclose(source,dash)
  if source.IsEnemy and source.IsHero and Menu.Get("AutoW") and Poppy.W:IsReady() then
    local paths = dash:GetPaths()
    local endPos = paths[#paths].EndPos
    local startPos = paths[#paths].StartPos
    if Player:Distance(endPos) <= 400 or (Player:Distance(startPos) <= 400 and Player:Distance(source.Position) <= 400) then
      if Poppy.W:Cast() then return true end
    end
  end
  return false
end

function Poppy.OnInterruptibleSpell(source, spell, danger, endT, canMove)
  if source.IsEnemy and Menu.Get("AutoEI") and Poppy.E:IsReady() and danger > 2 and Player:Distance(source.Position) <= Poppy.E.Range then
    if Poppy.E:Cast(source) then return true end
  elseif source.IsEnemy and Menu.Get("AutoRI") and Poppy.R:IsReady() and danger > 2 and Player:Distance(source.Position) <= Poppy.R.Range then
    Poppy.R:CastOnHitChance(source,Enums.HitChance.VeryHigh)
    if Orbwalker.MoveTo(nil) then return true end
  end
  return false
end

function Poppy.OnUpdate()
  if not Utils.IsGameAvailable() then return false end

  local OrbwalkerMode = Orbwalker.GetMode()

  local OrbwalkerLogic = Poppy.Logic[OrbwalkerMode]

  if OrbwalkerLogic then
    if OrbwalkerLogic() then return true end
  end

  if Poppy.Logic.Auto() then return true end
  return false
end

function Poppy.OnDraw()
  if Player.IsVisible and Player.IsOnScreen and not Player.IsDead then
    local Pos = Player.Position
    local spells = {Poppy.Q,Poppy.E,Poppy.R}
    for k, v in pairs(spells) do
      if Menu.Get("Drawing."..v.Key..".Enabled", true) and v:IsReady() then
        Renderer.DrawCircle3D(Pos, (v.Key == "R" and v.MaxRange) or v.Range, 30, 3, Menu.Get("Drawing."..v.Key..".Color"))
      end
    end
  end
end

function Poppy.LoadMenu()
  local function PoppyMenu()
    Menu.ColumnLayout("Casting", "Casting", 2, true, function ()
    Menu.ColoredText("Combo", 0xB65A94FF, true)
    Menu.ColoredText("> Q", 0x0066CCFF, false)
    Menu.Checkbox("Combo.Q", "Use Q", true)
    Menu.ColoredText("> W", 0x0066CCFF, false)
    Menu.Checkbox("Combo.W", "Use W", false)
    Menu.Slider("ActiveRange","W Active Range",800,100,900)
    Menu.ColoredText("> E", 0x0066CCFF, false)
    Menu.Checkbox("Combo.E", "Use E", true)
    Menu.ColoredText("> R", 0x0066CCFF, false)
    Menu.Checkbox("Combo.R", "Use R", false)
    Menu.ColoredText("Harass", 0x118AB2FF, true)
    Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
    Menu.Slider("ManaSlider","",50,0,100)
    Menu.ColoredText("> Q", 0x0066CCFF, false)
    Menu.Checkbox("Harass.Q", "Use Q", true)
    Menu.ColoredText("> E", 0x0066CCFF, false)
    Menu.Checkbox("Harass.E", "Use E", true)
    Menu.ColoredText("WaveClear/JungleClear", 0xEF476FFF, true)
    Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
    Menu.Slider("ManaSliderLane","",45,0,100)
    Menu.ColoredText("> Q", 0x0066CCFF, false)
    Menu.Checkbox("WaveClear.Q", "Use Q", true)
    Menu.ColoredText("> E", 0x0066CCFF, false)
    Menu.Checkbox("WaveClear.E", "Use E", false)
    Menu.NextColumn()
    Menu.ColoredText("Auto", 0xB65A94FF, true)
    Menu.Checkbox("AutoW", "Auto W AntiGapclose", true)
    Menu.Checkbox("AutoE", "Auto E Wall", false)
    Menu.Checkbox("AutoEI", "Auto E Interupt", true)
    Menu.Checkbox("AutoRI", "Auto R Interupt", true)
    Menu.Separator()
    Menu.ColoredText("Drawing", 0xB65A94FF, true)
    Menu.Checkbox("Drawing.Q.Enabled",   "Draw [Q] Range",true)
    Menu.ColorPicker("Drawing.Q.Color", "Draw [Q] Color", 0x118AB2FF)
    Menu.Checkbox("Drawing.E.Enabled",   "Draw [E] Range",false)
    Menu.ColorPicker("Drawing.E.Color", "Draw [E] Color", 0x118AB2FF)
    Menu.Checkbox("Drawing.R.Enabled",   "Draw [R] Range",false)
    Menu.ColorPicker("Drawing.R.Color", "Draw [R] Color", 0x118AB2FF)
    end)
  end
  if loaded == false then
    Menu.RegisterMenu("SimplePoppy", "SimplePoppy", PoppyMenu)
    loaded = true
  end
end

function OnLoad()
  Poppy.LoadMenu()
  for EventName, EventId in pairs(Events) do
    if Poppy[EventName] then
      EventManager.RegisterCallback(EventId, Poppy[EventName])
    end
  end
  return true
end
