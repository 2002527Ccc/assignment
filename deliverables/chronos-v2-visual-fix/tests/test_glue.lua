-- Integration of shipped CET Lua files against a mock host; not game validation.
local root = assert(arg[2])
package.path = root .. '/source/?.lua;' .. root .. '/source/?/init.lua;' .. package.path
local callbacks, before, after, logs = {}, {}, {}, {}
local config = dofile(root .. '/source/config.lua')
assert(config.expectedEffects == 3 and #config.effects == 3)
local m = {play=0, stop=0, suppress=0, prepare=0, load=0, active=false}
local function owner(id) return setmetatable({id=id},{__tostring=function() error('identity must not use tostring') end}) end
m.player = owner(1)
local names, paths = config.effects, {
  'ch13\\fx\\player\\time_dilation_vfx_radial_blur.effect',
  'ch13\\fx\\player\\time_dilation_vfx_outlines.effect',
  'ch13\\fx\\player\\time_dilation_vfx_flash.effect'
}
function registerForEvent(name,fn) callbacks[name]=fn end
function registerHotkey(name,description,fn) callbacks[name]=fn end
function ObserveBefore(class,name,fn) before[class..'.'..name]=fn end
function ObserveAfter(class,name,fn) after[class..'.'..name]=fn end
print = function(line) logs[#logs+1]=line end
CName = {new=function(name) return name end}
ChronosBridge = {
  SameOwner=function(a,b) return a and b and a.id==b.id end,
  IsRunning=function(p) return p and p.id==1 and m.active end,
  IsSuspended=function() return false end
}
ChronosLensFX = {
  Register=function(p) assert(p.id==1);m.prepare=m.prepare+1;return 3 end,
  Registered=function(p) return 3 end,
  Name=function(index) return names[index+1] end,
  Path=function(index) return paths[index+1] end,
  NativeTargets=function() return {{name='native_grade',path='native_grade.effect'}} end,
  Play=function(p,name)
    assert(p.id==1 and m.active)
    assert(name==names[1] or name==names[2] or name==names[3])
    m.play=m.play+1;return true
  end,
  StopOwn=function(p,name)
    assert(name==names[1] or name==names[2] or name==names[3])
    m.stop=m.stop+1
  end,
  SuppressGrade=function(p,name)
    assert(p.id==1 and m.active and name=='native_grade')
    m.suppress=m.suppress+1;return true
  end
}
ChronosV2VisualQueries={ResourceHasGrade=function(resource) return resource.grade end}
Game={GetPlayer=function() return m.player end,GetResourceDepot=function()
 return {LoadResource=function(self,path)
  assert(path==paths[1] or path==paths[2] or path==paths[3] or path=='native_grade.effect')
  m.load=m.load+1
  return {IsFailed=function()return false end,IsLoaded=function()return true end,
    GetResource=function()return {grade=path=='native_grade.effect'} end}
 end}
end}
local exported=assert(loadfile(root..'/source/init.lua'))()
callbacks.onInit()
before['PlayerPuppet.PlayerAttachedCallback'](owner(99),m.player)
after['PlayerPuppet.PlayerAttachedCallback'](owner(99),m.player)
callbacks.onUpdate(0.1)
assert(m.prepare==1 and m.load==4 and m.play==0 and m.suppress==0)
m.active=true
for _=1,30 do m.player=owner(1);callbacks.onUpdate(0.1) end
assert(m.play==3 and m.suppress==1 and m.stop==0)
after['GameObject.StartStatusEffectVFX'](owner(2),{})
assert(m.suppress==1)
after['GameObject.StartStatusEffectVFX'](owner(1),{})
assert(m.suppress==2)
exported.diagnostics()
m.active=false
for _=1,10 do callbacks.onUpdate(0.1) end
assert(m.stop==3 and m.play==3 and m.suppress==2)
after['GameObject.StartStatusEffectVFX'](owner(1),{})
assert(m.suppress==2)
m.active=true;callbacks.onUpdate(0.1)
assert(m.play==6 and m.load==4)
callbacks.onShutdown()
assert(m.stop==6)
assert(#logs>0)
io.write('PASS: shipped CET glue/config/three-effect lifecycle in mock host\n')
io.write('NOT VALIDATED: actual CET RTTI, REDscript cache or rendered output\n')
