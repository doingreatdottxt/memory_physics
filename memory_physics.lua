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

local burial_release = false
local burial_release_progress = 0

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

          collapse_memory_stack()

        end

      end

    ------------------------------------------------
    -- MANUAL MODE
    ------------------------------------------------

    else

      ------------------------------------------------
      -- WAITING FOR INPUT
      ------------------------------------------------

      if manual_waiting_for_input then

        if smoothed_level > threshold then

          begin_new_layer()

          manual_waiting_for_input = false
          manual_recording = true

        end

      end

      silence_time = silence_time + 0.05

      if silence_time > REMOVE_LAYER_TIMEOUT then

        collapse_memory_stack()

      end

    end

    update_burial_release()

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

  ------------------------------------------------
  -- TRUE RECORD LENGTH
  ------------------------------------------------

  record_duration =
    util.time() - record_start_time

  ------------------------------------------------
  -- AUTO MODE TAIL TRIM
  ------------------------------------------------

  local final_length

  if record_mode == "auto" then

    final_length =
      math.max(
        0.25,
        record_duration - NEW_LAYER_TIMEOUT
      )

  else

    ------------------------------------------------
    -- MANUAL MODE
    ------------------------------------------------

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

  burial_release = true
  burial_release_progress = 0

  apply_archeology()

end

------------------------------------------------
-- MANUAL ARM / STOP
------------------------------------------------

function manual_record_control()

  if record_mode ~= "manual" then
    return
  end

  ------------------------------------------------
  -- FIRST PRESS
  ------------------------------------------------

  if not manual_armed
  and not manual_recording then

    manual_armed = true
    manual_waiting_for_input = true

    print("manual armed")

    return

  end

  ------------------------------------------------
  -- SECOND PRESS
  ------------------------------------------------

  if manual_recording then

    finalize_layer()

    print("manual stop")

  end

end

------------------------------------------------
-- BURIAL RELEASE
------------------------------------------------

function update_burial_release()

  if not burial_release then
    return
  end

  burial_release_progress =
    burial_release_progress + 0.004

  if burial_release_progress >= 1 then

    burial_release = false

    burial_release_progress = 1

    burial_source_voice = nil

  end

  apply_archeology()

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
-- COLLAPSE
------------------------------------------------

function collapse_memory_stack()

  if not layers[1].active then
    return
  end

  print("memory collapse")

  local removed_voice = layers[1].voice

  softcut.level(removed_voice,0)

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

  silence_time = 0

  excavation_pressure =
    math.max(0, excavation_pressure - 0.12)

  apply_archeology()

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

      ------------------------------------------------
      -- ACTIVE EXCAVATION
      ------------------------------------------------

      if burial_active then

        if voice == burial_source_voice then

          softcut.level(voice,1.0)

          softcut.post_filter_fc(voice,12000)

          softcut.rate(voice,1.0)

        else

          softcut.level(voice,0)

        end

      ------------------------------------------------
      -- POST BURIAL
      ------------------------------------------------

      elseif burial_release
      and voice == burial_source_voice then

        local release = burial_release_progress

        local settling_gain =
          1.0 - (release * 0.88)

        settling_gain =
          math.max(0.08, settling_gain)

        softcut.level(voice, settling_gain)

        local settling_cutoff =
          12000 - (release * 10500)

        softcut.post_filter_fc(
          voice,
          settling_cutoff
        )

        softcut.rate(
          voice,
          1.0 - (release * 0.015)
        )

      ------------------------------------------------
      -- NORMAL PLAYBACK
      ------------------------------------------------

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

    if not burial_active then

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

  screen.move(10,15)
  screen.text("ARCHEOLOGY")

  screen.move(10,28)
  screen.text(
    "MODE "..record_mode
  )

  screen.move(10,40)
  screen.text(
    "LAYERS "..ACTIVE_LAYERS
  )

  screen.move(10,52)

  if manual_waiting_for_input then

    screen.text("ARMED")

  elseif recording then

    screen.text("RECORDING")

  else

    screen.text(environment)

  end

  screen.move(10,64)

  screen.text(
    "PRESS "..string.format("%.2f",
    excavation_pressure)
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
  -- K2 = RECORD MODE TOGGLE
  ------------------------------------------------

  if n == 2 and z == 1 then

    if record_mode == "auto" then
      record_mode = "manual"
    else
      record_mode = "auto"
    end

    print("mode "..record_mode)

  end

  ------------------------------------------------
  -- K3 = ARM / STOP
  ------------------------------------------------

  if n == 3 and z == 1 then

    manual_record_control()

  end

end

------------------------------------------------
-- ENCODERS
------------------------------------------------

function enc(n,d)

  if n == 2 then

    params:delta("threshold", d)

  elseif n == 3 then

    params:delta("active_layers", d)

  end

end
