"""Run Lua-only mock tests with system liblua5.4; not an actual CET/game host."""
from pathlib import Path
import ctypes
import ctypes.util
import json
import sys

root = Path(__file__).resolve().parents[1]
library = ctypes.util.find_library('lua5.4')
if not library:
    raise SystemExit('System liblua5.4 is required for this mock runner.')
lua = ctypes.CDLL(library)
lua.luaL_newstate.restype = ctypes.c_void_p
lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
lua.luaL_loadstring.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
lua.luaL_loadstring.restype = ctypes.c_int
lua.lua_pcallk.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_longlong, ctypes.c_void_p]
lua.lua_pcallk.restype = ctypes.c_int
lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
lua.lua_tolstring.restype = ctypes.c_char_p
lua.lua_close.argtypes = [ctypes.c_void_p]

tests = sys.argv[1:] or ['test_state.lua', 'test_glue.lua']
for test in tests:
    program = (
        'arg = {[1] = ' + json.dumps(str(root / 'source/modules/state.lua'))
        + ', [2] = ' + json.dumps(str(root)) + '}\n'
        'assert(loadfile(' + json.dumps(str(root / 'tests' / test)) + '))()\n'
    )
    state = lua.luaL_newstate()
    try:
        lua.luaL_openlibs(state)
        result = lua.luaL_loadstring(state, program.encode('utf-8'))
        if result == 0:
            result = lua.lua_pcallk(state, 0, 0, 0, 0, None)
        if result:
            message = lua.lua_tolstring(state, -1, None)
            raise SystemExit(message.decode('utf-8', errors='replace') if message else 'Lua error')
    finally:
        lua.lua_close(state)
