-- memory_physics.lua
-- Archeology Mode (transitional burial alpha)

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

-- transitional burial state
local burial_active = false
local burial_progress = 0
local burial_source_voice = nil

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

    softcut.level_cut_cut(i, i, 0)

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

      if recording then
        update_burial_progress()
      end

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
        collapse_memory_stack()
      end

    end

    clock.sleep(0.05)

  end

end

------------------------------------------------
-- RECORDING CONTROL
------------------------------------------------

function begin_new_layer()

  recording = true

  burial_active = true
  burial_progress = 0

  -- preserve current top layer for gradual burial
  if layers[1].active then
    burial_source_voice = layers[1].voice
  else
    burial_source_voice = nil
  end

  local new_voice = layers[NUM_LAYERS].voice

  print("recording layer "..new_voice)

  local start_pos = (new_voice - 1) * LOOP_LENGTH

  softcut.position(new_voice, start_pos)

  softcut.level(new_voice, 0)

  softcut.rate(new_voice,1.0)

  softcut.rec_level(new_voice,1.0)

  softcut.pre_level(new_voice,0.0)

  softcut.rec(new_voice,1)

  layers[NUM_LAYERS].active = true
  layers[NUM_LAYERS].dropout = false

end

function finalize_layer()

  recording = false

  local voice = layers[NUM_LAYERS].voice

  print("finalize layer "..voice)

  softcut.rec(voice,0)

  softcut.pre_level(voice,1.0)

  commit_burial()

  burial_active = false
  burial_progress = 0
  burial_source_voice = nil

  apply_archeology()

end

------------------------------------------------
-- TRANSITIONAL BURIAL
------------------------------------------------

function update_burial_progress()

  if not burial_active then
    return
  end

  burial_progress = burial_progress + 0.01

  if burial_progress > 1 then
    burial_progress = 1
  end

  apply_archeology()

end

function commit_burial()

  local temp = layers[NUM_LAYERS]

  for i = NUM_LAYERS, 2, -1 do
    layers[i] = layers[i-1]
  end

  layers[1] = temp

end

------------------------------------------------
-- RESURFACING
------------------------------------------------

function collapse_memory_stack()

  if not layers[1].active then
    return
  end

  print("memory collapse")

  local removed_voice = layers[1].voice

  softcut.level(removed_voice,0)

  for i = 1, NUM_LAYERS - 1 do

    layers[i].voice = layers[i+1].voice
    layers[i].active = layers[i+1].active
    layers[i].dropout = layers[i+1].dropout

  end

  layers[NUM_LAYERS].voice = removed_voice
  layers[NUM_LAYERS].active = false
  layers[NUM_LAYERS].dropout = false

  silence_time = 0

  apply_archeology()

end

------------------------------------------------
-- ARCHEOLOGY ENGINE
------------------------------------------------

function apply_archeology()

  for i = 1, NUM_LAYERS do

    local voice = layers[i].voice

    if layers[i].active then

      local depth = i

      local gain_table = {
        1.0,
        0.65,
        0.38,
        0.18,
        0.07
      }

      local cutoff_table = {
        12000,
        5000,
        2200,
        900,
        250
      }

      local drift_table = {
        0.0,
        0.004,
        0.012,
        0.03,
        0.08
      }

      local gain = gain_table[depth]

      ------------------------------------------------
      -- TRANSITIONAL BURIAL BEHAVIOR
      ------------------------------------------------

      if burial_active then

        local incoming_voice = layers[NUM_LAYERS].voice

        -- new layer gradually emerges
        if voice == incoming_voice then

          gain = burial_progress

          softcut.level(voice, gain)

          softcut.post_filter_fc(voice, 12000)

          softcut.rate(voice,1.0)

        -- previous surface gradually sinks
        elseif voice == burial_source_voice then

          local sink_gain = 1.0 - (burial_progress * 0.88)

          softcut.level(voice, sink_gain)

          local cutoff = 12000 - (burial_progress * 10500)

          softcut.post_filter_fc(voice, cutoff)

          local rate = 1.0 - (burial_progress * 0.015)

          softcut.rate(voice, rate)

        else

          -- deeper layers dormant during excavation
          softcut.level(voice,0)

        end

      else

        ------------------------------------------------
        -- NORMAL PLAYBACK DEGRADATION
        ------------------------------------------------

        if layers[i].dropout then
          gain = gain * 0.15
        end

        softcut.level(voice, gain)

        softcut.post_filter_fc(voice, cutoff_table[depth])

        softcut.post_filter_rq(voice, 1.8)

        local drift = drift_table[depth]

        local rate = 1.0 + ((math.random() * drift) - (drift / 2))

        softcut.rate(voice, rate)

      end

    else

      softcut.level(voice,0)

    end

  end

end

------------------------------------------------
-- MEMORY EROSION
------------------------------------------------

function archeology_decay_clock()

  while true do

    if not burial_active then

      for i = 4, NUM_LAYERS do

        if layers[i].active then

          local chance = 0

          if i == 4 then
            chance = 0.2
          elseif i == 5 then
            chance = 0.45
          end

          if math.random() < chance then
            layers[i].dropout = not layers[i].dropout
          end

        end

      end

      apply_archeology()

    end

    clock.sleep(0.6)

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
  screen.text("TH "..string.format("%.3f",threshold))

  screen.move(10,50)
  screen.text("S "..string.format("%.1f",silence_time))

  screen.move(10,60)

  if burial_active then
    screen.text("BURIAL "..string.format("%.2f",burial_progress))
  else
    screen.text("EXCAVATION STABLE")
  end

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
