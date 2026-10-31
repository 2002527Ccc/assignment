local State = {}
State.__index = State

local DEFAULT_PRIVATE = {"ch13_lens_radial_blur", "ch13_lens_outlines"}
local function numberOr(value, fallback) return tonumber(value) or fallback end

function State.new(api, config)
  local self = setmetatable({}, State)
  self.api, self.config = api, config or {}
  self.names = {}
  for _, name in ipairs(self.config.effects or DEFAULT_PRIVATE) do self.names[#self.names + 1] = name end
  self.expected = self.config.expectedEffects or #self.names
  self.interval = self.config.registrationInterval or 0.25
  self.maxAttempts = self.config.maxRegistrationAttempts or 8
  self.timeout = self.config.resourceTimeout or 8
  self.owner, self.prepared, self.registeredCount = nil, false, 0
  self.attempts, self.retryElapsed = 0, self.interval
  self.setupDone, self.custom, self.grades = false, {}, {}
  self.resourceElapsed, self.resourceReady, self.resourceFailed = 0, false, false
  self.activeObserved, self.requested, self.startAttempted = false, false, false
  self.bridgeFault, self.warned = false, {}
  return self
end

function State:_log(message)
  if type(self.api.log) == "function" then pcall(self.api.log, message) end
end

function State:_warn(key, message)
  if not self.warned[key] then
    self.warned[key] = true
    self:_log(message)
  end
end

function State:_call(name, ...)
  local fn = self.api[name]
  if type(fn) ~= "function" then return false, "missing api." .. name end
  return pcall(fn, ...)
end

-- Only configured private event aliases may reach api.stop.
function State:_endRequests(reason)
  if not self.requested then return end
  self.requested = false
  for _, name in ipairs(self.names) do
    local ok, result = self:_call("stop", self.owner, name)
    if not ok or result == false then
      self:_warn("stop_" .. tostring(name), "STOP_REQUEST_FAILED " .. tostring(name) .. ": " .. tostring(result))
    end
  end
  self:_log("STOP_REQUESTED reason=" .. tostring(reason) .. "; actual rendering state is unverified")
end

function State:stop(reason)
  self:_endRequests(reason or "external_stop")
  -- Do not restart while this same native activation remains true.
  self.startAttempted = true
end

function State:_fault(stage, message)
  self.bridgeFault = true
  self:_endRequests("bridge_error:" .. stage)
  self:_warn("bridge_fault", "BRIDGE_ERROR stage=" .. stage .. ": " .. tostring(message)
    .. "; playback blocked until inactive or owner replacement")
end

function State:_adopt(owner, reason)
  self:_endRequests(reason or "owner_changed")
  self.owner, self.prepared, self.registeredCount = owner, false, 0
  self.attempts, self.retryElapsed = 0, self.interval
  self.setupDone, self.custom, self.grades = false, {}, {}
  self.resourceElapsed, self.resourceReady, self.resourceFailed = 0, false, false
  self.activeObserved, self.requested, self.startAttempted = false, false, false
  self.bridgeFault, self.warned = false, {}
end

function State:_tryPrepare(phase)
  if not self.owner or self.prepared or self.attempts >= self.maxAttempts then return self.prepared end
  self.attempts = self.attempts + 1
  self.retryElapsed = 0
  local preparedOK, reported = self:_call("prepare", self.owner)
  local readOK, actual = self:_call("registered", self.owner)
  self.registeredCount = readOK and numberOr(actual, 0) or 0
  -- The prepare return value alone is insufficient: inspect the actual array.
  if preparedOK and readOK and self.registeredCount >= self.expected then
    self.prepared = true
    self:_log("REGISTERED readback=" .. self.registeredCount .. " phase=" .. tostring(phase)
      .. "; descriptor registration is not rendering proof")
    if phase == "late" then
      self:_log("LATE_REGISTRATION: component initialization timing remains unverified; reload may still be required")
    end
    return true
  end
  if self.attempts >= self.maxAttempts then
    self:_warn("registration_exhausted", "REGISTRATION_BLOCKED attempts=" .. self.attempts
      .. " readback=" .. self.registeredCount .. " prepareResult=" .. tostring(reported)
      .. "; playback will not be requested")
  end
  return false
end

function State:attach(owner, phase)
  if not owner then return false end
  if self.owner then
    local ok, same = self:_call("same", owner, self.owner)
    if not ok then self:_fault("attach_same", same); return false end
    if not same then self:_adopt(owner, "attach_owner_changed") end
  else
    self:_adopt(owner, "attach")
  end
  -- Repeated callbacks for the same owner never restart FX or reload resources.
  return self:_tryPrepare(phase or "attach")
end

function State:_loadResources()
  if not self.prepared or self.setupDone then return end
  self.setupDone, self.resourceElapsed = true, 0
  local ok, rows = self:_call("resources", self.owner)
  if not ok or type(rows) ~= "table" or #rows ~= self.expected then
    self.resourceFailed = true
    self:_warn("custom_resource_setup", "RESOURCE_BLOCKED: expected exactly " .. self.expected .. " private resource tokens")
  else
    for _, row in ipairs(rows) do
      self.custom[#self.custom + 1] = {name = row.name, token = row.token, state = "pending"}
      if row.token == nil then
        self.resourceFailed = true
        self:_warn("custom_resource_nil", "RESOURCE_BLOCKED: a private resource token is unavailable")
      end
    end
  end
  local gradeOK, candidates = self:_call("gradeTargets", self.owner)
  if not gradeOK or type(candidates) ~= "table" then
    self:_warn("grade_candidates", "NATIVE_GRADE_UNRESOLVED: no verified candidate list; no guessed native event will be suppressed")
    return
  end
  for _, row in ipairs(candidates) do
    local duplicate = false
    for _, existing in ipairs(self.grades) do
      if existing.name == row.name then duplicate = true; break end
    end
    if not duplicate then
      self.grades[#self.grades + 1] = {name = row.name, token = row.token,
        checked = false, grade = false, suppressed = false, suppressFailed = false}
    end
  end
  if #self.grades == 0 then
    self:_warn("no_grade_candidates", "NATIVE_GRADE_UNRESOLVED: candidate count is zero; absence of blue has not been established")
  end
end

function State:_pollResources(dt)
  if not self.setupDone then return end
  self.resourceElapsed = self.resourceElapsed + dt
  if not self.resourceFailed and not self.resourceReady then
    local loaded = 0
    for _, row in ipairs(self.custom) do
      if row.state ~= "loaded" then
        local ok, state = self:_call("resourceState", row.token)
        if not ok or state == "failed" or (state ~= "loaded" and state ~= "pending") then
          self.resourceFailed = true
          self:_warn("custom_resource_failed", "RESOURCE_BLOCKED: private resource failed or state unreadable")
          break
        end
        if state == "pending" and self.resourceElapsed >= self.timeout then
          self.resourceFailed = true
          self:_warn("custom_resource_timeout", "RESOURCE_BLOCKED: private resource timeout; no per-frame reload or playback retry")
          break
        end
        row.state = state
      end
      if row.state == "loaded" then loaded = loaded + 1 end
    end
    if not self.resourceFailed and loaded == self.expected then
      self.resourceReady = true
      self:_log("PRIVATE_RESOURCES_LOADED count=" .. loaded .. "; loaded resources are not rendering proof")
    end
  end
  for _, row in ipairs(self.grades) do
    if not row.checked then
      local ok, state = self:_call("resourceState", row.token)
      if ok and state == "loaded" then
        local gradeOK, grade = self:_call("hasGrade", row.token)
        row.checked = true
        if gradeOK and type(grade) == "boolean" then
          row.grade = grade
        else
          self:_warn("grade_inspection", "NATIVE_GRADE_UNRESOLVED: inspection failed; candidate will not be suppressed")
        end
      elseif not ok or state == "failed" or self.resourceElapsed >= self.timeout then
        row.checked = true
        self:_warn("grade_resource", "NATIVE_GRADE_UNRESOLVED: candidate load failed/timeout; no guessed suppression")
      end
    end
  end
end

function State:_suppress(force)
  -- Never remove the native visual while private replacements are unready.
  if not self.activeObserved or self.bridgeFault or not self.requested
    or not self.prepared or not self.resourceReady or self.resourceFailed then return end
  for _, row in ipairs(self.grades) do
    if row.checked and row.grade and not row.suppressFailed and (force or not row.suppressed) then
      -- The typed api.suppress also applies an exact-CHRONOS safety gate.
      local ok, result = self:_call("suppress", self.owner, row.name)
      if ok and result ~= false then
        row.suppressed = true
      else
        row.suppressFailed = true
        self:_warn("suppress_failed", "NATIVE_SUPPRESSION_REQUEST_FAILED: " .. tostring(result))
      end
    end
  end
end

function State:_startOnce()
  if self.startAttempted or not self.prepared or not self.resourceReady
    or self.resourceFailed or self.bridgeFault then return end
  if #self.names ~= self.expected or self.expected <= 0 then
    self.startAttempted = true
    self:_warn("configuration_mismatch", "PLAY_BLOCKED: configured event count does not match expectedEffects")
    return
  end
  local ok, count = self:_call("registered", self.owner)
  if not ok then self:_fault("registered", count); return end
  self.registeredCount = numberOr(count, 0)
  if self.registeredCount < self.expected then
    self.prepared = false
    self:_warn("registration_lost", "REGISTRATION_LOST: playback blocked pending bounded preparation")
    return
  end
  self.startAttempted = true
  -- Set first so a partially successful request can be cleaned safely.
  self.requested = true
  for _, name in ipairs(self.names) do
    local played, result = self:_call("play", self.owner, name)
    if not played or result == false then
      self:_warn("play_failed", "PRIVATE_PLAY_REQUEST_FAILED: " .. tostring(result))
      self:_endRequests("private_play_request_failed")
      return
    end
  end
  self:_log("PLAY_REQUESTED count=" .. #self.names .. "; rendered=UNVERIFIED")
end

function State:tick(dt)
  if type(dt) ~= "number" or dt ~= dt or dt < 0 or dt == math.huge then
    self:_warn("invalid_delta", "INVALID_DELTA: visual observation skipped")
    return
  end
  local playerOK, player = self:_call("player")
  if not playerOK then self:_fault("player", player); return end
  if not player then
    if self.owner then self:_adopt(nil, "player_unavailable") end
    return
  end
  if self.owner then
    local sameOK, same = self:_call("same", player, self.owner)
    if not sameOK then self:_fault("same", same); return end
    if not same then self:_adopt(player, "owner_changed") end
  else
    self:_adopt(player, "player_available")
  end
  -- Prewarm private descriptors/resources while inactive; no visual event here.
  if not self.prepared and self.attempts < self.maxAttempts then
    self.retryElapsed = self.retryElapsed + dt
    if self.retryElapsed >= self.interval then self:_tryPrepare("late") end
  end
  self:_loadResources()
  self:_pollResources(dt)
  local activeOK, active = self:_call("active", player)
  if not activeOK then self:_fault("active", active); return end
  if not active then
    self:_endRequests("chronos_inactive_or_suspended")
    self.activeObserved, self.startAttempted, self.bridgeFault = false, false, false
    self.warned.bridge_fault = nil
    for _, row in ipairs(self.grades) do row.suppressed, row.suppressFailed = false, false end
    return
  end
  if not self.activeObserved then self.activeObserved, self.startAttempted = true, false end
  if self.bridgeFault then return end
  -- Only suppress after all private playback requests have succeeded.
  self:_startOnce()
  self:_suppress(false)
end

function State:resuppress(owner)
  if not owner or not self.owner or self.bridgeFault or not self.requested
    or not self.prepared or not self.resourceReady or self.resourceFailed then return end
  local sameOK, same = self:_call("same", owner, self.owner)
  if not sameOK then self:_fault("resuppress_same", same); return end
  if not same then return end
  local activeOK, active = self:_call("active", owner)
  if not activeOK then self:_fault("resuppress_active", active); return end
  if not active then return end
  self.activeObserved = true
  self:_suppress(true)
end

function State:diagnose()
  local count = self.registeredCount
  if self.owner then
    local ok, value = self:_call("registered", self.owner)
    if ok then count = numberOr(value, 0) end
  end
  local loaded, confirmedGrades, gradeRequests = 0, 0, 0
  for _, row in ipairs(self.custom) do
    if row.state == 'loaded' then loaded = loaded + 1 end
    self:_log('RESOURCE name=' .. tostring(row.name) .. ' state=' .. tostring(row.state))
  end
  for _, row in ipairs(self.grades) do
    if row.checked and row.grade then confirmedGrades = confirmedGrades + 1 end
    if row.suppressed then gradeRequests = gradeRequests + 1 end
  end
  local result = {ownerPresent = self.owner ~= nil, prepared = self.prepared,
    registered = count, registrationAttempts = self.attempts,
    expected = self.expected, privateLoaded = loaded,
    nativeCandidates = #self.grades, nativeGradesConfirmed = confirmedGrades,
    nativeGradeStopRequested = gradeRequests,
    resourceReady = self.resourceReady, resourceFailed = self.resourceFailed,
    requested = self.requested, activeObserved = self.activeObserved,
    bridgeFault = self.bridgeFault, rendered = "UNVERIFIED"}
  self:_log("STATE prepared=" .. tostring(result.prepared) .. " registered=" .. tostring(result.registered)
    .. " resourcesReady=" .. tostring(result.resourceReady) .. " resourcesFailed=" .. tostring(result.resourceFailed)
    .. " privateLoaded=" .. loaded .. '/' .. self.expected
    .. " nativeGradesConfirmed=" .. confirmedGrades .. " gradeStopRequested=" .. gradeRequests
    .. " requested=" .. tostring(result.requested) .. " active=" .. tostring(result.activeObserved)
    .. " bridgeFault=" .. tostring(result.bridgeFault) .. " rendered=UNVERIFIED")
  return result
end

return State
