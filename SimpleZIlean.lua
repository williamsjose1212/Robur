if Player.CharName ~= "Zilean" then return end

module("Simple Zilean", package.seeall, log.setup)
clean.module("Simple Zlean", clean.seeall, log.setup)

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
local Profiler = Libs.Profiler
local ObjectManager = CoreEx.ObjectManager
local EventManager = CoreEx.EventManager
local Input = CoreEx.Input
local Enums = CoreEx.Enums
local Game = CoreEx.Game
local Geometry = CoreEx.Geometry
local Renderer = CoreEx.Renderer

local SpellSlots = Enums.SpellSlots
local SpellStates = Enums.SpellStates
local BuffTypes = Enums.BuffTypes
local Events = Enums.Events
local HitChanceEnum = Enums.HitChance
local Nav = CoreEx.Nav
local Zilean = {}
local loaded = false

Zilean.Q = SpellLib.Skillshot({
  Slot = Enums.SpellSlots.Q,
  Range = 920,
  Speed = 2000,
  Radius = 100,
  Type = "Circular",
  Collisions = {WindWall = true},
  Delay = 0.250,
  Key = "Q"
})

Zilean.W = SpellLib.Active({
  Slot = Enums.SpellSlots.W,
  Key = "W"
})

Zilean.E = SpellLib.Targeted({
  Slot = Enums.SpellSlots.E,
  Range = 550,
  Key = "E",
  LastE = os.clock()
})

Zilean.R = SpellLib.Targeted({
  Slot = Enums.SpellSlots.R,
  Range = 900,
  Key = "R"
})

Zilean.TargetSelector = nil
Zilean.Logic = {}

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

function Utils.HasQZileanBuff(target)
  local TargetAi = target.AsAI
  if TargetAi and TargetAi.IsValid then
    local ZileanBomb = TargetAi:GetBuff("zileanqenemybomb")
    local ZileanBombAlly = TargetAi:GetBuff("zileanqallybomb")
    if ZileanBomb or ZileanBombAlly then
      return true
    end
  end
  return false
end

function Utils.CountHeroes(pos,Range,type)
  local num = 0
  for k, v in pairs(ObjectManager.GetNearby(type, "heroes")) do
    local hero = v.AsHero
    if hero and hero.IsTargetable and hero:Distance(pos.Position) < Range then
      num = num + 1
    end
  end
  return num
end


function Utils.ValidUlt(target)
  local TargetAi = target.AsAI
  if TargetAi and TargetAi.IsValid then
    local KindredUlt = TargetAi:GetBuff("kindredrnodeathbuff")
    local TryndUlt = TargetAi:GetBuff("undyingrage") --idk if  HasUndyingBuff() do the same thing
    local KayleUlt = TargetAi:GetBuff("judicatorintervention") -- still this name ?
    local ZileanUlt = TargetAi:GetBuff("chronoshift") -- in case you are 2 zilean in the same team in some game mode

    if KindredUlt or TryndUlt or KayleUlt or ZileanUlt  or TargetAi.IsZombie or TargetAi.IsDead then
      return false
    end
  end
  return true
end

