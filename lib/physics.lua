local Physics = {}

function Physics.get_beat_sec()
  local tempo = params:get("clock_tempo") or 120
  return 60 / tempo
end

function Physics.snap_to_interval(duration, interval)
  if interval <= 0 then return duration end
  return math.max(interval, math.floor((duration / interval) + 0.5) * interval)
end

function Physics.calculate_layer_depth(i, total_active)
  if total_active <= 1 then return 0 end
  return (i - 1) / (total_active - 1)
end

function Physics.process_silence(input_level, dt, timer, limit)
  if input_level < 0.02 then
    timer = timer + dt
  else
    timer = 0
  end
  local trigger = (timer > limit)
  if trigger then timer = 0 end
  return trigger, timer
end

function Physics.interpolate(current, target, amt)
  return current + (target - current) * amt
end

return Physics
