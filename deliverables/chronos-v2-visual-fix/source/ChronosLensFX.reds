// CHRONOS-only visual registration. No combat/state-machine replacements.
// ResourceAsyncRef/ResRef and descriptor field types checked against 2.5 RTTI.
public class ChronosLensFX {
  public static func Name(index: Int32) -> CName {
    if index == 0 { return n"ch13_lens_radial_blur"; }
    if index == 1 { return n"ch13_lens_outlines"; }
    return n"ch13_lens_flash";
  }

  public static func Path(index: Int32) -> ResRef {
    if index == 0 { return ResRef.FromString("ch13\\fx\\player\\time_dilation_vfx_radial_blur.effect"); }
    if index == 1 { return ResRef.FromString("ch13\\fx\\player\\time_dilation_vfx_outlines.effect"); }
    return ResRef.FromString("ch13\\fx\\player\\time_dilation_vfx_flash.effect");
  }

  // Count by unique expected name AND resource hash, not Lua stringification.
  public static func Registered(owner: ref<GameObject>) -> Int32 {
    let count: Int32 = 0;
    let index: Int32 = 0;
    let fx: ref<entEffectSpawnerComponent>;
    if !IsDefined(owner) { return 0; }
    fx = owner.FindComponentByName(n"fx_player") as entEffectSpawnerComponent;
    if !IsDefined(fx) { return 0; }
    while index < 3 {
      for desc in fx.effectDescs {
        if IsDefined(desc) && Equals(desc.effectName, ChronosLensFX.Name(index))
          && !ResourceAsyncRef.IsEmpty(desc.effect)
          && ResourceAsyncRef.GetHash(desc.effect) == ResRef.GetHash(ChronosLensFX.Path(index)) {
          count += 1;
          break;
        }
      }
      index += 1;
    }
    return count;
  }

  public static func Register(owner: ref<GameObject>) -> Int32 {
    let index: Int32 = 0;
    let found: Bool;
    let fx: ref<entEffectSpawnerComponent>;
    let entry: ref<entEffectDesc>;
    if !IsDefined(owner as PlayerPuppet) { return 0; }
    fx = owner.FindComponentByName(n"fx_player") as entEffectSpawnerComponent;
    if !IsDefined(fx) { return 0; }
    while index < 3 {
      found = false;
      for desc in fx.effectDescs {
        if IsDefined(desc) && Equals(desc.effectName, ChronosLensFX.Name(index)) {
          ResourceAsyncRef.SetPath(desc.effect, ChronosLensFX.Path(index));
          found = true;
          break;
        }
      }
      if !found {
        entry = new entEffectDesc();
        entry.effectName = ChronosLensFX.Name(index);
        ResourceAsyncRef.SetPath(entry.effect, ChronosLensFX.Path(index));
        ArrayPush(fx.effectDescs, entry);
      }
      index += 1;
    }
    // A native field read-back, not a claim that the renderer rebuilt its cache.
    return ChronosLensFX.Registered(owner);
  }

  public static func NativeTargets(owner: ref<GameObject>) -> array<ref<ChronosV2VisualTarget>> {
    let result: array<ref<ChronosV2VisualTarget>>;
    let fx: ref<entEffectSpawnerComponent>;
    let present: Bool;
    let target: ref<ChronosV2VisualTarget>;
    if !IsDefined(owner) { return result; }
    result = ChronosV2VisualQueries.VisualTargets(owner);
    fx = owner.FindComponentByName(n"fx_player") as entEffectSpawnerComponent;
    if IsDefined(fx) {
      for desc in fx.effectDescs {
        if IsDefined(desc) && Equals(desc.effectName, n"time_dilation_vfx") && !ResourceAsyncRef.IsEmpty(desc.effect) {
          present = false;
          for item in result { if Equals(item.name, desc.effectName) { present = true; } }
          if !present {
            target = new ChronosV2VisualTarget();
            target.name = desc.effectName;
            target.path = ResourceAsyncRef.GetPath(desc.effect);
            ArrayPush(result, target);
          }
        }
      }
    }
    return result;
  }

  public static func Play(owner: ref<GameObject>, name: CName) -> Bool {
    if !ChronosBridge.IsRunning(owner) { return false; }
    if Equals(name, n"ch13_lens_radial_blur") || Equals(name, n"ch13_lens_outlines") || Equals(name, n"ch13_lens_flash") {
      GameObjectEffectHelper.StartEffectEvent(owner, name, true);
      return true;
    }
    return false;
  }

  public static func StopOwn(owner: ref<GameObject>, name: CName) -> Void {
    if !IsDefined(owner) { return; }
    if Equals(name, n"ch13_lens_radial_blur") || Equals(name, n"ch13_lens_outlines") || Equals(name, n"ch13_lens_flash") {
      GameObjectEffectHelper.BreakEffectLoopEvent(owner, name);
      GameObjectEffectHelper.StopEffectEvent(owner, name);
    }
  }

  public static func SuppressGrade(owner: ref<GameObject>, name: CName) -> Bool {
    // Caller supplies only a descriptor whose loaded resource was inspected.
    if !ChronosBridge.IsRunning(owner) { return false; }
    GameObjectEffectHelper.StopEffectEvent(owner, name);
    return true;
  }
}