function Zilean.Logic.Combo()
  local MenuValueQ = Menu.Get("Combo.Q")
  local MenuValueQW = Menu.Get("Combo.W")
  local MenuValueE = Menu.Get("Combo.E")
  local _W = Zilean.W:GetSpellData()
  for k, v in pairs(Utils.GetTargets(Zilean.Q)) do
    for _, hero in pairs(ObjectManager.GetNearby("enemy", "heroes")) do
      local Enemy = hero.AsAI
      local predQ = Zilean.Q:GetPrediction(v)
      if predQ ~= nil and Utils.IsValidTarget(v) then
        predHp = HPred.GetHealthPrediction(v,3,true)
        if Zilean.Q:GetManaCost() + Zilean.W:GetManaCost() <= Player.Mana then
          if Zilean.Q:IsReady() and ( Zilean.W:IsReady() or _W.RemainingCooldown < 2.750 )  then
            if Zilean.E:IsInRange(v) and Zilean.E:IsReady() and (Zilean.Q:GetManaCost() + Zilean.E:GetManaCost()) <= Player.Mana and MenuValueE then
              if Zilean.E:Cast(v) then return true end
            end
            if MenuValueQ and predQ.HitChanceEnum >= HitChanceEnum.High then
              if Zilean.Q:Cast(predQ.CastPosition) then return true end
            end
          elseif  Zilean.Q:IsReady() and not Zilean.W:IsReady() and Utils.HasQZileanBuff(Enemy) and Zilean.Q:IsInRange(Enemy) then
            if Zilean.E:IsInRange(Enemy) and Zilean.E:IsReady() and (Zilean.Q:GetManaCost() + Zilean.E:GetManaCost()) <= Player.Mana and MenuValueE then
              if Zilean.E:Cast(Enemy) then return true end
            end
            local predQ2 = Zilean.Q:GetPrediction(Enemy)
            if MenuValueQ and predQ2 ~= nil then
              if predQ2.HitChanceEnum >= HitChanceEnum.High  then
                if Zilean.Q:Cast(predQ2.CastPosition) then return true end
              end
            end
          elseif MenuValueQW and not Zilean.Q:IsReady() and Zilean.W:IsReady() and Utils.HasQZileanBuff(Enemy) then
            if Zilean.W:Cast() then return true end
          end
        end
        if Zilean.Q:IsReady() and Zilean.W:GetLevel() == 0 and predQ.HitChanceEnum >= HitChanceEnum.High then
          if Zilean.E:IsInRange(v) and Zilean.E:IsReady() and (Zilean.Q:GetManaCost() + Zilean.E:GetManaCost()) <= Player.Mana and MenuValueE then
            if Zilean.E:Cast(v) then return true end
          end
          if MenuValueQ then
            if Zilean.Q:Cast(predQ.CastPosition) then return true end
          end
        elseif predQ.HitChanceEnum >= HitChanceEnum.High and predHp <= (Zilean.Q:GetDamage(Enemy) * 3) and Zilean.Q:IsInRange(Enemy) then
          if Zilean.E:IsInRange(Enemy) and Zilean.E:IsReady() and (Zilean.Q:GetManaCost() + Zilean.E:GetManaCost()) <= Player.Mana and MenuValueE then
            if Zilean.E:Cast(Enemy) then return true end
          end
          local predQ2 = Zilean.Q:GetPrediction(Enemy)
          if  MenuValueQ and predQ2 ~= nil and Zilean.Q:IsReady() then
            if Zilean.Q:Cast(predQ2.CastPosition) then return true end
          end
        elseif not Zilean.Q:IsReady() and Zilean.W:IsReady() and predHp <= (Zilean.Q:GetDamage(Enemy) * 3) and Zilean.Q:IsInRange(Enemy) and MenuValueQW then
          if Zilean.W:Cast() then return true end
        end
        if not Zilean.Q:IsReady() and MenuValueE and Utils.HasQZileanBuff(Enemy) and Zilean.E:IsReady() and (Zilean.Q:GetManaCost() + Zilean.E:GetManaCost()) <= Player.Mana and Zilean.E:IsInRange(Enemy) then
          if Zilean.E:Cast(Enemy) then return true end
        end
      end
      for x, minions in pairs(ObjectManager.GetNearby("enemy", "minions")) do
        local minion = minions.AsAI
        local predMinion = Zilean.Q:GetPrediction(minion)
        if predMinion ~= nil and Enemy:Distance(minion) <= 300 and Utils.HasQZileanBuff(minion) and MenuValueQ and Zilean.Q:IsReady() then
          if Zilean.Q:Cast(predMinion.CastPosition) then return true end
        elseif Utils.HasQZileanBuff(minion) and MenuValueQW and not Zilean.Q:IsReady() and Zilean.W:IsReady() then
          if Zilean.W:Cast() then return true end
        end
      end
      for x, minions in pairs(ObjectManager.GetNearby("ally", "minions")) do
        local minion = minions.AsAI
        local predMinion = Zilean.Q:GetPrediction(minion)
        if predMinion ~= nil and Enemy:Distance(minion) <= 300 and Utils.HasQZileanBuff(minion) and MenuValueQ and Zilean.Q:IsReady() then
          if Zilean.Q:Cast(predMinion.CastPosition) then return true end
        elseif Utils.HasQZileanBuff(minion) and MenuValueQW and not Zilean.Q:IsReady() and Zilean.W:IsReady() then
          if Zilean.W:Cast() then return true end
        end
      end
      for x, allies in pairs(ObjectManager.GetNearby("ally", "heroes")) do
        local ally = allies.AsAI
        local predAlly = Zilean.Q:GetPrediction(ally)
        if predAlly ~= nil and Enemy:Distance(ally) <= 300 and Utils.HasQZileanBuff(ally) and MenuValueQ and Zilean.Q:IsReady() then
          if Zilean.Q:Cast(predAlly.CastPosition) then return true end
        elseif Utils.HasQZileanBuff(ally) and MenuValueQW and not Zilean.Q:IsReady() and Zilean.W:IsReady() then
          if Zilean.W:Cast() then return true end
        end
      end
    end
  end
  return false
