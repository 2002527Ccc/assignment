module CH13FinaleDiagHooks
import OneEyedTech.*

// Signature copied from the supplied Finale's protected RepeatedAction method.
// No global damage wrapper. The original effector executes exactly once.
@wrapMethod(OET_UploadHitEffector)
protected func RepeatedAction(owner: ref<GameObject>) -> Void {
  let hit: ref<gameHitEvent> = this.GetHitEvent();
  CH13FDHit.Capture(hit, n"blackwall_hit_before");
  wrappedMethod(owner);
  CH13FDHit.Capture(hit, n"blackwall_hit_after");
}

public abstract class CH13FDHit extends IScriptable {
  public static func Capture(hit: ref<gameHitEvent>, kind: CName) -> Void {
    let player: ref<PlayerPuppet>;
    let weapon: ref<WeaponObject>;
    let target: ref<NPCPuppet>;
    let entry: ref<CH13FDEvent>;
    if !IsDefined(hit) || !IsDefined(hit.attackData) { return; }
    player = hit.attackData.GetInstigator() as PlayerPuppet;
    if !IsDefined(player) || !player.m_ch13FDEnabled || player.m_ch13FDTrial <= 0 { return; }
    weapon = hit.attackData.GetWeapon();
    if !CH13FD.IsFinale(weapon) { return; }
    if ArraySize(player.m_ch13FDQueue) >= 128 {
      player.m_ch13FDDropped += 1;
      return;
    }
    target = hit.target as NPCPuppet;
    entry = new CH13FDEvent();
    entry.kind = kind;
    entry.trial = player.m_ch13FDTrial;
    entry.simTime = EngineTime.ToFloat(GameInstance.GetSimTime(player.GetGame()));
    entry.weapon = weapon;
    entry.weaponID = ItemID.GetTDBID(weapon.GetItemID());
    entry.target = target;
    entry.owner = player;
    entry.charge = hit.attackData.GetWeaponCharge();
    // Same read API used by the supplied Finale V6.2; runtime availability still needs testing.
    entry.perfectlyCharged = hit.attackData.HasFlag(hitFlag.PerfectlyCharged);
    entry.isRanged = Equals(hit.attackData.GetAttackType(), gamedataAttackType.Ranged);
    entry.attackType = EnumInt(hit.attackData.GetAttackType());
    entry.canExecute = OET_BlackwallUpload.CanExecute(target);
    if IsDefined(target) {
      entry.uploadPresent = IsDefined(target.oet_blackwallUpload);
      if entry.uploadPresent { entry.uploadProgress = target.oet_blackwallUpload.GetProgress(); }
      entry.normalMark = StatusEffectSystem.ObjectHasStatusEffect(target, t"BaseStatusEffect.OET_BlackwallMark");
      entry.bossMark = StatusEffectSystem.ObjectHasStatusEffect(target, t"BaseStatusEffect.OET_BossBlackwallMark");
    }
    ArrayPush(player.m_ch13FDQueue, entry);
  }
}
