local Physics = {}

function Physics.calculate_layer_depth(i, active_layers)
    if active_layers <= 1 then return 0 end
    return 0.25 + ((i - 1) / (active_layers - 1) * 0.75)
end

function Physics.update_pressure_memory(current, target, rate)
    return util.clamp(current + (target * rate), 0, 1)
end

function Physics.calculate_decay_chance(i, excavation_pressure)
    return 0.08 + (i * 0.08) + (excavation_pressure * 0.2)
end

return Physics
