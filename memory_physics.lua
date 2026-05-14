-- memory_physics (Geological Edition)
local Env = require "memory_physics/lib/environments"
local Phys = require "memory_physics/lib/physics"
local Soft = require "memory_physics/lib/engine_core"
local UI = require "memory_physics/lib/ui_manager"

-- State
layers = {}
active_layers = 1
excavation_pressure = 0
current_env = "grove"
silence_timer = 0
is_manual = false
is_recording = false

-- Timing State
local rec_start_time = 0
local master_duration = -1 -- -1 means not yet set

function init()
    for i = 1, 6 do
        layers[i] = { voice = i, pressure_mem = 0, active = (i == 1) }
        Soft.setup_voice(i, 60) -- Extended to 60s for long strata
    end
    
    -- Parameters
    params:add_separator("PHYSICS CONFIG")
    params:add_option("mode", "Mode", {"Auto", "Manual"}, 1)
    params:set_action("mode", function(x) is_manual = (x == 2) end)
    params:add_control("silence_time", "Silence Time", controlspec.new(0.5, 10, "lin", 0.1, 2))
    
    params:add_separator("TIMING & SYNC")
    params:add_option("sync_mode", "Clock Sync", {"Off", "Beat", "Bar"}, 1)
    params:add_option("master_toggle", "Master Length Toggle", {"Off", "On"}, 2)
    params:add_control("max_length", "Max Loop (sec)", controlspec.new(1, 60, "lin", 1, 30))

    params:add_option("environment", "Environment", Env.list, 3)
    params:set_action("environment", function(x) current_env = Env.list[x] end)
    
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

---------------------------------------------------------
-- RECORDING LOGIC
---------------------------------------------------------

function start_recording()
    rec_start_time = util.time()
    softcut.position(active_layers, 0)
    softcut.rec(active_layers, 1)
    is_recording = true
    print("Recording Layer " .. active_layers)
end

function stop_recording()
    local duration = util.time() - rec_start_time
    local sync = params:get("sync_mode")
    local master_on = params:get("master_toggle") == 2
    
    -- 1. Apply Clock Sync
    if sync == 2 then duration = Phys.snap_to_interval(duration, Phys.get_beat_sec())
    elseif sync == 3 then duration = Phys.snap_to_interval(duration, Phys.get_beat_sec() * 4) end
    
    -- 2. Apply Master Toggle Logic
    if master_on then
        if master_duration == -1 then
            master_duration = duration -- Define the "Bedrock Rhythm"
            print("Master Length set: " .. string.format("%.2f", master_duration) .. "s")
        else
            duration = Phys.snap_to_interval(duration, master_duration)
        end
    end

    duration = math.min(duration, params:get("max_length"))
    
    softcut.loop_end(active_layers, duration)
    softcut.rec(active_layers, 0)
    is_recording = false
    
    print("Layer " .. active_layers .. " set to " .. string.format("%.2f", duration) .. "s")
    advance_strata()
end

function advance_strata()
    if active_layers < 6 then
        active_layers = active_layers + 1
        if is_manual then softcut.rec(active_layers, 0) end
    end
end

---------------------------------------------------------
-- INTERACTION
---------------------------------------------------------

function key(n, z)
    if n == 2 and z == 1 then
        if is_manual then
            if not is_recording then start_recording()
            else stop_recording() end
        end
    elseif n == 3 and z == 1 then
        excavation_pressure = 0
        master_duration = -1 -- Reset timing on pressure clear
        print("Timing and Pressure reset.")
    end
end

function enc(n, d)
    if n == 1 then params:delta("environment", d)
    elseif n == 2 then active_layers = util.clamp(active_layers + d, 1, 6)
    elseif n == 3 then excavation_pressure = util.clamp(excavation_pressure + (d/100), 0, 1) end
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

function handle_event(idx, e)
    -- Refer to previous environmental event logic
end

function redraw()
    screen.clear()
    UI.draw_layers(layers, active_layers, excavation_pressure)
    screen.level(10)
    screen.move(0, 7)
    screen.text(current_env:upper() .. (params:get("master_toggle") == 2 and " (SYNCED)" or ""))
    screen.update()
end
