# CHRONOS private visual resource analysis

## Completed output

`Chronos13_PrivateVisuals.archive` is a structurally validated RDAR v12 archive
containing these four private depot resources:

```text
ch13\fx\player\time_dilation_vfx_outlines.effect
ch13\fx\player\time_dilation_vfx_outlines.particle
ch13\fx\player\time_dilation_vfx_radial_blur.effect
ch13\fx\player\time_dilation_vfx_flash.effect
```

No archive entry retains an original `base\` resource hash. The outlines effect's
import of its companion particle was changed to the private `ch13\` path. No
other resource imports, effect durations, loops, curves or distortion strengths were changed.
The optional flash has one strictly located material color neutralization,
described below; its checksum fields were recomputed.
The source archive's main `time_dilation_vfx.effect` is deliberately excluded.

This is **not a game load or visible rendering verification**. The game must
still load the private archive and its native material/particle dependencies.

## Actual decoded resource structure

The excluded source main effect has exactly four exports: `worldEffect`,
`effectTrackItemColorGrade` and two `CEvaluatorFloatConst` objects. It references
`base\weather\luts\photo_mode\neon_01.xbm`; it contains no particle distortion
event. Its duration is approximately 0.55 seconds with an effect loop.

The outlines effect has a particle event and references the included screen
particle. That particle uses the original `drugged_sobel.mt` material. A Sobel
outline is not proof of spatial refraction.

The radial blur effect has a particle event referencing the native
`base\fx\camera\splinter_buff\radial_blur_skif.particle`. Its original root
duration and loop are retained.

The optional flash has one particle event, an embedded particle system and
screen drawer, and a material based on `reflex_buster.mt` (also importing
`zoom.mt`). Its root length is approximately 0.76 seconds, the particle event
duration is 0.5 seconds, and no effectLoops property is present. The material
contains MaxDistortMulitiplier=20, RelativeFStop=1, ZoomMultiplier=1 and
MinDistortMulitiplier=-5. These values are not modified. It is a candidate for a
single startup distortion burst, not evidence of continuous distortion.

None of the included effects exports a ColorGrade track. The flash's material
originally has a named `Color` parameter of type `Color`, with explicit RGBA
properties (0,176,240,255). Following WolvenKit's CMaterialInstance appendix
layout, the builder structurally locates export 17 (`CMaterialInstance`), that
specific parameter, and its individual Uint8 channel properties. Only RGB is
changed to (143,143,143), retaining alpha=255. This approximately retains the
source color's Rec.709 luminance as a neutral-gray candidate, while leaving
timing, loops, curves and distortion multipliers unchanged. The modified chunk
CRC, export-table CRC and header CRC are recomputed; archive checksums/hashes are
then rebuilt. Exact offsets, original/new values and changed bytes are recorded
in the manifest.

The outlines particle's `BrightColor` remains (127,63,0,255), and `DarkColor`
remains (148,124,0,255). Those warm outline colors were not changed.

The shader's interpretation of the flash color parameter is not established by
this edit. **A neutral parameter and no ColorGrade track do not prove the
rendered image is free of every possible tint**. Actual neutral flash appearance
and distortion output remain game-test requirements.

## Canonical external buffer correction

The original decompression stage had appended the decompressed external buffer
to the outlines particle, yielding a 3418-byte analysis file while its CR2W
header described a 3416-byte on-disk file (diskSize=458, memSize=460). The builder
does not ship that analysis representation. It restores the source archive's
original 458-byte KARK buffer and verifies its original CRC32. The emitted
private particle is a canonical 3416-byte CR2W with matching buffer metadata.

## Format provenance and checks

Algorithms were checked against WolvenKit commit
`6ab5da88c009b99e653ce87be5251a9c5bd15330`:

- `WolvenKit.RED4/Archive/IO/CR2WWriter.File.cs`,
  `CalculateHeaderCRC32`: CRC32 over the 160-byte header with the CRC field set
  to `0xDEADBEEF`.
- `WolvenKit.RED4/Archive/IO/ArchiveWriter.cs`, `WriteIndex` and `WriteHeader`:
  RDAR index/header layout, file/segment entries, 4096-byte final page alignment.
- `WolvenKit.Core/CRC/CRC64Algo.cs`: reflected CRC64/XZ, initial/final complement;
  the original index checksum recalculates to `e90496dc756b7e92` exactly.
- `WolvenKit.RED4/Archive/Base/LxrsFooter.cs`: uncompressed custom-path footer
  where stored size equals unpacked size.

All original canonical CR2W header/table/buffer checksums were recalculated
before editing. Only the equal-length companion import path string changes;
its string table CRC and CR2W header CRC are recalculated. Object segments are
stored uncompressed, original buffer payloads retain their compression/metadata.
The newly emitted archive is re-read to check its index CRC64, bounds, sorted
resource hashes, private dependency resolution, exact resource reconstruction,
SHA1 values and all CR2W CRC32 values. See `PRIVATE_RESOURCE_MANIFEST.json`.

Rebuild:

```text
python3 resources/build_private_archive.py
```

The builder uses Python's standard library and the already decoded analysis
files plus the original supplied archive. It does not require Oodle binaries.
It never overwrites the original analysis files or baseline archive.
