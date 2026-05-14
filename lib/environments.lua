local Environments = {}

Environments.list = {"sand", "mountain", "grove", "river_bank", "sea"}

Environments.data = {
  sand = {
    base_fc = 16000, mod_fc = 15500, base_rq = 1.5, mod_rq = 6.0,
    drift = 0.08, flavor = "granular_sand"
  },
  mountain = {
    base_fc = 4000, mod_fc = 3800, base_rq = 2.0, mod_rq = 12.0,
    drift = 0.02, flavor = "seismic"
  },
  grove = {
    base_fc = 8000, mod_fc = 7500, base_rq = 1.2, mod_rq = 3.0,
    drift = 0.005, flavor = "damp"
  },
  river_bank = {
    base_fc = 12000, mod_fc = 11000, base_rq = 1.0, mod_rq = 2.5,
    drift = 0.01, flavor = "flood"
  },
  sea = {
    base_fc = 5000, mod_fc = 4600, base_rq = 1.5, mod_rq = 8.0,
    drift = 0.04, flavor = "submarine"
  }
}

function Environments.get_params(env_name, pressure, layer_idx)
    local d = Environments.data[env_name] or Environments.data["grove"]
    local p_sq = pressure * pressure
    local cutoff = 0
    local gain_mod = 0
    
    if env_name == "sand" or env_name == "mountain" then
        -- High Pass to Low Pass Transition
        cutoff = math.max(40, d.base_fc - (pressure * d.mod_fc))
    elseif env_name == "river_bank" then
        -- The Flood: Gain swells slightly with pressure before the wash-out
        gain_mod = math.sin(pressure * math.pi) * 0.2
        cutoff = d.base_fc - (p_sq * d.mod_fc)
    elseif env_name == "sea" then
        -- Sea: Breezy Bandpass (surface) to Submerged LPF (pressure)
        cutoff = d.base_fc - (p_sq * d.mod_fc)
    else
        cutoff = d.base_fc - (p_sq * d.mod_fc)
    end

    return {
        cutoff = safe_clamp(cutoff, 20, 20000),
        rq = d.base_rq + (p_sq * d.mod_rq),
        gain = (0.9 + gain_mod) - (pressure * 0.4),
        -- Rate creates "thrashing waves" in the Sea or "seismic jitter" in Mountain
        rate = 1.0 + (math.sin(util.time() * (d.drift * 25)) * (pressure * d.drift))
    }
end

function Environments.get_random_event(env_name, pressure)
    local chance = math.random()
    
    -- Sea: Thrashing Waves / Choppy Granular
    if env_name == "sea" and pressure > 0.4 and chance < 0.08 then
        -- Random choppy rate shifts
        return {type = "choppy_wave", rate_mult = 0.5 + math.random()}
    end
    
    -- River Bank: The Flood / Splashy wash
    if env_name == "river_bank" and pressure > 0.7 and chance < 0.05 then
        return {type = "washout", duration = 0.6}
    end

    -- Mountain: Seismic Avalanches
    if env_name == "mountain" and pressure > 0.8 and chance < 0.04 then
        return {type = "seismic_crack", duration = 0.4}
    end
    
    -- Sand: Granular fragments
    if env_name == "sand" and pressure < 0.3 and chance < 0.1 then
        return {type = "grain_scatter", duration = 0.1}
    end
    
    return nil
end

function safe_clamp(val, min, max)
    return math.max(min, math.min(max, val))
end

return Environments
