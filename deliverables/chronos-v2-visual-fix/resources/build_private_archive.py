#!/usr/bin/env python3
"""Build isolated CHRONOS resources from the supplied, previously decoded VFX.

No Oodle encoder is needed. CR2W object segments are stored uncompressed;
original external buffers keep their on-disk bytes and segment metadata.
Format algorithms follow WolvenKit 6ab5da88c009b99e653ce87be5251a9c5bd15330.
This validates resource structure; it is not a game load/render test.
"""
from pathlib import Path
import hashlib
import json
import struct
import zlib

ROOT = Path(__file__).resolve().parent
BASELINE = ROOT.parent / 'baseline/time/archive/pc/mod/TimeDilationVFX.archive'
DECODED = ROOT / 'original/base/fx/player'
PRIVATE = ROOT / 'private'
ARCHIVE = ROOT / 'Chronos13_PrivateVisuals.archive'
MASK = (1 << 64) - 1
WK_COMMIT = '6ab5da88c009b99e653ce87be5251a9c5bd15330'
TABLE_SIZES = (1, 8, 8, 16, 24, 24, 16, 0, 0, 0)
FILES = ('time_dilation_vfx_outlines.effect', 'time_dilation_vfx_outlines.particle',
         'time_dilation_vfx_radial_blur.effect', 'time_dilation_vfx_flash.effect')


def fnv64(path):
    value = 0xcbf29ce484222325
    for byte in path.encode('ascii'):
        value = ((value ^ byte) * 0x100000001b3) & MASK
    return value


def crc64(data):
    value = MASK
    for byte in data:
        value ^= byte
        for _ in range(8):
            value = (value >> 1) ^ (0xc96c5795d7870f42 if value & 1 else 0)
    return (~value) & MASK


def crc_header(data):
    header = bytearray(data[:160])
    struct.pack_into('<I', header, 32, 0xdeadbeef)
    return zlib.crc32(header)


def read_archive(data):
    magic, version, index, index_size, debug, debug_size, total = struct.unpack_from('<IIQIQIQ', data)
    assert magic == 0x52414452 and version == 12
    assert total == len(data)
    assert debug == debug_size == 0
    table_offset, table_size, expected = struct.unpack_from('<IIQ', data, index)
    assert table_offset == 8 and table_size == index_size - 8
    body = data[index + 16:index + index_size]
    assert crc64(body) == expected
    count, segment_count, dependencies = struct.unpack_from('<III', body)
    assert dependencies == 0  # Matches source archive and WolvenKit's disabled import index.
    pos, entries = 12, {}
    for _ in range(count):
        row = struct.unpack_from('<QQIIIII20s', body, pos)
        entries[row[0]] = row
        pos += 56
    segments = [struct.unpack_from('<QII', body, pos + i * 16) for i in range(segment_count)]
    assert pos + segment_count * 16 == len(body)
    for offset, size, unpacked in segments:
        assert offset >= 172 and offset + size <= index and size > 0 and unpacked > 0
    custom_size = struct.unpack_from('<Q', data, 40)[0]
    assert custom_size >= 20
    lxrs_magic, lxrs_version, size, stored, path_count = struct.unpack_from('<IIIII', data, 172)
    assert lxrs_magic == 0x4c585253 and lxrs_version == 1 and size == stored
    paths = data[192:192 + size].rstrip(b'\0').decode('ascii').split('\0')
    assert len(paths) == path_count == count and custom_size == size + 20
    assert set(map(fnv64, paths)) == set(entries)
    return entries, segments, paths, expected


