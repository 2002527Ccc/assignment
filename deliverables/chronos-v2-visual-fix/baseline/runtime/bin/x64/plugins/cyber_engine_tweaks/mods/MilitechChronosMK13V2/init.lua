-- V2 extension. Does not drive OS activation, health, mitigation, or deflection.
local config=require("config")
local Manager=require("modules/manager")
local Tech=require("modules/tech")
local Cooldowns=require("modules/cooldowns")
local Visual=require("modules/visual")
local manager
local counts={}
local api={}
function api.log(s) print("[CHRONOS V2] "..tostring(s)) end
function api.count(name) counts[name]=(counts[name] or 0)+1 end
function api.player() return Game.GetPlayer() end
function api.same(a,b) return ChronosBridge.SameOwner(a,b) end
function api.active(v)
  return ChronosBridge.ControllerIsActive(v) and ChronosBridge.IsRunning(v) and not ChronosBridge.IsSuspended(v)
end
function api.techWeapon(v)
  local weapon=ChronosBridge.ActiveWeapon(v)
  if ChronosBridge.IsTechGun(weapon) then return weapon end
end
function api.pool(v,name)
  assert(name~="SandevistanCharge" and name~="Health" and name~="TimeBank","Forbidden V2 pool access")
  local kind=gamedataStatPoolType[name]
  if not ChronosBridge.HasPool(v,kind) then return nil end
  local regen=ChronosBridge.GetRegeneration(v,kind)
  local decay=ChronosBridge.GetDecay(v,kind)
  local rate,limit=regen.valuePerSec,regen.rangeEnd
  if regen.usingPointValues then
    rate=ChronosV2Queries.PoolToPercent(v,kind,rate)
    limit=ChronosV2Queries.PoolToPercent(v,kind,limit)
  end
  return {value=ChronosBridge.ReadPercent(v,kind),rate=rate,limit=math.min(100,limit),
    enabled=regen.enabled,delayed=ChronosV2Queries.PoolDelayed(v,kind),
    decaying=decay.enabled and math.abs(decay.valuePerSec)>0.00001,
    sourcePoints=regen.usingPointValues,sourceRate=regen.valuePerSec,sourceLimit=regen.rangeEnd}
end
function api.changePool(v,name,amount,instigator)
  assert(name~="SandevistanCharge" and name~="Health" and name~="TimeBank","Forbidden V2 pool write")
  ChronosBridge.ChangePercent(v,gamedataStatPoolType[name],amount,instigator)
