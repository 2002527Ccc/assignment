module OneEyedTech

// Only direct hits made by the player's Finale enter either combat ability.
public class OET_WeaponHitPrereq extends GenericHitPrereq {
  protected func Initialize(recordID: TweakDBID) -> Void {
    super.Initialize(recordID);
    ArrayPush(this.m_conditions, new OET_WeaponHitCondition());
  }
}

public class OET_WeaponHitPrereqState extends GenericHitPrereqState {}

public class OET_MalfunctionPrereq extends OET_WeaponHitPrereq {
  protected func Initialize(recordID: TweakDBID) -> Void {
    let condition: ref<OET_EnemyKindCondition>;
    super.Initialize(recordID);
    condition = new OET_EnemyKindCondition();
    if recordID == t"Prereqs.OET_MalfunctionBoss" {
      condition.kind = 1;
    } else {
      if recordID == t"Prereqs.OET_MalfunctionChimera" {
        condition.kind = 2;
      } else {
        condition.kind = 0;
      };
    };
    ArrayPush(this.m_conditions, condition);
  }
}

public class OET_MalfunctionPrereqState extends GenericHitPrereqState {}

public class OET_EnemyKindCondition extends BaseHitPrereqCondition {
  public let kind: Int32;

  public func Evaluate(hitEvent: ref<gameHitEvent>) -> Bool {
    let target: ref<NPCPuppet> = hitEvent.target as NPCPuppet;
    let boss: Bool;
    if !IsDefined(target) {
      return false;
    };
    boss = Equals(target.GetNPCRarity(), gamedataNPCRarity.Boss) || StatusEffectSystem.ObjectHasStatusEffect(target, t"BaseStatusEffect.MainBossSE");
    switch this.kind {
      case 2:
        return Equals(target.GetNPCType(), gamedataNPCType.Chimera);
      case 1:
        return boss && NotEquals(target.GetNPCType(), gamedataNPCType.Chimera);
      default:
        return !boss && Equals(target.GetNPCType(), gamedataNPCType.Human);
    };
  }
}

public class OET_WeaponHitCondition extends BaseHitPrereqCondition {
  public func Evaluate(hitEvent: ref<gameHitEvent>) -> Bool {
    let weapon: ref<WeaponObject>;
    let attackType: gamedataAttackType;
    if !IsDefined(hitEvent) || !IsDefined(hitEvent.attackData) || !IsDefined(hitEvent.attackData.GetInstigator()) {
      return false;
    };
    // Only committed, damaging hits may trigger upload or malfunction effects.
    if hitEvent.projectionPipeline || hitEvent.attackData.HasFlag(hitFlag.DealNoDamage) || hitEvent.attackData.HasFlag(hitFlag.DamageNullified) || hitEvent.attackData.HasFlag(hitFlag.FriendlyFireIgnored) {
      return false;
    };
    if hitEvent.attackData.WasBlocked() || hitEvent.attackData.WasDeflectedAny() || hitEvent.attackComputed.GetTotalAttackValue(gamedataStatPoolType.Health) <= 0.00 {
      return false;
    };
    weapon = hitEvent.attackData.GetWeapon();
    if !IsDefined(weapon) || ItemID.GetTDBID(weapon.GetItemID()) != t"Items.Finale" || !hitEvent.attackData.GetInstigator().IsPlayer() {
      return false;
    };
    attackType = hitEvent.attackData.GetAttackType();
    return Equals(attackType, gamedataAttackType.Ranged) || AttackData.IsMelee(attackType);
  }
}

