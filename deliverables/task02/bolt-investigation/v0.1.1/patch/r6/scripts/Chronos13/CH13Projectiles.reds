// CHRONOS Model 13 V0.3 EXPERIMENTAL: own-projectile freeze at 3.5m.
// Original implementation. No copyrighted third-party script or asset bundled.
// Only ordinary linear projectile instances from V. Does NOT convert hitscan weapons.
// TEST IN A THROWAWAY SAVE. Runtime API/compilation not verified in game 2.5.

@addField(sampleBullet) public let m_ch13OwnerV: Bool;
@addField(sampleBullet) public let m_ch13Frozen: Bool;
@addField(sampleBullet) public let m_ch13EverFrozen: Bool;
@addField(sampleBullet) public let m_ch13OriginalVelocity: Float;
@addField(sampleBullet) public let m_ch13OriginalLifetime: Float;
@addField(sampleBullet) public let m_ch13Dirty: Bool;

@addField(sampleBulletGeneric) public let m_ch13OwnerV: Bool;
@addField(sampleBulletGeneric) public let m_ch13Frozen: Bool;
@addField(sampleBulletGeneric) public let m_ch13EverFrozen: Bool;
@addField(sampleBulletGeneric) public let m_ch13OriginalVelocity: Float;
@addField(sampleBulletGeneric) public let m_ch13OriginalLifetime: Float;
@addField(sampleBulletGeneric) public let m_ch13Dirty: Bool;

public func CH13_FieldEnabled(v: ref<PlayerPuppet>) -> Bool {
  return IsDefined(v) && CH13Bridge.IsNativeActive(v);
}

public func CH13_OutsideField(v: ref<PlayerPuppet>, position: Vector4) -> Bool {
  if !IsDefined(v) { return false; }
  return Vector4.Distance(v.GetWorldPosition(), position) > 3.5;
}

// Freeze exactly once; never reactivate because V walks close to an already frozen bullet.
@addMethod(sampleBullet)
public final func CH13_Freeze() -> Void {
  if this.m_ch13Frozen { return; }
  this.m_ch13OriginalVelocity = this.m_startVelocity;
  this.m_ch13OriginalLifetime = this.m_lifetime;
  this.m_ch13Dirty = true;
  this.m_ch13Frozen = true;
  this.m_ch13EverFrozen = true;
  this.m_startVelocity = 0.0;
  let linear: ref<LinearTrajectoryParams> = new LinearTrajectoryParams();
  linear.startVel = 0.0;
  this.m_projectileComponent.ClearTrajectories();
  this.m_projectileComponent.AddLinear(linear);
}

@addMethod(sampleBullet)
public final func CH13_Thaw() -> Void {
  if !this.m_ch13Frozen { return; }
  this.m_ch13Frozen = false;
  this.m_startVelocity = this.m_ch13OriginalVelocity;
  let linear: ref<LinearTrajectoryParams> = new LinearTrajectoryParams();
  linear.startVel = this.m_ch13OriginalVelocity;
  this.m_projectileComponent.ClearTrajectories();
  this.m_projectileComponent.AddLinear(linear);
}

@wrapMethod(sampleBullet)
protected cb func OnProjectileInitialize(eventData: ref<gameprojectileSetUpEvent>) -> Bool {
  if this.m_ch13Dirty {
    this.m_startVelocity = this.m_ch13OriginalVelocity;
    this.m_lifetime = this.m_ch13OriginalLifetime;
    this.m_ch13Dirty = false;
  }
  let r: Bool = wrappedMethod(eventData);
  let player: ref<PlayerPuppet> = GetPlayer(this.GetGame());
  this.m_ch13OwnerV = IsDefined(player) && IsDefined(eventData.owner) && eventData.owner == player;
  if this.m_ch13OwnerV { player.m_ch13ProjectileSeen += 1; }
  this.m_ch13Frozen = false;
  this.m_ch13EverFrozen = false;
  // TASK02: initialization telemetry only; no trajectory or lifecycle changes.
  if this.m_ch13OwnerV && player.m_ch13FDEnabled {
    CH13FD.Projectile(player, this, eventData.owner, this.m_startVelocity, this.m_lifetime, n"sampleBullet");
  }
  return r;
}

