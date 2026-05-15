-- memory_physics.lua
-- Geological Strata Looper

engine.name = 'MemoryPhysics'

local physics = {
  recording = false,
  start_time = 0,
  duration = 20,
  layers_active = 0,
  max_layers = 6,
  
  shift_held = false,
  auto_record = true,
  environment = 1,
  
  -- Parameters
  volume = 1.0,
  weather = 0.2,
  pressure = 0.0,
  
  -- Threshold Logic
  silence_frames = 0
}

local env_names = {"WIND", "SAND", "TIDE"}

function init()
  screen.clear()
  screen.update()

  clock.run(function()
    clock.sleep(1.0)
    engine.ready()
    engine.set_weather(physics.weather)
    engine.set_volume(physics.volume)
  end)

  redraw_metro = metro.init(function() redraw() end, 1/15)
  redraw_metro:start()
end

-- OSC LISTENER FOR AUTO-RECORD
function osc.event(path, args, from)
  if path == "/in_amp" then
    local amp = args[1]
    
    if physics.auto_record then
      if not physics.recording and amp > 0.02 then
        -- Threshold crossed: Start layer
        toggle_formation()
      elseif physics.recording and amp < 0.01 then
        -- Threshold lost: Wait 1.5s (30 frames at 20Hz) before burying
        physics.silence_frames = physics.silence_frames + 1
        if physics.silence_frames > 30 then
          toggle_formation()
          physics.silence_frames = 0
        end
      else
        -- Active playing
        physics.silence_frames = 0
      end
    end
  end
end

function toggle_formation()
  if not physics.recording then
    physics.start_time = util.time()
    engine.shift_layers()
    engine.record_start()
    physics.recording = true
    if physics.layers_active < physics.max_layers then
      physics.layers_active = physics.layers_active + 1
    end
  else
    physics.recording = false
    physics.duration = math.min(20, util.time() - physics.start_time)
    engine.record_stop()
  end
end

function key(n, z)
  if n == 1 then
    physics.shift_held = (z == 1)
  elseif n == 2 and z == 1 then
    if physics.shift_held then
      physics.environment = (physics.environment % 3) + 1
      engine.set_env(physics.environment - 1)
    else
      -- Manual override turns off auto-record to avoid conflicts
      physics.auto_record = false 
      toggle_formation()
    end
  elseif n == 3 and z == 1 then
    if physics.shift_held then
      physics.layers_active = 0
      print("Site Excavated")
    else
      physics.auto_record = not physics.auto_record
    end
  end
end

function enc(n, d)
  if n == 1 then
    physics.volume = util.clamp(physics.volume + d/100, 0, 2)
    engine.set_volume(physics.volume)
  elseif n == 2 then
    physics.weather = util.clamp(physics.weather + d/100, 0, 1)
    engine.set_weather(physics.weather)
  elseif n == 3 then
    physics.pressure = util.clamp(physics.pressure + d/100, 0, 1)
    engine.set_pressure(physics.pressure)
  end
end

-- VISUALS
function draw_surface(y, env_type)
  screen.level(15)
  if env_type == 1 then
    for x = 12, 108, 10 do screen.line(x+4, y); screen.stroke() end
  elseif env_type == 2 then
    for x = 15, 105, 8 do screen.pixel(x, y); screen.pixel(x-1, y+1) end
    screen.fill()
  elseif env_type == 3 then
    screen.move(12, y+2); screen.text("~  ~  ~  ~  ~  ~  ~")
  end
end

function draw_soil(y, density)
  screen.level(6)
  for x = 12, 108, density do
    screen.pixel(x + math.random(-2, 2), y + math.random(0, 4))
  end
  screen.fill()
end

function draw_rock(y)
  screen.level(2)
  for x = 15, 105, 15 do
    screen.rect(x, y, 6, 4)
  end
  screen.stroke()
end

function redraw()
  screen.clear()
  
  -- HEADER
  screen.level(physics.recording and 15 or 4)
  screen.move(0, 8)
  local status = physics.recording and "FORMING STRATA" or "STABLE"
  if physics.auto_record and not physics.recording then status = "AUTO-FORMING" end
  
  local timer = physics.recording and string.format("%.1f", util.time() - physics.start_time) or string.format("%.1f", physics.duration)
  screen.text(status .. " [" .. timer .. "s]")
  
  -- CENTER STACK
  math.randomseed(123) 
  for i=1, 6 do
    local is_active = i <= physics.layers_active
    local y = 14 + (i * 7)
    
    if is_active then
      if i == 1 then
        draw_surface(y, physics.environment)
        local play_pos = ((util.time() - physics.start_time) % physics.duration) / physics.duration
        screen.level(15)
        screen.move(10 + (play_pos * 106), y - 2)
        screen.line_rel(0, 6)
        screen.stroke()
      elseif i <= 3 then
        draw_soil(y, 6) 
      else
        draw_rock(y) 
      end
    else
      screen.level(1)
      screen.move(10, y + 3)
      screen.line(118, y + 3)
      screen.stroke()
    end
  end
  
  -- FOOTER
  screen.level(4)
  screen.move(0, 62)
  screen.text("V:" .. math.floor(physics.volume*100) .. "% W:" .. math.floor(physics.weather*100) .. "% P:" .. math.floor(physics.pressure*100) .. "%")
  
  screen.update()
end
