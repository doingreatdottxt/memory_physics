local Environments = {}

Environments.list = {"Sand", "Mountain", "Grove", "River Bank", "Sea", "Swamp", "Cave"}

Environments.data = {
  ["Sand"] = { base_fc = 16000, mod_fc = 15500, base_rq = 1.5, mod_rq = 6.0, drift = 0.08 },
  ["Mountain"] = { base_fc = 4000, mod_fc = 3800, base_rq = 2.0, mod_rq = 12.0, drift = 0.02 },
  ["Grove"] = { base_fc = 8000, mod_fc = 7500, base_rq = 1.2, mod_rq = 3.0, drift = 0.005 },
  ["River Bank"] = { base_fc = 12000, mod_fc = 11000, base_rq = 1.0, mod_rq = 2.5, drift = 0.01 },
  ["Sea"] = { base_fc = 5000, mod_fc = 4600, base_rq = 1.5, mod_rq = 8.0, drift = 0.04 },
  ["Swamp"] = { base_fc = 1800, mod_fc = 1600, base_rq = 2.5, mod_rq = 7.0, drift = 0.06 },
  ["Cave"] = { base_fc = 3500, mod_fc = 3200, base_rq = 0.8, mod_rq = 15.0, drift = 0.03 }
}

function Environments.get_params(env_name, pressure, layer_idx, weather)
  local d = Environments.data[env_name] or Environments.data["Grove"]
  local p_sq = pressure * pressure
  local layer_weather = weather * (0.5 ^ (layer_idx - 1))
  
  local cutoff = d.base_fc - (p_sq * d.mod_fc)
  
  return {
    cutoff = math.max(20, math.min(20000, cutoff)),
    rq = d.base_rq + (p_sq * d.mod_rq),
    gain = 0.9 - (pressure * 0.4),
    rate = 1.0 + (math.sin(util.time() * (d.drift * 25)) * (layer_weather * d.drift)),
    -- Pan fix: maintains a stereo floor so it doesn't collapse to mono-left
    pan_width = math.max(0.3, 1.0 - (pressure * 0.7))
  }
end

function Environments.get_random_event(env_name, pressure, layer_idx, weather)
  local layer_weather = weather * (0.5 ^ (layer_idx - 1))
  if math.random() > (layer_weather * 0.2) then return nil end

  if env_name == "Swamp" then
    return {type = "bubble_pop", rate_shift = 0.8 + (math.random() * 0.4)}
  elseif env_name == "Mountain" and pressure > 0.8 then
    return {type = "seismic_crack", duration = 0.4}
  end
  return nil
end

return Environments
