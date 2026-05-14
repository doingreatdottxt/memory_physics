-- memory_physics
-- archaeology of sound

local Env = require "memory_physics/lib/environments"
local Phys = require "memory_physics/lib/physics"
local Soft = require "memory_physics/lib/engine_core"
local UI = require "memory_physics/lib/ui_manager"

-- GLOBAL STATE
layers = {} 
active_layers = 6
excavation_pressure = 0
weather_intensity = 0.25
current_env = "Grove"

local is_recording = false
local is_manual = false
local silence_timer = 0
local rec_start_time = 0

---------------------------------------------------------
-- LOOPS (Define these BEFORE init)
---------------------------------------------------------

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

---------------------------------------------------------
-- CORE LOGIC
---------------------------------------------------------

function start_recording()
  -- ... (your existing code)
end

function stop_recording()
  -- ... (your existing code)
end

---------------------------------------------------------
-- INITIALIZATION
---------------------------------------------------------

function init()
  softcut.buffer_clear()
  layers = {} 
  
  for i = 1, 6 do
    layers[i] = { voice = i, pressure_mem = 0, active = true }
    Soft.setup_voice(i, 60)
  end

  -- ... (params and poll setup)

  -- Now these functions exist and won't be nil
  clock.run(physics_loop)
  clock.run(audio_update_loop)
end
