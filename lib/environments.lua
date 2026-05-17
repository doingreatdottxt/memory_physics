-- lib/environments.lua

local envs = {}

envs.list = {
  "Sand",
  "Mountain",
  "Grove",
  "River Bank",
  "Sea",
  "Swamp",
  "Cave",
  "Void"
}

envs.data = {
  ["Sand"]       = { base_fc = 18000, mod_fc = 16000, base_rq = 0.8, mod_rq = 2.5, drift = 0.005 },
  ["Mountain"]   = { base_fc = 16000, mod_fc = 14000, base_rq = 1.0, mod_rq = 3.0, drift = 0.002 },
  ["Grove"]      = { base_fc = 6000,  mod_fc = 4500,  base_rq = 1.2, mod_rq = 2.0, drift = 0.001 },
  ["River Bank"] = { base_fc = 5500,  mod_fc = 4000,  base_rq = 1.1, mod_rq = 1.8, drift = 0.008 },
  ["Sea"]        = { base_fc = 12000, mod_fc = 10000, base_rq = 0.9, mod_rq = 2.2, drift = 0.012 },
  ["Swamp"]      = { base_fc = 2500,  mod_fc = 1800,  base_rq = 1.5, mod_rq = 1.5, drift = 0.004 },
  ["Cave"]       = { base_fc = 3500,  mod_fc = 2800,  base_rq = 1.4, mod_rq = 1.2, drift = 0.001 },
  ["Void"]       = { base_fc = 20000, mod_fc = 0,     base_rq = 1.0, mod_rq = 0.0, drift = 0.0 }
}

return envs
