-- No global records or third-party mod files are modified by these switches.
return {
  v2Features = true, -- transfer ONLY optional cooldown correction; R1b core unchanged
  debug = false,
  -- WeaponCharge progress correction is OFF until 2.5 Tech/Bolt/Finale playtesting.
  -- Set true only for the acceptance test described in docs/TEST_PLAN.md.
  tech = false,
  pools = {"OpticalCamoCharges", "ProjectileLauncherCharges", "HealingItemsCharges", "GrenadesCharges"}
  -- Excluded: SandevistanCharge (own OS), CWMask (unrelated ability), vehicle missiles.
  -- ThrowRecovery is not assumed to live on the player; see COVERAGE.md.
}
