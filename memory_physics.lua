-- memory_physics
-- v1.0.0 @yourname
-- archaeology of sound
--
-- lwr wrld: excavation pressure
-- upr wrld: layer depth

local Env = require "memory_physics/lib/environments"
local Phys = require "memory_physics/lib/physics"
local Soft = require "memory_physics/lib/engine_core"
local UI = require "memory_physics/lib/ui_manager"

-- Constants
MAX_LAYERS = 6
MAX_LOOP_LENGTH = 30

-- State Variables
layers = {}
active_layers = 1
excavation_pressure = 0
current_env = "forest"
alt_held = false

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
    
    -- Setup Parameters (Norns Menu)
    params:add_separator("MEMORY PHYSICS")
    params:add_option("environment", "Environment", Env.list, 1)
    params:set_action("environment", function(x) current_env = Env.list[x] end)
    
    -- Start Logic Clocks
    clock.run(physics_loop)
    clock.run(audio_update_loop)
    clock.run(ui_loop)
end

---------------------------------------------------------
-- LOGIC LOOPS
---------------------------------------------------------

function physics_loop()
    while true do
        clock.sleep(1/15) -- 15Hz control rate logic
        for i, l in ipairs(layers) do
            if l.active then
                local depth = Phys.calculate_layer_depth(i, active_layers)
                local target_p = excavation_pressure * depth
                
                -- Smooth transitions in the physics module
                l.pressure_mem = Phys.interpolate(l.pressure_mem, target_p, 0.1)
                
                -- Check for random biome events
                local event = Env.get_random_event(current_env, l.pressure_mem)
                if event then handle_event(i, event) end
            end
        end
    end
end

function audio_update_loop()
    while true do
        clock.sleep(1/30) -- 30Hz update to Softcut
        for i, l in ipairs(layers) do
            if l.active then
                local p = Env.get_params(current_env, l.pressure_mem, i)
                Soft.apply_params(i, p)
            end
        end
    end
end

function ui_loop()
    while true do
        clock.sleep(1/15)
        redraw()
    end
end

---------------------------------------------------------
-- HARDWARE INTERACTION
---------------------------------------------------------

function enc(n, d)
    if n == 1 then
        -- Navigation or Environment selector
        params:delta("environment", d)
    elseif n == 2 then
        -- Layer Depth / Density
        active_layers = util.clamp(active_layers + d, 1, MAX_LAYERS)
        for i=1, MAX_LAYERS do layers[i].active = (i <= active_layers) end
    elseif n == 3 then
        -- Main Excavation Pressure
        excavation_pressure = util.clamp(excavation_pressure + (d/100), 0, 1)
    end
end

function key(n, z)
    if n == 1 then alt_held = z == 1 end
    if n == 3 and z == 1 then
        -- Global Reset or Pulse
        excavation_pressure = 0
    end
end

function handle_event(layer_idx, event)
    if event.type == "jump" then
        softcut.position(layer_idx, math.random(0, MAX_LOOP_LENGTH))
    elseif event.type == "dropout" then
        layers[layer_idx].is_dropout = true
        softcut.level(layer_idx, 0)
        clock.run(function() 
            clock.sleep(event.duration) 
            softcut.level(layer_idx, 1.0) 
            layers[layer_idx].is_dropout = false
        end)
    end
end

---------------------------------------------------------
-- DRAW
---------------------------------------------------------

function redraw()
    screen.clear()
    
    UI.draw_background(current_env)
    UI.draw_layers(layers, active_layers, excavation_pressure)
    UI.draw_pressure_gauge(excavation_pressure)
    
    -- Status Overlay
    screen.level(15)
    screen.move(0, 10)
    screen.text(current_env:upper())
    
    screen.update()
end
