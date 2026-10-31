// Additive V2 queries only. R1b bridge, OS records and state machine are unchanged.
// Interfaces checked against NativeDB RTTI labelled Cyberpunk 2077 2.5 and Codeware.
public class ChronosV2Status {
  public let id: TweakDBID;
  public let remaining: Float;
  public let stamp: Float;
  public let stacks: Uint32;
  public let affected: Bool;
  public let tagged: Bool;
}

public class ChronosV2Queries {
  public static func PoolDelayed(owner: ref<GameObject>, kind: gamedataStatPoolType) -> Bool {
    return GameInstance.GetStatPoolsSystem(owner.GetGame()).IsStatPoolModificationDelayed(ChronosBridge.StatsID(owner), kind);
  }

  public static func PoolToPercent(owner: ref<GameObject>, kind: gamedataStatPoolType, value: Float) -> Float {
    let pools = GameInstance.GetStatPoolsSystem(owner.GetGame());
    let id = ChronosBridge.StatsID(owner);
    if pools.GetStatPoolMaxPointValue(id, kind) <= 0.0 { return 0.0; }
    return pools.ToPercentage(id, kind, value);
  }

  public static func CooldownStat(id: TweakDBID) -> Bool {
    return Equals(id, t"BaseStats.KerenzikovCooldownDuration")
      || Equals(id, t"BaseStats.SecondHeartCooldownDuration")
      || Equals(id, t"BaseStats.TimeDilationOnHealthDropCooldownDuration")
      || Equals(id, t"BaseStats.TimeDilationOnDodgesCooldownDuration")
      || Equals(id, t"BaseStats.TimeDilationWhenEnteringCombatCooldownDuration")
      || Equals(id, t"BaseStats.HolographicSkinCooldownDuration")
      || Equals(id, t"BaseStats.MemoryTrackerCooldownDuration");
  }

  private static func DurationGroupMatches(group: wref<StatModifierGroup_Record>, depth: Int32) -> Bool {
    if !IsDefined(group) || depth > 4 { return false; }
    let modifiers: array<wref<StatModifier_Record>>;
    let related: array<wref<StatModifierGroup_Record>>;
    group.StatModifiers(modifiers);
    for modifier in modifiers {
      if IsDefined(modifier) {
        let stat = modifier.StatType();
        if IsDefined(stat) && ChronosV2Queries.CooldownStat(stat.GetID()) { return true; }
        let combined = modifier as CombinedStatModifier_Record;
        if IsDefined(combined) {
          let source = combined.RefStat();
          if IsDefined(source) && ChronosV2Queries.CooldownStat(source.GetID()) { return true; }
        }
      }
    }
    group.RelatedModifierGroups(related);
    for child in related {
      if ChronosV2Queries.DurationGroupMatches(child, depth + 1) { return true; }
    }
    return false;
  }

  public static func Statuses(owner: ref<GameObject>) -> array<ref<ChronosV2Status>> {
    let effects: array<ref<StatusEffect>>;
    let result: array<ref<ChronosV2Status>>;
    GameInstance.GetStatusEffectSystem(owner.GetGame()).GetAppliedEffects(owner.GetEntityID(), effects);
    for effect in effects {
      if IsDefined(effect) {
        let record = effect.GetRecord();
        if IsDefined(record) {
          let snapshot = new ChronosV2Status();
          snapshot.id = record.GetID();
          snapshot.remaining = effect.GetRemainingDuration();
          snapshot.stamp = EngineTime.ToFloat(effect.GetLastApplicationSimTimestamp());
          snapshot.stacks = effect.GetStackCount();
          snapshot.affected = record.IsAffectedByTimeDilationPlayer();
          let tags = record.GameplayTags();
          snapshot.tagged = ArrayContains(tags, n"PlayerCyberwareCooldown");
          ArrayPush(result, snapshot);
        }
      }
    }
    return result;
  }

  public static func RecordUsesCooldownStat(id: TweakDBID) -> Bool {
    let record = TweakDBInterface.GetStatusEffectRecord(id);
    return IsDefined(record) && ChronosV2Queries.DurationGroupMatches(record.Duration(), 0);
  }

}