end

function Zilean.Logic.Harass()
  if Menu.Get("ManaSlider") >= Player.ManaPercent * 100 then return false end
  local MenuValueQ = Menu.Get("Harass.Q")
  local MenuValueQW = Menu.Get("Harass.W")
  local MenuValueE = Menu.Get("Harass.E")
  local _W = Zilean.W:GetSpellData()
  for k, v in pairs(Utils.GetTargets(Zilean.Q)) do
    for _, hero in pairs(ObjectManager.GetNearby("enemy", "heroes")) do
      local Enemy = hero.AsAI
      local predQ = Zilean.Q:GetPrediction(v)
      if predQ ~= nil and Utils.IsValidTarget(v) then
        predHp = HPred.GetHealthPrediction(v,3,true)
        if Zilean.Q:GetManaCost() + Zilean.W:GetManaCost() <= Player.Mana then
          if Zilean.Q:IsReady() and ( Zilean.W:IsReady() or _W.RemainingCooldown < 2.750 )  then
            if Zilean.E:IsInRange(v) and Zilean.E:IsReady() and (Zilean.Q:GetManaCost() + Zilean.E:GetManaCost()) <= Player.Mana and MenuValueE then
              if Zilean.E:Cast(v) then return true end
            end
            if MenuValueQ and predQ.HitChanceEnum >= HitChanceEnum.VeryHigh  then
              if Zilean.Q:Cast(predQ.CastPosition) then return true end
            end
          elseif  Zilean.Q:IsReady() and not Zilean.W:IsReady() and Utils.HasQZileanBuff(Enemy) and Zilean.Q:IsInRange(Enemy) then
            if Zilean.E:IsInRange(Enemy) and Zilean.E:IsReady() and (Zilean.Q:GetManaCost() + Zilean.E:GetManaCost()) <= Player.Mana and MenuValueE then
              if Zilean.E:Cast(Enemy) then return true end
            end
            local predQ2 = Zilean.Q:GetPrediction(Enemy)
            if MenuValueQ and predQ2 ~= nil then
              if predQ2.HitChanceEnum >= HitChanceEnum.VeryHigh  then
                if Zilean.Q:Cast(predQ2.CastPosition) then return true end
              end
            end
          elseif MenuValueQW and not Zilean.Q:IsReady() and Zilean.W:IsReady() and Utils.HasQZileanBuff(Enemy) then
            if Zilean.W:Cast() then return true end
          end
        end
        if Zilean.Q:IsReady() and Zilean.W:GetLevel() == 0 and predQ.HitChanceEnum >= HitChanceEnum.VeryHigh then
          if Zilean.E:IsInRange(v) and Zilean.E:IsReady() and (Zilean.Q:GetManaCost() + Zilean.E:GetManaCost()) <= Player.Mana and MenuValueE then
            if Zilean.E:Cast(v) then return true end
          end
          if MenuValueQ then
            if Zilean.Q:Cast(predQ.CastPosition) then return true end
          end
        elseif predQ.HitChanceEnum >= HitChanceEnum.VeryHigh and predHp <= (Zilean.Q:GetDamage(Enemy) * 3) and Zilean.Q:IsInRange(Enemy) then
          if Zilean.E:IsInRange(Enemy) and Zilean.E:IsReady() and (Zilean.Q:GetManaCost() + Zilean.E:GetManaCost()) <= Player.Mana and MenuValueE then
            if Zilean.E:Cast(Enemy) then return true end
          end
          local predQ2 = Zilean.Q:GetPrediction(Enemy)
          if  MenuValueQ and predQ2 ~= nil and Zilean.Q:IsReady() then
            if Zilean.Q:Cast(predQ2.CastPosition) then return true end
          end
        elseif not Zilean.Q:IsReady() and Zilean.W:IsReady() and predHp <= (Zilean.Q:GetDamage(Enemy) * 3) and Zilean.Q:IsInRange(Enemy) and MenuValueQW then
          if Zilean.W:Cast() then return true end
        end
        if not Zilean.Q:IsReady() and MenuValueE and Utils.HasQZileanBuff(Enemy) and Zilean.E:IsReady() and (Zilean.Q:GetManaCost() + Zilean.E:GetManaCost()) <= Player.Mana and Zilean.E:IsInRange(Enemy) then
          if Zilean.E:Cast(Enemy) then return true end
        end
      end
      for x, minions in pairs(ObjectManager.GetNearby("enemy", "minions")) do
        local minion = minions.AsAI
        local predMinion = Zilean.Q:GetPrediction(minion)
        if predMinion ~= nil and Enemy:Distance(minion) <= 300 and Utils.HasQZileanBuff(minion) and MenuValueQ and Zilean.Q:IsReady() then
          if Zilean.Q:Cast(predMinion.CastPosition) then return true end
        elseif Utils.HasQZileanBuff(minion) and MenuValueQW and not Zilean.Q:IsReady() and Zilean.W:IsReady() then
          if Zilean.W:Cast() then return true end
        end
      end
      for x, minions in pairs(ObjectManager.GetNearby("ally", "minions")) do
        local minion = minions.AsAI
        local predMinion = Zilean.Q:GetPrediction(minion)
        if predMinion ~= nil and Enemy:Distance(minion) <= 300 and Utils.HasQZileanBuff(minion) and MenuValueQ and Zilean.Q:IsReady() then
          if Zilean.Q:Cast(predMinion.CastPosition) then return true end
        elseif Utils.HasQZileanBuff(minion) and MenuValueQW and not Zilean.Q:IsReady() and Zilean.W:IsReady() then
          if Zilean.W:Cast() then return true end
        end
      end
      for x, allies in pairs(ObjectManager.GetNearby("ally", "heroes")) do
        local ally = allies.AsAI
        local predAlly = Zilean.Q:GetPrediction(ally)
        if predAlly ~= nil and Enemy:Distance(ally) <= 300 and Utils.HasQZileanBuff(ally) and MenuValueQ and Zilean.Q:IsReady() then
          if Zilean.Q:Cast(predAlly.CastPosition) then return true end
        elseif Utils.HasQZileanBuff(ally) and MenuValueQW and not Zilean.Q:IsReady() and Zilean.W:IsReady() then
          if Zilean.W:Cast() then return true end
        end
      end
    end
  end
  return false
