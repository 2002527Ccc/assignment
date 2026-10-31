-- CHRONOS V2 visual restoration TEST01.
-- Vanilla blue tint stays disabled by the separately-installed chronos_vfx_probe.yaml.
-- Native sub-effects only; do NOT enable time_dilation_vfx (the blue graded effect).
return {
  outlines = true,
  radialBlur = true,
  flashOnStart = false, -- optional. Off: exactly two continuous visual elements.
  debug = true,
}
