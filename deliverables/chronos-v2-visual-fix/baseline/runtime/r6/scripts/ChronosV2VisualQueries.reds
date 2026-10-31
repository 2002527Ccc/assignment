// V2 optional camera-grade resource inspection; no cached resource mutations.
public class ChronosV2VisualTarget {
  public let name: CName;
  public let path: ResRef;
}

public class ChronosV2VisualQueries {
  public static func VisualTargets(owner: ref<GameObject>) -> array<ref<ChronosV2VisualTarget>> {
    let names: array<CName>;
    let result: array<ref<ChronosV2VisualTarget>>;
    let ids: array<TweakDBID>;
    ArrayPush(ids, t"BaseStatusEffect.SandevistanPlayerBuff");
    ArrayPush(ids, t"BaseStatusEffect.CooldownedSandevistanPlayerBuff");
    for id in ids {
      let record = TweakDBInterface.GetStatusEffectRecord(id);
      let list: array<wref<StatusEffectFX_Record>>;
      if IsDefined(record) {
        record.VFX(list);
        for fx in list {
          if IsDefined(fx) && !ArrayContains(names, fx.Name()) { ArrayPush(names, fx.Name()); }
        }
      }
    }
    let components = owner.GetComponents();
    for component in components {
      let spawner = component as entEffectSpawnerComponent;
      if IsDefined(spawner) {
        for desc in spawner.effectDescs {
          if IsDefined(desc) && ArrayContains(names, desc.effectName) && !ResourceAsyncRef.IsEmpty(desc.effect) {
            let target = new ChronosV2VisualTarget();
            target.name = desc.effectName;
            target.path = ResourceAsyncRef.GetPath(desc.effect);
            ArrayPush(result, target);
          }
        }
      }
    }
    return result;
  }

  private static func TrackHasGrade(node: ref<effectTrackBase>, depth: Int32) -> Bool {
    if !IsDefined(node) || depth > 24 { return false; }
    let group = node as effectTrackGroup;
    if IsDefined(group) {
      for child in group.tracks {
        if ChronosV2VisualQueries.TrackHasGrade(child, depth + 1) { return true; }
      }
    }
    let track = node as effectTrack;
    if IsDefined(track) {
      for item in track.items {
        if IsDefined(item as effectTrackItemColorGrade) || IsDefined(item as effectTrackItemColorGradeV2) { return true; }
      }
    }
    return false;
  }

  public static func ResourceHasGrade(resource: ref<CResource>) -> Bool {
    let effect = resource as worldEffect;
    if !IsDefined(effect) { return false; }
    for item in effect.events {
      if IsDefined(item as effectTrackItemColorGrade) || IsDefined(item as effectTrackItemColorGradeV2) { return true; }
    }
    return ChronosV2VisualQueries.TrackHasGrade(effect.trackRoot, 0);
  }

  public static func StopVisual(owner: ref<GameObject>, name: CName) -> Void {
    GameObjectEffectHelper.StopEffectEvent(owner, name);
  }

  public static func RestoreVisual(owner: ref<GameObject>, name: CName) -> Void {
    GameObjectEffectHelper.StartEffectEvent(owner, name);
  }
}
