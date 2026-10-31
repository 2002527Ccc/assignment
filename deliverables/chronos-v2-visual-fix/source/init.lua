-- CHRONOS V2 isolated lens repair. Replaces TEST02, not the combat controller.
local State = require('modules/state')
local config = require('config')
local state
local warned = {}
local api = {}
function api.log(message) print('[CHRONOS LENS FIX] ' .. tostring(message)) end
local function warn(key, message)
  if not warned[key] then warned[key] = true; api.log(message) end
end
function api.player() return Game.GetPlayer() end
function api.same(a,b) return ChronosBridge.SameOwner(a,b) end
function api.active(owner)
  -- No dependency on another CET module's per-frame ControllerActive echo.
  return ChronosBridge.IsRunning(owner) and not ChronosBridge.IsSuspended(owner)
end
function api.prepare(owner) return ChronosLensFX.Register(owner) end
function api.registered(owner) return ChronosLensFX.Registered(owner) end
function api.resources(owner)
  local result = {}
  for index=0,config.expectedEffects-1 do
    result[#result+1] = {name=ChronosLensFX.Name(index), token=Game.GetResourceDepot():LoadResource(ChronosLensFX.Path(index))}
  end
  return result
end
function api.resourceState(token)
  if not token or token:IsFailed() then return 'failed' end
  if token:IsLoaded() then return 'loaded' end
  return 'pending'
end
function api.gradeTargets(owner)
  local result = {}
  for _, target in ipairs(ChronosLensFX.NativeTargets(owner)) do
    result[#result+1] = {name=target.name, token=Game.GetResourceDepot():LoadResource(target.path)}
  end
  return result
end
function api.hasGrade(token) return ChronosV2VisualQueries.ResourceHasGrade(token:GetResource()) end
local function effectName(name)
  if type(name) == 'string' then return CName.new(name) end
  return name
end
function api.play(owner,name) return ChronosLensFX.Play(owner,effectName(name)) end
function api.stop(owner,name) ChronosLensFX.StopOwn(owner,effectName(name)) end
function api.suppress(owner,name) return ChronosLensFX.SuppressGrade(owner,effectName(name)) end

local function attach(owner,phase)
  if not state or not owner then return end
  local ok,err = pcall(function() state:attach(owner,phase) end)
  if not ok then warn('attach_' .. phase, 'registration callback failed (' .. phase .. '): ' .. tostring(err)) end
end
registerForEvent('onInit',function()
  state = State.new(api,config)
  -- CET instance observers receive self followed by the declared GameObject arg.
  -- Explicit before/after hooks do not claim an undocumented component-cache order.
  local ok,err=pcall(function()
    ObserveBefore('PlayerPuppet','PlayerAttachedCallback',function(self,playerPuppet)
      attach(playerPuppet or self,'PlayerAttachedCallback-before')
    end)
    ObserveAfter('PlayerPuppet','PlayerAttachedCallback',function(self,playerPuppet)
      attach(playerPuppet or self,'PlayerAttachedCallback-after')
    end)
  end)
  if not ok then warn('attach_observer','attach observer unavailable; bounded late registration only: '..tostring(err)) end
  local vfxOK,vfxErr=pcall(function()
    ObserveAfter('GameObject','StartStatusEffectVFX',function(owner,evt)
      if not state then return end
      local success,why=pcall(function() state:resuppress(owner) end)
      if not success then warn('vfx_observer','scoped grade resuppression failed: '..tostring(why)) end
    end)
  end)
  if not vfxOK then warn('vfx_observer_setup','optional VFX observer unavailable: '..tostring(vfxErr)) end
  api.log('loaded; typed descriptor read-back, private resources, native owner comparison; rendering NOT verified')
end)
registerForEvent('onUpdate',function(dt)
  if not state then return end
  local ok,err=pcall(function() state:tick(dt) end)
  if not ok then
    warn('tick','visual-only controller error: '..tostring(err))
    pcall(function() state:stop('visual-error') end)
  end
end)
registerForEvent('onShutdown',function()
  if state then pcall(function() state:stop('CET-shutdown') end) end
end)
registerHotkey('chronos_lens_fix_diagnostics','CHRONOS lens: registration/resource report',function()
  if state then
    local ok,err=pcall(function() state:diagnose() end)
    if not ok then api.log('diagnostic error: '..tostring(err)) end
  end
end)
return {diagnostics=function() if state then state:diagnose() end end}