public class OET_UploadHitEffector extends ModifyAttackEffector {
  protected func RepeatedAction(owner: ref<GameObject>) -> Void {
    let hit: ref<gameHitEvent> = this.GetHitEvent();
    let target: ref<NPCPuppet>;
    let player: ref<PlayerPuppet>;
    let fullCharge: Bool;
    let marker: TweakDBID;
    if !IsDefined(hit) || !IsDefined(hit.attackData) {
      return;
    };
    target = hit.target as NPCPuppet;
    player = hit.attackData.GetInstigator() as PlayerPuppet;
    if !IsDefined(player) || !OET_BlackwallUpload.CanExecute(target) {
      return;
    };
    fullCharge = Equals(hit.attackData.GetAttackType(), gamedataAttackType.Ranged) && hit.attackData.GetWeaponCharge() >= 0.999;
    // A later hit accelerates the existing upload. It never restarts it.
    if IsDefined(target.oet_blackwallUpload) {
      target.oet_blackwallUpload.AddHitProgress(fullCharge);
      return;
    };
    // The opening hit only marks: no bonus progress for that same hit.
    // Charge belongs to this fired attack, not the currently held weapon.
    if fullCharge {
      marker = OET_BlackwallUpload.IsBoss(target) ? t"BaseStatusEffect.OET_BossBlackwallMark" : t"BaseStatusEffect.OET_BlackwallMark";
      GameInstance.GetStatusEffectSystem(target.GetGame()).ApplyStatusEffect(target.GetEntityID(), marker, player.GetRecordID(), player.GetEntityID());
    };
  }
}

@addField(NPCPuppet)
public let oet_blackwallUpload: ref<OET_BlackwallUpload>;

@addField(NPCPuppet)
public let oet_blackwallMappin: wref<QuickHackMappinController>;

// This package also runs when a saved mark is restored. A restored mark starts
// a fresh countdown; it cannot become an orphaned permanent visual effect.
public class OET_MarkEffector extends Effector {
  private let m_target: wref<NPCPuppet>;

  protected func ActionOn(owner: ref<GameObject>) -> Void {
    this.m_target = owner as NPCPuppet;
    if OET_BlackwallUpload.CanTrack(this.m_target) && !IsDefined(this.m_target.oet_blackwallUpload) {
      this.m_target.oet_blackwallUpload = new OET_BlackwallUpload();
      this.m_target.oet_blackwallUpload.Start(this.m_target);
    };
  }

  protected func Uninitialize(game: GameInstance) -> Void {
    if IsDefined(this.m_target) && IsDefined(this.m_target.oet_blackwallUpload) {
      this.m_target.oet_blackwallUpload.Stop();
    };
  }
}

public class OET_UploadHealthListener extends ScriptStatPoolsListener {
  public let upload: wref<OET_BlackwallUpload>;

  public func OnStatPoolValueChanged(oldValue: Float, newValue: Float, percToPoints: Float) -> Void {
    if IsDefined(this.upload) {
      this.upload.CheckHealth();
    };
  }
}

public class OET_BlackwallUpload extends DelayCallback {
  private let m_game: GameInstance;
  private let m_target: wref<NPCPuppet>;
  private let m_player: wref<PlayerPuppet>;
  private let m_listener: ref<OET_UploadHealthListener>;
  private let m_delay: DelayID;
  private let m_nativeMappin: NewMappinID;
  private let m_lastTime: Float;
  private let m_progress: Float;
  private let m_duration: Float;
  private let m_hitBonus: Float;
  private let m_threshold: Float;
  private let m_bossNormalSeconds: Float;
  private let m_bossChargedSeconds: Float;
  private let m_bossDamagePercent: Float;
  private let m_isBoss: Bool;
  private let m_stopped: Bool;

  public final static func IsBoss(target: wref<NPCPuppet>) -> Bool {
    return IsDefined(target) && (Equals(target.GetNPCRarity(), gamedataNPCRarity.Boss) || Equals(target.GetNPCType(), gamedataNPCType.Chimera) || StatusEffectSystem.ObjectHasStatusEffect(target, t"BaseStatusEffect.MainBossSE"));
  }

  public final static func CanTrack(target: wref<NPCPuppet>) -> Bool {
    return IsDefined(target) && !target.IsDead() && !target.IsAboutToDie();
  }

  public final static func IsProtected(target: wref<NPCPuppet>) -> Bool {
    if !IsDefined(target) {
      return true;
    };
    return GameInstance.GetStatsSystem(target.GetGame()).GetStatValue(Cast<StatsObjectID>(target.GetEntityID()), gamedataStatType.IsInvulnerable) > 0.00 || GameInstance.GetGodModeSystem(target.GetGame()).HasGodMode(target.GetEntityID(), gameGodModeType.Invulnerable);
  }

