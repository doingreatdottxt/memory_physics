local Physics = {}
Physics.SILENCE_THRESHOLD = 0.02 

function Physics.get_beat_sec()
    return 60 / params:get("bpm")
end

function Physics.snap_to_interval(duration, interval)
    if interval <= 0 then return duration end
    local snapped = math.max(interval, math.floor((duration / interval) + 0.5) * interval)
    return snapped
end

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

return Physics