end

function Zilean.Logic.Waveclear()
  if Menu.Get("ManaSliderLane") >= Player.ManaPercent * 100 then return false end
  local MenuValueQ = Menu.Get("WaveClear.Q")
  local MenuValueQW = Menu.Get("WaveClear.W")
  local Cannons = {}
  local otherMinions = {}
  local JungleMinions = {}
  for k, v in pairs(ObjectManager.GetNearby("enemy", "minions")) do
    local minion = v.AsMinion
    local pos = minion:FastPrediction(Game.GetLatency()+ Zilean.Q.Delay)
    if Zilean.Q:IsInRange(minion) and minion.IsTargetable and (minion.IsSiegeMinion or minion.IsSuperMinion) then
      table.insert(Cannons, pos)
    elseif Zilean.Q:IsInRange(minion) and minion.IsTargetable and minion.IsLaneMinion then
      table.insert(otherMinions, pos)
    end
  end
  for k, v in pairs(ObjectManager.GetNearby("neutral", "minions")) do
    local minion = v.AsMinion
    local pos = minion:FastPrediction(Game.GetLatency()+ Zilean.Q.Delay)
    if Zilean.Q:IsInRange(minion) and minion.IsTargetable and not minion.IsJunglePlant then
      table.insert(JungleMinions, pos)
    end
  end
  if (Zilean.Q:IsReady() and Zilean.W:IsReady()) or (Zilean.Q:IsReady() and Zilean.W:GetLevel() == 0) and MenuValueQ then
    local cannonsPos, hitCount1 = Zilean.Q:GetBestCircularCastPos(Cannons, Zilean.Q.Radius)
    local laneMinionsPos, hitCount2 = Zilean.Q:GetBestCircularCastPos(otherMinions, 300)
    local JungleMinionPos, hitCount3 = Zilean.Q:GetBestCircularCastPos(JungleMinions, 300)
    if cannonsPos ~= nil and laneMinionsPos ~= nil then
      if hitCount1 >= 1 and hitCount2 >= 1 then
        if Zilean.Q:Cast(cannonsPos) then return true end
      end
    end
    if laneMinionsPos ~= nil then
      if hitCount2 >= 3 then
        if Zilean.Q:Cast(laneMinionsPos) then return true end
      end
    end
    if JungleMinionPos ~= nil then
      if hitCount3 >= 1 then
        if Zilean.Q:Cast(JungleMinionPos) then return true end
      end
    end
  end
  for k, v in pairs(ObjectManager.GetNearby("enemy", "minions")) do
    local minion = v.AsAI
    local predMinion = Zilean.Q:GetPrediction(minion)
    if predMinion ~= nil and Utils.HasQZileanBuff(minion) and Zilean.Q:IsReady() and MenuValueQ then
      if Zilean.Q:Cast(predMinion.CastPosition) then return true end
    elseif Utils.HasQZileanBuff(minion) and MenuValueQW and not Zilean.Q:IsReady() and Zilean.W:IsReady() then
      if Zilean.W:Cast() then return true end
    end
  end
  for k, v in pairs(ObjectManager.GetNearby("neutral", "minions")) do
    local minion = v.AsAI
    local predMinion = Zilean.Q:GetPrediction(minion)
    if predMinion ~= nil and Utils.HasQZileanBuff(minion) and Zilean.Q:IsReady() and MenuValueQ then
      if Zilean.Q:Cast(predMinion.CastPosition) then return true end
    elseif Utils.HasQZileanBuff(minion) and MenuValueQW and not Zilean.Q:IsReady() and Zilean.W:IsReady() then
      if Zilean.W:Cast() then return true end
    end
  end
  return false
