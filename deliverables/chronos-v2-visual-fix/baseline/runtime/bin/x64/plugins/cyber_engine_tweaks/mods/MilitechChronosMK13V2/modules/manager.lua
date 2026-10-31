local Manager = {}
Manager.__index = Manager
function Manager.new(api,config,modules)
  return setmetatable({api=api,config=config,modules=modules,running={},failed={},owner=nil},Manager)
end
function Manager:stop(restore)
  for name,module in pairs(self.modules) do
    if self.running[name] then
      local ok,err=pcall(function() module:stop(restore) end)
      if not ok then self.api.log(name.." cleanup failed: "..tostring(err)) end
    end
  end
  self.owner,self.running=nil,{}
end
function Manager:setEnabled(name,enabled)
  self.config.enabled[name]=enabled
  if not enabled and self.running[name] then
    self.modules[name]:stop(true);self.running[name]=nil
  elseif enabled then self.failed[name]=nil end
  self.api.log(name.."="..tostring(enabled))
end
function Manager:tick(dt)
  local owner=self.api.player()
  if self.owner and (not owner or not self.api.same(owner,self.owner)) then self:stop(false) end
  if not owner or not self.api.active(owner) then self:stop(false);return end
  if not self.owner then self.owner=owner end
  if type(dt)~="number" or dt~=dt or dt<=0 or dt>self.config.maxObservationGap then
    self:stop(true);return
  end
  for name,module in pairs(self.modules) do
    if not self.config.enabled[name] and self.running[name] then
      module:stop(true);self.running[name]=nil
    end
    if self.config.enabled[name] and not self.failed[name] then
      local ok,err=pcall(function()
        if not self.running[name] then
          self.running[name]=true -- mark before start so a partial start is cleaned
          module:start(owner)
        else module:tick(owner,dt) end
      end)
      if not ok then
        self.failed[name]=tostring(err)
        pcall(function() module:stop(true) end)
        self.running[name]=nil
        self.api.log("FEATURE DISABLED "..name..": "..tostring(err).."; R1b core unchanged")
      end
    end
  end
end
return Manager
