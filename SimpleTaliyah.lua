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
local BestCoveringRectangle = Geometry.BestCoveringRectangle
local next = next
local Taliyah = {}
local qMana = 0
local wMana = 0
local eMana = 0
local rMana = 0
local iTick = 0
local Combo,Harass,Laneclear,None = false,false,false, false
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
  Collisions = {Minions = true, WindWall = true },
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

local Utils = {}
local lastQ = 0

function Utils.IsGameAvailable()
  return not (
  Game.IsChatOpen()  or
  Game.IsMinimized() or
  Player.IsDead
  )
end

function Utils.SetMana()
  if Taliyah.Q:IsReady() then
    qMana = Taliyah.Q:GetManaCost()
  elseif (Player.Health/Player.MaxHealth) * 100 < 20 then
    qMana = 0
  else
    qMana = 0
  end
  if Taliyah.W:IsReady() then
    wMana = Taliyah.W:GetManaCost()
  elseif (Player.Health/Player.MaxHealth) * 100 < 20 then
    wMana = 0
  else
    wMana = 0
  end
  if Taliyah.E:IsReady() then
    eMana = Taliyah.E:GetManaCost()
  elseif (Player.Health/Player.MaxHealth) * 100 < 20 then
    eMana = 0
  else
    eMana = 0
  end
  if Taliyah.R:IsReady() then
    rMana = Taliyah.R:GetManaCost()
  elseif (Player.Health/Player.MaxHealth) * 100 < 20 then
    rMana = 0
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
    local TaliyahUlt = TargetAi:GetBuff("chronoshift")

    if KindredUlt or TryndUlt or KayleUlt or TaliyahUlt  or TargetAi.IsZombie or TargetAi.IsDead then
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

function Utils.GetPriorityMinion(pos, type, maxRange)
  local minionFocus = nil
  for k, v in pairs(ObjectManager.GetNearby(type, "minions")) do
    local minion = v.AsMinion
    if not minion.IsJunglePlant and minion.IsValid and not minion.IsDead and minion.IsTargetable and minion:Distance(pos) < maxRange then
      if minionFocus == nil then
        minionFocus = minion
      elseif minionFocus.IsEpicMinion then
        minionFocus = minion
      elseif not minionFocus.IsEpicMinion and minionFocus.IsEliteMinion then
        minionFocus = minion
      elseif not minionFocus.IsEpicMinion and not minionFocus.IsEliteMinion then
        if minion.Health < minionFocus.Health or minionFocus:Distance(pos) > minion:Distance(pos) then
          minionFocus = minion
        end
      end
    end
  end
  return minionFocus
end

function Utils.LinearCastMinionPos(pos, type, maxRange,spell,width)
  local minions = {}
  local res = {hitCount = 0, spellPos = Vector(0,0,0) }
  for k, v in pairs(ObjectManager.GetNearby(type, "minions")) do
    local minion = v.AsMinion
    if not minion.IsJunglePlant and minion.IsValid and not minion.IsDead and minion.IsTargetable and minion:Distance(pos) < maxRange then
      table.insert(minions, minion.Position)
    end
  end
  res.spellPos, res.hitCount = spell:GetBestLinearCastPos(minions,width)
  return res
end

function Utils.CircularCastMinionPos(pos, type, maxRange,spell,width)
  local minions = {}
  local res = {hitCount = 0, spellPos = Vector(0,0,0)}
  for k, v in pairs(ObjectManager.GetNearby(type, "minions")) do
    local minion = v.AsMinion
    if not minion.IsJunglePlant and minion.IsValid and not minion.IsDead and minion.IsTargetable and minion:Distance(pos) < maxRange then
      table.insert(minions, minion.Position)
    end
  end
  res.spellPos, res.hitCount = spell:GetBestCircularCastPos(minions,width)
  return res
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
  for k, v in ipairs(ObjectManager.GetNearby(type, "minions")) do
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
  for k, v in ipairs(t or ObjectManager.Get("enemy", "heroes")) do
    local hero = v.AsHero
    if hero and hero.IsTargetable and hero:Distance(pos) < range then
      res = res + 1
    end
  end
  return res
end

