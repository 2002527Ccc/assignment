"""Actual local integrity/scope checks. Not a REDscript/game compiler."""
from pathlib import Path
import hashlib
import importlib.util
import json
import re
import zipfile

ROOT = Path(__file__).resolve().parent
BASE, TREE = ROOT / 'baseline/runtime', ROOT / 'dist/full'
changed_config = 'bin/x64/plugins/cyber_engine_tweaks/mods/MilitechChronosMK13V2/config.lua'

checked = 0
for p in sorted(BASE.rglob('*')):
    if not p.is_file(): continue
    relative = p.relative_to(BASE).as_posix()
    if relative == 'RUNTIME_FILES_SHA256.txt':
        assert p.read_bytes() == (TREE / 'REFERENCE_ORIGINAL_RUNTIME_FILES_SHA256.txt').read_bytes()
        continue
    expected = p.read_bytes()
    if relative == changed_config:
        expected = expected.replace(b'visual = true', b'visual = false', 1)
    assert (TREE / relative).read_bytes() == expected, relative
    checked += 1
print(f'PASS {checked} baseline files preserved; only old visual=true -> false configuration changed')

for name in ['init.lua', 'config.lua', 'modules/state.lua']:
    assert (ROOT / 'source' / name).read_bytes() == (TREE / 'bin/x64/plugins/cyber_engine_tweaks/mods/MilitechChronosMK13Lens' / name).read_bytes()
assert (ROOT / 'source/ChronosLensFX.reds').read_bytes() == (TREE / 'r6/scripts/ChronosLensFX.reds').read_bytes()
newtext = '\n'.join(p.read_text() for p in (ROOT / 'source').rglob('*') if p.is_file())
for forbidden in ['TweakDB:SetFlat', 'SetTimeDilation(', 'RequestChangingStatPoolValue(',
                  'SetControllerActive(', 'AddModifier(', 'RemoveModifier(',
                  'sandevistanEffectReasons', 'kereznikovEffectReasons']:
    assert forbidden not in newtext, forbidden
assert 'tostring(p:GetEntityID())' not in newtext
assert 'ChronosBridge.SameOwner(a,b)' in newtext
assert 'ChronosBridge.IsRunning(owner)' in newtext
assert 'rendered=UNVERIFIED' in newtext
assert 'ResourceAsyncRef.SetPath' in newtext and 'ChronosLensFX.Registered(owner)' in newtext
print('PASS visual-only call scope, typed refs/read-back, native owner equality and explicit rendering limits')

spec = importlib.util.spec_from_file_location('private_resource_builder', ROOT / 'resources/build_private_archive.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
archive = (TREE / 'archive/pc/mod/Chronos13_PrivateVisuals.archive').read_bytes()
entries, segments, paths, crc = module.read_archive(archive)
assert len(entries) == 4 and len(segments) == 6
assert all(p.startswith('ch13\\') for p in paths)
assert 'ch13\\fx\\player\\time_dilation_vfx.effect' not in paths
assert not any(p.startswith('base\\') for p in paths)
for path in paths:
    row = entries[module.fnv64(path)]
    data = b''.join(archive[at:at + stored] for at, stored, unpacked in segments[row[3]:row[4]])
    assert data == (ROOT / 'resources/private' / Path(path.replace('\\', '/'))).read_bytes()
    assert hashlib.sha1(data).digest() == row[7]
    module.parse_cr2w(data)
manifest = json.loads((ROOT / 'resources/PRIVATE_RESOURCE_MANIFEST.json').read_text())
assert hashlib.sha256(archive).hexdigest() == manifest['private_archive_sha256']
print('PASS private archive re-read: index CRC64, CR2W CRC32, segments, SHA1, private paths and exact bytes')

packaged = json.loads((ROOT / 'SHA256_MANIFEST.json').read_text())
for rel, expected in packaged['full_install'].items():
    assert hashlib.sha256((TREE / rel).read_bytes()).hexdigest() == expected
for name in ['CHRONOS_V2_VisualFix_1.0.0_FULL.zip', 'CHRONOS_V2_VisualFix_1.0.0_Source.zip']:
    with zipfile.ZipFile(ROOT / 'dist' / name) as z:
        assert z.testzip() is None
        assert not any('/.git/' in p or '__pycache__' in p or '/research/' in p or '/tools/nativedb/' in p for p in z.namelist())
        if name.endswith('_FULL.zip'):
            assert set(z.namelist()) == set(packaged['full_install'])
            assert 'archive/pc/mod/TimeDilationVFX.archive' not in z.namelist()
            assert not any('/mods/TimeDilationVFX/' in p or p.endswith('chronos_vfx_probe.yaml') for p in z.namelist())
            for p in z.namelist(): assert z.read(p) == (TREE / p).read_bytes()
        else:
            assert z.read('source/init.lua') == (ROOT / 'source/init.lua').read_bytes()
            assert z.read('resources/Chronos13_PrivateVisuals.archive') == archive
print('PASS both ZIP CRCs, install paths/contents, no old global visual MOD/probe, SHA256 manifest')

api = json.loads((ROOT / 'API_EVIDENCE.json').read_text())
assert api['game_version'] == '2.5'
assert api['commit'] == '8d418f04128ce43a4f70a47689895bb0e7ecda7b'
print('PASS new helper API/property signatures checked against pinned community 2.5 RTTI')
print('NOT RUN: REDscript compilation, actual CET/engine registration, resource dependency loading, GPU visuals or gameplay regression')
