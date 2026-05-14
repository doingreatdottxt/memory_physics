-- memory_physics (Geological Edition)
-- archaeology of sound
--
-- enc 1: environment
-- enc 2: layer density
-- enc 3: excavation pressure
-- key 2: manual record/arm
-- key 3: pressure reset

local Env = require "memory_physics/lib/environments"
local Phys = require "memory_physics/lib/physics"
local Soft = require "memory_physics/lib/engine_core"
local UI = require "memory_physics/lib/ui_manager"

-- State Variables
layers = {}
active_layers = 1
excavation_pressure = 0
current_env = "grove"
silence_timer = 0
is_manual = false
is_recording = false

function init()
    -- Initialize 6 layers of memory
    for i = 1, 6 do
        layers[i] = { 
            voice = i, 
            pressure_mem = 0, 
            active = (i == 1),
            is_dropout = false 
        }
        Soft.setup_voice(i, 30) -- 30 second buffers
    end
    
    -- Norns Parameters
    params:add_separator("PHYSICS CONFIG")
    params:add_option("mode", "Mode", {"Auto", "Manual"}, 1)
    params:set_action("mode", function(x) is_manual = (x == 2) end)
    
    params:add_control("silence_time", "Silence Time", controlspec.new(0.5, 10, "lin", 0.1, 2))
    
    params:add_option("environment", "Environment", Env.list, 3) -- Default to Grove
    params:set_action("environment", function(x) current_env = Env.list[x] end)
    
    -- Silence Monitor Poll
    poll_input = poll.set("amp_in_l")
    poll_input.callback = function(val)
        if not is_manual then
            local limit = params:get("silence_time")
            local triggered, new_timer = Phys.process_silence(val, 0.1, silence_timer, limit)
            silence_timer = new_timer
            if triggered then advance_strata() end
        end
    end
    poll_input:start()

    -- Main Loops
    clock.run(physics_loop)
    clock.run(audio_update_loop)
end

---------------------------------------------------------
-- GEOLOGICAL LOGIC
---------------------------------------------------------

function advance_strata()
    if active_layers < 6 then
        active_layers = active_layers + 1
    end
    
    -- If manual, handle the record head transition
    if is_manual then
        softcut.rec(active_layers - 1, 0)
        softcut.rec(active_layers, 1)
    end
end

function handle_event(layer_idx, event)
    if event.type == "seismic_crack" then
        -- Mountain: Sudden over-recording distortion
        softcut.rec_level(layer_idx, 1.4)
        clock.run(function() 
            clock.sleep(event.duration) 
            softcut.rec_level(layer_idx, 1.0) 
        end)
    elseif event.type == "bubble_pop" then
        -- Swamp: Sudden pitch "burp"
        softcut.rate(layer_idx, event.rate_shift)
        clock.run(function() 
            clock.sleep(0.1) 
            softcut.rate(layer_idx, 1.0) 
        end)
    elseif event.type == "cave_groan" then
        -- Cave: Dark, slow oppressive shift
        softcut.rate(layer_idx, 0.4)
        clock.run(function() 
            clock.sleep(event.duration) 
            softcut.rate(layer_idx, 1.0) 
        end)
    elseif event.type == "drip" then
        -- Cave: Resonant "ping"
        softcut.post_filter_fc(layer_idx, event.fc)
        softcut.post_filter_rq(layer_idx, 15.0)
    elseif event.type == "choppy_wave" then
        -- Sea: Surface thrashing
        softcut.rate(layer_idx, event.rate_mult)
    elseif event.type == "washout" then
        -- River: Temporary gain dip
        softcut.level(layer_idx, 0.2)
        clock.run(function() 
            clock.sleep(event.duration) 
            softcut.level(layer_idx, 0.8) 
        end)
    end
end

---------------------------------------------------------
-- HARDWARE & UPDATES
---------------------------------------------------------

function enc(n, d)
    if n == 1 then params:delta("environment", d)
    elseif n == 2 then active_layers = util.clamp(active_layers + d, 1, 6)
    elseif n == 3 then excavation_pressure = util.clamp(excavation_pressure + (d/100), 0, 1) end
end

function key(n, z)
    if n == 2 and z == 1 and is_manual then
        if not is_recording then
            is_recording = true
            softcut.rec(active_layers, 1)
        else
            is_recording = false
            advance_strata()
        end
    elseif n == 3 and z == 1 then
        excavation_pressure = 0
    end
end

function physics_loop()
    while true do
        clock.sleep(1/15)
        for i, l in ipairs(layers) do
            local depth = Phys.calculate_layer_depth(i, active_layers)
            l.pressure_mem = Phys.interpolate(l.pressure_mem, excavation_pressure * depth, 0.1)
            
            -- Trigger random biome events from the environment module
            local event = Env.get_random_event(current_env, l.pressure_mem)
            if event then handle_event(i, event) end
        end
    end
end

function audio_update_loop()
    while true do
        clock.sleep(1/30)
        for i, l in ipairs(layers) do
            if i <= active_layers then
                local p = Env.get_params(current_env, l.pressure_mem, i)
                Soft.apply_params(i, p)
            end
        end
    end
end

function redraw()
    screen.clear()
    UI.draw_layers(layers, active_layers, excavation_pressure)
    
    screen.level(10)
    screen.move(0, 7)
    screen.text(current_env:upper())
    
    if is_manual then
        screen.level(is_recording and 15 or 2)
        screen.circle(123, 7, 2)
        screen.fill()
    end
    screen.update()
end