end

function Zilean.Logic.Auto()
  if Menu.Get("Misc.AutoCC") then
    for k,v in pairs(Utils.GetTargets(Zilean.Q)) do
      if not v.CanMove and Zilean.Q:IsReady() then
        if Zilean.Q:CastOnHitChance(v,Enums.HitChance.Immobile) then return true end
      end
    end
  end
  if Zilean.R:IsReady() and Menu.Get("Auto.R") then
    for _, v in pairs(ObjectManager.GetNearby("ally","heroes")) do
      local hero = v.AsHero
      local delay =  0.10 + Game.GetLatency()/1000
      local incomingDamage = HPred.GetDamagePrediction(hero,delay,true)
      if Zilean.R:IsInRange(hero) and Menu.Get("1" .. hero.CharName) and hero.Health - incomingDamage < hero.Level * 10 and Utils.ValidUlt(hero) then
        if Zilean.R:Cast(hero) then return true end
      end
    end
  end
  return false
end

function Zilean.OnProcessSpell(sender,spell)
  if (sender.IsHero and sender.IsEnemy and Zilean.R:IsReady()) then
    local spellTarget = spell.Target
    if Menu.Get("Auto.R") then
      if spellTarget and spellTarget.IsAlly and spellTarget.IsHero and Zilean.R:IsInRange(spellTarget) and Menu.Get("1" .. spellTarget.AsHero.CharName) and Utils.ValidUlt(spellTarget) then
        if spell.Name == "VeigarR" and (spellTarget.Health/spellTarget.MaxHealth)*100 <= 40 then
          if Zilean.R:Cast(spellTarget) then return true end
        end
        if spell.Name == "GarenR" and (spellTarget.Health/spellTarget.MaxHealth)*100 <= 40 then
          if Zilean.R:Cast(spellTarget) then return true end
        end
        if spell.Name == "TristanaR" and (spellTarget.Health/spellTarget.MaxHealth)*100 <= 35 then
          if Zilean.R:Cast(spellTarget) then return true end
        end
        if spell.Name == "ZedR" and (spellTarget.Health/spellTarget.MaxHealth)*100 <= 40 then
          if Zilean.R:Cast(spellTarget) then return true end
        end
        if spell.Name == "ChogathR" and (spellTarget.Health/spellTarget.MaxHealth)*100 <= 40 then
          if Zilean.R:Cast(spellTarget) then return true end
        end
        if spell.Name == "SyndraR" and (spellTarget.Health/spellTarget.MaxHealth)*100 <= 35 then
          if Zilean.R:Cast(spellTarget) then return true end
        end
        if spell.Name == "LeesinR" and (spellTarget.Health/spellTarget.MaxHealth)*100 <= 30 then
          if Zilean.R:Cast(spellTarget) then return true end
        end
        if spell.Name == "DariusR" and (spellTarget.Health/spellTarget.MaxHealth)*100 <= 45 then
          if Zilean.R:Cast(spellTarget) then return true end
        end
        if spell.Name == "ViR" and (spellTarget.Health/spellTarget.MaxHealth)*100 <= 40 then
          if Zilean.R:Cast(spellTarget) then return true end
        end
        if spell.Name == "LissandraR" and (spellTarget.Health/spellTarget.MaxHealth)*100 <= 35 then
          if Zilean.R:Cast(spellTarget) then return true end
        end
      end
    end
  end
  return false
