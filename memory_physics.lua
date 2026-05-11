-- memory_physics.lua
-- Archeology Mode Alpha
-- auto/manual excavation recording

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

local LOOP_FADE_TIME = 0.12

------------------------------------------------
-- RECORD POSITION TRACKING
------------------------------------------------

local record_start_time = 0
local record_duration = 0

------------------------------------------------
-- ENVIRONMENT
------------------------------------------------

local environment = "desert"

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

  params:add_number(
    "active_layers",
    "active layers",
    3,
    MAX_LAYERS,
    5
  )

  params:set_action("active_layers", function(x)

    ACTIVE_LAYERS = x

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

    ------------------------------------------------
    -- AUTO MODE
    ------------------------------------------------

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

    ------------------------------------------------
    -- MANUAL MODE
    ------------------------------------------------

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
    math.min(1.0, excavation_pressure + 0.08)

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

function get_environment_tables()

  if environment == "desert" then

    return {
      gains = {1.0,0.7,0.45,0.22,0.10,0.05},
      cutoffs = {12000,6500,3500,1800,800,250},
      drifts = {0,0.003,0.008,0.015,0.03,0.05}
    }

  elseif environment == "forest" then

    return {
      gains = {1.0,0.8,0.6,0.42,0.28,0.14},
      cutoffs = {9000,5000,2400,1200,700,300},
      drifts = {0,0.006,0.012,0.022,0.04,0.07}
    }

  else

    return {
      gains = {1.0,0.7,0.45,0.22,0.10,0.05},
      cutoffs = {12000,6500,3500,1800,800,250},
      drifts = {0,0.003,0.008,0.015,0.03,0.05}
    }

  end

end

------------------------------------------------
-- ARCHEOLOGY ENGINE
------------------------------------------------

function apply_archeology()

  local env = get_environment_tables()

  for i = 1, MAX_LAYERS do

    local voice = layers[i].voice

    if layers[i].active
    and i <= ACTIVE_LAYERS then

      local gain = env.gains[i] or 0.03

      local cutoff = env.cutoffs[i] or 250

      local drift = env.drifts[i] or 0.05

      gain =
        gain * (1.0 - (excavation_pressure * (i * 0.06)))

      cutoff =
        cutoff * (1.0 - (excavation_pressure * 0.35))

      if burial_active then

        softcut.level(voice,gain)

        softcut.post_filter_fc(voice,cutoff)

        softcut.rate(voice,1.0)

      elseif burial_crossfade
      and voice == burial_source_voice then

        local progress = burial_crossfade_progress

        local layer2_gain = env.gains[2] or 0.7
        local layer2_cutoff = env.cutoffs[2] or 6500

        local faded_gain =
          gain * (1.0 - progress) + (layer2_gain * progress)

        local faded_cutoff =
          cutoff * (1.0 - progress) + (layer2_cutoff * progress)

        softcut.level(voice, faded_gain)

        softcut.post_filter_fc(voice, faded_cutoff)

        softcut.rate(voice, 1.0)

      elseif collapse_crossfade then

        local progress = collapse_crossfade_progress

        if voice == collapse_source_voice then

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

      else

        if layers[i].dropout then
          gain = gain * 0.15
        end

        softcut.level(voice,gain)

        softcut.post_filter_fc(
          voice,
          cutoff
        )

        softcut.post_filter_rq(voice,1.8)

        local rate =
          1.0 +
          ((math.random() * drift)
          - (drift / 2))

        softcut.rate(voice,rate)

      end

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

      for i = 4, ACTIVE_LAYERS do

        if layers[i].active then

          local chance =
            0.08 + (i * 0.08)
            + (excavation_pressure * 0.2)

          if math.random() < chance then

            layers[i].dropout =
              not layers[i].dropout

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

  ------------------------------------------------
  -- K1 STATE
  ------------------------------------------------

  if n == 1 then
    k1_hold = (z == 1)
  end

  ------------------------------------------------
  -- K1 + K2 = TOGGLE AUTO/MANUAL
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
  -- K2 AUTO MODE = END RECORDING
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
  -- ENC 1 = EFFECTS PRESSURE
  ------------------------------------------------

  if n == 1 then

    excavation_pressure =
      util.clamp(
        excavation_pressure + (d * 0.01),
        0,
        1
      )

    apply_archeology()

  ------------------------------------------------
  -- ENC 2 = LAYER TIMEOUT
  ------------------------------------------------

  elseif n == 2 then

    REMOVE_LAYER_TIMEOUT =
      util.clamp(
        REMOVE_LAYER_TIMEOUT + (d * 0.25),
        1,
        30
      )

  ------------------------------------------------
  -- ENC 3 = MAX LAYERS
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
