```lua id="k3qq7s"
-- memory_physics.lua
-- MVP Prototype
engine.name = "None"

local poll_in

local input_level = 0
local threshold = 0.02

local silence_time = 0
local recording = false

local NEW_LAYER_TIMEOUT = 2
local REMOVE_LAYER_TIMEOUT = 10

local LOOP_LENGTH = 8

local layers = {
  {voice=1, active=false},
  {voice=2, active=false},
  {voice=3, active=false}
}



function init()

  setup_softcut()
  setup_params()
  setup_poll()

  clock.run(monitor_input)
  clock.run(redraw_clock)

end



function setup_softcut()

  audio.level_cut(1.0)

  softcut.buffer_clear()

  for i = 1,3 do

    softcut.enable(i,1)
    softcut.buffer(i,1)

    softcut.level(i,0)

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


function setup_params()

  params:add{
    type = "control",
    id = "threshold",
    name = "threshold",
    controlspec = controlspec.new(0.001,0.2,'lin',0,0.02)
  }

  params:set_action("threshold", function(x)
    threshold = x
  end)

end



function setup_poll()

  poll_in = poll.set("amp_in_l")

  poll_in.time = 0.05

  poll_in.callback = function(val)
    input_level = val
  end

  poll_in:start()

end



function monitor_input()

  while true do

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



function begin_new_layer()

  recording = true

  rotate_layers()

  local voice = layers[1].voice

  print("recording layer "..voice)

  softcut.position(voice,0)

  softcut.level(voice,1.0)

  softcut.rec(voice,1)

  layers[1].active = true

end

function finalize_layer()

  recording = false

  local voice = layers[1].voice

  print("finalize layer "..voice)

  softcut.rec(voice,0)

end

function rotate_layers()

  local temp_voice = layers[3].voice

  layers[3].voice = layers[2].voice
  layers[2].voice = layers[1].voice
  layers[1].voice = temp_voice

  layers[3].active = layers[2].active
  layers[2].active = layers[1].active
  layers[1].active = false

  apply_mix()

end

function remove_top_layer()

  if layers[1].active then

    local voice = layers[1].voice

    print("remove top layer "..voice)

    softcut.level(voice,0)

    layers[1].active = false

    silence_time = 0

    apply_mix()

  end

end

function apply_mix()

  for i = 1,3 do

    local voice = layers[i].voice

    if layers[i].active then

      if i == 1 then
        softcut.level(voice,1.0)
      elseif i == 2 then
        softcut.level(voice,0.6)
      else
        softcut.level(voice,0.3)
      end

    else

      softcut.level(voice,0)

    end

  end

end


function redraw()

  screen.clear()

  screen.move(10,20)
  screen.text("MEMORY PHYSICS")

  screen.move(10,35)
  screen.text("IN "..string.format("%.3f",input_level))

  screen.move(10,45)
  screen.text("TH "..string.format("%.3f",threshold))

  screen.move(10,55)
  screen.text("SIL "..string.format("%.1f",silence_time))

  screen.update()

end

function redraw_clock()

  while true do
    clock.sleep(1/15)
    redraw()
  end

end

function enc(n,d)

  if n == 2 then
    params:delta("threshold",d)
  end

end

