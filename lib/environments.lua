local Environments = {}

Environments.data = {
    forest = {
        base_fc = 12000, mod_fc = 8000,
        base_rq = 2.0, mod_rq = 4.0,
        gain_scale = 0.8
    },
    deep_sea = {
        base_fc = 800, mod_fc = 600,
        base_rq = 5.0, mod_rq = 2.0,
        gain_scale = 0.4
    }
}

function Environments.get_params(env_name, pressure, layer_idx)
    local d = Environments.data[env_name]
    local p_sq = pressure * pressure
    
    return {
        cutoff = d.base_fc - (p_sq * d.mod_fc),
        rq = d.base_rq + (p_sq * d.mod_rq),
        gain = d.gain_scale - (pressure * 0.2)
    }
end

function Environments.get_random_event(env_name, pressure)
    if pressure > 0.8 and math.random() < 0.01 then
        return {type = "dropout", duration = 0.1}
    end
    return nil
end

return Environments
