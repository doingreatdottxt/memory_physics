-- memory_physics.lua
engine.name = 'MemoryPhysics'

local envs = include("lib/environments")

local physics = {
    recording = false,
    start_time = 0,
    duration = 2, 
    layers_active = 0,
    max_layers = 6,
    shift_held = false,
    silence_frames = 0
}

local layer_phases = {0.0, 0.0, 0.0, 0.0, 0.0, 0.0}

function init()
    setup_params()

    -- Unified receiver handles bridged loopback tracking data from SuperCollider
    osc.event = function(path, args, from)
        if path == "/in_amp" then
            if params:get("auto_record") == 2 then
                -- BUG FIX (Bug 3): Array is isolated during forwarding, mapping directly to index 1
                local amp = args[1]
                if not physics.recording and amp > params:get("threshold") then
                    toggle_formation()
                elseif physics.recording then
                    if amp < (params:get("threshold") * 0.5) then
                        physics.silence_frames = physics.silence_frames + 1
                        if physics.silence_frames > (params:get("release_time") * 15) then 
                            toggle_formation()
                            physics.silence_frames = 0
                        end
                    else
                        physics.silence_frames = 0
                    end
                end
            end
        elseif path == "/layer_phase" then
            local layer_idx = math.floor(args[1] + 1)
            local phase_val = args[2]
            if layer_idx >= 1 and layer_idx <= physics.max_layers then
                layer_phases[layer_idx] = phase_val
            end
        end
    end

    redraw_metro = metro.init(function() redraw() end, 1/15)
    redraw_metro:start()
end

function setup_params()
    params:add_group("MEMORY PHYSICS", 8)

    params:add_control("main_vol", "GLOBAL VOLUME", controlspec.new(0, 2, 'lin', 0.01, 1.0))
    params:set_action("main_vol", function(x) engine.set_volume(x) end)

    params:add_option("auto_record", "AUTO RECORD", {"OFF", "ON"}, 2)

    params:add_control("threshold", "THRES: TRIGGER", controlspec.new(0.001, 1.0, 'exp', 0.001, 0.05))
    params:add_control("release_time", "THRES: RELEASE (S)", controlspec.new(0.1, 5.0, 'lin', 0.1, 2.0))

    params:add_option("environment", "ENVIRONMENT", envs.list, 3)
    params:set_action("environment", function(x)
        local env_name = envs.list[x]
        local d = envs.data[env_name]
        engine.set_env(x - 1)
        if d then
            engine.set_environment_params(d.base_fc, d.mod_fc, d.base_rq, d.mod_rq, d.drift)
        end
    end)

    params:add_control("weather", "WEATHER INTENSITY", controlspec.new(0, 1, 'lin', 0.01, 0.2))
    params:set_action("weather", function(x) engine.set_weather(x) end)

    params:add_control("pressure", "PRESSURE OVERRIDE", controlspec.new(0, 1, 'lin', 0.01, 0))
    params:set_action("pressure", function(x) engine.set_pressure(x) end)

    params:add_trigger("excavate", "EXCAVATE SITE")
    params:set_action("excavate", function()
        physics.layers_active = 0
        if engine.clear_layers then
            engine.clear_layers()
        end
    end)

    params:bang()
end

function toggle_formation()
    if not physics.recording then
        physics.start_time = util.time()
        engine.record_start()
        physics.recording = true
    else
        physics.recording = false
        physics.duration = math.max(0.5, util.time() - physics.start_time)
        engine.record_stop()
        
        engine.shift_layers(physics.duration)
        physics.layers_active = math.min(physics.max_layers, physics.layers_active + 1)
    end
end

-- CONTROLS
function key(n, z)
    if n == 1 then
        physics.shift_held = (z == 1)
    elseif n == 2 and z == 1 then
        if physics.shift_held then
            params:set("environment", util.wrap(params:get("environment") + 1, 1, #envs.list))
        else
            toggle_formation()
        end
    elseif n == 3 and z == 1 then
        if physics.shift_held then
            -- BUG FIX (Bug 2): Shift+Key 3 processes an erosion single-layer pop event to lift buried layers back up
            if physics.layers_active > 0 then
                engine.erode_layer()
                physics.layers_active = physics.layers_active - 1
            end
        else
            params:set("auto_record", params:get("auto_record") == 1 and 2 or 1)
        end
    end
end

function enc(n, d)
    if n == 1 then
        params:delta("main_vol", d)
    elseif n == 2 then
        params:delta("weather", d)
    elseif n == 3 then
        params:delta("pressure", d)
    end
end

-- VISUALS
function redraw()
    screen.clear()

    -- Header Layout
    screen.level(physics.recording and 15 or 3)
    screen.move(0, 8)
    local status = physics.recording and "FORMING STRATA" or "STABLE"
    screen.text(status .. " [" .. string.format("%.1f", physics.duration) .. "s]")

    -- Center Layout: Geological Strata Stack Display
    local current_env = envs.list[params:get("environment")]
    for i = 1, 6 do
        local y = 14 + (i * 7)

        if i <= physics.layers_active then
            screen.level(math.floor(math.max(1, 11 - (i * 1.5))))
            
            if i == 1 then
                screen.move(10, y + 3)
                screen.line(118, y + 3)
                screen.stroke()
                
                if current_env == "Grove" or current_env == "Swamp" then
                    screen.move(25, y + 1) screen.line_rel(0, 2)
                    screen.move(70, y + 1) screen.line_rel(0, 2)
                    screen.move(105, y + 1) screen.line_rel(0, 2)
                    screen.stroke()
                elseif current_env == "Mountain" or current_env == "Sand" then
                    screen.move(40, y + 3) screen.line_rel(2, -2) screen.line_rel(2, 2)
                    screen.move(85, y + 3) screen.line_rel(2, -2) screen.line_rel(2, 2)
                    screen.stroke()
                elseif current_env == "Sea" or current_env == "River Bank" then
                    screen.move(30, y + 2) screen.line_rel(3, 0)
                    screen.move(75, y + 2) screen.line_rel(3, 0)
                    screen.stroke()
                end
            else
                for x = 10, 118, 4 do
                    local offset = (x % (3 * i)) == 0 and (math.floor(i * 0.5)) or 0
                    screen.move(x, y + 3 + offset)
                    screen.line_rel(3, 0)
                    screen.stroke()
                end
            end

            local p = layer_phases[i] or 0.0
            screen.level(math.floor(math.max(4, 16 - (i * 2))))
            screen.rect(10 + (p * 108), y + 2, 2, 2)
            screen.fill()
        else
            screen.level(1)
            screen.move(20, y + 3)
            screen.line(100, y + 3)
            screen.stroke()
        end
    end

    -- Footer Layout
    screen.level(3)
    screen.move(0, 62)
    screen.text(current_env .. " | W:" .. math.floor(params:get("weather") * 100) .. "% P:" .. math.floor(params:get("pressure") * 100) .. "%")

    screen.update()
end
