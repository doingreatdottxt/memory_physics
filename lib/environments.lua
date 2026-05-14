local Environments = {}

-- The list of keys used by the Norns params menu
Environments.list = {"forest", "deep_sea", "desert", "mountain", "swamp", "cave"}

-- DSP and Physics profiles for each biome
Environments.data = {
  forest = {
    base_fc = 12000, mod_fc = 8000, 
    base_rq = 2.0, mod_rq = 4.0, 
    gain_scale = 0.8, noise_type = "rustle"
  },
  deep_sea = {
    base_fc = 800, mod_fc = 600, 
    base_rq = 5.0, mod_rq = 2.0, 
    gain_scale = 0.4, noise_type = "pressure"
  },
  desert = {
    base_fc = 15000, mod_fc = 12000, 
    base_rq = 1.4, mod_rq = 5.0, 
    gain_scale = 0.7, noise_type = "wind"
  },
  mountain = {
    base_fc = 3000, mod_fc = 2500, 
    base_rq = 8.0, mod_rq = 1.0, 
    gain_scale = 0.6, noise_type = "crackle"
  },
  swamp = {
    base_fc = 2000, mod_fc = 1800, 
    base_rq = 3.0, mod_rq = 6.0, 
    gain_scale = 0.5, noise_type = "bubbles"
  },
  cave = {
    base_fc = 5000, mod_fc = 4500, 
    base_rq = 1.2, mod_rq = 0.5, 
    gain_scale = 0.9, noise_type = "echo"
  }
}

-- Returns a table of parameters for Softcut/DaisySP
function Environments.get_params(env_name, pressure, layer_idx)
  local d = Environments.data[env_name] or Environments.data["forest"]
  local p_sq = pressure * pressure
  
  -- Logic: Higher pressure usually reduces cutoff (burying the sound)
  -- and increases resonance (narrowing the focus)
  return {
    cutoff = math.max(20, d.base_fc - (p_sq * d.mod_fc)),
    rq = d.base_rq + (p_sq * d.mod_rq),
    gain = d.gain_scale - (pressure * 0.2)
  }
end

-- Logic for random "archeological" glitches/events
function Environments.get_random_event(env_name, pressure)
  -- Global dropout chance based on high pressure
  if pressure > 0.8 and math.random() < 0.02 then
    return {type = "dropout", duration = math.random(5, 15) / 100}
  end
  
  -- Biome specific events
  if env_name == "cave" and pressure > 0.6 and math.random() < 0.01 then
    return {type = "jump"} -- Random playhead jump
  end
  
  return nil
end

return Environments
