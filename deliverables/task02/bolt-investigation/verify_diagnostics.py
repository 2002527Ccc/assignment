"""Safety/packaging audit; not a REDscript compiler or game test."""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parent
OLD = ROOT.parent
NEW = ROOT / 'v0.1.1'
PATCH = NEW / 'patch'

for relative in ['r6/scripts/Chronos13/CH13HitscanConversion.reds', 'r6/scripts/Chronos13/CH13Projectiles.reds']:
    assert (PATCH / relative).read_bytes() == (OLD / 'patch' / relative).read_bytes()
print('PASS existing CHRONOS selection/conversion/projectile code is byte-identical to v0.1.0')

diagnostics = 'r6/scripts/CH13FinaleDiagnostics/'
for name in ['CH13FinaleDiagnostics.reds', 'CH13FinaleHitDiagnostics.reds']:
    assert (NEW / 'source' / name).read_bytes() == (PATCH / diagnostics / name).read_bytes()
assert (NEW / 'source/init.lua').read_bytes() == (PATCH / 'bin/x64/plugins/cyber_engine_tweaks/mods/CH13FinaleDiagnostics/init.lua').read_bytes()

hit = (NEW / 'source/CH13FinaleHitDiagnostics.reds').read_text()
oldhit = (OLD / 'source/CH13FinaleHitDiagnostics.reds').read_text()
inserted = (
    '    // Same read API used by the supplied Finale V6.2; runtime availability still needs testing.\n'
    '    entry.perfectlyCharged = hit.attackData.HasFlag(hitFlag.PerfectlyCharged);\n'
    '    entry.isRanged = Equals(hit.attackData.GetAttackType(), gamedataAttackType.Ranged);\n'
)
assert inserted in hit and hit.replace(inserted, '', 1) == oldhit
assert hit.count('wrappedMethod(owner);') == 1
assert hit.count('@wrapMethod(') == oldhit.count('@wrapMethod(') == 1
assert 'protected func RepeatedAction(owner: ref<GameObject>) -> Void' in hit
for forbidden in ['SetFlat(', 'ApplyStatusEffect(', 'RequestChangingStatPoolValue(', 'StartAttack(', 'ClearTrajectories(']:
    assert forbidden not in hit
print('PASS only read-only hit snapshots added; effector signature/wrapper/call count unchanged')

event = (NEW / 'source/CH13FinaleDiagnostics.reds').read_text()
inserted = (
    '  // Hit-context snapshots only. PerfectlyCharged is not asserted to identify Bolt.\n'
    '  public let perfectlyCharged: Bool;\n'
    '  public let isRanged: Bool;\n'
)
assert inserted in event and event.replace(inserted, '', 1) == (OLD / 'source/CH13FinaleDiagnostics.reds').read_text()
print('PASS event/queue behavior unchanged except two diagnostic Bool fields')

manifest = json.loads((ROOT / 'SHA256_V0.1.1.json').read_text())
for section, folder in [('patch', PATCH), ('source', NEW / 'source')]:
    for relative, expected in manifest[section].items():
        assert hashlib.sha256((folder / relative).read_bytes()).hexdigest() == expected
for name, expected in manifest['old_zip_sha256'].items():
    assert hashlib.sha256((OLD / name).read_bytes()).hexdigest() == expected

with zipfile.ZipFile(ROOT / 'CHRONOS_TASK02_FinaleHitDiagnostics_V0.1.1.zip') as z:
    assert z.testzip() is None
    assert set(z.namelist()) == {p.relative_to(PATCH).as_posix() for p in PATCH.rglob('*') if p.is_file()}
    assert len(z.namelist()) == 6
    assert not any(name.endswith(('.yaml', '.archive', '.xl')) for name in z.namelist())
    assert not any('/OneEyedTech/' in name or '/mods/Chronos13/' in name for name in z.namelist())
    for name in z.namelist():
        assert z.read(name) == (PATCH / name).read_bytes()
with zipfile.ZipFile(ROOT / 'CHRONOS_TASK02_BoltInvestigation_V0.1.1_Source_and_Review.zip') as z:
    assert z.testzip() is None
    assert z.read('NATIVE_API_EVIDENCE.json') == (ROOT / 'NATIVE_API_EVIDENCE.json').read_bytes()
print('PASS both ZIP CRC/content; no formal Finale file, resources or old CHRONOS CET included')

# Before commit, prove all existing tracked deliverables still match the original
# Task02 published commit. New investigation files are outside that frozen list.
repo = subprocess.run(['git', 'rev-parse', '--show-toplevel'], cwd=ROOT, text=True, capture_output=True, check=True).stdout.strip()
paths = subprocess.run(['git','ls-tree','-r','--name-only','f59e150','--','deliverables/task02'],cwd=repo,text=True,capture_output=True,check=True).stdout.splitlines()
for path in paths:
    before = subprocess.run(['git','show','f59e150:' + path],cwd=repo,capture_output=True,check=True).stdout
    assert before == (Path(repo) / path).read_bytes(), path
print(f'PASS all {len(paths)} original published Task02 files preserved byte-for-byte')
print('NOT RUN: actual REDscript compilation, CET/game-host integration or gameplay regression')
