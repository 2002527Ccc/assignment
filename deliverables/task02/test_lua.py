"""Exercise Lua control flow using liblua5.4 and stubbed CET/REDscript APIs.

This checks Lua syntax and diagnostic lifecycle/serialization, NOT actual game APIs.
No generated sample observations are shipped as real game logs.
"""
from pathlib import Path
import ctypes
import ctypes.util
import json
import os
import tempfile

ROOT = Path(__file__).resolve().parent
lua = ctypes.CDLL(ctypes.util.find_library('lua5.4'))
lua.luaL_newstate.restype = ctypes.c_void_p
lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
lua.luaL_loadstring.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
lua.luaL_loadstring.restype = ctypes.c_int
lua.lua_pcallk.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_longlong, ctypes.c_void_p]
lua.lua_pcallk.restype = ctypes.c_int
lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
lua.lua_tolstring.restype = ctypes.c_char_p
lua.lua_close.argtypes = [ctypes.c_void_p]

source = (ROOT / 'source/init.lua').as_posix()
harness = r'''
local handlers, hotkeys, observations = {}, {}, {}
function registerForEvent(name, fn) handlers[name] = fn end
function registerHotkey(name, desc, fn) hotkeys[name] = fn end
print = function(line) observations[#observations+1] = line end
CName = {new=function(name) return name end}
TweakDBID = {new=function(id, suffix) return id .. suffix end}
TweakDB = {GetFlat=function(self, id)
  if id == 'Attacks.TestNormal.hitFlags' then return false end
  if id == 'Attacks.TestNormal.attackType' then return 'Ranged' end
  return nil
end}
local function record(id)
  return {GetID=function(self) return id end}
end
local normal = record('Attacks.TestNormal')
local packageRecord = record('Packages.Test')
packageRecord.DefaultFire = function(self) return normal end
local function entity(id) return {GetEntityID=function() return id end} end
local player = nil
Game = {GetPlayer=function() return player end}
CH13Bridge = {IsNativeActive=function() return false end}
local bridgeAvailable = true
CH13FD = {Drain=function(p)
  if not bridgeAvailable then error('MOCK missing REDscript bridge') end
  local rows = p.queue or {}; p.queue = {}; return rows
end}
local api = assert(loadfile(SOURCE_FILE))()
assert(type(api.arm) == 'function')
assert(api.arm('Normal') == false)
handlers.onInit()
assert(api.arm('Normal') == false) -- no save loaded
player = entity('Player1')
bridgeAvailable = false
assert(api.arm('Normal') == false)
assert(player.m_ch13FDEnabled == false)
bridgeAvailable = true
assert(api.arm('wrong-label') == false)

local function event(kind, extra)
  local row = {kind=kind, trial=player.m_ch13FDTrial, simTime=0.001,
    weaponID='Items.Finale', weapon=entity('Finale1'), owner=player,
    target=nil, charge=0, attackType=0, canExecute=false,
    uploadPresent=false, uploadProgress=0, normalMark=false, bossMark=false}
  for k,v in pairs(extra or {}) do row[k]=v end
  return row
end

assert(api.arm('Normal') == true)
api.mark('quote" backslash\\ newline\n中文')
player.queue = {
 event('selection', {attack=normal, attackPackage=packageRecord}),
 event('projectile_initialize', {entity=entity('Projectile1'), hookClass='sampleBullet', startVelocity=700, lifetime=3}),
 event('blackwall_hit_before', {target=entity('Target1'), charge=0, attackType=1, canExecute=true}),
 event('blackwall_hit_after', {target=entity('Target1'), charge=0, attackType=1, canExecute=true})
}
handlers.onUpdate(0.11)
api.stop('mock normal complete')
assert(player.m_ch13FDEnabled == false)

assert(api.arm('Charged') == true)
player.queue = {
 event('selection'), -- nil attack and package must not crash
 event('blackwall_hit_before', {target=entity('Target2'), charge=1, attackType=1, canExecute=true}),
 event('blackwall_hit_after', {target=entity('Target2'), charge=1, attackType=1, canExecute=true, uploadPresent=true, normalMark=true, uploadProgress=0})
}
api.stop('mock charged complete') -- stop must drain without waiting for onUpdate

assert(api.arm('Bolt') == true)
handlers.onUpdate(12.1) -- timeout must stop and disarm even with zero observations
assert(player.m_ch13FDEnabled == false)

assert(api.arm('Normal') == true)
bridgeAvailable = false
handlers.onUpdate(0.11)
handlers.onUpdate(0.11) -- only one drain error per active trial
api.stop('mock bridge failure')
bridgeAvailable = true

assert(api.arm('Normal') == true)
local oldPlayer = player
player = entity('Player2'); player.m_ch13FDEnabled = true
handlers.onUpdate(0.11)
assert(oldPlayer.m_ch13FDEnabled == false)
assert(player.m_ch13FDEnabled == false) -- stale serialized flag must not resume capture
assert(api.arm('Normal') == true)
handlers.onShutdown()
assert(player.m_ch13FDEnabled == false)

-- File I/O failure keeps console logging alive and does not abort a trial.
handlers.onInit()
local originalOpen = io.open
io.open = function() return nil, 'MOCK disk unavailable' end
assert(api.arm('Normal') == true)
api.stop('mock I/O failure')
io.open = originalOpen
assert(#observations > 15)
'''.replace('SOURCE_FILE', json.dumps(source))