function Utils.CountHeroes(pos,range,team)
  local num = 0
  for k, v in pairs(ObjectManager.Get(team, "heroes")) do
    local hero = v.AsHero
    if hero.IsValid and not hero.IsDead and hero.IsTargetable and hero:Distance(pos) < range then
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

function Utils.HasBuff(target,buffname)
  local TargetAi = target.AsAI
  if TargetAi and TargetAi.IsValid then
    local hBuff= TargetAi:GetBuff(buffname)
    if hBuff then
      return true
    end
  end
  return false
end

function Utils.SearchHeroes(startPos, endPos, width, speed, delay, minResults, allyOrEnemy, handlesToIgnore)
  local res = {Result = false, Positions = {}, Objects = {}}
  if type(handlesToIgnore) ~= "table" then handlesToIgnore = {} end
  if type(allyOrEnemy) ~= "string" or allyOrEnemy ~= "ally" then allyOrEnemy = "enemy" end

  local dist = startPos:Distance(endPos)
  local spellPath = Geometry.Path(startPos, endPos)
  for k, obj in pairs(ObjectManager.Get(allyOrEnemy, "heroes")) do
    if not handlesToIgnore[k] then
      local hero = obj.AsHero
      local pos = hero:FastPrediction(delay/1000 + hero:EdgeDistance(startPos)/speed)

      if pos:Distance(startPos) < dist and hero.IsTargetable then
        local isOnSegment, pointSegment, pointLine = pos:ProjectOn(startPos, endPos)
        local lineDist = pointSegment:Distance(pos)
        if isOnSegment and lineDist < (hero.BoundingRadius + width*0.5 + 25) then
          table.insert(res.Positions, pos:Extended(pointSegment, lineDist):SetHeight(startPos.y))
          table.insert(res.Objects, hero)
          if #res.Positions < minResults then
            res.Result = false
          else
            res.Result = true
          end
        end
      end
    end
  end
  return res
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

function Utils.Sqrd(num)
  return num*num
end

function Utils.IsUnderTurret(target)
  local TurretRange = 562500
  local turrets = ObjectManager.GetNearby("enemy", "turrets")
  for _, turret in ipairs(turrets) do
    if turret.IsDead then return false end
    if target.Position:DistanceSqr(turret) < TurretRange + Utils.Sqrd(target.BoundingRadius) / 2 then
      return true
    end
  end
  return false
end

function Utils.CanMove(target)
  if Utils.HasBuffType(target,BuffTypes.Charm) or Utils.HasBuffType(target,BuffTypes.Snare) or Utils.HasBuffType(target,BuffTypes.Stun) or Utils.HasBuffType(target,BuffTypes.Suppression) or Utils.HasBuffType(target,BuffTypes.Taunt) or Utils.HasBuffType(target,BuffTypes.Fear) or Utils.HasBuffType(target,BuffTypes.Knockup) or Utils.HasBuffType(target,BuffTypes.Knockback) then
    return false
  else
    return true
  end
end

function Utils.NoLag(tick)
  if (iTick == tick) then
    return true
  else
    return false
  end
end

function Utils.CanKill(target,spell,dmg)
  local predHp = HPred.GetHealthPrediction(target,spell.Delay,true)
  local incomingDamage = HPred.GetDamagePrediction(target,1,true)
  local enemies = Utils.CountHeroes(target.Position,700,"ally")
  if predHp <= dmg or target.Health - incomingDamage < enemies * target.Level * 15 then
    return true
  end
  return false
end

function Taliyah.LogicQ()
  local target = TS:GetTarget(Taliyah.Q.Range)
  if Utils.IsValidTarget(target) then
    local qPred = Taliyah.Q:GetPrediction(target)
    if qPred ~= nil and qPred.HitChanceEnum >= HitChanceEnum.Medium and (fullQ or Utils.CanKill(target,Taliyah.Q,Taliyah.GetDamage(target))) and ((Combo and Player.Mana > qMana) or (Harass and Player.Mana > qMana + wMana + eMana)) then
      if Taliyah.Q:Cast(qPred.CastPosition) then return true end
    end
  end
  return false
end

