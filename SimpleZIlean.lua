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
local HitChance = Enums.HitChance

local Nav = CoreEx.Nav
local Zilean = {}
local loaded = false

Zilean.Q = SpellLib.Skillshot({
    Slot = Enums.SpellSlots.Q,
    Range = 900,
    Speed = 2000,
    Radius = 100,
    Type = "Circular",
    Collisions = {WindWall = true},
    Delay = 0.350,
	UseHitbox = true,
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
    return {TS:GetTarget(Spell.Range,true)}
end

function Utils.HasQZileanBuff(target)
	local TargetAi = target.AsAI
	if TargetAi and TargetAi.IsValid then
		local ZileanBomb = TargetAi:GetBuff("zileanqenemybomb")
		if ZileanBomb then 
			return true 
		end
	end
	return false
end


function Utils.ValidUlt(target)
	local TargetAi = target.AsAI
	if TargetAi and TargetAi.IsValid then
	local KindredUlt = TargetAi:GetBuff("kindredrnodeathbuff")
	local TryndUlt = TargetAi:GetBuff("undyingrage") --idk if  HasUndyingBuff() doing the same thing
	local KayleUlt = TargetAi:GetBuff("judicatorintervention") -- still this name ?
	local ZileanUlt = TargetAi:GetBuff("chronoshift") -- in case you are 2 zilean in the same team in some game mode
	
		if KindredUlt or TryndUlt or KayleUlt or ZileanUlt  or TargetAi.IsZombie then
			return false
		end
	end
	return true
end

function Zilean.Logic.Combo()
	local MenuValueQ = Menu.Get("Combo.Q")
	local MenuValueQW = Menu.Get("Combo.W")
	local MenuValueE = Menu.Get("Combo.E")
    for k, v in pairs(Utils.GetTargets(Zilean.Q)) do
		for _, Enemy in pairs(ObjectManager.Get("enemy", "heroes")) do
			local predQ = Zilean.Q:GetPrediction(v)
			if predQ ~= nil then
				predHp = HPred.GetHealthPrediction(v,3,true)
				if Zilean.Q:GetManaCost() <= Player.Mana then
					if Zilean.Q:IsReady() and Zilean.W:IsReady()  then 
						if Zilean.E:IsInRange(v) and Zilean.E:IsReady() and (Zilean.Q:GetManaCost() + Zilean.E:GetManaCost()) <= Player.Mana and MenuValueE then 
							if Zilean.E:Cast(v) then return true end
						end
						if MenuValueQ and predQ.HitChance >= 0.60 then
							if Zilean.Q:Cast(predQ.CastPosition) then return true end
						end
					elseif  Zilean.Q:IsReady() and not Zilean.W:IsReady() and Utils.HasQZileanBuff(Enemy) and Zilean.Q:IsInRange(Enemy) then 
						if Zilean.E:IsInRange(Enemy) and Zilean.E:IsReady() and (Zilean.Q:GetManaCost() + Zilean.E:GetManaCost()) <= Player.Mana and MenuValueE then 
							if Zilean.E:Cast(Enemy) then return true end
						end
						local predQ2 = Zilean.Q:GetPrediction(Enemy)
						if MenuValueQ and predQ2 ~= nil then
							if predQ2.HitChance >= 0.60 then
								if Zilean.Q:Cast(predQ2.CastPosition) then return true end
							end
						end
					elseif MenuValueQW and not Zilean.Q:IsReady() and Zilean.W:IsReady() and Utils.HasQZileanBuff(Enemy) then
						if Zilean.W:Cast() then return true end
					end
				end
				if Zilean.Q:IsReady() and Zilean.W:GetLevel() == 0 and predQ.HitChance >= 0.60 then
					if Zilean.E:IsInRange(v) and Zilean.E:IsReady() and (Zilean.Q:GetManaCost() + Zilean.E:GetManaCost()) <= Player.Mana and MenuValueE then 
						if Zilean.E:Cast(v) then return true end
					end
					if MenuValueQ then
						if Zilean.Q:Cast(predQ.CastPosition) then return true end
					end
				elseif Zilean.Q:IsReady() and predQ.HitChance >= 0.60 and predHp <= (Zilean.Q:GetDamage(Enemy) * 3) and Zilean.Q:IsInRange(Enemy) then
					if Zilean.E:IsInRange(Enemy) and Zilean.E:IsReady() and (Zilean.Q:GetManaCost() + Zilean.E:GetManaCost()) <= Player.Mana and MenuValueE then 
						if Zilean.E:Cast(Enemy) then return true end
					end
					local predQ2 = Zilean.Q:GetPrediction(Enemy)
					if  MenuValueQ and predQ2 ~= nil then 
						if Zilean.Q:Cast(predQ2.CastPosition) then return true end
					end
				elseif not Zilean.Q:IsReady() and Zilean.W:IsReady() and predHp <= (Zilean.Q:GetDamage(Enemy) * 3) and Zilean.Q:IsInRange(Enemy) and MenuValueQW then
					if Zilean.W:Cast() then return true end
				end
				if not Zilean.Q:IsReady() and MenuValueE and Utils.HasQZileanBuff(Enemy) and Zilean.E:IsReady() and (Zilean.Q:GetManaCost() + Zilean.E:GetManaCost()) <= Player.Mana and Zilean.E:IsInRange(Enemy) then
					if Zilean.E:Cast(Enemy) then return true end
				end
			end
			for x, minions in pairs(ObjectManager.Get("enemy", "minions")) do
				local minion = minions.AsAI
				local predMinion = Zilean.Q:GetPrediction(minion)
				if predMinion ~= nil and Enemy:Distance(minion) <= 300 and Utils.HasQZileanBuff(minion) and MenuValueQ and Zilean.Q:IsReady() then
					if Zilean.Q:Cast(predMinion.CastPosition) then return true end
				elseif Utils.HasQZileanBuff(minion) and MenuValueQW and not Zilean.Q:IsReady() and Zilean.W:IsReady() then
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
    for k, v in pairs(Utils.GetTargets(Zilean.Q)) do
		for _, Enemy in pairs(ObjectManager.Get("enemy", "heroes")) do
			local predQ = Zilean.Q:GetPrediction(v)
			if predQ ~= nil then
				predHp = HPred.GetHealthPrediction(v,3,true)
				if Zilean.Q:GetManaCost() <= Player.Mana then
					if Zilean.Q:IsReady() and Zilean.W:IsReady() then 
						if Zilean.E:IsInRange(v) and Zilean.E:IsReady() and (Zilean.Q:GetManaCost() + Zilean.E:GetManaCost()) <= Player.Mana and MenuValueE then 
							if Zilean.E:Cast(v) then return true end
						end
						if MenuValueQ and predQ.HitChance >= 0.60 then
							if Zilean.Q:Cast(predQ.CastPosition) then return true end
						end
					elseif  Zilean.Q:IsReady() and not Zilean.W:IsReady() and Utils.HasQZileanBuff(Enemy) and Zilean.Q:IsInRange(Enemy) then 
						if Zilean.E:IsInRange(Enemy) and Zilean.E:IsReady() and (Zilean.Q:GetManaCost() + Zilean.E:GetManaCost()) <= Player.Mana and MenuValueE then 
							if Zilean.E:Cast(Enemy) then return true end
						end
						local predQ2 = Zilean.Q:GetPrediction(Enemy)
						if MenuValueQ and predQ2 ~= nil then
							if predQ2.HitChance >= 0.60 then
								if Zilean.Q:Cast(predQ2.CastPosition) then return true end
							end
						end
					elseif MenuValueQW and not Zilean.Q:IsReady() and Zilean.W:IsReady() and Utils.HasQZileanBuff(Enemy) then
						if Zilean.W:Cast() then return true end
					end
				end
				if Zilean.Q:IsReady() and Zilean.W:GetLevel() == 0 and predQ.HitChance >= 0.60 then
					if Zilean.E:IsInRange(v) and Zilean.E:IsReady() and (Zilean.Q:GetManaCost() + Zilean.E:GetManaCost()) <= Player.Mana and MenuValueE then 
						if Zilean.E:Cast(v) then return true end
					end
					if MenuValueQ then
						if Zilean.Q:Cast(predQ.CastPosition) then return true end
					end
				elseif Zilean.Q:IsReady() and predQ.HitChance >= 0.60 and predHp <= (Zilean.Q:GetDamage(Enemy) * 3) and Zilean.Q:IsInRange(Enemy) then
					if Zilean.E:IsInRange(Enemy) and Zilean.E:IsReady() and (Zilean.Q:GetManaCost() + Zilean.E:GetManaCost()) <= Player.Mana and MenuValueE then 
						if Zilean.E:Cast(Enemy) then return true end
					end
					local predQ2 = Zilean.Q:GetPrediction(Enemy)
					if  MenuValueQ and predQ2 ~= nil then 
						if Zilean.Q:Cast(predQ2.CastPosition) then return true end
					end
				elseif not Zilean.Q:IsReady() and Zilean.W:IsReady() and predHp <= (Zilean.Q:GetDamage(Enemy) * 3) and Zilean.Q:IsInRange(Enemy) and MenuValueQW then
					if Zilean.W:Cast() then return true end
				end
				if not Zilean.Q:IsReady() and MenuValueE and Utils.HasQZileanBuff(Enemy) and Zilean.E:IsReady() and (Zilean.Q:GetManaCost() + Zilean.E:GetManaCost()) <= Player.Mana and Zilean.E:IsInRange(Enemy) then
					if Zilean.E:Cast(Enemy) then return true end
				end
			end
			for x, minions in pairs(ObjectManager.Get("enemy", "minions")) do
				local minion = minions.AsAI
				local predMinion = Zilean.Q:GetPrediction(minion)
				if predMinion ~= nil and Enemy:Distance(minion) <= 300 and Utils.HasQZileanBuff(minion) and MenuValueQ and Zilean.Q:IsReady() then
					if Zilean.Q:Cast(predMinion.CastPosition) then return true end
				elseif Utils.HasQZileanBuff(minion) and MenuValueQW and not Zilean.Q:IsReady() and Zilean.W:IsReady() then
					if Zilean.W:Cast() then return true end
				end
			end
		end
	end
	return false
end

function Zilean.Logic.WaveClear()
	

	return false
end

function Zilean.Logic.Auto()
	if Zilean.R:IsReady() and Menu.Get("Auto.R") then
        for _, v in pairs(ObjectManager.Get("ally","heroes")) do
            local hero = v.AsHero
            local incomingDamage = HPred.GetDamagePrediction(hero,1,false)
            if Zilean.R:IsInRange(hero) and Menu.Get("1" .. hero.CharName) and (hero.Health - incomingDamage < hero.Level * 15 or hero.Health <= HPred.GetDamagePrediction(hero,5,false)) and Utils.ValidUlt(hero) then
                if Zilean.R:Cast(hero) then return true end
            end
        end
    end
	return false 
end

function Zilean.OnTick()
  -- Check if game is available to do anything
  if not Utils.IsGameAvailable() then return false end

  -- Get current orbwalker mode
  local OrbwalkerMode = Orbwalker.GetMode()

  -- Get the right logic func
  local OrbwalkerLogic = Zilean.Logic[OrbwalkerMode]

  -- Do we have a callback for the orbwalker mode?
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
			Menu.Checkbox("Combo.Q", "Combo Q", true)
			Menu.ColoredText("> W", 0x0066CCFF, false)
			Menu.Checkbox("Combo.W", "Reset Bomb with W", true)
			Menu.ColoredText("> E", 0x0066CCFF, false)
			Menu.Checkbox("Combo.E", "Use E", true)
			Menu.ColoredText("Harass", 0x118AB2FF, true)
			Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
            Menu.Slider("ManaSlider","",50,0,100)
			Menu.ColoredText("> Q", 0x0066CCFF, false)
			Menu.Checkbox("Harass.Q", "Combo Q", true)
			Menu.ColoredText("> W", 0x0066CCFF, false)
			Menu.Checkbox("Harass.W", "Reset Bomb with W", true)
			Menu.ColoredText("> E", 0x0066CCFF, false)
			Menu.Checkbox("Harass.E", "Use E", true)
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
