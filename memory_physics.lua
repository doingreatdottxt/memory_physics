@ -1,73 +1,84 @@
-- memory_physics.lua
-- Archeology Mode Alpha
-- armed manual recording mode

engine.name = "None"

local poll_in

------------------------------------------------
-- INPUT STATE
------------------------------------------------

local input_level = 0
local smoothed_level = 0

local threshold = 0.02

local silence_time = 0
local active_time = 0

local recording = false

------------------------------------------------
-- RECORD MODES
------------------------------------------------

local record_mode = "auto"

local manual_armed = false
local manual_waiting_for_input = false
local manual_recording = false

------------------------------------------------
-- TIMING
------------------------------------------------

local NEW_LAYER_TIMEOUT = 1
local REMOVE_LAYER_TIMEOUT = 16
local MIN_PHRASE_GAP = 0.1

------------------------------------------------
-- MEMORY SYSTEM
------------------------------------------------

local MAX_LOOP_LENGTH = 30

local MAX_LAYERS = 6
local ACTIVE_LAYERS = 5

local layers = {}

local can_trigger = true

------------------------------------------------
-- EXCAVATION PRESSURE
------------------------------------------------

local excavation_pressure = 0

------------------------------------------------
-- BURIAL STATE
------------------------------------------------

local burial_active = false
local burial_source_voice = nil

local burial_crossfade = false
local burial_crossfade_progress = 0
local burial_crossfade_duration = 0

------------------------------------------------
-- COLLAPSE STATE
------------------------------------------------

local collapse_crossfade = false
local collapse_crossfade_progress = 0
local collapse_source_voice = nil
local collapse_target_voice = nil

local COLLAPSE_CROSSFADE_TIME = 4.0

------------------------------------------------
-- LOOP CROSSFADE
------------------------------------------------
@ -114,6 +125,7 @@ function init()
  clock.run(redraw_clock)
  clock.run(archeology_decay_clock)
  clock.run(burial_crossfade_clock)
  clock.run(collapse_crossfade_clock)

end

@ -286,7 +298,7 @@ function monitor_input()

        if silence_time > REMOVE_LAYER_TIMEOUT then

          collapse_memory_stack()
          begin_collapse_sequence()

        end

@ -319,7 +331,7 @@ function monitor_input()

      if silence_time > REMOVE_LAYER_TIMEOUT then

        collapse_memory_stack()
        begin_collapse_sequence()

      end

@ -553,49 +565,60 @@ function burial_crossfade_clock()
end

------------------------------------------------
-- COMMIT BURIAL
-- COLLAPSE SEQUENCE
------------------------------------------------

function commit_burial()
function begin_collapse_sequence()

  local temp = {
    voice = layers[MAX_LAYERS].voice,
    active = layers[MAX_LAYERS].active,
    dropout = layers[MAX_LAYERS].dropout,
    loop_end = layers[MAX_LAYERS].loop_end
  }
  if not layers[1].active then
    return
  end

  for i = MAX_LAYERS, 2, -1 do
  print("memory collapse beginning")

    layers[i].voice = layers[i-1].voice
    layers[i].active = layers[i-1].active
    layers[i].dropout = layers[i-1].dropout
    layers[i].loop_end = layers[i-1].loop_end
  collapse_source_voice = layers[1].voice
  collapse_target_voice = layers[2].voice

  end
  collapse_crossfade = true
  collapse_crossfade_progress = 0

  layers[1].voice = temp.voice
  layers[1].active = temp.active
  layers[1].dropout = temp.dropout
  layers[1].loop_end = temp.loop_end
  silence_time = 0

end

------------------------------------------------
-- COLLAPSE
-- COLLAPSE CROSSFADE
------------------------------------------------

function collapse_memory_stack()
function update_collapse_crossfade()

  if not layers[1].active then
  if not collapse_crossfade then
    return
  end

  print("memory collapse")
  collapse_crossfade_progress =
    collapse_crossfade_progress + 0.05 / COLLAPSE_CROSSFADE_TIME

  if collapse_crossfade_progress >= 1 then

    collapse_crossfade = false
    collapse_crossfade_progress = 1

    finalize_collapse()

  end

  apply_archeology()