def parse_cr2w(data):
    assert data[:4] == b'CR2W' and struct.unpack_from('<I', data, 4)[0] == 195
    objects_end, buffers_end = struct.unpack_from('<II', data, 24)
    assert buffers_end == len(data) and objects_end <= buffers_end
    assert struct.unpack_from('<I', data, 32)[0] == crc_header(data)
    tables = [struct.unpack_from('<III', data, 40 + 12 * i) for i in range(10)]
    for i, (offset, count, expected) in enumerate(tables):
        if count:
            assert TABLE_SIZES[i] and 160 <= offset <= objects_end
            table_bytes = data[offset:offset + count * TABLE_SIZES[i]]
            assert len(table_bytes) == count * TABLE_SIZES[i]
            assert zlib.crc32(table_bytes) == expected, ('table CRC', i)
    start, size, _ = tables[0]

    def string(offset):
        assert offset < size
        return data[start + offset:data.index(b'\0', start + offset)].decode('ascii')

    offset, count, _ = tables[1]
    names = [string(struct.unpack_from('<I', data, offset + i * 8)[0]) for i in range(count)]
    offset, count, _ = tables[2]
    imports = []
    for i in range(count):
        path, cls, flags = struct.unpack_from('<IHH', data, offset + 8 * i)
        imports.append({'path': string(path), 'class_index': cls, 'flags': flags})
    offset, count, _ = tables[4]
    exports = []
    for i in range(count):
        cls, flags, parent, size, at, template, crc = struct.unpack_from('<HHIIIII', data, offset + i * 24)
        assert at + size <= objects_end and cls < len(names)
        if crc:
            assert zlib.crc32(data[at:at + size]) == crc, ('export CRC', i)
        exports.append({'class': names[cls], 'offset': at, 'size': size, 'crc32': crc})
    offset, count, _ = tables[5]
    buffers = []
    for i in range(count):
        flags, index, at, stored, unpacked, expected = struct.unpack_from('<IIIIII', data, offset + i * 24)
        assert at >= objects_end and at + stored <= buffers_end
        assert zlib.crc32(data[at:at + stored]) == expected
        buffers.append({'offset': at, 'stored': stored, 'unpacked': unpacked, 'crc32': expected})
    return {'objects_end': objects_end, 'buffers_end': buffers_end, 'tables': tables,
            'imports': imports, 'exports': exports, 'buffers': buffers, 'names': names}


def scalar_properties(data, info, chunk_index):
    """Read the ordinary CR2W property prefix, not class-specific trailing data."""
    chunk = info['exports'][chunk_index]
    part = data[chunk['offset']:chunk['offset'] + chunk['size']]
    assert part[0] == 0
    pos, result = 1, {}
    while pos + 2 <= len(part):
        name = struct.unpack_from('<H', part, pos)[0]
        if name == 0:
            break
        kind, length = struct.unpack_from('<HI', part, pos + 2)
        value = part[pos + 8:pos + 4 + length]
        assert len(value) == length - 4 and name < len(info['names']) and kind < len(info['names'])
        name, kind = info['names'][name], info['names'][kind]
        item = {'type': kind, 'raw_hex': value.hex()}
        if kind == 'Float' and len(value) == 4:
            item['value'] = struct.unpack('<f', value)[0]
        result[name] = item
        pos += 4 + length
    return result


def canonical_original(name, source, entries, segments):
    decoded = (DECODED / name).read_bytes()
    row = entries[fnv64('base\\fx\\player\\' + name)]
    first, last = row[3:5]
    objects_end = struct.unpack_from('<I', decoded, 24)[0]
    assert objects_end == segments[first][2]
    # The persisted previous decode concatenated decoded buffer bytes. Reattach
    # the ORIGINAL stored external buffer bytes to match CR2W diskSize and CRC.
    body = decoded[:objects_end]
    for offset, stored, unpacked in segments[first + 1:last]:
        body += source[offset:offset + stored]
    parse_cr2w(body)
    return body, row[1]


def material_colors(data, info):
    """Locate named Color parameters by CMaterialInstance's documented appendix."""
    result = []
    for chunk_index, chunk in enumerate(info['exports']):
        if chunk['class'] != 'CMaterialInstance':
            continue
        start, end = chunk['offset'], chunk['offset'] + chunk['size']
        assert data[start] == 0
        pos = start + 1
        while struct.unpack_from('<H', data, pos)[0]:
            size = struct.unpack_from('<I', data, pos + 4)[0]
            assert size >= 4 and pos + size + 4 <= end
            pos += 4 + size
        pos += 2
        count = struct.unpack_from('<I', data, pos)[0]
        pos += 4
        for _ in range(count):
            size, name_index, type_index = struct.unpack_from('<IHH', data, pos)
            assert size >= 8 and pos + size <= end
            name, kind = info['names'][name_index], info['names'][type_index]
            if kind == 'Color':
                color_start, color_end = pos + 8, pos + size
                assert data[color_start] == 0
                cursor, channels, channel_offsets = color_start + 1, {}, {}
                while struct.unpack_from('<H', data, cursor)[0]:
                    ni, ti, length = struct.unpack_from('<HHI', data, cursor)
                    channel = info['names'][ni]
                    assert info['names'][ti] == 'Uint8' and length == 5
                    assert channel in ('Red', 'Green', 'Blue', 'Alpha') and channel not in channels
                    channels[channel] = data[cursor + 8]
                    channel_offsets[channel] = cursor + 8
                    cursor += 4 + length
                assert cursor + 2 == color_end
                assert set(channels) == {'Red', 'Green', 'Blue', 'Alpha'}
                result.append({'export_index': chunk_index, 'export_class': chunk['class'],
                               'parameter': name, 'parameter_type': kind,
                               'payload_offset': color_start, 'channel_offsets': channel_offsets,
                               'channels': channels})
            pos += size
        assert pos == end
    return result


