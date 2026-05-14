-- memory_physics
local Env = require "memory_physics/lib/environments"
local Phys = require "memory_physics/lib/physics"
local Soft = require "memory_physics/lib/engine_core"
local UI = require "memory_physics/lib/ui_manager"

-- State
layers = {}
active_layers = 1
excavation_pressure = 0
current_env = "forest"
silence_timer = 0
is_manual = false
is_recording = false

function init()
    for i = 1, 6 do
        layers[i] = { voice = i, pressure_mem = 0, active = (i == 1) }
        Soft.setup_voice(i, 30)
    end
    
    -- Parameters
    params:add_separator("PHYSICS CONFIG")
    params:add_option("mode", "Mode", {"Auto", "Manual"}, 1)
    params:set_action("mode", function(x) is_manual = (x == 2) end)
    
    params:add_control("silence_time", "Silence Time", controlspec.new(0.5, 10, "lin", 0.1, 2))
    
    -- Poll for Silence (Auto Mode only)
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

    clock.run(physics_loop)
    clock.run(audio_update_loop)
end

function advance_strata()
    -- LIFO Logic: Push current to deeper level
    if active_layers < 6 then
        active_layers = active_layers + 1
        print("Layer " .. (active_layers-1) .. " buried. New surface layer active.")
    else
        print("Bedrock reached. Oldest layers collapsing.")
    end
    
    -- If manual, stop recording on the previous voice
    if is_manual then
        softcut.rec(active_layers - 1, 0)
        softcut.rec(active_layers, 1) -- Arm new layer
    end
end

function key(n, z)
    if n == 2 and z == 1 then
        if is_manual then
            if not is_recording then
                is_recording = true
                softcut.rec(active_layers, 1)
                print("Recording Layer " .. active_layers)
            else
                is_recording = false
                advance_strata()
            end
        end
    end
    
    if n == 3 and z == 1 then
        excavation_pressure = 0 -- Flash reset
    end
end

function physics_loop()
    while true do
        clock.sleep(1/15)
        for i, l in ipairs(layers) do
            local depth = Phys.calculate_layer_depth(i, active_layers)
            l.pressure_mem = Phys.interpolate(l.pressure_mem, excavation_pressure * depth, 0.1)
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
    
    -- Visual Indicator for Manual Mode
    if is_manual then
        screen.level(is_recording and 15 or 2)
        screen.move(120, 10)
        screen.circle(123, 7, 2)
        screen.fill()
    end
    
    screen.update()
end
