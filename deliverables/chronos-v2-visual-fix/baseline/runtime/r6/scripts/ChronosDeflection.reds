// Independent Process/Damage hit effector. Never changes NanoTechPlatesEffector.
public class ChronosDeflectionEffector extends ModifyAttackEffector {
  private let m_lastHit: wref<gameHitEvent>;

  protected func RepeatedAction(owner: ref<GameObject>) -> Void {
    if !ChronosBridge.ControllerIsActive(owner) || !ChronosBridge.IsRunning(owner) || ChronosBridge.IsSuspended(owner) { return; }
    let hit = this.GetHitEvent();
    if !IsDefined(hit) || hit == this.m_lastHit { return; }
    // One lottery per hit object; no second ActionOn lottery and no per-shot cap.
    this.m_lastHit = hit;
    if !IsDefined(hit.target) || hit.target.GetEntityID() != owner.GetEntityID() { return; }
    if !IsDefined(hit.attackData) || !IsDefined(hit.attackComputed) { return; }
    if NotEquals(hit.attackData.GetAttackType(), gamedataAttackType.Ranged) { return; }
    let weapon = hit.attackData.GetWeapon();
    if !IsDefined(weapon) || !weapon.IsRanged() { return; }
    if hit.attackComputed.GetTotalAttackValue(gamedataStatPoolType.Health) <= 0.0 { return; }
    let tech = GameInstance.GetStatsSystem(owner.GetGame()).GetStatValue(ChronosBridge.StatsID(owner), gamedataStatType.TechnicalAbility);
    let chance = ClampF(0.13 + tech * 0.001, 0.0, 1.0);
    if RandF() < chance {
      // Multiplication by zero commutes with ordinary mitigation multiplication.
      hit.attackComputed.MultAttackValue(0.0);
      // R1a: remove unsupported LogChannel call. Deflection logic unchanged.
    }
  }
}
