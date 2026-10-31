-- Pure Lua mocks: not CET/REDscript/engine registration or rendering validation.
local State = dofile((arg and arg[1]) or "source/modules/state.lua")
local PRIVATE = {"ch13_lens_radial_blur", "ch13_lens_outlines"}
local serial = 0
local function owner(id)
  return setmetatable({id = id}, {__tostring = function()
    serial = serial + 1
    return "unstable-wrapper-" .. serial
  end})
end

local function fixture(options)
  options = options or {}
  local names = options.effects or PRIVATE
  local m = {player = owner(1), active = {}, registered = {}, prepareCalls = 0,
    resourceCalls = 0, gradeCalls = 0, playCalls = {}, stopCalls = {}, suppressCalls = {},
    actions = {}, logs = {}, allowRegistration = options.allowRegistration ~= false,
    custom = {{state = options.resourceState or "loaded"}, {state = options.resourceState or "loaded"}},
    grade = {state = "loaded", grade = true}}
  for index = 3, #names do m.custom[index] = {state = options.resourceState or "loaded"} end
  local function append(t, value) t[#t + 1] = value end
  local api = {
    player = function() if m.playerError then error("mock player error") end; return m.player end,
    same = function(a, b)
      if m.sameError then error("mock same error") end
      return a ~= nil and b ~= nil and a.id == b.id
    end,
    active = function(p)
      if m.activeError then error("mock active error") end
      return m.active[p.id] == true
    end,
    prepare = function(p)
      m.prepareCalls = m.prepareCalls + 1
      if m.allowRegistration then m.registered[p.id] = #names end
      return #names -- Intentionally claims success even when readback stays zero.
    end,
    registered = function(p) return m.registered[p.id] or 0 end,
    resources = function()
      m.resourceCalls = m.resourceCalls + 1
      local result = {}
      for index, name in ipairs(names) do result[index] = {name = name, token = m.custom[index]} end
      return result
    end,
    resourceState = function(token) return token and token.state or "failed" end,
    gradeTargets = function()
      m.gradeCalls = m.gradeCalls + 1
      return {{name = "native_combined_grade", token = m.grade}}
    end,
    hasGrade = function(token) return token.grade == true end,
    play = function(p, name)
      append(m.actions, "play:" .. name)
      if m.playErrorAt == name then error("mock play failure") end
      append(m.playCalls, {id = p.id, name = name})
    end,
    stop = function(p, name)
      local allowed = false
      for _, expected in ipairs(names) do if name == expected then allowed = true end end
      assert(allowed, "only configured private aliases may be stopped")
      append(m.stopCalls, {id = p.id, name = name})
      append(m.actions, "stop:" .. name)
    end,
    suppress = function(p, name)
      assert(m.active[p.id], "native suppression must be active-only")
      assert(name == "native_combined_grade", "unexpected native name")
      append(m.suppressCalls, {id = p.id, name = name})
      append(m.actions, "suppress:" .. name)
    end,
    log = function(text) append(m.logs, text) end
  }
  local s = State.new(api, {effects = options.effects, expectedEffects = #names, registrationInterval = 0.25,
    maxRegistrationAttempts = 8, resourceTimeout = 8})
  return s, m
end

local function contains(logs, fragment)
  local count = 0
  for _, text in ipairs(logs) do if text:find(fragment, 1, true) then count = count + 1 end end
  return count
end

do -- Same native owner despite a fresh Lua object and unstable tostring each tick.
  local s, m = fixture(); m.active[1] = true
  assert(s:attach(m.player, "PlayerAttachedCallback"))
  for _ = 1, 20 do m.player = owner(1); s:tick(0.1) end
  assert(m.prepareCalls == 1 and m.resourceCalls == 1 and m.gradeCalls == 1)
  assert(#m.playCalls == 2 and #m.suppressCalls == 1 and #m.stopCalls == 0)
  assert(m.actions[1] == "play:" .. PRIVATE[1] and m.actions[2] == "play:" .. PRIVATE[2])
  assert(m.actions[3] == "suppress:native_combined_grade")
  assert(s:attach(owner(1), "same_owner_callback")); s:tick(0.1)
  assert(m.resourceCalls == 1 and #m.playCalls == 2)
end

do -- Zero registration readback blocks play and suppression despite prepare()=2.
  local s, m = fixture({allowRegistration = false}); m.active[1] = true
  assert(not s:attach(m.player, "attach"))
  for _ = 1, 30 do s:tick(0.25) end
  assert(m.prepareCalls == 8 and #m.playCalls == 0 and #m.suppressCalls == 0 and m.resourceCalls == 0)
  assert(contains(m.logs, "REGISTRATION_BLOCKED") == 1)
end

do -- Pending private resources must not remove the existing native visual.
  local s, m = fixture({resourceState = "pending"}); m.active[1] = true
  s:attach(m.player, "attach"); s:tick(1); s:resuppress(m.player)
  assert(#m.playCalls == 0 and #m.suppressCalls == 0)
  m.custom[1].state, m.custom[2].state = "loaded", "loaded"
  s:tick(0.1); s:tick(0.1)
  assert(#m.playCalls == 2 and #m.suppressCalls == 1)
end

do -- Failed resources are latched, not reloaded or played every frame.
  local s, m = fixture({resourceState = "failed"}); m.active[1] = true
  s:attach(m.player, "attach")
  for _ = 1, 20 do s:tick(0.1); s:resuppress(m.player) end
  assert(#m.playCalls == 0 and #m.suppressCalls == 0 and m.resourceCalls == 1)
  m.custom[1].state, m.custom[2].state = "loaded", "loaded"; s:tick(0.1)
  assert(#m.playCalls == 0 and contains(m.logs, "RESOURCE_BLOCKED") == 1)
end

do -- Timeout is a single diagnostic, not an infinite reload/start loop.
  local s, m = fixture({resourceState = "pending"}); m.active[1] = true
  s:attach(m.player, "attach")
  for _ = 1, 20 do s:tick(0.5) end
  assert(#m.playCalls == 0 and #m.suppressCalls == 0 and m.resourceCalls == 1)
  assert(contains(m.logs, "RESOURCE_BLOCKED") == 1)
end

do -- Other Sandy/Kerenzikov: inactive means no playback or suppression.
  local s, m = fixture(); s:attach(m.player, "attach")
  for _ = 1, 20 do s:tick(0.1) end
  s:resuppress(m.player)
  assert(#m.playCalls == 0 and #m.suppressCalls == 0)
  assert(s.resourceReady and m.resourceCalls == 1)
  m.active[1] = true; s:tick(0.1)
  m.active[1] = false
  for _ = 1, 20 do s:tick(0.1) end
  assert(s.resourceReady and m.prepareCalls == 1 and m.resourceCalls == 1)
  m.active[1] = true; s:tick(0.1)
  assert(#m.playCalls == 4 and m.resourceCalls == 1)
end

do -- Genuine owner replacement stops the old owner and creates a fresh cache.
  local s, m = fixture(); m.active[1], m.active[2] = true, true
  s:attach(m.player, "attach"); s:tick(0.1)
  m.player = owner(2); s:tick(0.25)
  assert(#m.stopCalls == 2 and m.stopCalls[1].id == 1)
  assert(#m.playCalls == 4 and m.playCalls[3].id == 2 and m.resourceCalls == 2)
  m.player = nil; s:tick(0.1)
  assert(#m.stopCalls == 4 and s.owner == nil)
end

do -- Fail closed on bridge errors without flapping in the same activation.
  local s, m = fixture(); m.active[1] = true
  s:attach(m.player, "attach"); s:tick(0.1)
  m.activeError = true; s:tick(0.1); s:tick(0.1)
  assert(#m.stopCalls == 2 and contains(m.logs, "BRIDGE_ERROR") == 1)
  m.activeError = false
  for _ = 1, 10 do s:tick(0.1) end
  assert(#m.playCalls == 2)
  m.active[1] = false; s:tick(0.1)
  m.active[1] = true; s:tick(0.1)
  assert(#m.playCalls == 4)
end

do -- Identity bridge failure also cleans up and remains latched.
  local s, m = fixture(); m.active[1] = true
  s:attach(m.player, "attach"); s:tick(0.1)
  m.sameError = true; s:tick(0.1)
  assert(#m.stopCalls == 2)
  m.sameError = false; s:tick(0.1)
  assert(#m.playCalls == 2)
end

do -- Resuppression checks exact owner and active state again, not stale flags.
  local s, m = fixture(); m.active[1] = true
  s:attach(m.player, "attach"); s:tick(0.1)
  assert(#m.suppressCalls == 1)
  s:resuppress(owner(2)); assert(#m.suppressCalls == 1)
  s:resuppress(owner(1)); assert(#m.suppressCalls == 2)
  m.active[1] = false; s:resuppress(owner(1)); assert(#m.suppressCalls == 2)
end

do -- An ungraded or unready native candidate is never guessed to be blue.
  local s, m = fixture(); m.grade.grade = false; m.active[1] = true
  s:attach(m.player, "attach"); s:tick(0.1); s:resuppress(m.player)
  assert(#m.suppressCalls == 0 and #m.playCalls == 2)
  local d = s:diagnose(); assert(d.requested and d.rendered == "UNVERIFIED")
  local s2, m2 = fixture(); m2.grade.state = "pending"; m2.active[1] = true
  s2:attach(m2.player, "attach"); s2:tick(0.1); s2:resuppress(m2.player)
  assert(#m2.suppressCalls == 0)
end

do -- Partial play request failure rolls back private requests before suppression.
  local s, m = fixture(); m.active[1] = true; m.playErrorAt = PRIVATE[2]
  s:attach(m.player, "attach"); s:tick(0.1); s:resuppress(m.player)
  assert(#m.playCalls == 1 and #m.stopCalls == 2 and #m.suppressCalls == 0)
  m.playErrorAt = nil; s:tick(0.1)
  assert(#m.playCalls == 1, "same activation must not retry a partial start")
end

do -- Optional third one-shot resource is requested once, never looped per tick.
  local s, m = fixture({effects = {PRIVATE[1], PRIVATE[2], "ch13_lens_flash"}})
  m.active[1] = true
  s:attach(m.player, "attach")
  for _ = 1, 20 do s:tick(0.1) end
  assert(#m.playCalls == 3 and m.playCalls[3].name == "ch13_lens_flash")
  assert(#m.suppressCalls == 1 and m.prepareCalls == 1 and m.resourceCalls == 1)
  m.active[1] = false; s:tick(0.1)
  assert(#m.stopCalls == 3 and m.stopCalls[3].name == "ch13_lens_flash")
  for _ = 1, 10 do s:tick(0.1) end
  assert(#m.playCalls == 3 and #m.stopCalls == 3)
end

print("PASS: 13 pure Lua mocked visual state scenarios")
print("NOT VALIDATED: CET, REDscript, engine registration or rendered visuals")