def private_copy(data, filename):
    info = parse_cr2w(data)
    changed = bytearray(data)
    string_at, string_size, _ = info['tables'][0]
    strings = data[string_at:string_at + string_size]
    old = b'base\\fx\\player\\time_dilation_vfx_outlines.particle'
    new = b'ch13\\fx\\player\\time_dilation_vfx_outlines.particle'
    if old in strings:
        assert strings.count(old) == 1 and len(old) == len(new)
        strings = strings.replace(old, new)
        changed[string_at:string_at + string_size] = strings
        struct.pack_into('<I', changed, 48, zlib.crc32(strings))
        struct.pack_into('<I', changed, 32, crc_header(changed))
    modifications = []
    if filename == 'time_dilation_vfx_flash.effect':
        candidates = [color for color in material_colors(data, info) if color['parameter'] == 'Color']
        assert len(candidates) == 1
        color = candidates[0]
        assert color['channels'] == {'Red': 0, 'Green': 176, 'Blue': 240, 'Alpha': 255}
        for channel in ('Red', 'Green', 'Blue'):
            changed[color['channel_offsets'][channel]] = 143
        export_index = color['export_index']
        export = info['exports'][export_index]
        new_export_crc = zlib.crc32(changed[export['offset']:export['offset'] + export['size']])
        export_table_at, export_count, _ = info['tables'][4]
        struct.pack_into('<I', changed, export_table_at + export_index * 24 + 20, new_export_crc)
        struct.pack_into('<I', changed, 40 + 4 * 12 + 8,
                         zlib.crc32(changed[export_table_at:export_table_at + export_count * 24]))
        struct.pack_into('<I', changed, 32, crc_header(changed))
        allowed = set(color['channel_offsets'][channel] for channel in ('Red', 'Green', 'Blue'))
        allowed.update(range(32, 36))
        allowed.update(range(40 + 4 * 12 + 8, 40 + 4 * 12 + 12))
        allowed.update(range(export_table_at + export_index * 24 + 20,
                             export_table_at + export_index * 24 + 24))
        differences = [at for at, (before, after) in enumerate(zip(data, changed)) if before != after]
        assert set(differences).issubset(allowed)
        modifications.append({**color, 'channels_before': color['channels'],
                              'channels_after': {'Red': 143, 'Green': 143, 'Blue': 143, 'Alpha': 255},
                              'export_crc32_before': export['crc32'],
                              'export_crc32_after': new_export_crc,
                              'changed_byte_offsets_including_checksums': differences,
                              'reason': 'Neutral RGB candidate only; actual shader/color rendering unverified.'})
    result = bytes(changed)
    new_info = parse_cr2w(result)
    if filename == 'time_dilation_vfx_flash.effect':
        assert scalar_properties(data, info, 0) == scalar_properties(result, new_info, 0)
        assert scalar_properties(data, info, 1) == scalar_properties(result, new_info, 1)
    # No import except the self-contained outlines particle is rewritten.
    assert len(result) == len(data)
    return result, modifications