end

function Zilean.OnDraw()
  if Player.IsVisible and Player.IsOnScreen and not Player.IsDead then
    local Pos = Player.Position
    local spells = {Zilean.Q,Zilean.E,Zilean.R}
    for k, v in pairs(spells) do
      if Menu.Get("Drawing."..v.Key..".Enabled", true) and v:IsReady() then
        Renderer.DrawCircle3D(Pos, v.Range, 30, 3, Menu.Get("Drawing."..v.Key..".Color"))
      end
    end
  end
end

function Zilean.OnInterruptibleSpell(source, spell, danger, endT, canMove)
  if source.IsEnemy and Menu.Get("Misc.QI") and Zilean.Q:IsReady() and danger > 2 and Player:Distance(source.Position) <= 900 then
    if Zilean.Q:CastOnHitChance(source,Enums.HitChance.VeryHigh)then return true end
  end
  return false
end

function Zilean.OnGapclose(source,dash)
  if source.IsEnemy then
    if Menu.Get("Misc.E") and Zilean.E:IsReady() and Player:Distance(source.Position) <= 550 then
      if Zilean.E:Cast(source) then return true end
    end
  end
  return false
end

function Zilean.OnUpdate()
  if not Utils.IsGameAvailable() then return false end

  local OrbwalkerMode = Orbwalker.GetMode()
  local OrbwalkerLogic = Zilean.Logic[OrbwalkerMode]

  if OrbwalkerLogic then
    if OrbwalkerLogic() then return true end
  end

  if Zilean.Logic.Auto() then return true end

  return false
end

function Zilean.LoadMenu()
  local function ZileanMenu()
    Menu.ColumnLayout("Casting", "Casting", 2, true, function ()
    Menu.ColoredText("Combo", 0xB65A94FF, true)
    Menu.ColoredText("> Q", 0x0066CCFF, false)
    Menu.Checkbox("Combo.Q", "Use Q", true)
    Menu.ColoredText("> W", 0x0066CCFF, false)
    Menu.Checkbox("Combo.W", "Reset Bomb with W", true)
    Menu.ColoredText("> E", 0x0066CCFF, false)
    Menu.Checkbox("Combo.E", "Use E", true)
    Menu.ColoredText("Harass", 0x118AB2FF, true)
    Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
    Menu.Slider("ManaSlider","",50,0,100)
    Menu.ColoredText("> Q", 0x0066CCFF, false)
    Menu.Checkbox("Harass.Q", "Use Q", true)
    Menu.ColoredText("> W", 0x0066CCFF, false)
    Menu.Checkbox("Harass.W", "Reset Bomb with W", true)
    Menu.ColoredText("> E", 0x0066CCFF, false)
    Menu.Checkbox("Harass.E", "Use E", true)
    Menu.ColoredText("WaveClear/JungleClear", 0xEF476FFF, true)
    Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
    Menu.Slider("ManaSliderLane","",35,0,100)
    Menu.ColoredText("> Q", 0x0066CCFF, false)
    Menu.Checkbox("WaveClear.Q", "Use Q", true)
    Menu.ColoredText("> W", 0x0066CCFF, false)
    Menu.Checkbox("WaveClear.W", "Reset Bomb with W", true)
    Menu.NextColumn()
    Menu.ColoredText("Auto", 0xB65A94FF, true)
    Menu.Checkbox("Auto.R", "Auto R", true)
    Menu.NewTree("Rlist","R Whitelist", function()
    Menu.ColoredText("R Whitelist", 0x06D6A0FF, true)
    for _, Object in pairs(ObjectManager.Get("ally", "heroes")) do
      local Name = Object.AsHero.CharName
      Menu.Checkbox("1" .. Name, "Use on " .. Name, true)
    end
    end)
    Menu.ColoredText("Misc", 0xB65A94FF, true)
    Menu.Checkbox("Misc.QI",   "Use [Q] on Interrupter", true)
    Menu.Checkbox("Misc.E",   "Use [E] on gapclose", true)
    Menu.Checkbox("Misc.AutoCC",   "Auto Q on CC", true)
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
    Menu.RegisterMenu("Simple Zilean", "Simple Zilean", ZileanMenu)
    loaded = true
  end
end

function OnLoad()
  Zilean.LoadMenu()
  for EventName, EventId in pairs(Events) do
    if Zilean[EventName] then
      EventManager.RegisterCallback(EventId, Zilean[EventName])
    end
  end
  return true
end
