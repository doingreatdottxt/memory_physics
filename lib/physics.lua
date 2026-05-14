local Physics = {}

function Physics.calculate_layer_depth(i, total_active)
  return (i - 1) / (total_active - 1)
end

function Physics.process_silence(input_level, dt, timer, limit)
  -- If input is below threshold, increment timer
  if input_level < 0.025 then 
    timer = timer + dt
  else
    timer = 0
  end
  
  local triggered = (timer > limit)
  if triggered then timer = 0 end
  return triggered, timer
end

function Physics.interpolate(current, target, amt)
  return current + (target - current) * amt
end

return Physics
