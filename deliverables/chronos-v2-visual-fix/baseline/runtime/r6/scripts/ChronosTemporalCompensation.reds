// CHRONOS V12.2c-R1. Native-type boundary for the CET real-time controller.
// No replacement/wrapper of the vanilla Sandevistan state machine.
@addField(PlayerPuppet)
public let m_chronosControllerActive: Bool;

public class ChronosBridge {
  public static func SetControllerActive(owner: ref<GameObject>, active: Bool) -> Void {
    let player = owner as PlayerPuppet;
    if IsDefined(player) { player.m_chronosControllerActive = active; }
  }

  public static func ControllerIsActive(owner: ref<GameObject>) -> Bool {
    let player = owner as PlayerPuppet;
    return IsDefined(player) && player.m_chronosControllerActive;
  }

  public static func StatsID(owner: ref<GameObject>) -> StatsObjectID {
    return Cast<StatsObjectID>(owner.GetEntityID());
  }

  public static func SameOwner(a: ref<GameObject>, b: ref<GameObject>) -> Bool {
    return IsDefined(a) && IsDefined(b) && a.GetEntityID() == b.GetEntityID();
  }

  public static func IsEquipped(owner: ref<GameObject>) -> Bool {
    let player = owner as PlayerPuppet;
    if !IsDefined(player) { return false; }
    let eq = EquipmentSystem.GetInstance(player);
    if !IsDefined(eq) { return false; }
    let data = eq.GetPlayerData(player);
    if !IsDefined(data) { return false; }
    let item = data.GetItemInEquipSlot(gamedataEquipmentArea.SystemReplacementCW, 0);
    return ItemID.IsValid(item) && Equals(ItemID.GetTDBID(item), t"Items.MilitechChronosMk13");
  }

  public static func IsRunning(owner: ref<GameObject>) -> Bool {
    let player = owner as PlayerPuppet;
    if !IsDefined(player) || !player.IsAttached() || player.IsDeadNoStatPool() || !ChronosBridge.IsEquipped(player) {
      return false;
    }
    if ChronosBridge.ReadPercent(player, gamedataStatPoolType.Health) <= 0.0 { return false; }
    let bb = player.GetPlayerStateMachineBlackboard();
    if !IsDefined(bb) { return false; }
    if bb.GetInt(GetAllBlackboardDefs().PlayerStateMachine.HighLevel) != EnumInt(gamePSMHighLevel.SceneTier1) {
      return false;
    }
    if bb.GetInt(GetAllBlackboardDefs().PlayerStateMachine.TimeDilation) != EnumInt(gamePSMTimeDilation.Sandevistan) {
      return false;
    }
    return GameInstance.GetTimeSystem(player.GetGame()).IsTimeDilationActive(TimeDilationHelper.GetSandevistanKey());
  }

  public static func IsSuspended(owner: ref<GameObject>) -> Bool {
    if !IsDefined(owner) { return true; }
    if GameInstance.GetTimeSystem(owner.GetGame()).IsPausedState() { return true; }
    let ui = GameInstance.GetBlackboardSystem(owner.GetGame()).Get(GetAllBlackboardDefs().UI_System);
    return IsDefined(ui) && ui.GetBool(GetAllBlackboardDefs().UI_System.IsInMenu);
  }

  public static func HasPool(owner: ref<GameObject>, kind: gamedataStatPoolType) -> Bool {
    return GameInstance.GetStatPoolsSystem(owner.GetGame()).HasActiveStatPool(ChronosBridge.StatsID(owner), kind);
  }

  public static func ReadPercent(owner: ref<GameObject>, kind: gamedataStatPoolType) -> Float {
    return GameInstance.GetStatPoolsSystem(owner.GetGame()).GetStatPoolValue(ChronosBridge.StatsID(owner), kind, true);
  }

  public static func GetRegeneration(owner: ref<GameObject>, kind: gamedataStatPoolType) -> StatPoolModifier {
    let modifier: StatPoolModifier;
    GameInstance.GetStatPoolsSystem(owner.GetGame()).GetModifier(ChronosBridge.StatsID(owner), kind, gameStatPoolModificationTypes.Regeneration, modifier);
    return modifier;
  }

  public static func GetDecay(owner: ref<GameObject>, kind: gamedataStatPoolType) -> StatPoolModifier {
    let modifier: StatPoolModifier;
    GameInstance.GetStatPoolsSystem(owner.GetGame()).GetModifier(ChronosBridge.StatsID(owner), kind, gameStatPoolModificationTypes.Decay, modifier);
    return modifier;
  }

  public static func ChangePercent(owner: ref<GameObject>, kind: gamedataStatPoolType, change: Float, instigator: ref<GameObject>) -> Void {
    GameInstance.GetStatPoolsSystem(owner.GetGame()).RequestChangingStatPoolValue(ChronosBridge.StatsID(owner), kind, change, instigator, false, true);
  }

  public static func DrainHealth(owner: ref<GameObject>, realDelta: Float) -> Void {
    // Percentage points of MAXIMUM health, not current-health multiplication.
    // Direct pool debit bypasses the damage pipeline. Zero is permitted; no cutoff.
    ChronosBridge.ChangePercent(owner, gamedataStatPoolType.Health, -100.0 * realDelta / 13.0, owner);
  }

  public static func Cooldowns(owner: ref<GameObject>) -> array<ref<StatusEffect>> {
    let effects: array<ref<StatusEffect>>;
    StatusEffectHelper.GetAppliedEffectsWithTag(owner, n"PlayerCyberwareCooldown", effects);
    return effects;
  }

  public static func ActiveWeapon(owner: ref<GameObject>) -> ref<WeaponObject> {
    return GameObject.GetActiveWeapon(owner);
  }

  public static func IsTechGun(weapon: ref<WeaponObject>) -> Bool {
    if !IsDefined(weapon) || !weapon.IsRanged() { return false; }
    // Item evolution, not a name whitelist; includes custom Tech pistols.
    if NotEquals(RPGManager.GetWeaponEvolution(weapon.GetItemID()), gamedataWeaponEvolution.Tech) { return false; }
    let record = TweakDBInterface.GetItemRecord(ItemID.GetTDBID(weapon.GetItemID()));
    if !IsDefined(record) { return false; }
    switch record.ItemType().Type() {
      case gamedataItemType.Wea_Handgun:
      case gamedataItemType.Wea_Revolver:
      case gamedataItemType.Wea_AssaultRifle:
      case gamedataItemType.Wea_Rifle:
      case gamedataItemType.Wea_SubmachineGun:
      case gamedataItemType.Wea_LightMachineGun:
      case gamedataItemType.Wea_HeavyMachineGun:
      case gamedataItemType.Wea_Shotgun:
      case gamedataItemType.Wea_ShotgunDual:
      case gamedataItemType.Wea_SniperRifle:
      case gamedataItemType.Wea_PrecisionRifle:
        return true;
    }
    return false;
  }
}