end

function finalize_collapse()

  print("memory collapse finalized")

  local removed_voice = layers[1].voice

  softcut.level(removed_voice,0)
  softcut.level(removed_voice, 0)

  for i = 1, MAX_LAYERS - 1 do

@ -611,15 +634,57 @@ function collapse_memory_stack()
  layers[MAX_LAYERS].dropout = false
  layers[MAX_LAYERS].loop_end = MAX_LOOP_LENGTH

  silence_time = 0

  excavation_pressure =
    math.max(0, excavation_pressure - 0.12)

  collapse_source_voice = nil
  collapse_target_voice = nil

  apply_archeology()

end

function collapse_crossfade_clock()

  while true do

    clock.sleep(0.05)

    update_collapse_crossfade()

  end

end

------------------------------------------------
-- COMMIT BURIAL
------------------------------------------------

function commit_burial()

  local temp = {
    voice = layers[MAX_LAYERS].voice,
    active = layers[MAX_LAYERS].active,
    dropout = layers[MAX_LAYERS].dropout,
    loop_end = layers[MAX_LAYERS].loop_end
  }

  for i = MAX_LAYERS, 2, -1 do

    layers[i].voice = layers[i-1].voice
    layers[i].active = layers[i-1].active
    layers[i].dropout = layers[i-1].dropout
    layers[i].loop_end = layers[i-1].loop_end

  end

  layers[1].voice = temp.voice
  layers[1].active = temp.active
  layers[1].dropout = temp.dropout
  layers[1].loop_end = temp.loop_end

end

------------------------------------------------
-- ENVIRONMENT TABLES
------------------------------------------------
@ -718,6 +783,74 @@ function apply_archeology()

        softcut.rate(voice, 1.0)

      ------------------------------------------------
      -- COLLAPSE CROSSFADE
      ------------------------------------------------

      elseif collapse_crossfade then

        local progress = collapse_crossfade_progress

        if voice == collapse_source_voice then

          -- fading out: collapse_source_voice at layer 1
          local layer1_gain = env.gains[1] or 1.0
          local layer1_cutoff = env.cutoffs[1] or 12000

          local faded_gain =
            layer1_gain * (1.0 - progress)

          local faded_cutoff =
            layer1_cutoff * (1.0 - progress) + (env.cutoffs[2] or 6500) * progress

          softcut.level(voice, faded_gain)

          softcut.post_filter_fc(voice, faded_cutoff)

          softcut.rate(voice, 1.0)

        elseif voice == collapse_target_voice then

          -- fading in: collapse_target_voice from layer 2 to layer 1
          local layer1_gain = env.gains[1] or 1.0
          local layer1_cutoff = env.cutoffs[1] or 12000
          local layer2_gain = env.gains[2] or 0.7
          local layer2_cutoff = env.cutoffs[2] or 6500

          local faded_gain =
            layer2_gain * (1.0 - progress) + (layer1_gain * progress)

          local faded_cutoff =
            layer2_cutoff * (1.0 - progress) + (layer1_cutoff * progress)

          softcut.level(voice, faded_gain)

          softcut.post_filter_fc(voice, faded_cutoff)

          softcut.rate(voice, 1.0)

        else

          -- normal playback for other layers
          if layers[i].dropout then
            gain = gain * 0.15
          end

          softcut.level(voice,gain)

          softcut.post_filter_fc(voice,cutoff)

          softcut.post_filter_rq(voice,1.8)

          local rate =
            1.0 +
            ((math.random() * drift)
            - (drift / 2))

          softcut.rate(voice,rate)

        end

      ------------------------------------------------
      -- NORMAL PLAYBACK
      ------------------------------------------------
@ -764,7 +897,7 @@ function archeology_decay_clock()

  while true do

    if not burial_active then
    if not burial_active and not collapse_crossfade then

      for i = 4, ACTIVE_LAYERS do