  public final static func CanExecute(target: wref<NPCPuppet>) -> Bool {
    return OET_BlackwallUpload.CanTrack(target) && !OET_BlackwallUpload.IsProtected(target);
  }

  public final func Start(target: ref<NPCPuppet>) -> Void {
    this.m_game = target.GetGame();
    this.m_target = target;
    this.m_player = GetPlayer(this.m_game);
    this.m_isBoss = OET_BlackwallUpload.IsBoss(target);
    this.m_duration = MaxF(0.10, TweakDBInterface.GetFloat(t"OET.Config.uploadDuration", 7.00));
    if this.m_isBoss {
      this.m_duration = MaxF(0.10, TweakDBInterface.GetFloat(t"OET.Config.bossUploadDuration", 359.00));
    };
    this.m_hitBonus = MaxF(0.00, TweakDBInterface.GetFloat(t"OET.Config.progressPerHit", 19.00));
    this.m_threshold = TweakDBInterface.GetFloat(t"OET.Config.executeHealthPercent", 31.00);
    this.m_bossNormalSeconds = MaxF(0.00, TweakDBInterface.GetFloat(t"OET.Config.bossNormalSeconds", 1.00));
    this.m_bossChargedSeconds = MaxF(0.00, TweakDBInterface.GetFloat(t"OET.Config.bossChargedSeconds", 7.00));
    this.m_bossDamagePercent = ClampF(TweakDBInterface.GetFloat(t"OET.Config.bossDamagePercent", 100.00), 0.00, 100.00);
    this.m_lastTime = EngineTime.ToFloat(GameInstance.GetSimTime(this.m_game));
    this.m_listener = new OET_UploadHealthListener();
    this.m_listener.upload = this;
    GameInstance.GetStatPoolsSystem(this.m_game).RequestRegisteringListener(Cast<StatsObjectID>(target.GetEntityID()), gamedataStatPoolType.Health, this.m_listener);
    this.CheckHealth();
    if !this.m_stopped {
      this.UpdateUI();
      this.Schedule();
    };
  }

  public final func GetProgress() -> Float {
    return ClampF(this.m_progress, 0.00, 100.00);
  }

