local Environments = {}

Environments.list = {"sand", "mountain", "grove", "river_bank", "sea", "cave", "swamp"}

Environments.data = {
  sand = { base_fc = 16000, mod_fc = 15500, base_rq = 1.5, mod_rq = 6.0, drift = 0.08 },
  mountain = { base_fc = 4000, mod_fc = 3800, base_rq = 2.0, mod_rq = 12.0, drift = 0.02 },
  grove = { base_fc = 8000, mod_fc = 7500, base_rq = 1.2, mod_rq = 3.0, drift = 0.005 },
  river_bank = { base_fc = 12000, mod_fc = 11000, base_rq = 1.0, mod_rq = 2.5, drift = 0.01 },
  sea = { base_fc = 5000, mod_fc = 4600, base_rq = 1.5, mod_rq = 8.0, drift = 0.04 },
  cave = { base_fc = 3500, mod_fc = 3200, base_rq = 0.8, mod_rq = 15.0, drift = 0.03 },
  swamp = { base_fc = 1800, mod_fc = 1600, base_rq = 2.5, mod_rq = 7.0, drift = 0.06 }
}

function Environments.get_params(env_name, pressure, layer_idx, weather)
    local d = Environments.data[env_name] or Environments.data["grove"]
    local p_sq = pressure * pressure
    
    -- Weather dampening: 50% reduction per layer depth
    local layer_weather = weather * (0.5 ^ (layer_idx - 1))
    
    local cutoff = 0
    local gain_mod = 0
    
    if env_name == "sand" or env_name == "mountain" then
        cutoff = math.max(40, d.base_fc - (pressure * d.mod_fc))
    elseif env_name == "river_bank" then
        gain_mod = math.sin(pressure * math.pi) * 0.2
        cutoff = d.base_fc - (p_sq * d.mod_fc)
    elseif env_name == "cave" then
        cutoff = d.base_fc - (p_sq * d.mod_fc)
        if pressure > 0.7 then gain_mod = -(math.random() * (pressure * 0.3)) end
    else
        cutoff = d.base_fc - (p_sq * d.mod_fc)
    end

    return {
        cutoff = math.max(20, math.min(20000, cutoff)),
        rq = d.base_rq + (p_sq * d.mod_rq),
        gain = (0.9 + gain_mod) - (pressure * 0.4),
        rate = 1.0 + (math.sin(util.time() * (d.drift * 25)) * (layer_weather * d.drift)),
        pan_width = 1.0 - (pressure * 0.8)
    }
end

function Environments.get_random_event(env_name, pressure, layer_idx, weather)
    local layer_weather = weather * (0.5 ^ (layer_idx - 1))
    if math.random() > (layer_weather * 0.2) then return nil end

    if env_name == "swamp" then
        return {type = "bubble_pop", rate_shift = 0.8 + (math.random() * 0.4)}
    elseif env_name == "cave" then
        return {type = "drip", fc = 4000 + math.random(2000)}
    elseif env_name == "sea" and pressure > 0.4 then
        return {type = "choppy_wave", rate_mult = 0.5 + math.random()}
    elseif env_name == "mountain" and pressure > 0.8 then
        return {type = "seismic_crack", duration = 0.4}
    elseif env_name == "sand" and pressure < 0.3 then
        return {type = "grain_scatter", duration = 0.1}
    end
    
    return nil
end

return Environments
