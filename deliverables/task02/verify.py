"""Structural safety audit only. This is NOT a REDscript compiler."""
from pathlib import Path
import argparse
import ast
import hashlib
import json
import re
import zipfile

ROOT = Path(__file__).resolve().parent
parser = argparse.ArgumentParser()
parser.add_argument('--chronos-base', type=Path, default=Path('/tmp/mod-analysis/chronos'))
parser.add_argument('--finale-base', type=Path, default=Path('/tmp/mod-analysis/finale'))
args = parser.parse_args()
BASE, FINALE = args.chronos_base.resolve(), args.finale_base.resolve()
PATCH = ROOT / 'patch'
manifest = json.loads((ROOT / 'SHA256_MANIFEST.json').read_text())

for section, folder in [('baseline', BASE), ('finale_reference', FINALE), ('patch', PATCH)]:
    for rel, expected in manifest[section].items():
        assert hashlib.sha256((folder / rel).read_bytes()).hexdigest() == expected, (section, rel)
print('PASS baseline/Finale inputs and patch hashes match manifest')

rel = 'r6/scripts/Chronos13/CH13HitscanConversion.reds'
base, patched = (BASE / rel).read_text(), (PATCH / rel).read_text()
# Remove only the specifically delimited telemetry insertion; byte-for-byte base must remain.
start = patched.index('  // TASK02: passive capture')
end = patched.index('  if !IsDefined(original)', start)
assert patched[:start] + patched[end:] == base
assert patched.count('@wrapMethod(WeaponTransition)') == 1
assert patched.count('wrappedMethod(stateContext, scriptInterface)') == 1
print('PASS attack-selection original body and return paths preserved exactly')

rel = 'r6/scripts/Chronos13/CH13Projectiles.reds'
base, patched = (BASE / rel).read_text(), (PATCH / rel).read_text()
recovered = re.sub(
    r'  // TASK02: initialization telemetry only; no trajectory or lifecycle changes\.\n'
    r'  if this\.m_ch13OwnerV && player\.m_ch13FDEnabled \{\n'
    r'    CH13FD\.Projectile\([^\n]+\);\n  \}\n', '', patched)
assert recovered == base
assert patched.count('wrappedMethod(eventData)') == base.count('wrappedMethod(eventData)')
print('PASS original projectile initialization/tick/freeze/thaw body preserved exactly')

reds = list(PATCH.rglob('*.reds'))
newreds = list((PATCH / 'r6/scripts/CH13FinaleDiagnostics').glob('*.reds'))
text = '\n'.join(p.read_text() for p in newreds)
for forbidden in [r'\bSetFlat\s*\(', r'\bUpdateRecord\s*\(', r'\bApplyStatusEffect\s*\(',
                  r'\bRequestChangingStatPoolValue\s*\(', r'\bClearTrajectories\s*\(',
                  r'\bAddLinear\s*\(', r'\bStartAttack\s*\(', r'\bProcessRPGAction\s*\(']:
    assert not re.search(forbidden, text), forbidden
wrappers = []
for p in reds:
    for cls, method in re.findall(r'@wrapMethod\(([^)]+)\)\s*(?:protected|public|private)\s+(?:final\s+)?(?:cb\s+)?func\s+(\w+)', p.read_text()):
        wrappers.append((cls, method))
assert len(wrappers) == len(set(wrappers)), wrappers
hit = (PATCH / 'r6/scripts/CH13FinaleDiagnostics/CH13FinaleHitDiagnostics.reds').read_text()
assert hit.count('wrappedMethod(owner);') == 1
sig = 'protected func RepeatedAction(owner: ref<GameObject>) -> Void'
assert sig in hit and sig in (FINALE / 'r6/scripts/OneEyedTech/OneEyedTech.reds').read_text()
assert '@wrapMethod(OET_UploadHitEffector)' in hit
print('PASS no duplicate wrapper targets in installed patch; Finale effector signature matches input')
print('PASS new telemetry has no attack, trajectory, status-effect or damage mutator calls')

assert not list(PATCH.rglob('*.yaml')) and not list(PATCH.rglob('*.archive'))
assert not list(PATCH.rglob('OneEyedTech.reds'))
assert not (PATCH / 'bin/x64/plugins/cyber_engine_tweaks/mods/Chronos13').exists()
expected = {
 'r6/scripts/Chronos13/CH13HitscanConversion.reds',
 'r6/scripts/Chronos13/CH13Projectiles.reds',
 'r6/scripts/CH13FinaleDiagnostics/CH13FinaleDiagnostics.reds',
 'r6/scripts/CH13FinaleDiagnostics/CH13FinaleHitDiagnostics.reds',
 'bin/x64/plugins/cyber_engine_tweaks/mods/CH13FinaleDiagnostics/init.lua',
 'README_CH13_TASK02.md'
}
with zipfile.ZipFile(ROOT / 'CHRONOS_TASK02_FinaleDiagnostics_V0.1.0.zip') as z:
    assert z.testzip() is None
    assert set(z.namelist()) == expected
    for name in z.namelist():
        assert z.read(name) == (PATCH / name).read_bytes()
print('PASS Vortex ZIP CRC, exact install paths and content; no Finale/resource/core CET changes')
ast.parse((ROOT / 'build.py').read_text())
print('NOT RUN: REDscript compilation, actual CET integration, game 2.5 or Vortex deployment')