  private final func AdvanceTime() -> Void {
    let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(this.m_game));
    this.m_progress = MinF(100.00, this.m_progress + MaxF(0.00, now - this.m_lastTime) * 100.00 / this.m_duration);
    this.m_lastTime = now;
  }

  public final func AddHitProgress(fullCharge: Bool) -> Void {
    let seconds: Float;
    if this.m_stopped {
      return;
    };
    this.AdvanceTime();
    if this.m_isBoss {
      seconds = fullCharge ? this.m_bossChargedSeconds : this.m_bossNormalSeconds;
      this.m_progress = MinF(100.00, this.m_progress + seconds * 100.00 / this.m_duration);
    } else {
      this.m_progress = MinF(100.00, this.m_progress + this.m_hitBonus);
    };
    this.CheckHealth();
    if !this.m_stopped {
      this.UpdateUI();
    };
  }

  public final func CheckHealth() -> Void {
    let health: Float;
    if this.m_stopped {
      return;
    };
    if !OET_BlackwallUpload.CanTrack(this.m_target) {
      this.Stop();
      return;
    };
    if !this.m_isBoss && OET_BlackwallUpload.IsProtected(this.m_target) {
      this.Stop();
      return;
    };
    health = GameInstance.GetStatPoolsSystem(this.m_game).GetStatPoolValue(Cast<StatsObjectID>(this.m_target.GetEntityID()), gamedataStatPoolType.Health, true);
    if health <= 0.00 {
      this.Stop();
      return;
    };
    if this.m_progress >= 100.00 || (!this.m_isBoss && health < this.m_threshold) {
      this.Complete();
    };
  }

  public func Call() -> Void {
    if this.m_stopped {
      return;
    };
    this.AdvanceTime();
    this.CheckHealth();
    if !this.m_stopped {
      this.UpdateUI();
      this.Schedule();
    };
  }

  private final func Schedule() -> Void {
    this.m_delay = GameInstance.GetDelaySystem(this.m_game).DelayCallback(this, 0.05, true);
  }

  private final func Complete() -> Void {
    let target: ref<NPCPuppet> = this.m_target;
    let player: ref<PlayerPuppet> = this.m_player;
    let boss: Bool;
    let damage: Float;
    // A full boss bar waits through invulnerability without losing progress.
    // Settlement happens once, when the original game allows damage again.
    if !OET_BlackwallUpload.CanExecute(target) || !IsDefined(player) {
      return;
    };
    boss = this.m_isBoss || OET_BlackwallUpload.IsBoss(target);
    if boss {
      damage = this.GetBossDamagePercent(target);
      if damage <= 0.00 {
        return;
      };
    };
    this.m_progress = 100.00;
    this.UpdateUI();
    this.Stop();
    if boss {
      this.DamageBoss(target, player, damage);
      return;
    };
    GameInstance.GetStatusEffectSystem(this.m_game).ApplyStatusEffect(target.GetEntityID(), t"BaseStatusEffect.HauntedGunBlackWallForceKill", player.GetRecordID(), player.GetEntityID());
  }

  private final func GetBossDamagePercent(target: ref<NPCPuppet>) -> Float {
    let pools: ref<StatPoolsSystem> = GameInstance.GetStatPoolsSystem(this.m_game);
    let damage: Float = this.m_bossDamagePercent;
    let maximum: Float;
    let remaining: Float;
    remaining = pools.GetStatPoolValue(Cast<StatsObjectID>(target.GetEntityID()), gamedataStatPoolType.Health, true);
    // Mirror Smasher's native Blackwall stage floors instead of crossing
    // all health-listener thresholds with one direct health-pool change.
    if StatusEffectSystem.ObjectHasStatusEffect(target, t"AdamSmasher.Phase1") {
      damage = MinF(damage, MaxF(0.00, remaining - 50.00));
    } else {
      if StatusEffectSystem.ObjectHasStatusEffect(target, t"AdamSmasher.Phase2") {
        if remaining > 30.00 {
          damage = MinF(damage, remaining - 30.00);
        } else {
          damage = MinF(damage, MaxF(0.00, remaining - 5.00));
        };
      };
    };
    if GameInstance.GetGodModeSystem(this.m_game).HasGodMode(target.GetEntityID(), gameGodModeType.Immortal) {
      maximum = pools.GetStatPoolMaxPointValue(Cast<StatsObjectID>(target.GetEntityID()), gamedataStatPoolType.Health);
      damage = MinF(damage, MaxF(0.00, remaining - 100.00 / MaxF(maximum, 1.00)));
    };
    return damage;
  }

  private final func DamageBoss(target: ref<NPCPuppet>, player: ref<PlayerPuppet>, damage: Float) -> Void {
    let pools: ref<StatPoolsSystem> = GameInstance.GetStatPoolsSystem(this.m_game);
    if !OET_BlackwallUpload.CanExecute(target) {
      return;
    };
    if damage > 0.00 {
      // Percentage of MAXIMUM HP; custom health/phase limits remain enabled.
      pools.RequestChangingStatPoolValue(Cast<StatsObjectID>(target.GetEntityID()), gamedataStatPoolType.Health, -damage, player, false, true, false);
    };
  }

  public final func Stop() -> Void {
    if this.m_stopped {
      return;
    };
    this.m_stopped = true;
    GameInstance.GetDelaySystem(this.m_game).CancelCallback(this.m_delay);
    if IsDefined(this.m_target) {
      GameInstance.GetStatPoolsSystem(this.m_game).RequestUnregisteringListener(Cast<StatsObjectID>(this.m_target.GetEntityID()), gamedataStatPoolType.Health, this.m_listener);
      this.m_target.oet_blackwallMappin = null;
      this.m_target.oet_blackwallUpload = null;
      GameInstance.GetStatusEffectSystem(this.m_game).RemoveStatusEffect(this.m_target.GetEntityID(), t"BaseStatusEffect.OET_BlackwallMark");
      GameInstance.GetStatusEffectSystem(this.m_game).RemoveStatusEffect(this.m_target.GetEntityID(), t"BaseStatusEffect.OET_BossBlackwallMark");
    };
    if this.m_nativeMappin.value != Cast<Uint64>(0u) {
      GameInstance.GetMappinSystem(this.m_game).UnregisterMappin(this.m_nativeMappin);
      this.m_nativeMappin.value = Cast<Uint64>(0u);
    };
    this.m_listener = null;
  }

  private final func UpdateUI() -> Void {
    if this.m_nativeMappin.value == Cast<Uint64>(0u) && this.m_progress < 100.00 && !this.m_stopped {
      this.CreateNativeMappin();
    };
    if IsDefined(this.m_target) && IsDefined(this.m_target.oet_blackwallMappin) {
      this.m_target.oet_blackwallMappin.OET_SetUploadProgress(true, this.GetProgress());
    };
  }

  private final func CreateNativeMappin() -> Void {
    let action: ref<PuppetAction>;
    let icon: wref<ChoiceCaptionIconPart_Record>;
    let visual: ref<OET_UploadMappinData>;
    let data: MappinData;
    if !IsDefined(this.m_target) || !IsDefined(this.m_player) {
      return;
    };
    // This is display metadata only. Never ProcessRPGAction/StartUpload:
    // the working custom countdown remains the sole owner of execution.
    action = new PuppetAction();
    action.SetExecutor(this.m_player);
    action.RegisterAsRequester(this.m_target.GetEntityID());
    action.SetObjectActionID(t"QuickHack.BlackWallHack");
    action.SetInteractionIcon(t"ChoiceCaptionParts.BlackwallBreachIcon");
    visual = new OET_UploadMappinData();
    visual.upload = this;
    visual.target = this.m_target;
    visual.statPoolType = gamedataStatPoolType.Invalid;
    visual.m_duration = this.m_duration;
    visual.m_progressBarType = EProgressBarType.UPLOAD;
    visual.m_progressBarContext = EProgressBarContext.QuickHack;
    visual.m_visibleThroughWalls = true;
    visual.m_showOnMiniMap = false;
    visual.m_action = action;
    icon = TweakDBInterface.GetChoiceCaptionIconPartRecord(t"ChoiceCaptionParts.BlackwallBreachIcon");
    if IsDefined(icon) {
      visual.m_textureID = icon.TexturePartID().GetID();
    };
    data.mappinType = t"Mappins.DeviceMappinDefinition";
    data.variant = gamedataMappinVariant.QuickHackVariant;
    data.active = true;
    data.visibleThroughWalls = true;
    data.scriptData = visual;
    this.m_nativeMappin = GameInstance.GetMappinSystem(this.m_game).RegisterMappinWithObject(data, this.m_target, this.m_target.GetQuickHackIndicatorSlotName());
  }
}

