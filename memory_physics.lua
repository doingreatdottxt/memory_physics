-- memory_physics.lua
-- Archeology Mode Alpha
-- environmental excavation memory system

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

local excavation_pressure = 0.25

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

local LOOP_FADE_TIME = 0.12

------------------------------------------------
-- RECORD POSITION TRACKING
------------------------------------------------

local record_start_time = 0
local record_duration = 0

------------------------------------------------
-- ENVIRONMENT
------------------------------------------------

local environments = {
  "desert",
  "forest",
  "swamp",
  "river",
  "deep_sea",
  "mountain",
  "cave"
}

local environment_index = 1
local environment = environments[environment_index]

------------------------------------------------
-- KEY STATE
------------------------------------------------

local k1_hold = false

------------------------------------------------
-- INIT
------------------------------------------------

function init()

  math.randomseed(os.time())

  for i = 1, MAX_LAYERS do

    layers[i] = {
      voice = i,
      active = false,
      dropout = false,
      loop_end = MAX_LOOP_LENGTH
    }

  end

  setup_softcut()
  setup_params()
  setup_poll()

  clock.run(monitor_input)
  clock.run(redraw_clock)
  clock.run(archeology_decay_clock)
  clock.run(burial_crossfade_clock)
  clock.run(collapse_crossfade_clock)

end

------------------------------------------------
-- SOFTCUT
------------------------------------------------

