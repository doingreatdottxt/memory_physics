-- memory_physics.lua
engine.name = 'MemoryPhysics'

local envs = include("lib/environments")
local physics = {
  recording = false, start_time = 0, duration = 5,
  layers_active = 0, max_layers = 6, shift_held = false,
  silence_frames = 0
}

function init()
  setup_params()
  
  -- Register incoming amp tracker data for auto-record behavior
  osc.event = function(path, args, from)
    if path == "/in_amp" and params:get("auto_record") == 2 then
      local amp = args[3] 
      if not physics.recording and amp > params:get("threshold") then
        toggle_formation()
      elseif physics.recording and amp < (params:get("threshold") * 0.5) then
        physics.silence_frames = physics.silence_frames + 1
        if physics.silence_frames > (params:get("release_time") * 10) then
          toggle_formation()
          physics.silence_frames = 0
        end
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
  params:add_control("release_time", "THRES: RELEASE (S)", controlspec.new(0.1, 5.0, 'lin', 0.1, 1.0))
  
  -- Reintegrated Environment Option using environments.lua specifications
  params:add_option("environment", "ENVIRONMENT", envs.list, 3) -- Defaults to Index 3 ("Grove")
  params:set_action("environment", function(x)
    local env_name = envs.list[x]
    local d = envs.data[env_name]
    engine.set_env(x - 1)
    if d then
      engine.set_environment_params(d.base_fc, d.mod_fc, d.base_rq, d.mod_rq, d.drift)
    end
  end)
  
  params:add_control("weather", "WEATHER INTENSITY", controlspec.new(0, 1, 'lin', 0.01, 0.5))
  params:set_action("weather", function(x) engine.set_weather(x) end)
  params:add_control("pressure", "PRESSURE OVERRIDE", controlspec.new(0, 1, 'lin', 0.01, 0))
  params:set_action("pressure", function(x) engine.set_pressure(x) end)
  params:add_trigger("excavate", "EXCAVATE SITE")
  params:set_action("excavate", function() physics.layers_active = 0 end)
  params:bang()
end

function toggle_formation()
  if not physics.recording then
    physics.start_time = util.time()
    engine.shift_layers()
    engine.record_start()
    physics.recording = true
    physics.layers_active = math.min(physics.max_layers, physics.layers_active + 1)
  else
    physics.recording = false
    physics.duration = math.max(0.5, util.time() - physics.start_time)
    engine.set_duration(0, physics.duration)
    engine.record_stop()
  end
end

-- CONTROLS
function key(n, z)
  if n == 1 then physics.shift_held = (z == 1)
  elseif n == 2 and z == 1 then
    if physics.shift_held then params:delta("environment", 1) else toggle_formation() end
  elseif n == 3 and z == 1 then
    if physics.shift_held then params:set("excavate", 1) else params:delta("auto_record", 1) end
  end
end

function enc(n, d)
  if n == 1 then params:delta("main_vol", d)
  elseif n == 2 then params:delta("weather", d)
  elseif n == 3 then params:delta("pressure", d) end
end

-- VISUALS
function redraw()
  screen.clear()
  screen.level(physics.recording and 15 or 3)
  screen.move(0, 8)
  local status = physics.recording and "FORMING STRATA" or "STABLE"
  screen.text(status .. " [" .. string.format("%.1f", physics.duration) .. "s]")
  
  for i=1, 6 do
    local y = 14 + (i * 7)
    if i <= physics.layers_active then
      screen.level(math.max(1, 10 - i))
      screen.move(10, y+3); screen.line(118, y+3); screen.stroke()
      if i == 1 then
        local p = ((util.time() - physics.start_time) % physics.duration) / physics.duration
        screen.level(15); screen.move(10 + (p * 106), y - 1); screen.line_rel(0, 5); screen.stroke()
      end
    else
      screen.level(1); screen.move(20, y+3); screen.line(100, y+3); screen.stroke()
    end
  end
  
  screen.level(3); screen.move(0, 62)
  screen.text("V:" .. math.floor(params:get("main_vol")*100) .. "% W:" .. math.floor(params:get("weather")*100) .. "% P:" .. math.floor(params:get("pressure")*100) .. "%")
  screen.update()
end