// Reuse the game's quickhack square, icon and upload animation. These mappins
// have their own IDs and data; no real quickhack pool or queue is changed.
public class OET_UploadMappinData extends GameplayRoleMappinData {
  public let upload: wref<OET_BlackwallUpload>;
  public let target: wref<NPCPuppet>;
}

@wrapMethod(QuickHackMappinController)
protected cb func OnIntro() -> Bool {
  let result: Bool = wrappedMethod();
  let data: ref<OET_UploadMappinData> = this.GetVisualData() as OET_UploadMappinData;
  if IsDefined(data) && IsDefined(data.target) && IsDefined(data.upload) {
    data.target.oet_blackwallMappin = this;
    this.OET_SetUploadProgress(true, data.upload.GetProgress());
  };
  return result;
}

@addMethod(QuickHackMappinController)
public final func OET_SetUploadProgress(visible: Bool, progress: Float) -> Void {
  let data: ref<OET_UploadMappinData> = this.GetVisualData() as OET_UploadMappinData;
  if !IsDefined(data) {
    return;
  };
  this.GetRootWidget().SetVisible(visible);
  if visible {
    this.OnStatsDataUpdated(ClampF(progress, 0.00, 100.00) / 100.00);
  };
}

@wrapMethod(QuickHackMappinController)
private final func OnStatsDataUpdated(progress: Float) -> Void {
  let data: ref<OET_UploadMappinData> = this.GetVisualData() as OET_UploadMappinData;
  if IsDefined(data) && IsDefined(data.upload) {
    wrappedMethod(data.upload.GetProgress() / 100.00);
  } else {
    wrappedMethod(progress);
  };
}

