"""Package the reviewed diagnostic tree; never rebuild or alter old releases."""
from pathlib import Path
import difflib
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parent
OLD = ROOT.parent
NEW = ROOT / 'v0.1.1'
PATCH = NEW / 'patch'

(PATCH / 'README_CH13_TASK02.md').write_bytes((NEW / 'README_zh.md').read_bytes())
changes = []
for p in sorted(PATCH.rglob('*')):
    if not p.is_file():
        continue
    relative = p.relative_to(PATCH).as_posix()
    before = (OLD / 'patch' / relative).read_text().splitlines(keepends=True)
    after = p.read_text().splitlines(keepends=True)
    changes.extend(difflib.unified_diff(before, after, fromfile='v0.1.0/' + relative, tofile='v0.1.1/' + relative))
(ROOT / 'Task02_V0.1.0_to_V0.1.1.diff').write_text(''.join(changes))

def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

manifest = {
    'diagnostic_version': '0.1.1',
    'formal_mod_changed': False,
    'game_compiled': False,
    'old_zip_sha256': {p.name: digest(p) for p in sorted(OLD.glob('*.zip'))},
    'patch': {p.relative_to(PATCH).as_posix(): digest(p) for p in sorted(PATCH.rglob('*')) if p.is_file()},
    'source': {p.relative_to(NEW / 'source').as_posix(): digest(p) for p in sorted((NEW / 'source').rglob('*')) if p.is_file()},
    'evidence_sha256': digest(ROOT / 'NATIVE_API_EVIDENCE.json'),
}
(ROOT / 'SHA256_V0.1.1.json').write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + '\n')

target = ROOT / 'CHRONOS_TASK02_FinaleHitDiagnostics_V0.1.1.zip'
with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED) as z:
    for p in sorted(PATCH.rglob('*')):
        if p.is_file():
            z.write(p, p.relative_to(PATCH).as_posix())

target = ROOT / 'CHRONOS_TASK02_BoltInvestigation_V0.1.1_Source_and_Review.zip'
with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED) as z:
    for p in sorted(NEW.rglob('*')):
        if p.is_file():
            z.write(p, 'v0.1.1/' + p.relative_to(NEW).as_posix())
    for name in ['BOLT_INVESTIGATION_zh.md', 'NATIVE_API_EVIDENCE.json', 'NATIVE_DB_LICENSE.txt',
                 'Task02_V0.1.0_to_V0.1.1.diff', 'SHA256_V0.1.1.json', 'VALIDATION_V0.1.1.md',
                 'package_diagnostics.py', 'verify_diagnostics.py']:
        z.write(ROOT / name, name)
print('Packaged diagnostic v0.1.1 and source/review ZIP; no old release or formal mod rebuilt.')
