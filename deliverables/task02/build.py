from pathlib import Path
import argparse
import difflib
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parent
parser = argparse.ArgumentParser()
parser.add_argument('--chronos-base', type=Path, default=Path('/tmp/mod-analysis/chronos'))
parser.add_argument('--finale-base', type=Path, default=Path('/tmp/mod-analysis/finale'))
args = parser.parse_args()
BASE, FINALE = args.chronos_base.resolve(), args.finale_base.resolve()
PATCH = ROOT / 'patch'

def write(relative, text):
    p = PATCH / relative
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text, encoding='utf-8')

selection = 'r6/scripts/Chronos13/CH13HitscanConversion.reds'
original = (BASE / selection).read_text()
needle = '  let original: ref<Attack_Record> = wrappedMethod(stateContext, scriptInterface);\n'
addition = '''  // TASK02: passive capture before the original Power/active filters.
  // Selection is NOT a confirmed discharge. The original return paths remain intact.
  let diagPlayer: ref<PlayerPuppet> = scriptInterface.executionOwner as PlayerPuppet;
  if IsDefined(diagPlayer) && diagPlayer.m_ch13FDEnabled {
    CH13FD.Selection(diagPlayer, this.GetWeaponObject(scriptInterface), original, this.m_rangedAttackPackage);
  }
'''
assert original.count(needle) == 1
write(selection, original.replace(needle, needle + addition))

projectiles = 'r6/scripts/Chronos13/CH13Projectiles.reds'
original = (BASE / projectiles).read_text()
needle = '  this.m_ch13EverFrozen = false;\n  return r;'
assert original.count(needle) == 2
for cls in ('sampleBullet', 'sampleBulletGeneric'):
    addition = f'''  this.m_ch13EverFrozen = false;
  // TASK02: initialization telemetry only; no trajectory or lifecycle changes.
  if this.m_ch13OwnerV && player.m_ch13FDEnabled {{
    CH13FD.Projectile(player, this, eventData.owner, this.m_startVelocity, this.m_lifetime, n"{cls}");
  }}
  return r;'''
    original = original.replace(needle, addition, 1)
write(projectiles, original)

for name in ('CH13FinaleDiagnostics.reds', 'CH13FinaleHitDiagnostics.reds'):
    write('r6/scripts/CH13FinaleDiagnostics/' + name, (ROOT / 'source' / name).read_text())
write('bin/x64/plugins/cyber_engine_tweaks/mods/CH13FinaleDiagnostics/init.lua', (ROOT / 'source/init.lua').read_text())
write('README_CH13_TASK02.md', (ROOT / 'README_zh.md').read_text())

diff = []
for p in sorted(PATCH.rglob('*')):
    if not p.is_file():
        continue
    rel = p.relative_to(PATCH).as_posix()
    before = (BASE / rel).read_text().splitlines(keepends=True) if (BASE / rel).is_file() else []
    diff.extend(difflib.unified_diff(before, p.read_text().splitlines(keepends=True),
                                     fromfile='a/' + rel if before else '/dev/null', tofile='b/' + rel))
(ROOT / 'CHRONOS_V032_to_TASK02.diff').write_text(''.join(diff))

# These source inputs are references for reproducibility, never installed by the patch ZIP.
manifest = {'baseline': {}, 'finale_reference': {}, 'patch': {}}
for section, folder in [('baseline', BASE), ('finale_reference', FINALE), ('patch', PATCH)]:
    for p in sorted(folder.rglob('*')):
        if p.is_file():
            manifest[section][p.relative_to(folder).as_posix()] = hashlib.sha256(p.read_bytes()).hexdigest()
(ROOT / 'SHA256_MANIFEST.json').write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + '\n')

def archive(target, folder, prefix=''):
    with zipfile.ZipFile(target, 'w', compression=zipfile.ZIP_DEFLATED) as z:
        for p in sorted(folder.rglob('*')):
            if p.is_file():
                z.write(p, prefix + p.relative_to(folder).as_posix())

archive(ROOT / 'CHRONOS_TASK02_FinaleDiagnostics_V0.1.0.zip', PATCH)
with zipfile.ZipFile(ROOT / 'CHRONOS_TASK02_Source_and_Review.zip', 'w', zipfile.ZIP_DEFLATED) as z:
    for p in sorted(PATCH.rglob('*')):
        if p.is_file():
            z.write(p, 'install_tree/' + p.relative_to(PATCH).as_posix())
    for p in sorted((ROOT / 'source').rglob('*')):
        if p.is_file():
            z.write(p, 'source/' + p.relative_to(ROOT / 'source').as_posix())
    for name in ['build.py', 'README_zh.md', 'CHRONOS_V032_to_TASK02.diff', 'SHA256_MANIFEST.json', 'VALIDATION.md', 'verify.py', 'test_lua.py']:
        p = ROOT / name
        if p.exists():
            z.write(p, name)
print('Built installable patch, source bundle, diff and SHA256 manifest.')