@wrapMethod(WeaponObject)
public final static func GetMagazineCapacity(self: ref<WeaponObject>) -> Uint32 {
  let capacity: Uint32 = wrappedMethod(self);
  if IsDefined(self) && ItemID.GetTDBID(self.GetItemID()) == t"Items.Finale" && capacity > 13u {
    return 13u;
  };
  return capacity;
}

// Resolve the speaker before either cinematic or chatter lines are spawned.
// Native lines may provide a name directly, without a puppet speaker, and may
// arrive after Finale is holstered. Neither case matched the old predicate.

// V6: the same haunted-gun fact can be toggled by multiple weapon packages
// during dual wielding. All Finale voice event types share one player-wide
// throttle, so two simultaneous package callbacks don't create two lines.
// This only gates Finale's chatter-trigger facts. It does not affect combat.
@addField(PlayerPuppet)
public let oet_voiceBlockUntil: Float;

public abstract class OET_VoiceGate extends IScriptable {
  public final static func Toggle(owner: ref<GameObject>, fact: CName) -> Void {
    let player: ref<PlayerPuppet>;
    let quests: ref<QuestsSystem>;
    let now: Float;
    let cooldown: Float;
    if !IsDefined(owner) {
      return;
    };
    player = GetPlayer(owner.GetGame());
    if !IsDefined(player) {
      return;
    };
    now = EngineTime.ToFloat(GameInstance.GetSimTime(owner.GetGame()));
    if now < player.oet_voiceBlockUntil {
      return;
    };
    quests = GameInstance.GetQuestsSystem(owner.GetGame());
    if !IsDefined(quests) {
      return;
    };
    // Player-wide (not per weapon/effector) so both hands share the same gate.
    cooldown = MaxF(0.20, TweakDBInterface.GetFloat(t"OET.Config.voiceCooldownSeconds", 3.50));
    player.oet_voiceBlockUntil = now + cooldown;
    // Keep native ToggleFactEffector's 0/1 edge semantics for quest dialogue.
    quests.SetFact(fact, quests.GetFact(fact) > 0 ? 0 : 1);
  }
}

public class OET_VoiceReloadEffector extends Effector {
  protected func ActionOn(owner: ref<GameObject>) -> Void {
    OET_VoiceGate.Toggle(owner, n"q305_haunted_weapon_reload");
  }
}

public class OET_VoiceMovementEffector extends Effector {
  protected func ActionOn(owner: ref<GameObject>) -> Void {
    OET_VoiceGate.Toggle(owner, n"q305_haunted_weapon_disobedience");
  }
}

public class OET_VoiceHumanKillEffector extends Effector {
  protected func ActionOn(owner: ref<GameObject>) -> Void {
    OET_VoiceGate.Toggle(owner, n"q305_haunted_weapon_npc_dead");
  }
}

public class OET_VoiceMechanicalKillEffector extends Effector {
  protected func ActionOn(owner: ref<GameObject>) -> Void {
    OET_VoiceGate.Toggle(owner, n"q305_haunted_weapon_android_dead");
  }
}

public abstract class OET_SubtitleNames extends IScriptable {
  public final static func IsHauntedGunLine(line: scnDialogLineData) -> Bool {
    let puppet: ref<gamePuppetBase> = line.speaker as gamePuppetBase;
    let supplied: String = line.speakerName;
    let nativeKey: String = LocKeyToString(TweakDBInterface.GetItemRecord(t"Items.Preset_Borg4a_HauntedGun").DisplayName());
    let nativeName: String = GetLocalizedText(nativeKey);
    if IsDefined(puppet) && puppet.GetRecordID() == t"Character.q305_haunted_gun" {
      return true;
    };
    if !IsStringValid(supplied) && IsDefined(line.speaker) {
      supplied = line.speaker.GetDisplayName();
    };
    if !IsStringValid(supplied) || !IsStringValid(nativeName) {
      return false;
    };
    return Equals(supplied, nativeKey) || Equals(supplied, "LocKey#85504") || Equals(supplied, "Erebus") || Equals(supplied, "EREBUS") || Equals(supplied, nativeName) || Equals(GetLocalizedText(supplied), nativeName);
  }

