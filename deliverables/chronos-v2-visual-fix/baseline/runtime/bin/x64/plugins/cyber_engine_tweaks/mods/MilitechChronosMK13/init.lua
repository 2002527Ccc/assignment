-- CHRONOS V12.2c-R1. CET supplies an undilated frame delta; no wall-clock timers.
local Controller = require("modules/controller")
local config = require("config")
local controller
local fault
local function log(s) print("[CHRONOS MK.13] " .. tostring(s)) end

local api = {}
function api.log(s) log(s) end
function api.player() return Game.GetPlayer() end
function api.sameOwner(a, b) return ChronosBridge.SameOwner(a, b) end
function api.running(v) return ChronosBridge.IsRunning(v) end
function api.suspended(v) return ChronosBridge.IsSuspended(v) end
function api.drain(v, dt) ChronosBridge.DrainHealth(v, dt) end
function api.arm(v, active) ChronosBridge.SetControllerActive(v, active) end
function api.makeModifier(name, value)
  return RPGManager.CreateStatModifier(gamedataStatType[name], gameStatModifierType.Additive, value)
end
function api.addModifier(v, modifier)
  Game.GetStatsSystem():AddModifier(ChronosBridge.StatsID(v), modifier)
end
function api.removeModifier(v, modifier)
  if not v or not IsDefined(v) then return true end -- owner destroyed; native stats destroyed with it
  Game.GetStatsSystem():RemoveModifier(ChronosBridge.StatsID(v), modifier)
  return true
end
function api.pool(owner, name)
  local kind = gamedataStatPoolType[name]
  if not ChronosBridge.HasPool(owner, kind) then return nil end
  local regen = ChronosBridge.GetRegeneration(owner, kind)
  local decay = ChronosBridge.GetDecay(owner, kind)
  return {value = ChronosBridge.ReadPercent(owner, kind), rate = regen.valuePerSec,
    limit = math.min(100, regen.rangeEnd), enabled = regen.enabled,
    points = regen.usingPointValues, decaying = decay.enabled and decay.valuePerSec > 0}
end
function api.changePool(v, name, amount, instigator)
  ChronosBridge.ChangePercent(v, gamedataStatPoolType[name], amount, instigator)
end
function api.techWeapon(v)
  local weapon = ChronosBridge.ActiveWeapon(v)
  if ChronosBridge.IsTechGun(weapon) then return weapon end
end
function api.cooldowns(v)
  local result = {}
  local ownCooldown = TweakDBID.new("BaseStatusEffect.SandevistanCooldown")
  for _, effect in ipairs(ChronosBridge.Cooldowns(v)) do
    local id = effect:GetRecord():GetID()
    table.insert(result, {key = tostring(id), id = id,
      token = EngineTime.ToFloat(effect:GetLastApplicationSimTimestamp()),
      remaining = effect:GetRemainingDuration(), excluded = id == ownCooldown})
  end
  return result
end
function api.setDuration(v, id, duration)
  return Game.GetStatusEffectSystem():SetStatusEffectRemainingDuration(v:GetEntityID(), id, duration)
end

local function stop(reason)
  if not controller then return end
  local ok, err = pcall(function() controller:stop(reason) end)
  if not ok then log("CLEANUP ERROR " .. tostring(err)) end
end

