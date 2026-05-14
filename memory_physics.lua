-- memory_physics
-- v1.0.0 @yourname
-- archaeology of sound
--
-- lwr wrld: excavation pressure
-- upr wrld: layer depth

local Env = require "memory_physics/lib/environments"
local Phys = require "memory_physics/lib/physics"
local Soft = require "memory_physics/lib/engine_core"

-- Constants
MAX_LAYERS = 6
MAX_LOOP_LENGTH = 30

-- State Variables
layers = {}
active_layers = 1
excavation_pressure = 0
current_env = "forest"

function init()
    -- Initialize Layers
    for i = 1, MAX_LAYERS do
        layers[i] = {
            voice = i,
            pressure_mem = 0,
            active = i == 1,
            is_dropout = false
        }
        Soft.setup_voice(i, MAX_LOOP_LENGTH)
    end
    
    -- Start Physics Clocks
    clock.run(physics_loop)
    clock.run(audio_update_loop)
    
    redraw()
end

-- The "Brain" Loop: Handles the math and logic timing
function physics_loop()
    while true do
        clock.sleep(1/15) -- 15Hz logic update (ideal for Daisy control rate)
        
        for i, l in ipairs(layers) do
            local depth = Phys.calculate_layer_depth(i, active_layers)
            local target_p = excavation_pressure * depth
            
            -- Smooth the pressure transitions
            l.pressure_mem = Phys.interpolate(l.pressure_mem, target_p, 0.1)
            
            -- Check for random "Archeological" events (dropouts/crackles)
            local event = Env.get_random_event(current_env, l.pressure_mem)
            if event then
                handle_event(i, event)
            end
        end
    end
end

-- The "Execution" Loop: Sends commands to the audio engine
function audio_update_loop()
    while true do
        clock.sleep(1/30) 
        for i, l in ipairs(layers) do
            if l.active then
                local params = Env.get_params(current_env, l.pressure_mem, i)
                Soft.apply_params(i, params)
            end
        end
    end
end

function handle_event(layer_idx, event)
    if event.type == "jump" then
        softcut.position(layer_idx, math.random(0, MAX_LOOP_LENGTH))
    elseif event.type == "dropout" then
        -- Temporarily dip gain
        softcut.level(layer_idx, 0)
        clock.run(function() 
            clock.sleep(event.duration) 
            softcut.level(layer_idx, 1.0) 
        end)
    end
end

-- UI and Interaction logic continues below...
function redraw()
    screen.clear()
    -- Visual representation of the 6 layers and pressure
    screen.stroke()
    screen.update()
end