function Taliyah.LogicW()
  local target = TS:GetTarget(Taliyah.W.Range)
  if Utils.IsValidTarget(target) then
    local incomingDamage = HPred.GetDamagePrediction(Player,1,false)
    local enemies = Utils.CountHeroes(Player,700,"enemy")
    local wPred = Taliyah.W:GetPrediction(target)
    if (Combo and Player.Mana > wMana + eMana) or (Harass and Player.Mana > qMana*3 + wMana + eMana) and (Taliyah.E:IsReady() or Utils.CanKill(target,Taliyah.W,Taliyah.GetDamage(target)) or eIsOn or Taliyah.E:GetLevel() == 0 or Player.Health - incomingDamage < enemies * Player.Level * 15) then
      if wPred and wPred.HitChanceEnum >= HitChanceEnum.High and Player:Distance(wPred.TargetPosition) > 420 and wPred.TargetPosition:Distance(wPred.CastPosition) <= 400  then
        if Input.Cast(SpellSlots.W,Player.Position,wPred.CastPosition) then return true end
      end
      if wPred and wPred.HitChanceEnum >= HitChanceEnum.High and Player:Distance(wPred.TargetPosition) < 420 and wPred.TargetPosition:Distance(wPred.CastPosition) <= 400 then
        if Input.Cast(SpellSlots.W,-Player.Direction,wPred.CastPosition) then return true end
      end
    end
  end
  return false
end

function Taliyah.LogicE()
  local target = TS:GetTarget(Taliyah.E.Range)
  if Utils.IsValidTarget(target) and (not Taliyah.W:IsReady() or Taliyah.W:GetLevel() == 0) then
    local ePred = Taliyah.E:GetPrediction(target)
    if (Combo and Player.Mana > eMana) or (Harass and Player.Mana > qMana*2 + wMana + eMana) then
      if ePred and ePred.HitChanceEnum >= HitChanceEnum.High then
        if Input.Cast(SpellSlots.E, ePred.TargetPosition) then return true end
      end
    end
  end
  return false
end

function Taliyah.Jungle()
  if Laneclear then
    local monsters = Utils.CountMinionsInRange(Taliyah.W.Range, "neutral")
    local minions = Utils.CountMinionsInRange(Taliyah.W.Range, "enemy")
    if minions > monsters then
      local minionFocus = Utils.GetPriorityMinion(Player.Position, "enemy",Taliyah.W.Range)
      if minionFocus == nil then return false end
      if Taliyah.Q:IsReady() and Menu.Get("qFarm") and fullQ and Player.Mana > qMana + wMana + eMana then
        if Taliyah.Q:Cast(Utils.LinearCastMinionPos(Player.Position, "enemy", Taliyah.W.Range,Taliyah.Q,100).spellPos) then return true end
      end
      if Player.Mana > qMana*3 + wMana + eMana and Taliyah.W:IsReady() and (Taliyah.E:IsReady() or eIsOn or Taliyah.E:GetLevel() == 0) and Menu.Get("wFarm") then
        local hitCount = Utils.CircularCastMinionPos(Player.Position, "enemy", Taliyah.W.Range,Taliyah.W,200).hitCount
        local wPos = Utils.CircularCastMinionPos(Player.Position, "enemy", Taliyah.W.Range,Taliyah.W,200).spellPos
        if hitCount >= 3 then
          if Input.Cast(SpellSlots.W,Player.Position,wPos) then return true end
        end
      end
    else
      local minionFocus = Utils.GetPriorityMinion(Player.Position, "neutral", Taliyah.W.Range)
      if minionFocus == nil then return false end
      if minionFocus.IsEpicMinion  then
        if Taliyah.Q:IsReady() and fullQ and Player.Mana > qMana and Menu.Get("qFarm") then
          if Taliyah.Q:Cast(minionFocus.Position) then return true end
        end
      else
        if Taliyah.Q:IsReady() and fullQ and Player.Mana > qMana and Menu.Get("qFarm") and not Taliyah.W:IsReady() then
          if Taliyah.Q:Cast(Utils.LinearCastMinionPos(Player.Position, "neutral", Taliyah.W.Range,Taliyah.Q,100).spellPos) then return true end
        end
        if Taliyah.W:IsReady() and (Taliyah.E:IsReady() or eIsOn or Taliyah.E:GetLevel() == 0) and Menu.Get("wFarm") and Player.Mana > wMana + eMana then
          local wPos = Utils.CircularCastMinionPos(Player.Position, "neutral", Taliyah.W.Range,Taliyah.W,200).spellPos
          if Input.Cast(SpellSlots.W,Player.Position,wPos) then return true end
        end
      end
    end
  end
  return false