with tempfile.TemporaryDirectory(prefix='ch13fd-lua-') as temp:
    previous = os.getcwd()
    os.chdir(temp)
    state = lua.luaL_newstate()
    try:
        lua.luaL_openlibs(state)
        result = lua.luaL_loadstring(state, harness.encode())
        if result == 0:
            result = lua.lua_pcallk(state, 0, 0, 0, 0, None)
        if result:
            raise RuntimeError(lua.lua_tolstring(state, -1, None).decode())
        rows = [json.loads(line) for line in Path('finale_diag.jsonl').read_text().splitlines()]
    finally:
        lua.lua_close(state)
        os.chdir(previous)

assert all(row['session'] and isinstance(row['seq'], int) for row in rows)
assert [r['seq'] for r in rows] == sorted(set(r['seq'] for r in rows))
trials = [r for r in rows if r['event'] == 'trial_begin']
assert [r['manual_label'] for r in trials[:3]] == ['Normal', 'Charged', 'Bolt']
assert len({r['trial'] for r in trials[:3]}) == 3
assert all(r['label_is_native_bolt_detection'] is False for r in trials)
engine = [r for r in rows if r['event'] == 'engine_observation']
selection = next(r for r in engine if r['engine_event_kind'] == 'selection' and r['trial'] == 1)
assert selection['original_attack']['id'] == 'Attacks.TestNormal'
assert selection['attack_flats']['hitFlags'] is False
assert selection['attack_flats']['projectileTemplate'] == 'UNAVAILABLE'
nil_selection = next(r for r in engine if r['engine_event_kind'] == 'selection' and r['trial'] == 2)
assert nil_selection['original_attack']['present'] is False
assert nil_selection['default_fire']['present'] is False
charged = [r for r in engine if r['trial'] == 2 and r['engine_event_kind'].startswith('blackwall')]
assert len(charged) == 2 and charged[0]['hit_weapon_charge'] == 1
assert charged[0]['upload_present'] is False and charged[1]['upload_present'] is True
assert any(r['event'] == 'trial_end' and r['reason'] == '12s_window_complete' for r in rows)
assert all(r['no_projectile_observed_means_hitscan'] is False for r in rows if r['event'] == 'trial_end')
assert len([r for r in rows if r['event'] == 'telemetry_error' and r['stage'] == 'Drain']) == 1
assert not [r for r in rows if r['event'] == 'telemetry_error' and r['stage'] == 'serialize']
marker = next(r for r in rows if r['event'] == 'manual_marker')
assert marker['is_engine_fire_event'] is False and '中文' in marker['note']
print('PASS Lua 5.4 parse and mocked CET lifecycle: manual trials, selection/projectile/hit serialization, stop drain, timeout, player change, missing bridge and failed file I/O')
print('PASS JSONL parsing, unique trial/event IDs, false/missing fields, charge and before/after state preservation')
print('NOT VALIDATED: actual CET LuaJIT/RTTI or REDscript/game integration; mock data is not game evidence')
