// CHRONOS 13 V0.3.2 - Power weapon conversion, diagnostic only until in-game validated.
// Adapted design based on ChronoField's ranged attack selection approach; independently written.
// Does NOT change Tech/Smart/custom/throwing attacks. No resource assets included.
@addField(PlayerPuppet) public let m_ch13AttackConverted: Int32;
@addField(PlayerPuppet) public let m_ch13ConversionCandidates: Int32;
@addField(PlayerPuppet) public let m_ch13ProjectileSeen: Int32;
@addField(PlayerPuppet) public let m_ch13ProjectileFrozen: Int32;
@addField(PlayerPuppet) public let m_ch13ProjectileThawed: Int32;

@wrapMethod(WeaponTransition)
protected final func GetDesiredAttackRecord(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> ref<Attack_Record> {
  let original: ref<Attack_Record> = wrappedMethod(stateContext, scriptInterface);
  // TASK02: passive capture before the original Power/active filters.
  // Selection is NOT a confirmed discharge. The original return paths remain intact.
  let diagPlayer: ref<PlayerPuppet> = scriptInterface.executionOwner as PlayerPuppet;
  if IsDefined(diagPlayer) && diagPlayer.m_ch13FDEnabled {
    CH13FD.Selection(diagPlayer, this.GetWeaponObject(scriptInterface), original, this.m_rangedAttackPackage);
  }
  if !IsDefined(original) { return original; }
  let v: ref<PlayerPuppet> = scriptInterface.executionOwner as PlayerPuppet;
  if !IsDefined(v) || !CH13Bridge.IsNativeActive(v) { return original; }
  let weapon: ref<WeaponObject> = this.GetWeaponObject(scriptInterface);
  if !IsDefined(weapon) { return original; }
  if !Equals(weapon.GetWeaponRecord().Evolution().Type(), gamedataWeaponEvolution.Power) { return original; }
  let stats: ref<StatsSystem> = GameInstance.GetStatsSystem(weapon.GetGame());
  let pellets: Float = stats.GetStatValue(Cast<StatsObjectID>(weapon.GetEntityID()), gamedataStatType.ProjectilesPerShot);
  if pellets != 1.0 { return original; }
  let package: ref<RangedAttackPackage_Record> = this.m_rangedAttackPackage;
  if !IsDefined(package) { return original; }
  let attack: ref<RangedAttack_Record> = package.DefaultFire();
  if !IsDefined(attack) { return original; }
  let replacement: ref<Attack_Record>;
  switch attack.GetID() {
    case t"Attacks.PhysicalBullet":
      replacement = TweakDBInterface.GetAttackRecord(t"Attacks.PowerBullets_Projectile");
      break;
    case t"Attacks.PhysicalStatusEffectBullet":
      replacement = TweakDBInterface.GetAttackRecord(t"Attacks.BleedingBulletProjectile");
      break;
    case t"Attacks.ThermalBullet":
      replacement = TweakDBInterface.GetAttackRecord(t"Attacks.ThermalBulletProjectile");
      break;
    case t"Attacks.ThermalStatusEffectBullet":
      replacement = TweakDBInterface.GetAttackRecord(t"Attacks.BurningBulletProjectile");
      break;
    case t"Attacks.ChemicalBullet":
      replacement = TweakDBInterface.GetAttackRecord(t"Attacks.ChemicalBulletProjectile");
      break;
    case t"Attacks.ChemicalStatusEffectBullet":
      replacement = TweakDBInterface.GetAttackRecord(t"Attacks.PoisonBulletProjectile");
      break;
    case t"Attacks.ElectricBullet":
    case t"Attacks.ElectricStatusEffectBullet":
      replacement = TweakDBInterface.GetAttackRecord(t"Attacks.ElectricBulletProjectile");
      break;
    case t"Attacks.PowerRoundsBullet":
      replacement = TweakDBInterface.GetAttackRecord(t"Attacks.PowerRounds_Projectile");
      break;
    case t"Attacks.PowerBulletsBullet":
      replacement = TweakDBInterface.GetAttackRecord(t"Attacks.PowerBullets_Projectile");
      break;
  }
  v.m_ch13ConversionCandidates += 1;
  if !IsDefined(replacement) { return original; }
  v.m_ch13AttackConverted += 1;
  return replacement;
}
