-- memory_physics.lua
-- 
-- E1: Env Intensity
-- E2: Weather
-- E3: Pressure

engine.name = "MemoryPhysics"

local physics = {
    duration = 2.0,
    surface_cycles = 0,
    layers_active = 6
}

local layer_phases = {0, 0, 0, 0, 0, 0}
local envs = { list = {"Grove", "Sand", "Mountain", "River Bank", "Sea", "Swamp", "Cave"} }

function init()
    -- Environment Intensity (Mapped to E1)
    params:add_control("env_intensity", "Env Intensity", controlspec.new(0, 1, 'lin', 0.01, 1))
    params:set_action("env_intensity", function(x) engine.set_env_intensity(x) end)

    -- Weather (Mapped to E2)
    params:add_control("weather", "Weather", controlspec.new(0, 1, 'lin', 0.01, 0.2))
    params:set_action("weather", function(x) engine.set_weather(x) end)

    -- Pressure (Mapped to E3)
    params:add_control("pressure", "Pressure", controlspec.new(0, 1, 'lin', 0.01, 0.0))
    params:set_action("pressure", function(x) engine.set_pressure(x) end)
    
    -- Environment Selection
    params:add_option("environment", "Environment", envs.list, 1)
    params:set_action("environment", function(x) engine.set_env(x - 1) end)

    -- OSC Polling from SuperCollider for Phase UI
    osc.event = function(path, args, from)
        if path == "/layer_phase" then
            layer_phases[args[1] + 1] = args[2]
        end
    end
    
    -- UI Refresh Metro
    clock.run(function()
        while true do
            clock.sleep(1/15)
            redraw()
        end
    end)
end

function enc(n, d)
    if n == 1 then
        params:delta("env_intensity", d)
    elseif n == 2 then
        params:delta("weather", d)
    elseif n == 3 then
        params:delta("pressure", d)
    end
end

function redraw()
    screen.clear()
    
    local status = "PLAY"
    screen.level(15)
    screen.move(0, 10)
    screen.text(status .. " [" .. string.format("%.1f", physics.duration) .. "s] C:" .. physics.surface_cycles .. "/5")

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
                elseif current_env == "Mountain" or current_env == "Sand" or current_env == "Cave" then
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

    -- Bottom readout now includes "E:" for Env Intensity
    screen.level(3)
    screen.move(0, 62)
    screen.text(current_env .. " | E:" .. math.floor(params:get("env_intensity") * 100) .. "% W:" .. math.floor(params:get("weather") * 100) .. "% P:" .. math.floor(params:get("pressure") * 100) .. "%")

    screen.update()
end
