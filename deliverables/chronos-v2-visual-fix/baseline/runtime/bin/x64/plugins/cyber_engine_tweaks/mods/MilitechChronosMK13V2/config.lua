return {
  enabled = {tech = true, cooldowns = true, visual = true},
  debug = false,
  sampleInterval = 0.05,
  maxObservationGap = 0.5,
  -- ONLY these player recharge pools; never SandevistanCharge/Health/TimeBank.
  pools = {"OpticalCamoCharges", "ProjectileLauncherCharges", "HealingItemsCharges", "GrenadesCharges"},
  -- Disable a specific pool if another mod already repairs its time scaling.
  excludedPools = {},
  excludedStatuses = {},
  visualResolveTimeout = 8,
}