local function diagnostics()
  local ok, err = pcall(function()
    local item = TweakDB:GetRecord("Items.MilitechChronosMk13")
    assert(item, "Independent TweakXL item is missing")
    local v = Game.GetPlayer()
    log("build=V12.2c-R1; target=2.5; source build, GAME COMPILE/PLAYTEST NOT VERIFIED")
    if not v then log("No player attached"); return end
    log("equipped=" .. tostring(ChronosBridge.IsEquipped(v)) .. "; running=" .. tostring(api.running(v)))
    log("SandevistanCharge(percent)=" .. tostring(ChronosBridge.ReadPercent(v, gamedataStatPoolType.SandevistanCharge)))
    log("SandevistanCooldownActive=" .. tostring(Game.GetStatusEffectSystem():HasStatusEffect(v:GetEntityID(), TweakDBID.new("BaseStatusEffect.SandevistanCooldown"))))
    local stats, id = Game.GetStatsSystem(), ChronosBridge.StatsID(v)
    for _, name in ipairs({"HasSandevistan", "HasSandevistanTier3", "TimeDilationSandevistanDuration",
      "TimeDilationSandevistanTimeScale", "TimeDilationSandevistanRechargeDuration",
      "SandevistanRechargeDuration", "TimeDilationSandevistanEnterCost", "TimeDilationSandevistanCooldownBase",
      "SandevistanKillRechargeValue", "HumanityAllocated", "MitigationChance", "MitigationStrength"}) do
      log(name .. "=" .. tostring(stats:GetStatValue(id, gamedataStatType[name])))
    end
    for _, name in ipairs(config.pools) do
      local pool = api.pool(v, name)
      if pool then log(name .. ": value=" .. pool.value .. ", rate=" .. pool.rate .. ", enabled=" .. tostring(pool.enabled)
        .. ", points=" .. tostring(pool.points) .. ", decaying=" .. tostring(pool.decaying))
      else log(name .. ": absent on player") end
    end
    for _, effect in ipairs(api.cooldowns(v)) do log("tagged cooldown " .. effect.key .. ": " .. effect.remaining) end
    log("tech correction=" .. tostring(config.tech) .. "; blue grade removal=NOT IMPLEMENTED")
    -- Dump only public game record identities; useful to verify inherited native packages.
    local base = TweakDB:GetRecord("Items.AdvancedSandevistanApogeePlusPlus")
    if base then
      for _, package in ipairs(base:OnEquip()) do
        log("native Apogee package=" .. tostring(package:GetID()))
        for _, e in ipairs(package:Effectors()) do
          log("  effector=" .. tostring(e:GetID()) .. "; class=" .. tostring(e:EffectorClassName()))
        end
      end
    end
  end)
  if not ok then log("DIAGNOSTIC ERROR " .. tostring(err)) end
end

registerForEvent("onInit", function()
  controller = Controller.new(api, config)
  local ok, err = pcall(function()
    assert(TweakDB:GetRecord("Items.MilitechChronosMk13"), "TweakXL item not loaded")
    -- Fail at startup if the typed bridge did not compile/load.
    local v = Game.GetPlayer()
    if v then ChronosBridge.IsEquipped(v) end
    TweakDB:SetFlat("Chronos.Runtime.debug", config.debug)
  end)
  if not ok then fault = tostring(err); log("STARTUP ERROR " .. fault); return end
  -- Observers register ONCE, never in tick, activation, or weapon-switch paths.
  for _, method in ipairs({"OnExit", "OnForcedExit"}) do
    local observed, why = pcall(function()
      ObserveBefore("SandevistanEvents", method, function() stop("native " .. method) end)
    end)
    if not observed then log("OBSERVER unavailable " .. method .. ": " .. tostring(why)) end
  end
  local observed, why = pcall(function()
    ObserveBefore("PlayerPuppet", "OnDetach", function(v)
      if controller.owner and api.sameOwner(v, controller.owner) then stop("player detach/load") end
    end)
  end)
  if not observed then log("OBSERVER unavailable OnDetach: " .. tostring(why)) end
  log("Loaded V12.2c-R1; native charge pool untouched; hotkey CHRONOS diagnostics available")
end)

registerForEvent("onUpdate", function(dt)
  if fault then stop("runtime disabled after error"); return end
  if not controller then return end
  local ok, err = pcall(function() controller:tick(dt) end)
  if not ok then
    fault = tostring(err)
    log("RUNTIME ERROR; controller disabled for this session: " .. fault)
    stop("runtime error")
  end
end)

registerForEvent("onShutdown", function() stop("CET shutdown/reload") end)
registerHotkey("chronos_mk13_diagnostics", "CHRONOS: print diagnostic report", diagnostics)

return {diagnostics = diagnostics, stop = function() stop("manual diagnostic stop") end}
