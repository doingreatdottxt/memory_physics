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
local master_duration = -1
local key_2_down = false
local key_3_down = false
local silence_timer = 0
local rec_start_time = 0

---------------------------------------------------------
-- HELPER FUNCTIONS                                    --
---------------------------------------------------------

function advance_strata()
  print("Strata Advanced")
end

function start_recording()
  rec_start_time = util.time()
  softcut.position(1, 0)
  softcut.rec(1, 1)
  is_recording = true
  redraw()
end

function stop_recording()
  local duration = util.time() - rec_start_time
  local sync = params:get("sync_mode")
  
  if sync == 2 then duration = Phys.snap_to_interval(duration, Phys.get_beat_sec())
  elseif sync == 3 then duration = Phys.snap_to_interval(duration, Phys.get_beat_sec() * 4) end
  
  if params:get("master_toggle") == 2 then
    if master_duration == -1 then master_duration = duration 
    else duration = Phys.snap_to_interval(duration, master_duration) end
  end

  softcut.loop_end(1, duration)
  softcut.rec(1, 0)
  is_recording = false
  advance_strata()
  redraw()
end

function handle_event(idx, e)
  if e.type == "bubble_pop" then
    softcut.rate(idx, e.rate_shift)
    clock.run(function() clock.sleep(0.1) softcut.rate(idx, 1.0) end)
  elseif e.type == "seismic_crack" then
    softcut.rec_level(idx, 1.4)
    clock.run(function() clock.sleep(e.duration) softcut.rec_level(idx, 1.0) end)
  end
end

---------------------------------------------------------
-- CORE NORNS FUNCTIONS                                --
---------------------------------------------------------

function init()
  for i = 1, 6 do
    layers[i] = { voice = i, pressure_mem = 0, active = true }
    Soft.setup_voice(i, 60)
  end

  params:add_separator("ARCHAEOLOGY")
  params:add_option("mode", "Rec Mode", {"Auto", "Manual"}, 1)
  params:set_action("mode", function(x) is_manual = (x == 2) end)

  params:add_separator("TIMING")
  params:add_option("sync_mode", "Sync", {"Free", "Beat", "Bar"}, 1)
  params:add_option("master_toggle", "Master Sync", {"Off", "On"}, 2)
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
  if n == 2 then key_2_down = (z == 1) end
  if n == 3 then key_3_down = (z == 1) end

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
  redraw()
end

function physics_loop()
  while true do
    clock.sleep(1/15)
    for i, l in ipairs(layers) do
      local depth = Phys.calculate_layer_depth(i, active_layers)
      l.pressure_mem = Phys.interpolate(l.pressure_mem, excavation_pressure * depth, 0.1)
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
  if layers and #layers > 0 then
    if show_help then
      UI.draw_help(is_manual)
    else
      UI.draw_layers(layers, active_layers, excavation_pressure)
      draw_status_header()
    end
  end
  screen.update()
end

function draw_status_header()
  screen.level(10)
  screen.move(0, 7)
  screen.text(current_env:upper())
  
  screen.move(128, 7)
  screen.text_right(is_manual and "MANUAL" or "AUTO")

  if is_recording then
    screen.level(15)
    screen.move(128, 17)
    screen.text_right("● REC")
  end

  screen.move(64, 7)
  screen.level(4)
  local tempo = params:get("clock_tempo") or 120
  screen.text_center(math.floor(tempo) .. " [" .. ({"FREE", "BEAT", "BAR"})[params:get("sync_mode")] .. "]")
  
  screen.move(110, 62)
  screen.level(5)
  screen.text("W:" .. math.floor(weather_intensity * 100))
end