end

function Taliyah.OnGapclose(source,dash)
  if source.IsEnemy and source.IsHero and Menu.Get("Misc.GapcloseE") and Taliyah.E:IsReady() and not dash.IsBlink and Player.Mana > eMana then
    local paths = dash:GetPaths()
    local endPos = paths[#paths].EndPos
    local startPos = paths[#paths].StartPos
    if Player:Distance(endPos) <= 800 then
      if Taliyah.E:Cast(endPos) then return true end
    end
  end
  return false
end

function Taliyah.OnInterruptibleSpell(source, spell, danger, endT, canMove)
  if source.IsEnemy and Menu.Get("Misc.AutoWI") and Taliyah.W:IsReady() and danger > 2 and Player:Distance(source.Position) <= Taliyah.W.Range then
    if Input.Cast(SpellSlots.W,-Player.Direction,source.Position) then return true end
  end
  return false
end

function Taliyah.OnCastStop(sender, spell)
  if sender.IsMe and spell.Name == "TaliyahWVC" and Menu.Get("autoE") then
    local wPos = spell.EndPos
    local wDir = wPos + (Player.Position - wPos) : Normalized()
    if Taliyah.E:IsReady() and Player.Mana > eMana then
      if Input.Cast(SpellSlots.E, wDir) then return true end
    end
  end
  return false
end

function Taliyah.GetDamage(target)
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
-- function Taliyah.OnSpellCast(sender,spell)
-- if sender.IsMe and not spell.IsBasicAttack then
-- if printf(spell.MissileSpeed) then return true end
-- end
-- return false
-- end
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
  if Utils.NoLag(0)  then
    if Taliyah.Jungle() then return true end
  end
  if Utils.NoLag(1) and Taliyah.Q:IsReady() and Menu.Get("autoQ") then
    if Taliyah.LogicQ() then return true end
  end
  if Utils.NoLag(2) and Taliyah.E:IsReady() and Menu.Get("autoE") then
    if Taliyah.LogicE() then return true end
  end
  if Utils.NoLag(3) and Taliyah.W:IsReady() and Menu.Get("autoW")  then
    if Taliyah.LogicW() then return true end
  end
  local OrbwalkerMode = Orbwalker.GetMode()
  if OrbwalkerMode == "Combo" then
    Combo = true
  else
    Combo = false
  end
  if OrbwalkerMode == "Harass" then
    Harass = true
  else
    Harass = false
  end
  if OrbwalkerMode == "Waveclear" or OrbwalkerMode == "Lasthit" then
    Laneclear = true
  else
    Laneclear = false
  end
  if OrbwalkerMode == "nil" then
    None = true
  else
    None = false
  end
  iTick = iTick + 1
  if iTick > 3 then
    iTick = 0
  end
  return false
end

function Taliyah.LoadMenu()
  local function TaliyahMenu()
    Menu.ColumnLayout("Casting", "Casting", 2, true, function ()
    Menu.ColoredText("> Q", 0xB65A94FF, true)
    Menu.Checkbox("autoQ", "Auto Q", false)
    Menu.ColoredText("> W", 0x118AB2FF, true)
    Menu.Checkbox("autoW", "Auto W", true)
    Menu.ColoredText("> E", 0xB65A94FF, true)
    Menu.Checkbox("autoE", "Auto E", true)
    Menu.ColoredText("Farm", 0xB65A94FF, true)
    Menu.Checkbox("qFarm", "Q Farm", true)
    Menu.Checkbox("wFarm", "W Farm", true)
    Menu.ColoredText("Misc", 0xB65A94FF, true)
    Menu.Checkbox("Misc.GapcloseE", "Auto E Gapclose", true)
    Menu.Checkbox("Misc.AutoWI", "Auto W Interupt", true)
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
