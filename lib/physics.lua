local Physics = {}

function Physics.calculate_layer_depth(idx, active_count)
  return (idx - 1) / (active_count - 1)
end

function Physics.interpolate(current, target, rate)
  return current + (target - current) * rate
end

function Physics.process_silence(amp, threshold, timer, max_time)
  if amp < threshold then
    timer = timer + (1/15)
    if timer >= max_time then return true, 0 end
  else
    timer = 0
  end
  return false, timer
end

function Physics.get_beat_sec()
  local bpm = params:get("clock_tempo") or 120
  return 60 / bpm
end

function Physics.snap_to_interval(duration, interval)
  return math.max(interval, math.floor((duration / interval) + 0.5) * interval)
end

-- BAR MODE: Snaps to bedrock fractions (0.25x, 0.5x) or multiples (1x, 2x, 3x)
function Physics.snap_to_bedrock(duration, bedrock)
  if bedrock <= 0 then return duration end
  local ratio = duration / bedrock
  
  if ratio >= 1 then
    return math.floor(ratio + 0.5) * bedrock
  else
    if ratio < 0.375 then return bedrock * 0.25
    elseif ratio < 0.75 then return bedrock * 0.5
    else return bedrock end
  end
end

return Physics
