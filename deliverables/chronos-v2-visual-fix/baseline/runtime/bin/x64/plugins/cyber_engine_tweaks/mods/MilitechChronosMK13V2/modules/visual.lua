local Visual = {}
Visual.__index = Visual
function Visual.new(api,config) return setmetatable({api=api,config=config},Visual) end
function Visual:start(owner)
  self:stop(false)
  self.owner,self.pending,self.suppressed,self.elapsed,self.checked=owner,{},{},0,{}
  for _,target in ipairs(self.api.visualTargets(owner)) do
    local key=tostring(target.name)
    if not self.checked[key] then
      self.checked[key]=true
      table.insert(self.pending,{name=target.name,token=self.api.loadResource(target.path)})
    end
  end
  if #self.pending==0 then self.api.log("visual unresolved: no native Sandevistan VFX descriptor; no guessed event stopped") end
end
function Visual:tick(owner,dt)
  self.elapsed=self.elapsed+dt
  local waiting={}
  for _,target in ipairs(self.pending) do
    local state=self.api.resourceState(target.token)
    if state=="loaded" then
      if self.api.resourceHasGrade(target.token) then
        self.api.stopVisual(owner,target.name)
        self.suppressed[#self.suppressed+1]=target.name
        self.api.log("visual: stopped native effect containing camera color-grade track: "..tostring(target.name))
      elseif self.config.debug then self.api.log("visual: left non-grade native effect intact: "..tostring(target.name)) end
    elseif state=="pending" and self.elapsed<self.config.visualResolveTimeout then
      waiting[#waiting+1]=target
    else self.api.log("visual resource unresolved/timeout: "..tostring(target.name)) end
  end
  self.pending=waiting
end
function Visual:resuppress()
  if self.owner then for _,name in ipairs(self.suppressed) do self.api.stopVisual(self.owner,name) end end
end
function Visual:stop(restore)
  if restore and self.owner and self.api.active(self.owner) then
    for _,name in ipairs(self.suppressed or {}) do
      local ok,err=pcall(self.api.restoreVisual,self.owner,name)
      if not ok then self.api.log("visual restore failed: "..tostring(err)) end
    end
  end
  self.owner,self.pending,self.suppressed,self.checked=nil,{},{},{}
  self.elapsed=0
end
return Visual
