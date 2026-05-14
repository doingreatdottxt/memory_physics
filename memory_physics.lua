-- memory_physics
-- Archaeology of Sound Prototype

local Env = require "memory_physics/lib/environments"
local Phys = require "memory_physics/lib/physics"
local Soft = require "memory_physics/lib/engine_core"
local UI = require "memory_physics/lib/ui_manager"

-- GLOBAL STATE initialization
layers = {}
active_layers = 6 
excavation_pressure = 0
weather_intensity = 0.25 
current_env = "forest" -- Matches your library's default

-- System State
local alt_held = false
local show_help = false
local is_manual = false
local is_recording = false
local master_duration = -1
local key_2_down = false
local key_3_down = false
local silence_timer = 0

function init()
    -- 1. Initialize Table FIRST
    for i = 1, 6 do
        layers[i] = { voice = i, pressure_mem = 0, active = true }
    end
    
    -- 2. Setup Softcut
    for i = 1, 6 do
        Soft.setup_voice(i, 60)
    end
    
    -- 3. Parameters
    params:add_separator("ARCHAEOLOGY")
    params:add_option("mode", "Rec Mode", {"Auto", "Manual"}, 1)
    params:set_action("mode", function(x) is_manual = (x == 2) end)
    
    params:add_separator("TIMING")
    params:add_option("sync_mode", "Sync", {"Free", "Beat", "Bar"}, 1)
    params:add_option("master_toggle", "Master Sync", {"Off", "On"}, 2)
    params:add_control("silence_time", "Silence Time", controlspec.new(0.5, 10, "lin", 0.1, 2))

    -- Using Env.list directly from your environments.lua
    params:add_option("environment", "Environment", Env.list, 1)
    params:set_action("environment", function(x) current_env = Env.list[x] end)

    -- 4. Polls & Clocks
    poll_input = poll.set("amp_in_l")
    poll_input.callback = function(val)
        if not is_manual and not is_recording then
            local triggered, new_timer = Phys.process_silence(val, 0.1, silence_timer, params:get("silence_time"))
            silence_timer = new_timer
            if triggered then advance_strata() end
        end
    end
    poll_input:start()

    clock.run(physics_loop)
    clock.run(audio_update_loop)
end

function redraw()
    screen.clear()
    
    -- Safety Check: Ensure layers exists before drawing
    if layers and #layers > 0 then
        if show_help then
            UI.draw_help(is_manual)
        else
            UI.draw_layers(layers, active_layers, excavation_pressure)
            draw_status_header()
        end
    else
        screen.move(64, 32)
        screen.text_center("INITIALIZING...")
    end
    
    screen.update()
end

-- Ensure this matches your hardware mapping
function key(n, z)
    if n == 1 then alt_held = (z == 1) end
    if n == 2 then key_2_down = (z == 1) end
    if n == 3 then key_3_down = (z == 1) end

    -- Safety Reset
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

-- (Enc, loops, and handle_event remain the same)
