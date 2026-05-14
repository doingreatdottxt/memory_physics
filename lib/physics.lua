local Physics = {}

-- Initial defaults (overridden by params)
Physics.SILENCE_THRESHOLD = 0.02 

function Physics.calculate_layer_depth(i, total_active)
    if total_active <= 1 then return i == 1 and 0 or 1 end
    return (i - 1) / (total_active - 1)
end

function Physics.process_silence(input_level, dt, timer, limit)
    if input_level < Physics.SILENCE_THRESHOLD then
        timer = timer + dt
    else
        timer = 0
    end
    
    local trigger = false
    if timer > limit then
        trigger = true
        timer = 0 
    end
    
    return trigger, timer
end

function Physics.interpolate(current, target, amt)
    return current + (target - current) * amt
end
-- Add to lib/physics.lua

function Physics.get_beat_sec()
    return 60 / params:get("bpm")
end

function Physics.snap_to_beat(time_elapsed, quantize_div)
    local beat_sec = Physics.get_beat_sec()
    local interval = beat_sec * (quantize_div or 1) -- default to 1 beat
    
    -- Round to the nearest interval
    local snapped = math.max(interval, math.floor((time_elapsed / interval) + 0.5) * interval)
    return snapped
end
return Physics
