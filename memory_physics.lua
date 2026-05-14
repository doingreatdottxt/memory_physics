-- memory_physics
-- Archaeology of Sound Prototype

local Env = require "memory_physics/lib/environments"
local Phys = require "memory_physics/lib/physics"
local Soft = require "memory_physics/lib/engine_core"
local UI = require "memory_physics/lib/ui_manager"

-- Performance State
active_layers = 6 
excavation_pressure = 0
weather_intensity = 0.25 -- 25% Standard Breeze
current_env = "grove"

-- System State
local alt_held = false
local show_help = false
local is_manual = false
local is_recording = false
local master_duration = -1
local key_2_down = false
local key_3_down = false

function init()
    for i = 1, 6 do
        layers[i] = { voice = i, pressure_mem = 0, active = true }
        Soft.setup_voice(i, 60)
    end
    
    -- Parameters
    params:add_separator("ARCHAEOLOGY")
    params:add_option("mode", "Rec Mode", {"Auto", "Manual"}, 1)
    params:set_action("mode", function(x) is_manual = (x == 2) end)
    
    params:add_separator("TIMING")
    params:add_option("sync_mode", "Sync", {"Free", "Beat", "Bar"}, 1)
    params:add_option("master_toggle", "Master Sync", {"Off", "On"}, 2)

    params:add_option("environment", "Environment", Env.list, 3)
    params:set_action("environment", function(x) current_env = Env.list[x] end)

    clock.run(physics_loop)
    clock.run(audio_update_loop)
end

---------------------------------------------------------
-- HARDWARE INPUTS
---------------------------------------------------------

function enc(n, d)
    if n == 1 then 
        params:delta("environment", d)
    elseif n == 2 then 
        weather_intensity = util.clamp(weather_intensity + (d/100), 0, 1)
    elseif n == 3 then 
        excavation_pressure = util.clamp(excavation_pressure + (d/100), 0, 1)
    end
end

function key(n, z)
    if n == 1 then alt_held = (z == 1) end
    if n == 2 then key_2_down = (z == 1) end
    if n == 3 then key_3_down = (z == 1) end

    -- Safety Reset: K2 + K3 simultaneously
    if z == 1 and key_2_down and key_3_down then
        excavation_pressure = 0
        weather_intensity = 0.25
        master_duration = -1
        return
    end

    if z == 1 then
        if alt_held then
            if n == 2 then show_help = not show_help
            elseif n == 3 then params:set("sync_mode", (params:get("sync_mode") % 3) + 1) end
        else
            if n == 2 and is_manual then
                if not is_recording then start_recording() else stop_recording() end
            elseif n == 3 then
                params:set("mode", (params:get("mode") % 2) + 1)
            end
        end
    end
end

---------------------------------------------------------
-- LOOPS
---------------------------------------------------------

function physics_loop()
    while true do
        clock.sleep(1/15)
        for i, l in ipairs(layers) do
            local depth = Phys.calculate_layer_depth(i, active_layers)
            l.pressure_mem = Phys.interpolate(l.pressure_mem, excavation_pressure * depth, 0.1)
            
            -- Pass weather and index for depth-attenuated probability
            local event = Env.get_random_event(current_env, l.pressure_mem, i, weather_intensity)
            if event then handle_event(i, event) end
        end
    end
end

function audio_update_loop()
    while true do
        clock.sleep(1/30)
        for i, l in ipairs(layers) do
            local p = Env.get_params(current_env, l.pressure_mem, i, weather_intensity)
            Soft.apply_params(i, p)
        end
    end
end

function redraw()
    screen.clear()
    if show_help then
        draw_help_screen()
    else
        UI.draw_layers(layers, active_layers, excavation_pressure)
        draw_status_header()
    end
    screen.update()
end

function draw_status_header()
    screen.level(10)
    screen.move(0, 7)
    screen.text(current_env:upper())
    
    screen.move(60, 7)
    screen.level(4)
    screen.text(params:get("bpm") .. " [" .. ({"FREE", "BEAT", "BAR"})[params:get("sync_mode")] .. "]")
    
    screen.move(110, 62)
    screen.level(5)
    screen.text("W:" .. math.floor(weather_intensity * 100))
end
