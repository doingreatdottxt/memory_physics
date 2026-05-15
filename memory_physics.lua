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
  silence_frames = 0,
  env_names = {"WIND", "SAND", "TIDE"}
}

function init()
  setup_params()
  
  -- OSC Listener for Threshold-based Auto Record
  osc.event = function(path, args, from)
    if path == "/in_amp" and params:get("auto_record") == 2 then
      local amp = args[1]
      local threshold = params:get("threshold")
      
      if not physics.recording and amp > threshold then
        toggle_formation()
      elseif physics.recording and amp < (threshold * 0.4) then
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
  params:add_option("environment", "ENVIRONMENT", physics.env_names, 1)
  params:set_action("environment", function(x) engine.set_env(x-1) end)
  params:add_control("weather", "WEATHER INTENSITY", controlspec.new(0, 1, 'lin', 0.01, 0.2))
  params:set_action("weather", function(x) engine.set_weather(x) end)
  params:add_control("pressure", "PRESSURE OVERRIDE", controlspec.new(0, 1, 'lin', 0.01, 0))
  params:set_action("pressure", function(x) engine.set_pressure(x) end)
  params:add_trigger("excavate", "EXCAVATE SITE")
  params:set_action("excavate", function() physics.layers_active = 0 end)
  params:bang()
end

-- KEY & ENC
function key(n, z)
  if n == 1 then physics.shift_held = (z == 1)
  elseif n == 2 and z == 1 then
    if physics.shift_held then params:delta("environment", 1)
    else toggle_formation() end
  elseif n == 3 and z == 1 then
    if physics.shift_held then params:set("excavate", 1)
    else params:delta("auto_record", 1) end
  end
end

function enc(n, d)
  if n == 1 then params:delta("main_vol", d)
  elseif n == 2 then params:delta("weather", d)
  elseif n == 3 then params:delta("pressure", d) end
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
    engine.set_duration(0, physics.duration) -- Tell layer 0 its new length
    engine.record_stop()
  end
end

-- VISUAL PICTOGRAMS
function draw_surface(y, env_type)
  screen.level(15)
  if env_type == 1 then -- Wind
    for x = 12, 108, 15 do screen.move(x, y); screen.line_rel(6, 0); screen.stroke() end
  elseif env_type == 2 then -- Sand
    for x = 15, 105, 8 do screen.pixel(x, y); screen.pixel(x-2, y+1) end
    screen.fill()
  elseif env_type == 3 then -- Tide
    screen.move(12, y+2); screen.text("~ ~ ~ ~ ~ ~ ~")
  end
end

function draw_soil(y, depth)
  screen.level(math.max(1, 8 - depth))
  for i=1, 15 do screen.pixel(math.random(12, 115), y + math.random(0, 4)) end
  screen.fill()
end

function draw_rock(y, depth)
  screen.level(2)
  for x = 15, 105, 20 do screen.rect(x + (depth*2), y, 8, 4); screen.stroke() end
end

function redraw()
  screen.clear()
  
  -- Header
  screen.level(physics.recording and 15 or 3)
  screen.move(0, 8)
  local status = physics.recording and "FORMING STRATA" or "STABLE"
  if params:get("auto_record") == 2 and not physics.recording then status = "AUTO-IDLE" end
  local timer = physics.recording and string.format("%.1f", util.time() - physics.start_time) or string.format("%.1f", physics.duration)
  screen.text(status .. " [" .. timer .. "s]")
  
  -- Strata Stack
  math.randomseed(123)
  for i=1, 6 do
    local is_active = i <= physics.layers_active
    local y = 14 + (i * 7)
    if is_active then
      if i == 1 then 
        draw_surface(y, params:get("environment"))
        -- Playhead
        local play_pos = ((util.time() - physics.start_time) % physics.duration) / physics.duration
        screen.level(15); screen.move(10 + (play_pos * 106), y - 2); screen.line_rel(0, 6); screen.stroke()
      elseif i <= 3 then draw_soil(y, i)
      else draw_rock(y, i) end
    else
      screen.level(1); screen.move(10, y + 3); screen.line(118, y + 3); screen.stroke()
    end
  end
  
  -- Footer
  screen.level(3); screen.move(0, 62)
  screen.text("V:" .. math.floor(params:get("main_vol")*100) .. "% W:" .. math.floor(params:get("weather")*100) .. "% P:" .. math.floor(params:get("pressure")*100) .. "%")
  
  screen.update()
end
