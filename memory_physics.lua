-- memory_physics.lua
-- Archeology Mode (enhanced degradation)

engine.name = "None"

local poll_in

local input_level = 0
local smoothed_level = 0

local threshold = 0.02

local silence_time = 0
local active_time = 0

local recording = false

local NEW_LAYER_TIMEOUT = 2
local REMOVE_LAYER_TIMEOUT = 10
local MIN_PHRASE_GAP = 1.5

local LOOP_LENGTH = 8
local NUM_LAYERS = 5

local layers = {}

local can_trigger = true

------------------------------------------------
-- INIT
------------------------------------------------

function init()

  math.randomseed(os.time())

  for i = 1, NUM_LAYERS do
    layers[i] = {
      voice = i,
      active = false,
      dropout = false
    }
  end

  setup_softcut()
  setup_params()
  setup_poll()

  clock.run(monitor_input)
  clock.run(redraw_clock)
  clock.run(archeology_decay_clock)

end

------------------------------------------------
-- SOFTCUT
------------------------------------------------

function setup_softcut()

  audio.level_adc_cut(1.0)
  audio.level_cut(1.0)

  softcut.buffer_clear()

  for i = 1, NUM_LAYERS do

    local start_pos = (i - 1) * LOOP_LENGTH
    local end_pos = start_pos + LOOP_LENGTH

    softcut.enable(i,1)

    softcut.buffer(i,1)

    softcut.level(i,0)

    softcut.pan(i,0)

    softcut.play(i,1)
    softcut.loop(i,1)

    softcut.loop_start(i,start_pos)
    softcut.loop_end(i,end_pos)

    softcut.position(i,start_pos)

    softcut.rec(i,0)

    softcut.rec_level(i,1.0)
    softcut.pre_level(i,0.0)

    softcut.fade_time(i,0.05)

    softcut.level_input_cut(1, i, 1.0)
    softcut.level_input_cut(2, i, 1.0)

  end

end

------------------------------------------------
-- PARAMS
------------------------------------------------

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

------------------------------------------------
-- INPUT POLL
------------------------------------------------

function setup_poll()

  poll_in = poll.set("amp_in_l")

  poll_in.time = 0.05

  poll_in.callback = function(val)

    input_level = val

    smoothed_level = (smoothed_level * 0.8) + (val * 0.2)

  end

  poll_in:start()

end

------------------------------------------------
-- INPUT MONITOR
------------------------------------------------

function monitor_input()

  while true do

    if smoothed_level > threshold then

      silence_time = 0
      active_time = active_time + 0.05

      if not recording and can_trigger and active_time > MIN_PHRASE_GAP then
        begin_new_layer()
        can_trigger = false
      end

    else

      silence_time = silence_time + 0.05
      active_time = 0
      can_trigger = true

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

------------------------------------------------
-- LAYER CONTROL
------------------------------------------------

function begin_new_layer()

  recording = true

  rotate_layers()

  local voice = layers[1].voice

  print("recording layer "..voice)

  softcut.position(voice, (voice - 1) * LOOP_LENGTH)

  softcut.level(voice,1.0)

  softcut.rate(voice,1.0)

  softcut.rec_level(voice,1.0)
  softcut.pre_level(voice,0.0)

  softcut.rec(voice,1)

  layers[1].active = true
  layers[1].dropout = false

  apply_archeology()

end

function finalize_layer()

  recording = false

  local voice = layers[1].voice

  print("finalize layer "..voice)

  softcut.rec(voice,0)

  softcut.pre_level(voice,1.0)

end

function rotate_layers()

  local temp_voice = layers[NUM_LAYERS].voice

  for i = NUM_LAYERS, 2, -1 do

    layers[i].voice = layers[i-1].voice
    layers[i].active = layers[i-1].active
    layers[i].dropout = layers[i-1].dropout

  end

  layers[1].voice = temp_voice
  layers[1].active = false
  layers[1].dropout = false

  apply_archeology()

end

function remove_top_layer()

  if layers[1].active then

    local voice = layers[1].voice

    print("remove top layer "..voice)

    softcut.level(voice,0)

    layers[1].active = false

    silence_time = 0

    apply_archeology()

  end

end

------------------------------------------------
-- ARCHEOLOGY ENGINE
------------------------------------------------

function apply_archeology()

  for i = 1, NUM_LAYERS do

    local voice = layers[i].voice

    if layers[i].active then

      local depth = i

      ------------------------------------------------
      -- GAIN LOSS
      ------------------------------------------------

      local gain_table = {
        1.0,
        0.65,
        0.38,
        0.18,
        0.07
      }

      local gain = gain_table[depth]

      if layers[i].dropout then
        gain = gain * 0.2
      end

      softcut.level(voice, gain)

      ------------------------------------------------
      -- FILTER DECAY
      ------------------------------------------------

      local cutoff_table = {
        12000,
        5000,
        2200,
        900,
        350
      }

      softcut.post_filter_fc(voice, cutoff_table[depth])

      softcut.post_filter_rq(voice, 1.6)

      ------------------------------------------------
      -- PLAYBACK INSTABILITY
      ------------------------------------------------

      local drift_amount = {
        0.0,
        0.003,
        0.008,
        0.02,
        0.05
      }

      local drift = drift_amount[depth]

      local rate = 1.0 + ((math.random() * drift) - (drift / 2))

      softcut.rate(voice, rate)

      ------------------------------------------------
      -- STEREO COLLAPSE
      ------------------------------------------------

      local pan_table = {
        0,
        0,
        0,
        -0.05 + math.random() * 0.1,
        -0.02 + math.random() * 0.04
      }

      softcut.pan(voice, pan_table[depth])

    else

      softcut.level(voice,0)

    end

  end

end

------------------------------------------------
-- MEMORY LOSS / DROPOUTS
------------------------------------------------

function archeology_decay_clock()

  while true do

    for i = 4, NUM_LAYERS do

      if layers[i].active then

        local dropout_chance = 0

        if i == 4 then
          dropout_chance = 0.15
        elseif i == 5 then
          dropout_chance = 0.35
        end

        if math.random() < dropout_chance then
          layers[i].dropout = not layers[i].dropout
        end

      end

    end

    apply_archeology()

    clock.sleep(0.7)

  end

end

------------------------------------------------
-- UI
------------------------------------------------

function redraw()

  screen.clear()

  screen.move(10,15)
  screen.text("ARCHEOLOGY")

  screen.move(10,30)
  screen.text("IN "..string.format("%.3f",input_level))

  screen.move(10,40)
  screen.text("SM "..string.format("%.3f",smoothed_level))

  screen.move(10,50)
  screen.text("TH "..string.format("%.3f",threshold))

  screen.move(10,60)
  screen.text("S "..string.format("%.1f",silence_time))

  screen.move(10,70)
  screen.text("5 MEMORY LAYERS")

  screen.update()

end

function redraw_clock()

  while true do
    clock.sleep(1/15)
    redraw()
  end

end

------------------------------------------------
-- ENCODERS
------------------------------------------------

function enc(n,d)

  if n == 2 then
    params:delta("threshold", d)
  end

end
