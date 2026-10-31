local Timing = require("modules/timing")
local Controller = {}
Controller.__index = Controller

function Controller.new(api, config)
  return setmetatable({api = api, config = config, owner = nil, modifiers = {},
    active = false, pools = {}, statuses = {}, weapon = nil,
    elapsed = 0, healthLog = 0, corrected = 0, removals = {}}, Controller)
end

function Controller:stop(reason)
  if self.owner then
    local ok, err = pcall(self.api.arm, self.owner, false)
    if not ok then self.api.log("CONTROLLER GATE CLEANUP ERROR " .. tostring(err)) end
  end
  -- Retain failed removals for retry: never discard the sole modifier handle.
  for _, handle in ipairs(self.modifiers) do
    table.insert(self.removals, {owner = self.owner, handle = handle})
  end
  self.modifiers = {}
  local pending = {}
  for _, removal in ipairs(self.removals) do
    local ok, removed = pcall(self.api.removeModifier, removal.owner, removal.handle)
    if not ok or removed == false then table.insert(pending, removal) end
  end
  self.removals = pending
  if self.active then self.api.log("STOP " .. reason) end
  self.owner, self.active, self.weapon = nil, false, nil
  self.pools, self.statuses = {}, {}
  self.elapsed, self.healthLog, self.corrected = 0, 0, 0
end

function Controller:start(owner)
  if #self.removals > 0 then return false end
  self.owner = owner
  -- Register each handle BEFORE adding it, so exceptions can roll back safely.
  for _, spec in ipairs({{"MitigationChance", 28}, {"MitigationStrength", 7}}) do
    local handle = self.api.makeModifier(spec[1], spec[2])
    assert(handle, "Cannot create " .. spec[1])
    table.insert(self.modifiers, handle)
    self.api.addModifier(owner, handle)
  end
  self.api.arm(owner, true)
  self.active = true
  self.api.log("START exact Chronos item; drain=1/13 maxHP/real-second; mitigation=+28/+7")
  return true
end

function Controller:updatePool(owner, key, kind, dt)
  local current = self.api.pool(owner, kind)
  if not current then self.pools[key] = nil; return end
  local extra = Timing.pool(self.pools[key], current, dt)
  if extra > 0.0001 then
    self.api.changePool(owner, kind, extra, self.owner)
    -- Account for our own queued debit/credit, not just the pre-request value.
    current.value = current.value + extra
    self.corrected = self.corrected + 1
  end
  self.pools[key] = current
end

function Controller:updateCooldowns(dt)
  if self.config.v2Features then return end -- optional cooldowns owned by independent V2 module
  for _, kind in ipairs(self.config.pools) do
    self:optional("pool_" .. kind, function() self:updatePool(self.owner, kind, kind, dt) end)
  end
  self:optional("statuses", function() self:updateStatuses(dt) end)
end

function Controller:updateStatuses(dt)
  local nextStatuses = {}
  for _, current in ipairs(self.api.cooldowns(self.owner)) do
    if not current.excluded then
      local extra = Timing.status(self.statuses[current.key], current, dt)
      if extra > 0.0001 and self.api.setDuration(self.owner, current.id, current.remaining - extra) then
        current.remaining = current.remaining - extra
        self.corrected = self.corrected + 1
      end
      nextStatuses[current.key] = current
    end
  end
  self.statuses = nextStatuses
end

function Controller:updateTech(dt)
  if not self.config.tech then return end
  local weapon = self.api.techWeapon(self.owner)
  if not weapon then self.weapon = nil; self.pools.weapon = nil; return end
  if not self.weapon or not self.api.sameOwner(weapon, self.weapon) then
    self.weapon, self.pools.weapon = weapon, nil
  end
  -- Operates on the equipped Tech gun's native WeaponCharge pool, never ChargeTime.
  -- No modifier exists to leak to the old weapon after holstering/swapping.
  self:updatePool(weapon, "weapon", "WeaponCharge", dt)
end

function Controller:optional(name, fn)
  local key = name .. "Failed"
  if self[key] then return end
  local ok, err = pcall(fn)
  if not ok then
    self[key] = true
    self.pools, self.statuses = {}, {}
    self.api.log("FEATURE DISABLED " .. name .. ": " .. tostring(err)
      .. "; health drain and active-only defense remain running")
  end
end

function Controller:tick(dt)
  assert(type(dt) == "number" and dt == dt and dt >= 0 and dt < math.huge, "Invalid real delta")
  local owner = self.api.player()
  if self.owner and (not owner or not self.api.sameOwner(owner, self.owner)) then self:stop("owner changed") end
  if not owner or not self.api.running(owner) or self.api.suspended(owner) then
    if self.active or #self.removals > 0 or #self.modifiers > 0 then self:stop("inactive/paused/detached") end
    return
  end
  if not self.active then
    if #self.removals > 0 then self:stop("retry modifier cleanup") end
    self:start(owner)
    return -- activation-crossing frame is not billed retroactively
  end
  if dt == 0 then return end
  self.api.drain(owner, dt)
  self.healthLog = self.healthLog + dt
  if self.config.debug and self.healthLog >= 1 then
    self.api.log(string.format("DRAIN %.4fs = %.4f%% maxHP; correction requests=%d",
      self.healthLog, self.healthLog * 100 / 13, self.corrected))
    self.healthLog, self.corrected = 0, 0
  end
  -- Health runs each frame. Small fixed pool list at frame cadence also avoids
  -- coarse 100ms Tech/Bolt charge jumps. Tagged effects are queried at 10Hz only.
  if dt > 0.5 then
    self.pools, self.statuses = {}, {}
    self.elapsed = 0
    return -- preserve health debit; discard ambiguous cooldown observations only
  end
  self:optional("tech", function() self:updateTech(dt) end)
  self.elapsed = self.elapsed + dt
  if self.elapsed >= 0.1 then
    self:optional("cooldowns", function() self:updateCooldowns(self.elapsed) end)
    self.elapsed = 0
  end
end

return Controller
