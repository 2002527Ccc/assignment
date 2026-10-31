"""Assemble full install/review ZIPs from preserved inputs and reviewed sources."""
from pathlib import Path
import difflib
import hashlib
import json
import shutil
import zipfile

ROOT = Path(__file__).resolve().parent
BASE = ROOT / 'baseline/runtime'
DIST = ROOT / 'dist'
TREE = DIST / 'full'
DIST.mkdir(exist_ok=True)
if TREE.exists():
    shutil.rmtree(TREE)  # Generated output only, never baseline/source/user checkout.
shutil.copytree(BASE, TREE)

relative = 'bin/x64/plugins/cyber_engine_tweaks/mods/MilitechChronosMK13V2/config.lua'
old = (BASE / relative).read_bytes()
assert old.count(b'visual = true') == 1
(TREE / relative).write_bytes(old.replace(b'visual = true', b'visual = false', 1))

lens = TREE / 'bin/x64/plugins/cyber_engine_tweaks/mods/MilitechChronosMK13Lens'
for name in ['init.lua', 'config.lua', 'modules/state.lua']:
    (lens / name).parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ROOT / 'source' / name, lens / name)
shutil.copyfile(ROOT / 'source/ChronosLensFX.reds', TREE / 'r6/scripts/ChronosLensFX.reds')
archive = TREE / 'archive/pc/mod/Chronos13_PrivateVisuals.archive'
archive.parent.mkdir(parents=True, exist_ok=True)
shutil.copyfile(ROOT / 'resources/Chronos13_PrivateVisuals.archive', archive)
shutil.copyfile(ROOT / 'README_安装与实机验证.md', TREE / '00_README_安装与实机验证.md')
shutil.copyfile(ROOT / '问题分析与修改范围.md', TREE / '问题分析与修改范围.md')

original_manifest = TREE / 'RUNTIME_FILES_SHA256.txt'
if original_manifest.exists():
    original_manifest.rename(TREE / 'REFERENCE_ORIGINAL_RUNTIME_FILES_SHA256.txt')

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

runtime_files = [p for p in sorted(TREE.rglob('*')) if p.is_file()]
(TREE / 'RUNTIME_FILES_SHA256.txt').write_text(''.join(sha(p) + '  ' + p.relative_to(TREE).as_posix() + '\n' for p in runtime_files))

diff = []
for p in sorted(TREE.rglob('*')):
    if not p.is_file() or p.suffix not in ['.lua', '.reds', '.yaml']:
        continue
    rel = p.relative_to(TREE).as_posix()
    oldpath = BASE / rel
    before = oldpath.read_text().splitlines(keepends=True) if oldpath.exists() else []
    diff.extend(difflib.unified_diff(before, p.read_text().splitlines(keepends=True),
        fromfile='baseline/' + rel if before else '/dev/null', tofile='visual-fix/' + rel))
(ROOT / 'CHRONOS_V2_VisualFix_1.0.0.diff').write_text(''.join(diff))

manifest = {
    'version': '1.0.0', 'game_compile_tested': False, 'render_tested': False,
    'baseline': {p.relative_to(BASE).as_posix(): sha(p) for p in sorted(BASE.rglob('*')) if p.is_file()},
    'full_install': {p.relative_to(TREE).as_posix(): sha(p) for p in sorted(TREE.rglob('*')) if p.is_file()},
    'reference_resource_source': 'User supplied TimeDilationVFX archive; isolated/edited private copies only.',
}
(ROOT / 'SHA256_MANIFEST.json').write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + '\n')

full_zip = DIST / 'CHRONOS_V2_VisualFix_1.0.0_FULL.zip'
with zipfile.ZipFile(full_zip, 'w', zipfile.ZIP_DEFLATED) as z:
    for p in sorted(TREE.rglob('*')):
        if p.is_file(): z.write(p, p.relative_to(TREE).as_posix())

source_zip = DIST / 'CHRONOS_V2_VisualFix_1.0.0_Source.zip'
with zipfile.ZipFile(source_zip, 'w', zipfile.ZIP_DEFLATED) as z:
    for folder in ['source', 'tests', 'baseline', 'resources/original', 'resources/private']:
        for p in sorted((ROOT / folder).rglob('*')):
            if p.is_file() and '__pycache__' not in p.parts: z.write(p, p.relative_to(ROOT).as_posix())
    for name in ['README_安装与实机验证.md', '问题分析与修改范围.md', 'VALIDATION.md',
                 'CHRONOS_V2_VisualFix_1.0.0.diff', 'SHA256_MANIFEST.json', 'API_EVIDENCE.json',
                 'SOURCE_TIMING_EVIDENCE.json',
                 'NATIVE_DB_LICENSE.txt', 'build_release.py', 'verify_release.py',
                 'resources/build_private_archive.py', 'resources/PRIVATE_RESOURCE_MANIFEST.json',
                 'resources/RESOURCE_ANALYSIS.md', 'resources/Chronos13_PrivateVisuals.archive']:
        z.write(ROOT / name, name)
print('Built complete install ZIP and source/review ZIP; no compile/render claim.')
