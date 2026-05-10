```lua
-- memory_physics.lua
-- MVP Archeology Prototype

engine.name = "None"

local poll_l

local threshold = 0.02
local silence_time = 0
local recording = false

local NEW_LAYER_TIMEOUT = 2
local REMOVE_LAYER_TIMEOUT = 10

local LOOP_LENGTH = 8

local current_layer = 1

local layers = {
  {voice=1, active=false},
  {voice=2, active=false},
  {voice=3, active=false}
}

--------------------------------------------------
-- INIT
--------------------------------------------------

function init()

  audio.level_adc_cut(1.0)

  setup_softcut()
  setup_polls()
  setup_params()

  clock.run(monitor_input)

end

--------------------------------------------------
-- SOFTCUT SETUP
--------------------------------------------------

function setup_softcut()

  audio.level_cut(1.0)

  for i=1,3 do

    softcut.enable(i,1)

    softcut.buffer(i,1)

    softcut.level(i,1.0)

    softcut.pan(i,0)

    softcut.play(i,1)

    softcut.loop(i,1)

    softcut.loop_start(i,0)
    softcut.loop_end(i,LOOP_LENGTH)

    softcut.position(i,0)

    softcut.rec(i,0)

    softcut.rec_level(i,1.0)

    softcut.pre_level(i,0.0)

    softcut.fade_time(i,0.05)

  end

end

--------------------------------------------------
-- PARAMS
--------------------------------------------------

function setup_params()

  params:add_control(
    "threshold",
    "input threshold",
    controlspec.new(0.001,0.2,'lin',0,0.02)
  )

  params:set_action("threshold", function(x)
    threshold = x
  end)

end

--------------------------------------------------
-- INPUT POLL
--------------------------------------------------

function setup_polls()

  poll_l = poll.set("amp_in_l")

  poll_l.time = 0.05

  poll_l.callback = function(val)
    input_level = val
  end

  poll_l:start()

end

--------------------------------------------------
-- INPUT MONITOR
--------------------------------------------------

function monitor_input()

  while true do

    if input_level == nil then
      input_level = 0
    end

    if input_level > threshold then

      silence_time = 0

      if not recording then
        begin_new_layer()
      end

    else

      silence_time = silence_time + 0.05

      if recording and silence_time > NEW_LAYER_TIMEOUT then
        finalize_layer()
      end

      if silence_time > REMOVE_LAYER_TIMEOUT then
        remove_top_layer()
      end

    end

    clock.sleep(0.05)

  end

end

--------------------------------------------------
-- LAYER MANAGEMENT
--------------------------------------------------

function begin_new_layer()

  recording = true

  rotate_layers()

  local voice = layers[1].voice

  print("recording layer "..voice)

  softcut.position(voice,0)

  softcut.rec(voice,1)

  softcut.rec_level(voice,1.0)

  softcut.pre_level(voice,0.0)

  layers[1].active = true

end

function finalize_layer()

  recording = false

  local voice = layers[1].voice

  print("finalizing layer "..voice)

  softcut.rec(voice,0)

  softcut.pre_level(voice,1.0)

end

function rotate_layers()

  layers[3].active = layers[2].active
  layers[2].active = layers[1].active
  layers[1].active = false

  local temp = layers[3].voice

  layers[3].voice = layers[2].voice
  layers[2].voice = layers[1].voice
  layers[1].voice = temp

  apply_layer_mix()

end

function remove_top_layer()

  if layers[1].active then

    print("removing top layer")

    local voice = layers[1].voice

    softcut.level(voice,0)

    layers[1].active = false

    silence_time = 0

    apply_layer_mix()

  end

end

--------------------------------------------------
-- MIXING / AGING
--------------------------------------------------

function apply_layer_mix()

  for i=1,3 do

    local voice = layers[i].voice

    if layers[i].active then

      if i == 1 then
        softcut.level(voice,1.0)

      elseif i == 2 then
        softcut.level(voice,0.6)

      elseif i == 3 then
        softcut.level(voice,0.3)

      end

    else

      softcut.level(voice,0)

    end

  end

end

--------------------------------------------------
-- UI
--------------------------------------------------

function redraw()

  screen.clear()

  screen.move(10,20)
  screen.text("MEMORY PHYSICS")

  screen.move(10,35)
  screen.text("input: "..string.format("%.3f",input_level or 0))

  screen.move(10,45)
  screen.text("threshold: "..string.format("%.3f",threshold))

  screen.move(10,55)
  screen.text("silence: "..string.format("%.1f",silence_time))

  screen.update()

end

function enc(n,d)

  if n == 2 then
    params:delta("threshold",d)
  end

  redraw()

end
```
