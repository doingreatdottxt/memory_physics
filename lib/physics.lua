local Physics = {}

function Physics.calculate_layer_depth(i, total_active)
    if total_active <= 1 then return i == 1 and 1 or 0 end
    return (i - 1) / (total_active - 1)
end

function Physics.interpolate(current, target, amt)
    return current + (target - current) * amt
end

function Physics.get_decay_rate(pressure)
    -- Higher pressure = faster "erosion" of the sound
    return 0.01 + (pressure * 0.05)
end

return Physics
