local Environments = {}

Environments.list = {"desert", "forest", "swamp", "river", "deep_sea", "mountain", "cave"}

Environments.data = {
  desert = {
    cutoff_base = 15000, cutoff_mod = 12000, rq_base = 1.4, rq_mod = 5.0, 
    drift = 0.18, hp = 0.95, bp = 0.75, gain_mod = 0.34
  },
  deep_sea = {
    cutoff_base = 5000, cutoff_mod = 4600, rq_base = 3.2, rq_mod = 6.0, 
    drift = 0.008, hp = 0, bp = 0.65, gain_mod = 0.04
  },
  -- Add other biomes following this pattern...
}

function Environments.get_noise_event(env, pressure)
    if env == "desert" and pressure > 0.55 then
        if math.random() < pressure * 0.08 then return {type = "level", val = 0.3 + math.random() * 1.2} end
    elseif env == "cave" and pressure > 0.55 then
        if math.random() < pressure * 0.08 then return {type = "jump"} end
    end
    return nil
end

return Environments
