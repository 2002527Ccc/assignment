-- Pure progress accounting shared by cooldown and weapon-pool correction.
-- Does not modify regeneration/decay modifiers, duration records, or base stats.
local M = {}
local EPS = 0.0001

function M.pool(previous, current, dt)
  if not previous or dt <= 0 or dt > 0.5 then return 0 end
  if not current.enabled or current.decaying or current.points then return 0 end
  if not previous.enabled or previous.decaying or previous.points then return 0 end
  if current.rate <= 0 or math.abs(current.rate - previous.rate) > EPS then return 0 end
  if current.limit <= current.value + EPS then return 0 end
  local natural = current.value - previous.value
  -- A use/reset or a regeneration delay is not elapsed cooldown progress.
  if natural <= EPS then return 0 end
  local expected = current.rate * dt
  -- Already real-time (or accelerated by another mod): no correction.
  local missing = math.max(0, expected - natural)
  -- At 0.4 world speed, at most 1.5 extra per observed unit of progress.
  -- This bound preserves partial-interval regen starts and interruptions.
  return math.max(0, math.min(missing, 1.5 * natural, current.limit - current.value))
end

function M.status(previous, current, dt)
  if not previous or dt <= 0 or dt > 0.5 then return 0 end
  if previous.token ~= current.token then return 0 end
  if current.remaining <= 0 or previous.remaining <= current.remaining then return 0 end
  local natural = previous.remaining - current.remaining
  if natural > dt * 3 + 0.01 then return 0 end -- reset/foreign duration edit
  return math.max(0, math.min(dt - natural, 1.5 * natural, current.remaining - 0.001))
end

return M
