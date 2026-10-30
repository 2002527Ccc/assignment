// TASK02 passive telemetry. Global classes intentionally match CET's existing
// CH13Bridge calling convention. Requires the supplied CHRONOS V0.3.2 baseline.
// No attack creation, record substitution, hit replay, time or trajectory writes.

@addField(PlayerPuppet) public let m_ch13FDEnabled: Bool;
@addField(PlayerPuppet) public let m_ch13FDTrial: Int32;
@addField(PlayerPuppet) public let m_ch13FDDropped: Int32;
@addField(PlayerPuppet) public let m_ch13FDQueue: array<ref<CH13FDEvent>>;
@addField(PlayerPuppet) public let m_ch13FDSelectionCalls: Int32;
@addField(PlayerPuppet) public let m_ch13FDSelectionTrial: Int32;
@addField(PlayerPuppet) public let m_ch13FDSelectionAttack: ref<Attack_Record>;
@addField(PlayerPuppet) public let m_ch13FDSelectionPackage: ref<RangedAttackPackage_Record>;
@addField(PlayerPuppet) public let m_ch13FDSelectionEvents: Int32;
@addField(PlayerPuppet) public let m_ch13FDSelectionSuppressed: Int32;

public class CH13FDEvent extends IScriptable {
  public let kind: CName;
  public let trial: Int32;
  public let simTime: Float;
  public let weapon: wref<WeaponObject>;
  public let weaponID: TweakDBID;
  public let attack: ref<Attack_Record>;
  public let attackPackage: ref<RangedAttackPackage_Record>;
  public let entity: wref<GameObject>;
  public let owner: wref<GameObject>;
  public let target: wref<NPCPuppet>;
  public let hookClass: CName;
  public let startVelocity: Float;
  public let lifetime: Float;
  public let charge: Float;
  public let attackType: Int32;
  public let canExecute: Bool;
  public let uploadPresent: Bool;
  public let uploadProgress: Float;
  public let normalMark: Bool;
  public let bossMark: Bool;
}

public abstract class CH13FD extends IScriptable {
  public static func IsFinale(weapon: ref<WeaponObject>) -> Bool {
    return IsDefined(weapon) && ItemID.GetTDBID(weapon.GetItemID()) == t"Items.Finale";
  }

  // The queue is bounded. Exhaustion drops telemetry, never an attack or a hit.
  private static func NewEvent(player: ref<PlayerPuppet>, kind: CName, weapon: ref<WeaponObject>) -> ref<CH13FDEvent> {
    let entry: ref<CH13FDEvent>;
    if !IsDefined(player) || !player.m_ch13FDEnabled || player.m_ch13FDTrial <= 0 || !CH13FD.IsFinale(weapon) {
      return null;
    }
    if ArraySize(player.m_ch13FDQueue) >= 128 {
      player.m_ch13FDDropped += 1;
      return null;
    }
    entry = new CH13FDEvent();
    entry.kind = kind;
    entry.trial = player.m_ch13FDTrial;
    entry.simTime = EngineTime.ToFloat(GameInstance.GetSimTime(player.GetGame()));
    entry.weapon = weapon;
    entry.weaponID = ItemID.GetTDBID(weapon.GetItemID());
    return entry;
  }

  public static func Drain(player: ref<PlayerPuppet>) -> array<ref<CH13FDEvent>> {
    let result: array<ref<CH13FDEvent>>;
    if IsDefined(player) {
      result = player.m_ch13FDQueue;
      ArrayClear(player.m_ch13FDQueue);
    }
    return result;
  }

  public static func Selection(player: ref<PlayerPuppet>, weapon: ref<WeaponObject>, attack: ref<Attack_Record>, attackPackage: ref<RangedAttackPackage_Record>) -> Void {
    let entry: ref<CH13FDEvent>;
    if !IsDefined(player) || !player.m_ch13FDEnabled || !CH13FD.IsFinale(weapon) { return; }
    player.m_ch13FDSelectionCalls += 1;
    // Some states query attack selection repeatedly. Log record transitions, not frames.
    if player.m_ch13FDSelectionTrial == player.m_ch13FDTrial
      && player.m_ch13FDSelectionAttack == attack && player.m_ch13FDSelectionPackage == attackPackage { return; }
    if player.m_ch13FDSelectionEvents >= 32 {
      player.m_ch13FDSelectionSuppressed += 1;
      return;
    }
    entry = CH13FD.NewEvent(player, n"selection", weapon);
    if !IsDefined(entry) { return; }
    player.m_ch13FDSelectionTrial = player.m_ch13FDTrial;
    player.m_ch13FDSelectionAttack = attack;
    player.m_ch13FDSelectionPackage = attackPackage;
    player.m_ch13FDSelectionEvents += 1;
    entry.attack = attack;
    entry.attackPackage = attackPackage;
    ArrayPush(player.m_ch13FDQueue, entry);
  }

  public static func Projectile(player: ref<PlayerPuppet>, entity: ref<GameObject>, owner: ref<GameObject>, velocity: Float, lifetime: Float, hookClass: CName) -> Void {
    let weapon: ref<WeaponObject> = ScriptedPuppet.GetActiveWeapon(player);
    let entry: ref<CH13FDEvent> = CH13FD.NewEvent(player, n"projectile_initialize", weapon);
    if !IsDefined(entry) { return; }
    entry.entity = entity;
    entry.owner = owner;
    entry.hookClass = hookClass;
    entry.startVelocity = velocity;
    entry.lifetime = lifetime;
    ArrayPush(player.m_ch13FDQueue, entry);
  }
}