end
local ownStatuses={
  "BaseStatusEffect.SandevistanCooldown","BaseStatusEffect.SandevistanPlayerBuff",
  "BaseStatusEffect.CooldownedSandevistanPlayerBuff","BaseStatusEffect.NoSandevistanGlitch",
  "BaseStatusEffect.NoCooldownedSandevistanGlitch"
}
local candidateIDs
function api.statuses(v)
  if not candidateIDs then
    candidateIDs={}
    for name in pairs(Cooldowns.namedCandidates) do candidateIDs[#candidateIDs+1]=TweakDBID.new(name) end
  end
  local result={}
  for _,s in ipairs(ChronosV2Queries.Statuses(v)) do
    local own=false
    for _,name in ipairs(ownStatuses) do if s.id==TweakDBID.new(name) then own=true;break end end
    local name=s.id.value
    if not name or name=="" then name=tostring(s.id) end
    local nativeCandidate=false
    for _,id in ipairs(candidateIDs) do if s.id==id then nativeCandidate=true;break end end
    result[#result+1]={id=s.id,key=tostring(s.id.hash)..":"..tostring(s.id.length),
      name=name,remaining=s.remaining,stamp=s.stamp,stacks=s.stacks,
      affected=s.affected,tagged=s.tagged,own=own,nativeCandidate=nativeCandidate}
  end
  return result
end
function api.durationUsesCooldown(id) return ChronosV2Queries.RecordUsesCooldownStat(id) end
function api.duration(v,id,t)
  return Game.GetStatusEffectSystem():SetStatusEffectRemainingDuration(v:GetEntityID(),id,t)
end
function api.visualTargets(v) return ChronosV2VisualQueries.VisualTargets(v) end
function api.loadResource(path) return Game.GetResourceDepot():LoadResource(path) end
function api.resourceState(token)
  if not token or token:IsFailed() then return "failed" end
  if token:IsLoaded() then return "loaded" end
  return "pending"
end
function api.resourceHasGrade(token) return ChronosV2VisualQueries.ResourceHasGrade(token:GetResource()) end
function api.stopVisual(v,name) ChronosV2VisualQueries.StopVisual(v,name) end
function api.restoreVisual(v,name) ChronosV2VisualQueries.RestoreVisual(v,name) end

local function stop()
  if manager then manager:stop(false) end
end
local function diagnose()
  local ok,err=pcall(function()
    api.log("build=2.0; R1b core preserved; V2 game compile/playtest NOT VERIFIED")
    local v=api.player()
    for _,name in ipairs({"tech","cooldowns","visual"}) do
      api.log(name..": configured="..tostring(config.enabled[name]).." running="..tostring(manager and manager.running[name] or false)
        .." failure="..tostring(manager and manager.failed[name] or "none"))
    end
    if not v then return end
    api.log("native Chronos running="..tostring(ChronosBridge.IsRunning(v)).." core ready="..tostring(ChronosBridge.ControllerIsActive(v)))
    for _,kind in ipairs(config.pools) do
      local s=api.pool(v,kind)
      if s then
        api.log(kind..": percent="..s.value.." normalizedRate="..s.rate.." normalizedLimit="..s.limit
          .." delayed="..tostring(s.delayed).." sourcePoints="..tostring(s.sourcePoints)
          .." sourceRate="..s.sourceRate.." sourceLimit="..s.sourceLimit)
      else api.log(kind..": not present on this owner") end
    end
    for _,s in ipairs(api.statuses(v)) do
      local eligible=manager and manager.modules.cooldowns:classify(s) or false
      if s.tagged or s.own or eligible or s.nativeCandidate
        or (manager and manager.modules.cooldowns.metadata[s.key]) or s.name:lower():find("cooldown",1,true) then
        api.log("status="..s.name.." remaining="..s.remaining.." affected="..tostring(s.affected)
          .." stacks="..s.stacks.." selected="..tostring(eligible).." own="..tostring(s.own))
      end
    end
    local weapon=api.techWeapon(v)
    if weapon then
      local s=api.pool(weapon,"WeaponCharge")
      api.log("Tech gun="..tostring(weapon:GetItemID()).." chargePool="..tostring(s and s.value))
    end
    local visual=manager and manager.modules.visual
    if visual then api.log("visual confirmed grade effects stopped="..#(visual.suppressed or {}).." pending="..#(visual.pending or {})) end
    for name,n in pairs(counts) do api.log("correction requests "..name.."="..n) end
    api.log("unexported native CooldownSystem timers are not rewritten; absence of a status/pool is NOT coverage proof")
  end)
  if not ok then api.log("DIAGNOSTIC ERROR "..tostring(err)) end
end

registerForEvent("onInit",function()
  manager=Manager.new(api,config,{tech=Tech.new(api,config),cooldowns=Cooldowns.new(api,config),visual=Visual.new(api,config)})
  for _,name in ipairs({"OnExit","OnForcedExit"}) do
    local ok,err=pcall(function() ObserveBefore("SandevistanEvents",name,stop) end)
    if not ok then api.log("optional observer unavailable "..name..": "..tostring(err)) end
  end
  local ok,err=pcall(function()
    ObserveBefore("PlayerPuppet","OnDetach",function(v)
      if manager.owner and api.same(v,manager.owner) then stop() end
    end)
    ObserveAfter("GameObject","StartStatusEffectVFX",function(v,evt)
      if manager.running.visual and manager.owner and api.same(v,manager.owner) and api.active(v) then
        manager.modules.visual:resuppress()
      end
    end)
  end)
  if not ok then api.log("optional visual/detach observer unavailable: "..tostring(err)) end
  api.log("Loaded three independent modules; OS activation/health/defense owned by unchanged R1b core")
end)
registerForEvent("onUpdate",function(dt)
  if manager then
    local ok,err=pcall(function() manager:tick(dt) end)
    if not ok then api.log("EXTENSION ERROR "..tostring(err));stop() end
  end
end)
registerForEvent("onShutdown",stop)
registerHotkey("chronos_v2_diagnostics","CHRONOS V2: diagnostic report",diagnose)
for _,name in ipairs({"tech","cooldowns","visual"}) do
  local featureName=name -- explicit per-binding capture for CET's LuaJIT/Lua 5.1
  registerHotkey("chronos_v2_toggle_"..featureName,"CHRONOS V2: toggle "..featureName,function()
    if manager then
      local ok,err=pcall(function() manager:setEnabled(featureName,not config.enabled[featureName]) end)
      if not ok then api.log("TOGGLE ERROR "..featureName..": "..tostring(err)) end
    end
  end)
end
return {diagnostics=diagnose}