function setup_softcut()

  audio.level_adc_cut(1.0)
  audio.level_cut(1.0)

  softcut.buffer_clear()

  for i = 1, MAX_LAYERS do

    local start_pos = (i - 1) * MAX_LOOP_LENGTH
    local end_pos = start_pos + MAX_LOOP_LENGTH

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

    softcut.fade_time(i, LOOP_FADE_TIME)

    softcut.level_input_cut(1, i, 1.0)
    softcut.level_input_cut(2, i, 1.0)

    softcut.level_cut_cut(i, i, 0)

    softcut.post_filter_dry(i,0.0)
    softcut.post_filter_lp(i,1.0)
    softcut.post_filter_bp(i,0.0)
    softcut.post_filter_hp(i,0.0)

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

  params:add{
    type = "control",
    id = "loop_fade",
    name = "loop fade",
    controlspec = controlspec.new(0.01,1.0,'lin',0,0.12,"s")
  }

  params:set_action("loop_fade", function(x)

    LOOP_FADE_TIME = x

    for i = 1, MAX_LAYERS do
      softcut.fade_time(i, LOOP_FADE_TIME)
    end

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

    smoothed_level =
      (smoothed_level * 0.8) + (val * 0.2)

  end

  poll_in:start()

end

------------------------------------------------
-- INPUT MONITOR
------------------------------------------------

function monitor_input()

  while true do

    if record_mode == "auto" then

      if smoothed_level > threshold then

        silence_time = 0

        active_time = active_time + 0.05

        if not recording
        and can_trigger
        and active_time > MIN_PHRASE_GAP then

          begin_new_layer()

          can_trigger = false

        end

      else

        silence_time = silence_time + 0.05

        active_time = 0

        can_trigger = true

        if recording
        and silence_time > NEW_LAYER_TIMEOUT then

          finalize_layer()

        end

        if silence_time > REMOVE_LAYER_TIMEOUT then

          begin_collapse_sequence()

        end

      end

    else

      if manual_waiting_for_input then

        if smoothed_level > threshold then

          begin_new_layer()

          manual_waiting_for_input = false
          manual_recording = true

        end

      end

      silence_time = silence_time + 0.05

      if silence_time > REMOVE_LAYER_TIMEOUT then

        begin_collapse_sequence()

      end

    end

    clock.sleep(0.05)

  end

end

------------------------------------------------
-- RECORDING
------------------------------------------------

function begin_new_layer()

  recording = true

  burial_active = true

  if layers[1].active then
    burial_source_voice = layers[1].voice
  else
    burial_source_voice = nil
  end

  local new_voice = layers[MAX_LAYERS].voice

  print("recording layer "..new_voice)

  local start_pos =
    (new_voice - 1) * MAX_LOOP_LENGTH

  softcut.loop_start(new_voice,start_pos)

  softcut.loop_end(
    new_voice,
    start_pos + MAX_LOOP_LENGTH
  )

  softcut.position(new_voice,start_pos)

  softcut.level(new_voice, 1.0)

  softcut.rate(new_voice,1.0)

  softcut.rec_level(new_voice,1.0)

  softcut.pre_level(new_voice,0.0)

  softcut.rec(new_voice,1)

  record_start_time = util.time()

  layers[MAX_LAYERS].active = true
  layers[MAX_LAYERS].dropout = false
  layers[MAX_LAYERS].loop_end = MAX_LOOP_LENGTH

  excavation_pressure =
    math.min(1.0, excavation_pressure + 0.06)

  apply_archeology()

end

function finalize_layer()

  recording = false

  manual_recording = false
  manual_armed = false
  manual_waiting_for_input = false

  local voice = layers[MAX_LAYERS].voice

  print("finalize layer "..voice)

  softcut.rec(voice,0)

  softcut.pre_level(voice,1.0)

  record_duration =
    util.time() - record_start_time

  local final_length

  if record_mode == "auto" then

    final_length =
      math.max(
        0.25,
        record_duration - NEW_LAYER_TIMEOUT
      )

  else

    final_length =
      math.max(
        0.25,
        record_duration
      )

  end

  final_length =
    math.min(final_length, MAX_LOOP_LENGTH)

  local start_pos =
    (voice - 1) * MAX_LOOP_LENGTH

  local end_pos =
    start_pos + final_length

  softcut.loop_start(voice,start_pos)

  softcut.loop_end(voice,end_pos)

  layers[MAX_LAYERS].loop_end =
    final_length

  print("loop length "..final_length)

  commit_burial()

  burial_active = false

  if burial_source_voice ~= nil then
    burial_crossfade = true
    burial_crossfade_progress = 0
    burial_crossfade_duration = final_length * 0.5
  end

  apply_archeology()

end

------------------------------------------------
-- MANUAL ARM / STOP
------------------------------------------------

function manual_record_control()

  if record_mode ~= "manual" then
    return
  end

  if not manual_armed
  and not manual_recording then

    manual_armed = true
    manual_waiting_for_input = true

    print("manual armed")

    return

  end

  if manual_recording then

    finalize_layer()

    print("manual stop")

  end

end

------------------------------------------------
-- BURIAL CROSSFADE
------------------------------------------------

function update_burial_crossfade()

  if not burial_crossfade then
    return
  end

  burial_crossfade_progress =
    burial_crossfade_progress + 0.004

  if burial_crossfade_progress >= 1 then

    burial_crossfade = false

    burial_crossfade_progress = 1

    burial_source_voice = nil

  end

  apply_archeology()

end

function burial_crossfade_clock()

  while true do

    clock.sleep(0.05)

    update_burial_crossfade()

  end

end

------------------------------------------------
-- COLLAPSE SEQUENCE
------------------------------------------------

function begin_collapse_sequence()

  if not layers[1].active then
    return
  end

  print("memory collapse beginning")

  collapse_source_voice = layers[1].voice
  collapse_target_voice = layers[2].voice

  collapse_crossfade = true
  collapse_crossfade_progress = 0

  silence_time = 0

end

------------------------------------------------
-- COLLAPSE CROSSFADE
------------------------------------------------

function update_collapse_crossfade()

  if not collapse_crossfade then
    return
  end

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

  softcut.level(removed_voice, 0)

  for i = 1, MAX_LAYERS - 1 do

    layers[i].voice = layers[i+1].voice
    layers[i].active = layers[i+1].active
    layers[i].dropout = layers[i+1].dropout
    layers[i].loop_end = layers[i+1].loop_end

  end

  layers[MAX_LAYERS].voice = removed_voice
  layers[MAX_LAYERS].active = false
  layers[MAX_LAYERS].dropout = false
  layers[MAX_LAYERS].loop_end = MAX_LOOP_LENGTH

  excavation_pressure =
    math.max(0, excavation_pressure - 0.1)

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
-- ARCHEOLOGY ENGINE
------------------------------------------------

function apply_archeology()

  for i = 1, MAX_LAYERS do

    local voice = layers[i].voice

    if layers[i].active
    and i <= ACTIVE_LAYERS then

      local gain = 1.0 - ((i - 1) * 0.18)

      local pressure =
        excavation_pressure * excavation_pressure

      local cutoff = 12000
      local rq = 1.2
      local drift = 0.0

      ------------------------------------------------
      -- DESERT
      ------------------------------------------------

      if environment == "desert" then

        cutoff =
          14000 -
          (pressure * i * 5000)

        rq =
          1.4 + (pressure * 2.4)

        gain =
          gain *
          (1.0 - (pressure * i * 0.22))

        drift =
          pressure * 0.08

        softcut.post_filter_hp(
          voice,
          math.min(1.0, pressure * 0.85)
        )

        softcut.post_filter_bp(
          voice,
          pressure * 0.35
        )

      ------------------------------------------------
      -- FOREST
      ------------------------------------------------

      elseif environment == "forest" then

        cutoff =
          10000 -
          (pressure * i * 9000)

        rq =
          0.8 + (pressure * 0.6)

        gain =
          gain *
          (1.0 - (pressure * 0.32))

        drift =
          pressure * 0.015

        softcut.post_filter_hp(
          voice,
          0
        )

        softcut.post_filter_bp(
          voice,
          pressure * 0.08
        )

      ------------------------------------------------
      -- SWAMP
      ------------------------------------------------

      elseif environment == "swamp" then

        cutoff =
          7000 -
          (pressure * i * 6000)

        rq =
          2.0 + (pressure * 2.5)

        gain =
          gain *
          (1.0 - (pressure * 0.15))

        drift =
          pressure * 0.14

        softcut.post_filter_hp(
          voice,
          pressure * 0.05
        )

        softcut.post_filter_bp(
          voice,
          pressure * 0.22
        )

      ------------------------------------------------
      -- RIVER
      ------------------------------------------------

      elseif environment == "river" then

        cutoff =
          12000 -
          (pressure * i * 3000)

        rq =
          1.2 + (pressure * 1.0)

        gain =
          gain *
          (1.0 - (pressure * 0.12))

        drift =
          pressure * 0.24

        if i >= 4 and math.random() < (pressure * 0.18) then
          gain = gain * 2.2
        end

        softcut.post_filter_hp(
          voice,
          pressure * 0.12
        )

        softcut.post_filter_bp(
          voice,
          pressure * 0.12
        )

      ------------------------------------------------
      -- DEEP SEA
      ------------------------------------------------

      elseif environment == "deep_sea" then

        cutoff =
          5000 -
          (pressure * i * 4200)

        rq =
          2.4 + (pressure * 4.0)

        gain =
          gain *
          (1.0 - (pressure * 0.08))

        drift =
          pressure * 0.01

        softcut.post_filter_hp(
          voice,
          0
        )

        softcut.post_filter_bp(
          voice,
          pressure * 0.45
        )

      ------------------------------------------------
      -- MOUNTAIN
      ------------------------------------------------

      elseif environment == "mountain" then

        cutoff =
          15000 -
          (pressure * i * 7000)

        rq =
          1.6 + (pressure * 5.0)

        gain =
          gain *
          (1.0 - (pressure * 0.28))

        drift =
          pressure * 0.18

        if pressure > 0.75
        and math.random() < 0.12 then

          gain = gain * 3.5

        end

        softcut.post_filter_hp(
          voice,
          pressure * 0.42
        )

        softcut.post_filter_bp(
          voice,
          pressure * 0.65
        )

      ------------------------------------------------
      -- CAVE
      ------------------------------------------------

      elseif environment == "cave" then

        cutoff =
          9000 -
          (pressure * i * 4500)

        rq =
          2.0 + (pressure * 2.2)

        gain =
          gain *
          (1.0 - (pressure * 0.18))

        drift =
          pressure * 0.03

        softcut.post_filter_hp(
          voice,
          pressure * 0.04
        )

        softcut.post_filter_bp(
          voice,
          pressure * 0.32
        )

      end

      ------------------------------------------------
      -- DROPOUT DAMAGE
      ------------------------------------------------

      if layers[i].dropout then
        gain = gain * 0.12
      end

      ------------------------------------------------
      -- APPLY
      ------------------------------------------------

      softcut.level(
        voice,
        util.clamp(gain,0,2.5)
      )

      softcut.post_filter_fc(
        voice,
        math.max(80, cutoff)
      )

      softcut.post_filter_rq(
        voice,
        rq
      )

      softcut.post_filter_lp(
        voice,
        1.0
      )

      local rate =
        1.0 +
        ((math.random() * drift)
        - (drift / 2))

      softcut.rate(voice,rate)

    else

      softcut.level(voice,0)

    end

  end

end

------------------------------------------------
-- EROSION CLOCK
------------------------------------------------

function archeology_decay_clock()

  while true do

    if not burial_active and not collapse_crossfade then

      for i = 3, ACTIVE_LAYERS do

        if layers[i].active then

          local chance =
            0.05 +
            (i * 0.1) +
            (excavation_pressure * 0.45)

          if math.random() < chance then

            layers[i].dropout =
              not layers[i].dropout

          end

        end

      end

      apply_archeology()

    end

    clock.sleep(0.45)

  end

end

------------------------------------------------
-- UI
------------------------------------------------

function redraw()

  screen.clear()

  screen.level(15)
  screen.move(10,12)
  screen.text("ARCHEOLOGY")

  screen.level(10)
  screen.move(10,24)
  screen.text("MODE")

  screen.level(15)
  screen.move(64,24)
  screen.text(record_mode)

  screen.level(10)
  screen.move(10,36)
  screen.text("STATE")

  screen.level(15)
  screen.move(64,36)

  if manual_waiting_for_input then

    screen.text("ARMED")

  elseif recording then

    screen.text("REC")

  elseif collapse_crossfade then

    screen.text("COLLAPSE")

  else

    screen.text(environment)

  end

  screen.level(10)
  screen.move(10,48)
  screen.text("PRESS")

  screen.level(15)
  screen.move(64,48)
  screen.text(
    string.format("%.2f",
    excavation_pressure)
  )

  screen.level(10)
  screen.move(10,60)
  screen.text("TIMEOUT")

  screen.level(15)
  screen.move(64,60)
  screen.text(
    string.format("%.1fs",
    REMOVE_LAYER_TIMEOUT)
  )

  screen.level(10)
  screen.move(10,72)
  screen.text("LAYERS")

  screen.level(15)
  screen.move(64,72)
  screen.text(
    ACTIVE_LAYERS
  )

  screen.update()

end

function redraw_clock()

  while true do

    clock.sleep(1/15)

    redraw()

  end

end

------------------------------------------------
-- KEYS
------------------------------------------------

function key(n,z)

  if n == 1 then
    k1_hold = (z == 1)
  end

  ------------------------------------------------
  -- K1 + K2 = TOGGLE MODE
  ------------------------------------------------

  if n == 2 and z == 1 and k1_hold then

    if record_mode == "auto" then
      record_mode = "manual"
    else
      record_mode = "auto"
    end

    manual_armed = false
    manual_waiting_for_input = false
    manual_recording = false

    print("mode "..record_mode)

    return

  end

  ------------------------------------------------
  -- K1 + K3 = ENVIRONMENT
  ------------------------------------------------

  if n == 3 and z == 1 and k1_hold then

    environment_index =
      environment_index + 1

    if environment_index > #environments then
      environment_index = 1
    end

    environment =
      environments[environment_index]

    print("environment "..environment)

    apply_archeology()

    return

  end

  ------------------------------------------------
  -- K2 RECORD CONTROL
  ------------------------------------------------

  if n == 2 and z == 1 and not k1_hold then

    if record_mode == "auto" then

      if recording then
        finalize_layer()
      end

    else

      manual_record_control()

    end

  end

end

------------------------------------------------
-- ENCODERS
------------------------------------------------

function enc(n,d)

  ------------------------------------------------
  -- ENC 1 = PRESSURE
  ------------------------------------------------

  if n == 1 then

    excavation_pressure =
      util.clamp(
        excavation_pressure + (d * 0.02),
        0,
        1
      )

    apply_archeology()

  ------------------------------------------------
  -- ENC 2 = TIMEOUT
  ------------------------------------------------

  elseif n == 2 then

    REMOVE_LAYER_TIMEOUT =
      util.clamp(
        REMOVE_LAYER_TIMEOUT + (d * 0.25),
        1,
        30
      )

  ------------------------------------------------
  -- ENC 3 = LAYERS
  ------------------------------------------------

  elseif n == 3 then

    ACTIVE_LAYERS =
      util.clamp(
        ACTIVE_LAYERS + d,
        3,
        MAX_LAYERS
      )

    apply_archeology()

  end

end
