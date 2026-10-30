-- CHRONOS TASK02 / Finale passive diagnostics, v0.1.1.
-- No Observe/Override hooks, attack calls, game-record writes or damage writes here.
-- Public API: GetMod('CH13FinaleDiagnostics').arm('Normal'|'Charged'|'Bolt')
local api = {}
local enabled, overlay = false, false
local elapsed, poll, trial, seq = 0, 0, 0, 0
local current, boundPlayer, pendingPlayer = nil, nil, nil
local lastSeenPlayer = nil
local status = 'Not initialized'
local logfile = 'finale_diag.jsonl' -- CET mod-relative sandbox path.
local session = os.date('!%Y%m%dT%H%M%SZ') .. '-' .. tostring({}):gsub('[^%w]', '')
local U = 'UNAVAILABLE'
local pollInterval, trialDuration = 0.10, 12.0

local function quote(s)
  return '"' .. tostring(s):gsub('[%z\1-\31\\"]', function(c)
    local replacements = {['"']='\\"', ['\\']='\\\\', ['\n']='\\n', ['\r']='\\r', ['\t']='\\t'}
    return replacements[c] or string.format('\\u%04x', c:byte())
  end) .. '"'
end

local function json(value)
  local t = type(value)
  if t == 'nil' then return 'null' end
  if t == 'boolean' then return value and 'true' or 'false' end
  if t == 'number' then
    if value ~= value or value == math.huge or value == -math.huge then return 'null' end
    return tostring(value)
  end
  if t ~= 'table' then return quote(value) end
  local keys, out = {}, {}
  for k in pairs(value) do keys[#keys+1] = k end
  table.sort(keys, function(a,b) return tostring(a) < tostring(b) end)
  for _, k in ipairs(keys) do out[#out+1] = quote(k) .. ':' .. json(value[k]) end
  return '{' .. table.concat(out, ',') .. '}'
end

local function attempt(fn, fallback)
  local ok, value = pcall(fn)
  if ok and value ~= nil then return value end
  if fallback ~= nil then return fallback end
  return U
end

local function emit(kind, data)
  data = data or {}
  seq = seq + 1
  data.event, data.session, data.seq = kind, session, seq
  data.poll_real_seconds = elapsed -- Collection time, NOT exact engine callback wall time.
  if current then
    data.trial = data.trial or current.id
    data.manual_label = current.label
    data.label_is_native_bolt_detection = false
  end
  local line = json(data)
  -- print uses CET's normal logger. File failure must never stop gameplay.
  print('[CH13FD] ' .. line)
  local ok = pcall(function()
    local f, err = io.open(logfile, 'a')
    if not f then error(err or 'io.open failed') end
    local written, writeError = f:write(line .. '\n')
    local closed, closeError = f:close()
    if not written then error(writeError or 'write failed') end
    if not closed then error(closeError or 'close failed') end
  end)
  if not ok then status = 'JSONL write failed; copy [CH13FD] lines from CET console/log.' end
end

local function recordInfo(record)
  if record == nil then return {present=false, id=U, runtime_type=U} end
  return {
    present=true,
    id=attempt(function() return tostring(record:GetID()) end),
    -- CET RTTI object's text is preserved verbatim. Do not parse it as a guaranteed class name.
    rtti_object_text=attempt(function() return tostring(record) end),
    runtime_type=U,
    runtime_type_note='No unverified GetClassName/GetType API is called.'
  }
end

-- Read-only schema probes. Missing flats are UNAVAILABLE, not false or proof of absence.
-- These names are candidates, not assertions about the 2.5 record schema.
local function flats(record, names)
  local result = {}
  if record == nil then return {availability=U} end
  for _, name in ipairs(names) do
    result[name] = attempt(function()
      local id = TweakDBID.new(record:GetID(), '.' .. name)
      local value = TweakDB:GetFlat(id)
      if value == nil then return U end
      if type(value) == 'table' then
        local copy = {}
        for i, v in ipairs(value) do
          if i > 24 then copy.truncated = true; break end
          copy[tostring(i)] = tostring(v)
        end
        return copy
      end
      if type(value) == 'number' or type(value) == 'boolean' or type(value) == 'string' then return value end
      return tostring(value)
    end)
  end
  return result
end

local function identity(object)
  if object == nil then return U end
  return attempt(function() return tostring(object:GetEntityID()) end)
end

local function process(entry)
  local kind = tostring(entry.kind)
  -- CName text formatting is not used to dispatch: all populated fields are safe to read.
  local data = {
    trial=tonumber(entry.trial), engine_event_kind=kind,
    sim_time=tonumber(entry.simTime), weapon_id=tostring(entry.weaponID),
    weapon_entity=identity(entry.weapon), target_entity=identity(entry.target),
    callback_wall_time=U, shot_id=U,
    note='trial is a manually isolated test window; selection callbacks are not shot counts.'
  }
  if current then current.events = current.events + 1 end
  -- Event-specific fields are selected by exact CName equality, not substring guessing.
  if entry.kind == CName.new('selection') then
    data.original_attack = recordInfo(entry.attack)
    data.attack_package = recordInfo(entry.attackPackage)
    data.default_fire = recordInfo(attempt(function() return entry.attackPackage:DefaultFire() end, false) or nil)
    data.attack_flats = flats(entry.attack, {
      'attackType', 'attackName', 'effectName', 'effectTag', 'hitFlags',
      'projectileTemplateName', 'projectileTemplate', 'statModifiers', 'statusEffects'
    })
    data.package_flat_probes = flats(entry.attackPackage, {
      'defaultFire', 'chargeFire', 'fullyChargedFire', 'secondaryFire', 'overchargeFire'
    })
    data.native_mode, data.fire_charge, data.native_bolt = U, U, U
    data.selection_is_discharge = false
  elseif entry.kind == CName.new('projectile_initialize') then
    data.entity = identity(entry.entity)
    data.entity_object_text = attempt(function() return tostring(entry.entity) end)
    data.observed_hook_class = tostring(entry.hookClass)
    data.actual_script_class, data.entity_template, data.trajectory_type = U, U, U
    data.owner_entity, data.owner_is_player = identity(entry.owner), true
    data.initial_velocity_field, data.lifetime_field = tonumber(entry.startVelocity), tonumber(entry.lifetime)
    data.source_attribution = 'player owner + Finale currently active; not proof this entity came from this shot'
    data.positive_evidence = 'an entity initialization callback was observed in one of the two covered classes'
  else
    data.attack_type_enum = tonumber(entry.attackType)
    data.hit_weapon_charge = tonumber(entry.charge)
    data.full_charge_by_finale_threshold = data.hit_weapon_charge ~= nil and data.hit_weapon_charge >= 0.999
    data.full_charge_by_finale_threshold_note = 'Numeric threshold only; not Finale V6.2 fullCharge or native Bolt detection.'
    data.WeaponCharge = data.hit_weapon_charge or U
    data.PerfectlyCharged = entry.perfectlyCharged == true
    data.IsRanged = entry.isRanged == true
    data.NativeBoltFlag = U
    data.NativeBoltFlag_note = 'No independent native Bolt flag has been verified; PerfectlyCharged is a separate hit-context observation.'
    -- Reproduce Finale V6.2's read-only classification from the captured hit values.
    -- This does not set flags, alter attacks, or execute the blackwall effect.
    data.BlackwallFullCharge = data.IsRanged and (data.full_charge_by_finale_threshold or data.PerfectlyCharged)
    data.BlackwallFullCharge_note = 'Ranged && (WeaponCharge >= 0.999 || PerfectlyCharged), matching supplied Finale V6.2; not proof that a blackwall mark was applied.'
    data.can_execute = entry.canExecute == true
    data.upload_present = entry.uploadPresent == true
    data.upload_progress = tonumber(entry.uploadProgress)
    data.normal_mark, data.boss_mark = entry.normalMark == true, entry.bossMark == true
    data.native_bolt, data.hit_attack_record, data.final_damage = U, U, U
    data.pipeline_scope = 'Finale OET_UploadHitEffector.RepeatedAction; not a universal hit/damage observer'
    data.pipeline_stage_declared_in_supplied_yaml = 'PostProcess'
  end
  emit('engine_observation', data)
end

local function drain(player)
  if player == nil then return end
  local ok, rows = pcall(function() return CH13FD.Drain(player) end)
  if not ok then
    -- A bridge/interop error means incomplete telemetry, never a successful diagnosis.
    if current and not current.drainError then
      current.drainError = true
      emit('telemetry_error', {stage='Drain', error=tostring(rows)})
    end
    return
  end
  for _, entry in ipairs(rows or {}) do
    local valid, err = pcall(process, entry)
    if not valid then emit('telemetry_error', {stage='serialize', error=tostring(err)}) end
  end
end

function api.stop(reason)
  if not current then return end
  local player = boundPlayer
  if player then
    pcall(function() player.m_ch13FDEnabled = false end)
    drain(player)
  end
  emit('trial_end', {
    reason=reason or 'manual', observations=current.events,
    dropped=attempt(function() return tonumber(player.m_ch13FDDropped) end),
    selection_calls=attempt(function() return tonumber(player.m_ch13FDSelectionCalls) end),
    selection_transitions_logged=attempt(function() return tonumber(player.m_ch13FDSelectionEvents) end),
    selection_transitions_suppressed=attempt(function() return tonumber(player.m_ch13FDSelectionSuppressed) end),
    drain_error=current.drainError == true,
    hitscan_verdict='UNDETERMINED',
    no_projectile_observed_means_hitscan=false
  })
  if player then
    pcall(function()
      player.m_ch13FDSelectionAttack = nil
      player.m_ch13FDSelectionPackage = nil
    end)
  end
  current, boundPlayer = nil, nil
  status = 'Stopped. JSONL appended; no attack behavior was changed.'
end

function api.arm(label)
  if not enabled then return false, status end
  if label ~= 'Normal' and label ~= 'Charged' and label ~= 'Bolt' then
    return false, 'Use exactly Normal, Charged or Bolt (manual labels only).'
  end
  if current then api.stop('rearmed') end
  local player = Game.GetPlayer()
  if not player then status = 'Load a save before arming.'; return false, status end
  -- Also disarm onInit's deferred cleanup target, before starting a fresh capture.
  pendingPlayer = nil
  local ok, err = pcall(function()
    player.m_ch13FDEnabled = false
    CH13FD.Drain(player)
    player.m_ch13FDDropped = 0
    player.m_ch13FDSelectionCalls = 0
    player.m_ch13FDSelectionEvents = 0
    player.m_ch13FDSelectionSuppressed = 0
    trial = trial + 1
    player.m_ch13FDTrial = trial
    player.m_ch13FDSelectionTrial = -1
    player.m_ch13FDEnabled = true
  end)
  if not ok then
    pcall(function() player.m_ch13FDEnabled = false end)
    status = 'REDscript bridge unavailable: ' .. tostring(err)
    emit('telemetry_error', {stage='arm', error=tostring(err)})
    return false, status
  end
  boundPlayer = player
  lastSeenPlayer = player
  current = {id=trial, label=label, started=elapsed, events=0}
  status = 'ARMED ' .. label .. ' #' .. trial .. ': fire ONCE, then stop (12s auto stop).'
  emit('trial_begin', {
    expected_weapon='Items.Finale', expected_shots=1, duration_real_seconds=trialDuration,
    chronos_active_at_arm=attempt(function() return CH13Bridge.IsNativeActive(player) end),
    native_bolt=U, fire_event=U, fire_charge=U,
    entity_coverage='sampleBullet + sampleBulletGeneric initialize only',
    exact_engine_callback_wall_time=U,
    warning='Manual label is not native mode/Bolt detection. One trial may contain zero or multiple actual shots.'
  })
  return true
end

function api.mark(note)
  if not current then return false end
  emit('manual_marker', {note=tostring(note or 'trigger_reference'), is_engine_fire_event=false})
  return true
end

registerForEvent('onInit', function()
  enabled = true
  status = 'Ready to arm; REDscript bridge is checked when arming. Bind CET hotkeys or use GetMod API.'
  -- Added fields may have been serialized in a save; never automatically resume capture.
  pendingPlayer = true
  emit('session_begin', {
    version='0.1.1', output=logfile,
    validation='NOT_COMPILED_OR_TESTED_IN_CYBERPUNK_2077_2_5',
    native_bolt=U, universal_discharge_event=U, exact_damage_settlement=U
  })
end)

registerForEvent('onUpdate', function(delta)
  if not enabled or type(delta) ~= 'number' or delta <= 0 or delta ~= delta or delta == math.huge then return end
  elapsed = elapsed + delta
  local player = Game.GetPlayer()
  if current and player ~= boundPlayer then api.stop('player_changed_or_unloaded') end
  if player and (pendingPlayer or player ~= lastSeenPlayer) then
    pcall(function() player.m_ch13FDEnabled = false; CH13FD.Drain(player) end)
    pendingPlayer = nil
  end
  lastSeenPlayer = player
  if not current then return end
  poll = poll + delta
  if poll >= pollInterval then
    poll = 0
    drain(boundPlayer)
  end
  if elapsed - current.started >= trialDuration then api.stop('12s_window_complete') end
end)

registerForEvent('onShutdown', function() api.stop('CET_shutdown'); enabled = false end)
registerForEvent('onOverlayOpen', function() overlay = true end)
registerForEvent('onOverlayClose', function() overlay = false end)
registerHotkey('CH13FD_normal', 'CH13FD: arm Normal (manual)', function() api.arm('Normal') end)
registerHotkey('CH13FD_charged', 'CH13FD: arm Charged (manual)', function() api.arm('Charged') end)
registerHotkey('CH13FD_bolt', 'CH13FD: arm Bolt (manual)', function() api.arm('Bolt') end)
registerHotkey('CH13FD_stop', 'CH13FD: stop capture', function() api.stop('hotkey') end)
registerHotkey('CH13FD_marker', 'CH13FD: manual trigger reference (NOT engine fire event)', function() api.mark() end)

registerForEvent('onDraw', function()
  if not overlay then return end
  if ImGui.Begin('CHRONOS Task02 | Finale diagnostics') then
    ImGui.TextWrapped(status)
    ImGui.TextWrapped('Manual labels only. No native Bolt detection. One shot per trial.')
    if ImGui.Button('Arm Normal') then api.arm('Normal') end
    if ImGui.Button('Arm Charged') then api.arm('Charged') end
    if ImGui.Button('Arm Bolt (manual label)') then api.arm('Bolt') end
    if ImGui.Button('Manual trigger reference') then api.mark() end
    if ImGui.Button('Stop / flush trial') then api.stop('overlay') end
    ImGui.TextWrapped('Output: this mod folder / finale_diag.jsonl. Inspect trial_end for errors/drops.')
  end
  ImGui.End()
end)

return api
