-- memory_physics
-- archaeology of sound

local Env = require "memory_physics/lib/environments"
local Phys = require "memory_physics/lib/physics"
local Soft = require "memory_physics/lib/engine_core"
local UI = require "memory_physics/lib/ui_manager"

-- GLOBAL STATE INITIALIZATION
layers = {} -- THIS MUST EXIST BEFORE init() RUNS
active_layers = 6
excavation_pressure = 0
weather_intensity = 0.25
current_env = "Grove"

local is_recording = false
local is_manual = false
local silence_timer = 0
local rec_start_time = 0

---------------------------------------------------------
-- CORE LOGIC
---------------------------------------------------------

function start_recording()
  rec_start_time = util.time()
  softcut.position(1, 0)
  softcut.rec(1, 1)
  softcut.rec_level(1, 1.0)
  softcut.pre_level(1, 0.0) 
  is_recording = true
  redraw()
end

function stop_recording()
  local duration = util.time() - rec_start_time
  softcut.rec(1, 0)
  softcut.rec_level(1, 0.0)
  softcut.pre_level(1, 1.0)
  softcut.loop_end(1, math.max(0.1, duration))
  is_recording = false
  redraw()
end

---------------------------------------------------------
-- INITIALIZATION
---------------------------------------------------------

function init()
  softcut.buffer_clear()
  
  -- Initialize the layers table
  layers = {} 
  
  for i = 1, 6 do
    layers[i] = { voice = i, pressure_mem = 0, active = true }
    Soft.setup_voice(i, 60)
  end

  params:add_separator("ARCHAEOLOGY")
  params:add_option("mode", "Rec Mode", {"Auto", "Manual"}, 1)
  params:set_action("mode", function(x) is_manual = (x == 2) end)

  poll_input = poll.set("amp_in_l")
  poll_input.callback = function(val)
    if not is_manual then
      if val > 0.02 and not is_recording then
        start_recording()
      elseif is_recording then
        local triggered, new_timer = Phys.process_silence(val, 0.1, silence_timer, 2.0)
        silence_timer = new_timer
        if triggered then stop_recording() end
      end
    end
  end
  poll_input:start()

  clock.run(physics_loop)
  clock.run(audio_update_loop)
end

-- ... (rest of your physics_loop and audio_update_loop functions)
