local Progress = require("modules/progress")
local Cooldowns = {}
Cooldowns.__index = Cooldowns
local candidates={
  ["BaseStatusEffect.KerenzikovCooldown"]=true,
  ["BaseStatusEffect.SecondHeartCooldown"]=true,
  ["BaseStatusEffect.SynapticAcceleratorCooldown"]=true,
  ["BaseStatusEffect.ReflexRecorderCooldown"]=true,
  ["BaseStatusEffect.AutomaticReplenishmentCooldown"]=true,
  ["BaseStatusEffect.ElectroshockMechanismCooldown"]=true,
  ["BaseStatusEffect.IconicCyberwareCooldown"]=true,
  ["BaseStatusEffect.SuddenAidCooldown"]=true,
  ["BaseStatusEffect.ProjectileLauncherCooldown"]=true,
  ["BaseStatusEffect.OpticalCamo_Cool_40_Cooldown"]=true,
}
local forbidden={
  ["BaseStatusEffect.SandevistanCooldown"]=true,
  ["BaseStatusEffect.SandevistanPlayerBuff"]=true,
  ["BaseStatusEffect.CooldownedSandevistanPlayerBuff"]=true,
  ["BaseStatusEffect.NoSandevistanGlitch"]=true,
  ["BaseStatusEffect.NoCooldownedSandevistanGlitch"]=true,
}
Cooldowns.namedCandidates=candidates
function Cooldowns.new(api,config)
  return setmetatable({api=api,config=config,metadata={}},Cooldowns)
end
function Cooldowns:start(owner) self:stop();self.owner=owner end
function Cooldowns:stop() self.owner=nil;self.pools={};self.statuses={};self.elapsed=0 end
function Cooldowns:classify(now)
  if now.own or forbidden[now.name] or now.name:find("Sandevistan",1,true)
    or self.config.excludedStatuses[now.name] or self.config.excludedStatuses[now.key] then return false end
  local known=self.metadata[now.key]
  if known==nil then
    known=now.tagged or now.nativeCandidate or candidates[now.name] or self.api.durationUsesCooldown(now.id)
    self.metadata[now.key]=not not known
    if self.config.debug and known then self.api.log("cooldown candidate: "..now.name) end
  end
  return known and now.affected
end
function Cooldowns:tick(owner,dt)
  if not Progress.validDelta(dt,self.config.maxObservationGap) then self:stop();self.owner=owner;return end
  self.elapsed=self.elapsed+dt
  if self.elapsed<self.config.sampleInterval then return end
  local elapsed=self.elapsed;self.elapsed=0
  for _,kind in ipairs(self.config.pools) do
    assert(kind~="SandevistanCharge" and kind~="Health" and kind~="TimeBank","Forbidden pool")
    if not self.config.excludedPools[kind] then
      local now=self.api.pool(owner,kind)
      if now then
        local extra=Progress.pool(self.pools[kind],now,elapsed,self.config.maxObservationGap)
        if extra>0.00001 then
          self.api.changePool(owner,kind,extra,owner);now.value=now.value+extra;self.api.count("pool:"..kind)
        end
      end
      self.pools[kind]=now
    end
  end
  local nextStatuses={}
  for _,now in ipairs(self.api.statuses(owner)) do
    if self:classify(now) then
      local extra=Progress.status(self.statuses[now.key],now,elapsed,self.config.maxObservationGap)
      if extra>0.00001 and self.api.duration(owner,now.id,now.remaining-extra) then
        now.remaining=now.remaining-extra;self.api.count("status:"..now.name)
      end
      nextStatuses[now.key]=now
    end
  end
  self.statuses=nextStatuses
end
return Cooldowns