def main():
    assert crc64(b'123456789') == 0x995dc9bbdf1939fa
    source = BASELINE.read_bytes()
    entries, segments, source_paths, source_crc = read_archive(source)
    assert source_crc == 0xe90496dc756b7e92
    PRIVATE.mkdir(parents=True, exist_ok=True)
    files, manifest = [], {
        'format_source': {'repository': 'https://github.com/WolvenKit/WolvenKit', 'commit': WK_COMMIT},
        'original_archive_sha256': hashlib.sha256(source).hexdigest(),
        'original_index_crc64_recalculated': f'{source_crc:016x}',
        'game_load_or_render_verified': False,
        'files': [],
    }
    for name in FILES:
        original, timestamp = canonical_original(name, source, entries, segments)
        body, modifications = private_copy(original, name)
        path = 'ch13\\fx\\player\\' + name
        target = PRIVATE / path.replace('\\', '/')
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(body)
        info = parse_cr2w(body)
        assert not any(x['class'] in ['effectTrackItemColorGrade', 'effectTrackItemColorGradeV2'] for x in info['exports'])
        files.append((fnv64(path), path, body, timestamp, info))
        item = {
            'path': path, 'fnv1a64': f'{fnv64(path):016x}',
            'canonical_original_size': len(original), 'private_size': len(body),
            'canonical_original_sha256': hashlib.sha256(original).hexdigest(),
            'private_sha256': hashlib.sha256(body).hexdigest(),
            'modified': original != body,
            'material_color_modifications': modifications,
            'exports': [x['class'] for x in info['exports']], 'imports': info['imports'],
            'buffers': info['buffers'],
            'root_properties': scalar_properties(body, info, 0),
        }
        if name.endswith('.effect'):
            item['particle_event_properties'] = scalar_properties(body, info, 1)
        if 'CMaterialInstance' in item['exports']:
            item['material_colors'] = material_colors(body, info)
        manifest['files'].append(item)
    files.sort()
    paths = b''.join(path.encode('ascii') + b'\0' for _, path, _, _, _ in files)
    custom = struct.pack('<IIIII', 0x4c585253, 1, len(paths), len(paths), len(files)) + paths
    archive = bytearray(172) + custom
    packed_entries, packed_segments = [], []
    for key, path, body, timestamp, info in files:
        first = len(packed_segments)
        objects = body[:info['objects_end']]
        packed_segments.append((len(archive), len(objects), len(objects)))
        archive.extend(objects)
        for buffer in info['buffers']:
            raw = body[buffer['offset']:buffer['offset'] + buffer['stored']]
            packed_segments.append((len(archive), buffer['stored'], buffer['unpacked']))
            archive.extend(raw)
        packed_entries.append((key, timestamp, 0, first, len(packed_segments), 0, 0, hashlib.sha1(body).digest()))
    archive.extend(bytes((-len(archive)) % 4096))
    index_at = len(archive)
    index_body = struct.pack('<III', len(packed_entries), len(packed_segments), 0)
    index_body += b''.join(struct.pack('<QQIIIII20s', *row) for row in packed_entries)
    index_body += b''.join(struct.pack('<QII', *row) for row in packed_segments)
    index = struct.pack('<IIQ', 8, len(index_body) + 8, crc64(index_body)) + index_body
    archive.extend(index)
    archive.extend(bytes((-len(archive)) % 4096))
    struct.pack_into('<IIQIQIQ', archive, 0, 0x52414452, 12, index_at, len(index), 0, 0, len(archive))
    struct.pack_into('<Q', archive, 40, len(custom))
    ARCHIVE.write_bytes(archive)

    # Re-read the actual emitted archive rather than trusting builder objects.
    actual = ARCHIVE.read_bytes()
    new_entries, new_segments, new_paths, new_crc = read_archive(actual)
    assert len(new_entries) == len(files) == 4 and len(new_segments) == 6
    assert all(path.startswith('ch13\\') for path in new_paths)
    assert not set(new_entries).intersection(entries)
    for key, path, expected, timestamp, info in files:
        row = new_entries[key]
        reconstructed = b''.join(actual[at:at + stored] for at, stored, unpacked in new_segments[row[3]:row[4]])
        assert reconstructed == expected
        assert row[7] == hashlib.sha1(reconstructed).digest()
        parsed = parse_cr2w(reconstructed)
        for dependency in parsed['imports']:
            if dependency['path'].startswith('ch13\\'):
                assert fnv64(dependency['path']) in new_entries
            else:
                assert dependency['path'] in [d['path'] for d in info['imports']]
    manifest['private_archive_sha256'] = hashlib.sha256(actual).hexdigest()
    manifest['private_archive_size'] = len(actual)
    manifest['private_index_crc64'] = f'{new_crc:016x}'
    manifest['validation'] = [
        'Original archive index CRC64 recalculates exactly.',
        'Original canonical CR2W header/table/buffer CRC32 values all match.',
        'Private CR2W header/table/buffer CRC32 values all match.',
        'Private archive index, bounds, segments, SHA1 and reconstructed bytes all match.',
        'No original archive depot hash remains; private outlines particle dependency resolves.',
        'No ColorGrade export in included effects; flash timing and strengths unchanged.',
        'Flash Color parameter structurally located and changed only from RGBA(0,176,240,255) to (143,143,143,255).',
    ]
    (ROOT / 'PRIVATE_RESOURCE_MANIFEST.json').write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + '\n')
    print(f'Built {ARCHIVE.name}: {len(actual)} bytes, 4 private files, 6 segments. Structural validation passed; game load/render NOT tested.')


if __name__ == '__main__':
    main()