  public final static func GetFinaleNameKey(player: ref<PlayerPuppet>) -> String {
    let weapon: ref<WeaponObject>;
    let record: ref<Item_Record>;
    let equipment: ref<EquipmentSystemPlayerData>;
    let item: ItemID;
    let key: String;
    let anotherHauntedGun: Bool;
    let index: Int32;
    let slots: Int32;
    if !IsDefined(player) {
      return "";
    };
    weapon = ScriptedPuppet.GetActiveWeapon(player);
    if IsDefined(weapon) {
      record = TweakDBInterface.GetItemRecord(ItemID.GetTDBID(weapon.GetItemID()));
      if ItemID.GetTDBID(weapon.GetItemID()) == t"Items.Finale" {
        return LocKeyToString(record.DisplayName());
      };
      if IsDefined(record) && record.TagsContains(n"Haunted_Gun") {
        return "";
      };
    };
    equipment = EquipmentSystem.GetData(player);
    if !IsDefined(equipment) {
      return "";
    };
    slots = equipment.GetNumberOfSlots(gamedataEquipmentArea.Weapon, true);
    index = 0;
    while index < slots {
      item = equipment.GetItemInEquipSlot(gamedataEquipmentArea.Weapon, index);
      if ItemID.IsValid(item) {
        record = TweakDBInterface.GetItemRecord(ItemID.GetTDBID(item));
        if ItemID.GetTDBID(item) == t"Items.Finale" {
          key = LocKeyToString(record.DisplayName());
        } else {
          if IsDefined(record) && record.TagsContains(n"Haunted_Gun") {
            anotherHauntedGun = true;
          };
        };
      };
      index += 1;
    };
    return anotherHauntedGun ? "" : key;
  }
}

@wrapMethod(BaseSubtitlesGameController)
private final func SpawnDialogLine(const lineData: script_ref<scnDialogLineData>) -> Void {
  let player: ref<PlayerPuppet> = this.GetPlayerControlledObject() as PlayerPuppet;
  let nameKey: String = OET_SubtitleNames.GetFinaleNameKey(player);
  let renamedLine: scnDialogLineData;
  if IsStringValid(nameKey) && OET_SubtitleNames.IsHauntedGunLine(Deref(lineData)) {
    renamedLine = Deref(lineData);
    renamedLine.speakerName = nameKey;
    wrappedMethod(renamedLine);
    return;
  };
  wrappedMethod(lineData);
}

// The native formatter treats NAME as another localization key. Supply an
// already-resolved literal to retain the gun's exact Chinese display name.
@wrapMethod(SubtitleLineLogicController)
public func SetLineData(const lineData: script_ref<scnDialogLineData>) -> Void {
  let params: ref<inkTextParams>;
  let name: String;
  let finaleName: String = GetLocalizedText("LocKey#oet_name");
  wrappedMethod(lineData);
  if IsStringValid(Deref(lineData).speakerName) {
    name = GetLocalizedText(Deref(lineData).speakerName);
    if IsStringValid(finaleName) && Equals(name, finaleName) {
      params = new inkTextParams();
      params.SetAsyncFormat(false);
      params.AddString("NAME", name);
      inkTextRef.SetLocalizedTextScript(this.m_speakerNameWidget, "LocKey#76968", params);
      inkTextRef.SetLocalizedTextScript(this.m_radioSpeaker, "LocKey#76968", params);
    };
  };
}

// Use the native Erebus recipe for both displayed and consumed ingredients.
// Its Random quality controls level-based recipe additions only; Finale's
// crafted quality and the separate upgrade-cost path remain unchanged.
@wrapMethod(CraftingSystem)
public final const func GetItemCraftingCost(itemRecord: wref<Item_Record>) -> [IngredientData] {
  let erebusRecord: wref<Item_Record>;
  if IsDefined(itemRecord) && itemRecord.GetID() == t"Items.Finale" {
    erebusRecord = TweakDBInterface.GetItemRecord(t"Items.Preset_Borg4a_HauntedGun");
    if IsDefined(erebusRecord) {
      return wrappedMethod(erebusRecord);
    };
  };
  return wrappedMethod(itemRecord);
}
