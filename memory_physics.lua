-- Top of script
local Env = require "memory_physics/lib/environments"
local Phys = require "memory_physics/lib/physics"

-- In your apply_archeology loop:
function apply_archeology()
    for i = 1, MAX_LAYERS do
        local layer = layers[i]
        local depth = Phys.calculate_layer_depth(i, ACTIVE_LAYERS)
        local local_p = excavation_pressure * depth
        
        -- Pull data from the Env module instead of a long if/else
        local config = Env.data[environment]
        
        local pressure_sq = local_p * local_p
        local cutoff = config.cutoff_base - (pressure_sq * i * config.cutoff_mod)
        
        softcut.post_filter_fc(layer.voice, math.max(60, cutoff))
        softcut.post_filter_rq(layer.voice, config.rq_base + (pressure_sq * config.rq_mod))
        -- etc...
    end
end
