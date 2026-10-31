-- MILITECH CHRONOS MK.13: native sub-VFX restoration, TEST02 (CET, Cyberpunk 2077).
-- Add-on ONLY: never mutates R1b/V2 stats, cooldowns, health, weapons or input.
-- Requires the separate no-blue TweakXL diagnostic to remain installed.
-- The game's default time_dilation_vfx is intentionally NOT started (its color grade is blue).
local config = require("config")

local TAG = "[CHRONOS LENS] "
local function log(msg) print(TAG .. tostring(msg)) end
local assets = {}
if config.radialBlur then
  assets[#assets + 1] = "time_dilation_vfx_radial_blur"
end
if config.outlines then
  assets[#assets + 1] = "time_dilation_vfx_outlines"
end
local optionalFlash = "time_dilation_vfx_flash"
local function allNames()
  local names = {}
  for _, name in ipairs(assets) do names[#names + 1] = name end
  if config.flashOnStart then names[#names + 1] = optionalFlash end
  return names
end

local lastOwnerKey = nil
local lastOwner = nil
local preparedOwnerKey = nil
local preAttachKeys = {}
local currentlyRunning = false
local warned = {}
local function warnOnce(key, message)
  if not warned[key] then warned[key] = true; log(message) end
end
local function ownerKey(p)
  return tostring(p:GetEntityID())
end
local function stopEffects(p)
  if not p then return end
  for _, name in ipairs(allNames()) do
    -- The two APIs cover one-shot/looping variations without touching other VFX.
    pcall(function() GameObjectEffectHelper.BreakEffectLoopEvent(p, CName.new(name)) end)
    pcall(function() GameObjectEffectHelper.StopEffectEvent(p, CName.new(name)) end)
  end
  if currentlyRunning then log("STOP: original non-blue VFX ended") end
  currentlyRunning = false
end

-- Add only missing game-native effect descriptors to the player's FX component.
-- This pattern follows the public Custom VFX mod's game-native resource references.
local function preparePlayerFX(p)
  local fx = p:FindComponentByName("fx_player")
  if not fx then return false, "fx_player component not ready" end
  local list = fx.effectDescs
  if not list then return false, "fx_player.effectDescs unavailable" end
  local changed = false
  for _, name in ipairs(allNames()) do
    local cname = CName.new(name)
    local found = false
    for _, desc in ipairs(list) do
      if desc and tostring(desc.effectName) == tostring(cname) then
        found = true
        break
      end
    end
    if not found then
      local desc = entEffectDesc.new()
      desc.effectName = cname
      desc.effect = "base\\fx\\player\\" .. name .. ".effect"
      table.insert(list, desc)
      changed = true
    end
  end
  if changed then fx.effectDescs = list end
  return true
end

local function isChronosActive(p)
  -- Strictly limited to V2's Chronos controller + actual running state.
  -- No generic SandevistanEvents hooks: never activates for ordinary Sandys.
  return ChronosBridge.ControllerIsActive(p) and ChronosBridge.IsRunning(p)
end

local function startEffects(p)
  for _, name in ipairs(assets) do
    local ok, err = pcall(function()
      GameObjectEffectHelper.StartEffectEvent(p, CName.new(name), true)
    end)
    if not ok then warnOnce("start_" .. name, "Start failed: " .. name .. ": " .. tostring(err)) end
  end
  if config.flashOnStart then
    local ok,err=pcall(function()
      GameObjectEffectHelper.StartEffectEvent(p, CName.new(optionalFlash), true)
    end)
    if not ok then warnOnce("flash", "Flash failed: " .. tostring(err)) end
  end
  currentlyRunning = true
  log("START: requested " .. table.concat(assets, " + ") .. " (no blue main effect); visible output is not guaranteed")
end

-- Native VFX descriptors are normally registered during PlayerAttachedCallback,
-- BEFORE the player FX component is fully initialized. TEST01 registered them only
-- after Chronos was already running, which can be too late for effect playback.
local function onPlayerAttached(p)
  local ok, success, reason = pcall(preparePlayerFX, p)
  local okKey, k = pcall(ownerKey, p)
  if ok and success then
    if okKey then preAttachKeys[k] = true; preparedOwnerKey = k end
    log("ATTACH: native FX descriptors prepared before normal gameplay")
  else
    log("ATTACH: FX setup pending: " .. tostring(ok and reason or success))
  end
end

registerForEvent("onInit", function()
  log("TEST02 loaded; attaching native VFX descriptors early.")
  Observe("PlayerPuppet", "PlayerAttachedCallback", function(p)
    if p then onPlayerAttached(p) end
  end)
end)

registerForEvent("onUpdate", function(dt)
  local p = Game.GetPlayer()
  if not p then
    if currentlyRunning then stopEffects(lastOwner) end
    lastOwnerKey, lastOwner, preparedOwnerKey = nil, nil, nil
    return
  end
  local okKey, key = pcall(ownerKey, p)
  if not okKey then return end
  if lastOwnerKey ~= key then
    if currentlyRunning then stopEffects(lastOwner) end
    lastOwnerKey, lastOwner = key, p
    preparedOwnerKey = preAttachKeys[key] and key or nil
  end
  local ok, active = pcall(isChronosActive, p)
  if not ok then
    warnOnce("chronos_bridge", "ChronosBridge not ready: " .. tostring(active))
    if currentlyRunning then stopEffects(p) end
    return
  end
  if not active then
    if currentlyRunning then stopEffects(p) end
    return
  end
  if preparedOwnerKey ~= key then
    local success, prepared, reason = pcall(preparePlayerFX, p)
    if not success or not prepared then
      warnOnce("fx_not_ready", "FX setup pending: " .. tostring(success and reason or prepared))
      return
    end
    preparedOwnerKey = key
    log("FALLBACK: native effect descriptors registered after player attach; may not render until reload")
  end
  if not currentlyRunning then startEffects(p) end
end)

registerForEvent("onShutdown", function()
  if currentlyRunning then stopEffects(lastOwner) end
end)