@wrapMethod(sampleBullet)
protected cb func OnTick(eventData: ref<gameprojectileTickEvent>) -> Bool {
  if this.m_ch13OwnerV && this.m_alive {
    if this.m_ch13Frozen {
      if !CH13_FieldEnabled(GetPlayer(this.GetGame())) {
        this.CH13_Thaw();
        let diagP: ref<PlayerPuppet> = GetPlayer(this.GetGame());
        if IsDefined(diagP) { diagP.m_ch13ProjectileThawed += 1; }
      } else {
        // Prevent expiry while frozen; the pool reset code restores original lifetime.
        this.m_countTime = 0.0;
      }
    } else {
      if !this.m_ch13EverFrozen && CH13_FieldEnabled(GetPlayer(this.GetGame()))
        && CH13_OutsideField(GetPlayer(this.GetGame()), this.GetWorldPosition()) {
        this.CH13_Freeze();
        let diagP: ref<PlayerPuppet> = GetPlayer(this.GetGame());
        if IsDefined(diagP) { diagP.m_ch13ProjectileFrozen += 1; }
        this.m_countTime = 0.0;
      }
    }
  }
  return wrappedMethod(eventData);
}

@addMethod(sampleBulletGeneric)
public final func CH13_Freeze() -> Void {
  if this.m_ch13Frozen { return; }
  this.m_ch13OriginalVelocity = this.m_startVelocity;
  this.m_ch13OriginalLifetime = this.m_lifetime;
  this.m_ch13Dirty = true;
  this.m_ch13Frozen = true;
  this.m_ch13EverFrozen = true;
  this.m_startVelocity = 0.0;
  let linear: ref<LinearTrajectoryParams> = new LinearTrajectoryParams();
  linear.startVel = 0.0;
  this.m_projectileComponent.ClearTrajectories();
  this.m_projectileComponent.AddLinear(linear);
}

@addMethod(sampleBulletGeneric)
public final func CH13_Thaw() -> Void {
  if !this.m_ch13Frozen { return; }
  this.m_ch13Frozen = false;
  this.m_startVelocity = this.m_ch13OriginalVelocity;
  let linear: ref<LinearTrajectoryParams> = new LinearTrajectoryParams();
  linear.startVel = this.m_ch13OriginalVelocity;
  this.m_projectileComponent.ClearTrajectories();
  this.m_projectileComponent.AddLinear(linear);
}

@wrapMethod(sampleBulletGeneric)
protected cb func OnProjectileInitialize(eventData: ref<gameprojectileSetUpEvent>) -> Bool {
  if this.m_ch13Dirty {
    this.m_startVelocity = this.m_ch13OriginalVelocity;
    this.m_lifetime = this.m_ch13OriginalLifetime;
    this.m_ch13Dirty = false;
  }
  let r: Bool = wrappedMethod(eventData);
  let player: ref<PlayerPuppet> = GetPlayer(this.GetGame());
  this.m_ch13OwnerV = IsDefined(player) && IsDefined(eventData.owner) && eventData.owner == player;
  if this.m_ch13OwnerV { player.m_ch13ProjectileSeen += 1; }
  this.m_ch13Frozen = false;
  this.m_ch13EverFrozen = false;
  // TASK02: initialization telemetry only; no trajectory or lifecycle changes.
  if this.m_ch13OwnerV && player.m_ch13FDEnabled {
    CH13FD.Projectile(player, this, eventData.owner, this.m_startVelocity, this.m_lifetime, n"sampleBulletGeneric");
  }
  return r;
}

@wrapMethod(sampleBulletGeneric)
protected cb func OnTick(eventData: ref<gameprojectileTickEvent>) -> Bool {
  if this.m_ch13OwnerV && this.m_alive {
    if this.m_ch13Frozen {
      if !CH13_FieldEnabled(GetPlayer(this.GetGame())) {
        this.CH13_Thaw();
        let diagP: ref<PlayerPuppet> = GetPlayer(this.GetGame());
        if IsDefined(diagP) { diagP.m_ch13ProjectileThawed += 1; }
      } else {
        this.m_countTime = 0.0;
      }
    } else {
      if !this.m_ch13EverFrozen && CH13_FieldEnabled(GetPlayer(this.GetGame()))
        && CH13_OutsideField(GetPlayer(this.GetGame()), this.GetWorldPosition()) {
        this.CH13_Freeze();
        let diagP: ref<PlayerPuppet> = GetPlayer(this.GetGame());
        if IsDefined(diagP) { diagP.m_ch13ProjectileFrozen += 1; }
        this.m_countTime = 0.0;
      }
    }
  }
  return wrappedMethod(eventData);
}
