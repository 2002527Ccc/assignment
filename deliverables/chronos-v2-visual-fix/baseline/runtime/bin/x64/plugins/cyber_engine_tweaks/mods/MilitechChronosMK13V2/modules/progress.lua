local M = {}
local EPS = 0.00001
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
function M.validDelta(dt, maximum)
  return type(dt) == "number" and dt == dt and dt > 0 and dt <= maximum
end

function M.pool(previous, now, dt, maximum)
  if not M.validDelta(dt, maximum) or not previous then return 0 end
  if not finite(now.value) or not finite(now.rate) or not finite(now.limit)
    or not finite(previous.value) or not finite(previous.rate) or not finite(previous.limit) then return 0 end
  if not now.enabled or now.delayed or now.decaying or not previous.enabled
    or previous.delayed or previous.decaying then return 0 end
  if now.rate <= 0 or math.abs(now.rate - previous.rate) > EPS
    or math.abs(now.limit - previous.limit) > EPS then return 0 end
  local natural = now.value - previous.value
  if natural <= EPS or now.value >= now.limit - EPS then return 0 end
  -- Detect already-real-time progress. No permanent 2.5x stat modifier.
  local deficit = now.rate * dt - natural
  return math.max(0, math.min(deficit, natural * 1.5, now.limit - now.value))
end

function M.status(previous, now, dt, maximum)
  if not M.validDelta(dt, maximum) or not previous or not now.affected then return 0 end
  if not finite(now.remaining) or not finite(previous.remaining) then return 0 end
  if previous.stamp ~= now.stamp or previous.stacks ~= now.stacks then return 0 end
  local natural = previous.remaining - now.remaining
  if natural <= EPS or natural > dt * 3 + 0.01 or now.remaining <= 0.001 then return 0 end
  return math.max(0, math.min(dt - natural, natural * 1.5, now.remaining - 0.001))
end
return M
