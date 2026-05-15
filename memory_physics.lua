-- memory_physics
-- archaeology of sound

local Env = require "memory_physics/lib/environments"
local Phys = require "memory_physics/lib/physics"
local Soft = require "memory_physics/lib/engine_core"
local UI = require "memory_physics/lib/ui_manager"

-- Global State
layers = {}
active_layers = 6
excavation_pressure = 0
weather_intensity = 0.25
current_env = "Grove"

-- System State
local alt_held = false
local show_help = false
local is_manual = false
local is_recording = false
local silence_timer = 0
local rec_start_time = 0
local master_duration = -1 

-- Acoustic Depth Manifesto: 100% -> 50% -> 20% -> Silence
local BASE_VOLS = {1.0, 0.5, 0.2, 0.0, 0.0, 0.0}

---------------------------------------------------------
-- ARCHAEOLOGY LOGIC (LIFO / ROTATION)                 --
---------------------------------------------------------

function advance_strata()
  local recycled_voice = layers[6].voice
  
  for i = 6, 2, -1 do
    layers[i].voice = layers[i-1].voice
    layers[i].gain_mem = layers[i-1].gain_mem
    layers[i].pressure_mem = layers[i-1].pressure_mem
    layers[i].duration = layers[i-1].duration
    layers[i].current_vol = layers[i-1].current_vol 
    layers[i].target_vol = BASE_VOLS[i] 
  end
  
  layers[1].voice = recycled_voice
  layers[1].gain_mem = 1.0
  layers[1].duration = -1 
  layers[1].current_vol = 0.0 
  layers[1].target_vol = BASE_VOLS[1]
  
  softcut.rec_level(recycled_voice, 0.0)
end

function recede_strata()
  local dead_voice = layers[1].voice
  
  for i = 1, 5 do
    layers[i].voice = layers[i+1].voice
    layers[i].gain_mem = layers[i+1].gain_mem
    layers[i].pressure_mem = layers[i+1].pressure_mem
    layers[i].duration = layers[i+1].duration
    layers[i].current_vol = layers[i+1].current_vol
    layers[i].target_vol = BASE_VOLS[i] 
  end
  
  layers[6].voice = dead_voice
  layers[6].gain_mem = 1.0
  layers[6].duration = -1
  layers[6].current_vol = 0.0
  layers[6].target_vol = BASE_VOLS[6]
  
  softcut.rec_level(dead_voice, 0.0)
  softcut.level(dead_voice, 0.0)
end

function start_recording()
  if layers[1].duration ~= -1 then
    advance_strata()
  end

  local v = layers[1].voice
  rec_start_time = util.time()
  softcut.position(v, 0)
  softcut.rec(v, 1)
  softcut.rec_level(v, 1.0)
  softcut.pre_level(v, 0.0) 
  is_recording = true
  redraw()
end

function stop_recording()
  local v = layers[1].voice
  local duration = util.time() - rec_start_time
  local sync = params:get("sync_mode")
  
  if sync == 2 then 
    duration = Phys.snap_to_interval(duration, Phys.get_beat_sec())
  elseif sync == 3 then 
    if master_duration > 0 then
      duration = Phys.snap_to_bedrock(duration, master_duration)
    else
      duration = Phys.snap_to_interval(duration, Phys.get_beat_sec())
    end
  end
  
  if master_duration == -1 then master_duration = duration end
  layers[1].duration = duration
  softcut.loop_end(v, duration)
  softcut.rec(v, 0)
  softcut.rec_level(v, 0.0)
  softcut.pre_level(v, 1.0) 
  is_recording = false
  redraw()
end

---------------------------------------------------------
-- CLOCK LOOPS
---------------------------------------------------------

function audio_update_loop()
  local dt = 1/30
  while true do
    clock.sleep(dt)
    
    if layers[1] and layers[1].duration > 0 and not is_recording then
      local decay_rate = params:get("decay") / 100
      local loss = decay_rate * (dt / layers[1].duration)
      layers[1].gain_mem = layers[1].gain_mem - loss
      
      if layers[1].gain_mem <= 0 then
        recede_strata()
      end
    end

    for i, l in ipairs(layers) do
      l.current_vol = Phys.interpolate(l.current_vol, l.target_vol, 0.05)
      local p = Env.get_params(current_env, l.pressure_mem, i, weather_intensity)
      local safe_gain_mem = math.max(0, l.gain_mem)
      p.gain = p.gain * safe_gain_mem * l.current_vol
      Soft.apply_params(l.voice, p)
    end
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

---------------------------------------------------------
-- CORE
---------------------------------------------------------

function init()
  softcut.buffer_clear()
  layers = {}
  for i = 1, 6 do
    layers[i] = { 
      voice = i, pressure_mem = 0, gain_mem = 1.0, 
      duration = -1, current_vol = BASE_VOLS[i], target_vol = BASE_VOLS[i] 
    }
    Soft.setup_voice(i, 60)
  end

  params:add_separator("ARCHAEOLOGY")
  params:add_option("mode", "Rec Mode", {"Auto", "Manual"}, 1)
  params:set_action("mode", function(x) is_manual = (x == 2) end)
  params:add_control("decay", "Surface Erosion", controlspec.new(0, 100, "lin", 1, 20, "%"))

  params:add_separator("TIMING")
  params:add_option("sync_mode", "Sync", {"Free", "Beat", "Bar"}, 1)
  params:add_control("silence_time", "Silence Time", controlspec.new(0.5, 10, "lin", 0.1, 2))

  params:add_option("environment", "Environment", Env.list, 3) 
  params:set_action("environment", function(x) current_env = Env.list[x] end)

  poll_input = poll.set("amp_in_l")
  poll_input.callback = function(val)
    if not is_manual then
      if val > 0.05 and not is_recording then
        start_recording()
      elseif is_recording then
        local triggered, new_timer = Phys.process_silence(val, 0.1, silence_timer, params:get("silence_time"))
        silence_timer = new_timer
        if triggered then stop_recording() end
      end
    end
  end
  poll_input:start()

  clock.run(physics_loop)
  clock.run(audio_update_loop)
end

function enc(n, d)
  if n == 1 then params:delta("environment", d)
  elseif n == 2 then weather_intensity = util.clamp(weather_intensity + (d/100), 0, 1)
  elseif n == 3 then excavation_pressure = util.clamp(excavation_pressure + (d/100), 0, 1) end
  redraw() 
end

function key(n, z)
  if n == 1 then alt_held = (z == 1) end
  if z == 1 then
    if alt_held then
      if n == 2 then show_help = not show_help
      elseif n == 3 then params:set("sync_mode", (params:get("sync_mode") % 3) + 1) end
    else
      if n == 2 and is_manual then
        if not is_recording then start_recording() else stop_recording() end
      elseif n == 3 then params:set("mode", (params:get("mode") % 2) + 1) end
    end
  end
  redraw()
end

function redraw()
  screen.clear()
  if show_help then UI.draw_help(is_manual)
  else
    UI.draw_layers(layers, active_layers, excavation_pressure)
    draw_status_header()
  end
  screen.update()
end

function draw_status_header()
  screen.level(10); screen.move(0, 7); screen.text(current_env:upper())
  screen.move(128, 7); screen.text_right(is_manual and "MANUAL" or "AUTO")
  if is_recording then
    screen.level(15); screen.move(128, 17); screen.text_right("● REC")
  end
  screen.move(64, 7); screen.level(4)
  local sync_text = ({"FREE", "BEAT", "BAR"})[params:get("sync_mode")]
  screen.text_center("[" .. sync_text .. "]")
end
