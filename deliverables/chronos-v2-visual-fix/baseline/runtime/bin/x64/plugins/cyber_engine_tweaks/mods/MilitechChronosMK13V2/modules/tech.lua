local Progress = require("modules/progress")
local Tech = {}
Tech.__index = Tech
function Tech.new(api, config) return setmetatable({api=api, config=config},Tech) end
function Tech:start(owner) self:stop(); self.owner=owner end
function Tech:stop() self.owner,self.weapon,self.previous=nil,nil,nil end
function Tech:tick(owner,dt)
  local weapon=self.api.techWeapon(owner)
  if not weapon then self.weapon,self.previous=nil,nil;return end
  if not self.weapon or not self.api.same(weapon,self.weapon) then self.previous=nil;self.weapon=weapon end
  local now=self.api.pool(weapon,"WeaponCharge")
  if not now then self.previous=nil;return end
  -- No charge threshold, ChargeTime minimum, Bolt-window or weapon record edit.
  local extra=Progress.pool(self.previous,now,dt,self.config.maxObservationGap)
  if extra>0.00001 then
    self.api.changePool(weapon,"WeaponCharge",extra,owner)
    now.value=now.value+extra
    self.api.count("tech")
  end
  self.previous=now
end
return Tech
