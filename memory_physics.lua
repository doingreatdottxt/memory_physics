-- memory_physics.lua
-- Geological Strata Looper
-- Audio as archaeological record.

engine.name = 'MemoryPhysics'

local physics = {
  recording = false,
  start_time = 0,
  duration = 20,
  layers_active = 0,
  max_layers = 6,
  shift_held = false,
  silence_frames = 0
}

function init()
  setup_params()
  
  -- OSC Listener for Threshold
  osc.event = function(path, args, from)
    if path == "/in_amp" and params:get("auto_record") == 2 then
      local amp = args[1]
      local threshold = params:get("threshold")
      
      if not physics.recording and amp > threshold then
        toggle_formation()
      elseif physics.recording and amp < (threshold * 0.5) then
        physics.silence_frames = physics.silence_frames + 1
        if physics.silence_frames > (params:get("release_time") * 20) then
          toggle_formation()
          physics.silence_frames = 0
        end
      else
        physics.silence_frames = 0
      end
    end
  end

  redraw_metro = metro.init(function() redraw() end, 1/15)
  redraw_metro:start()
end

function setup_params()
  params:add_group("MEMORY PHYSICS", 8)
  
  params:add_control("main_vol", "GLOBAL VOLUME", controlspec.new(0, 2, 'lin', 0.01, 1))
  params:set_action("main_vol", function(x) engine.set_volume(x) end)
  
  params:add_option("auto_record", "AUTO RECORD", {"OFF", "ON"}, 2)
  
  params:add_control("threshold", "THRES: TRIGGER", controlspec.new(0.001, 0.5, 'exp', 0.001, 0.02))
  
  params:add_control("release_time", "THRES: RELEASE (S)", controlspec.new(0.1, 5.0, 'lin', 0.1, 1.5))
  
  params:add_option("environment", "ENVIRONMENT", {"WIND", "SAND", "TIDE"}, 1)
  params:set_action("environment", function(x) engine.set_env(x-1) end)
  
  params:add_control("weather", "WEATHER INTENSITY", controlspec.new(0, 1, 'lin', 0.01, 0.2))
  params:set_action("weather", function(x) engine.set_weather(x) end)
  
  params:add_control("pressure", "PRESSURE OVERRIDE", controlspec.new(0, 1, 'lin', 0.01, 0))
  params:set_action("pressure", function(x) engine.set_pressure(x) end)
  
  params:add_separator("DANGER")
  params:add_trigger("excavate", "EXCAVATE SITE")
  params:set_action("excavate", function() physics.layers_active = 0 end)
  
  params:bang()
end

-- KEY & ENC Mapping
function key(n, z)
  if n == 1 then physics.shift_held = (z == 1)
  elseif n == 2 and z == 1 then
    if physics.shift_held then
      params:delta("environment", 1)
    else
      toggle_formation()
    end
  elseif n == 3 and z == 1 then
    if physics.shift_held then
      params:set("excavate", 1)
    else
      params:delta("auto_record", 1)
    end
  end
end

function enc(n, d)
  if n == 1 then params:delta("main_vol", d)
  elseif n == 2 then params:delta("weather", d)
  elseif n == 3 then params:delta("pressure", d)
  end
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
    physics.duration = math.min(20, util.time() - physics.start_time)
    engine.record_stop()
  end
end

-- Visuals remain the same as previous Bible version
function redraw()
  screen.clear()
  -- [Insert the draw_surface, draw_soil, draw_rock and redraw loops from previous version]
  -- Ensure it pulls from params:get("environment"), params:get("weather"), etc.
  screen.update()
end
