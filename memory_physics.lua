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
-- GRANULAR / NOISE STATE
------------------------------------------------

local grain_clock_running = false
local noise_clock_running = false

local layer_pressure_memory = {}

------------------------------------------------
-- BEDROCK
------------------------------------------------

local bedrock_enabled = false

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
      loop_end = MAX_LOOP_LENGTH,

      pressure_memory = 0,
      erosion_memory = 0,
      granulated = false
    }

    layer_pressure_memory[i] = 0

  end

  setup_softcut()
  setup_params()
  setup_poll()

  clock.run(monitor_input)
  clock.run(redraw_clock)
  clock.run(archeology_decay_clock)
  clock.run(burial_crossfade_clock)
  clock.run(collapse_crossfade_clock)

  clock.run(granular_motion_clock)
  clock.run(environment_noise_clock)

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

  local active_count = 0

  for i = 1, ACTIVE_LAYERS do
    if layers[i].active then
      active_count = active_count + 1
    end
  end

  if bedrock_enabled and active_count <= 1 then
    return
  end

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

  if bedrock_enabled then

    local lowest_active = nil

    for i = ACTIVE_LAYERS, 1, -1 do

      if layers[i].active then
        lowest_active = i
        break
      end

    end

    if lowest_active == 1 then

      collapse_crossfade = false
      collapse_source_voice = nil
      collapse_target_voice = nil

      return

    end

    print("bedrock protected collapse")

    local removed_voice = layers[1].voice

    softcut.level(removed_voice, 0)

    for i = 1, lowest_active - 2 do

      layers[i].voice = layers[i+1].voice
      layers[i].active = layers[i+1].active
      layers[i].dropout = layers[i+1].dropout
      layers[i].loop_end = layers[i+1].loop_end
      layers[i].pressure_memory =
        layers[i+1].pressure_memory

    end

    local insert_index = lowest_active - 1

    layers[insert_index].voice = removed_voice
    layers[insert_index].active = false
    layers[insert_index].dropout = false
    layers[insert_index].loop_end = MAX_LOOP_LENGTH
    layers[insert_index].pressure_memory = 0

    excavation_pressure =
      math.max(0, excavation_pressure - 0.08)

    collapse_source_voice = nil
    collapse_target_voice = nil

    apply_archeology()

    return

  end

  print("memory collapse finalized")

  local removed_voice = layers[1].voice

  softcut.level(removed_voice, 0)

  for i = 1, MAX_LAYERS - 1 do

    layers[i].voice = layers[i+1].voice
    layers[i].active = layers[i+1].active
    layers[i].dropout = layers[i+1].dropout
    layers[i].loop_end = layers[i+1].loop_end
    layers[i].pressure_memory =
      layers[i+1].pressure_memory

  end

  layers[MAX_LAYERS].voice = removed_voice
  layers[MAX_LAYERS].active = false
  layers[MAX_LAYERS].dropout = false
  layers[MAX_LAYERS].loop_end = MAX_LOOP_LENGTH
  layers[MAX_LAYERS].pressure_memory = 0

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
-- ADD THESE MISSING FUNCTIONS
-- PLACE BELOW collapse_crossfade_clock()
------------------------------------------------

function layer_pressure_depth(i)

  if ACTIVE_LAYERS <= 1 then
    return 0
  end

  local depth =
    (i - 1) / (ACTIVE_LAYERS - 1)

  ------------------------------------------------
  -- TOP LAYER ONLY RECEIVES 25%
  ------------------------------------------------

  local scaled =
    0.25 + (depth * 0.75)

  return scaled

end

------------------------------------------------
-- GRANULAR MOTION CLOCK
------------------------------------------------

function granular_motion_clock()

  while true do

    for i = 1, ACTIVE_LAYERS do

      if layers[i].active then

        local voice = layers[i].voice

        local depth_scale =
          layer_pressure_depth(i)

        local local_pressure =
          excavation_pressure * depth_scale

        ------------------------------------------------
        -- PRESSURE MEMORY
        ------------------------------------------------

        layers[i].pressure_memory =
          util.clamp(
            layers[i].pressure_memory +
            (local_pressure * 0.004),
            0,
            1
          )

        ------------------------------------------------
        -- GRANULAR FRAGMENTATION
        ------------------------------------------------

        if local_pressure > 0.45 then

          local chance =
            local_pressure * 0.18

          if math.random() < chance then

            local pos =
              math.random() *
              layers[i].loop_end

            local loop_start =
              (voice - 1) * MAX_LOOP_LENGTH

            softcut.position(
              voice,
              loop_start + pos
            )

          end

        end

        ------------------------------------------------
        -- MICRO RATE INSTABILITY
        ------------------------------------------------

        if local_pressure > 0.3 then

          local drift =
            (math.random() - 0.5)
            * local_pressure
            * 0.12

          softcut.rate(
            voice,
            1.0 + drift
          )

        end

      end

    end

    clock.sleep(0.12)

  end

end

------------------------------------------------
-- ENVIRONMENT NOISE CLOCK
------------------------------------------------

function environment_noise_clock()

  while true do

    for i = 1, ACTIVE_LAYERS do

      if layers[i].active then

        local voice = layers[i].voice

        local depth_scale =
          layer_pressure_depth(i)

        local local_pressure =
          excavation_pressure * depth_scale

        ------------------------------------------------
        -- DESERT
        ------------------------------------------------

        if environment == "desert" then

          if local_pressure > 0.55 then

            if math.random() <
              local_pressure * 0.08 then

              softcut.level(
                voice,
                0.3 + math.random() * 1.2
              )

            end

          end

        ------------------------------------------------
        -- SWAMP
        ------------------------------------------------

        elseif environment == "swamp" then

          if local_pressure > 0.45 then

            if math.random() <
              local_pressure * 0.12 then

              softcut.rate(
                voice,
                0.6 + math.random() * 0.4
              )

            end

          end

        ------------------------------------------------
        -- RIVER
        ------------------------------------------------

        elseif environment == "river" then

          if local_pressure > 0.35 then

            if math.random() <
              local_pressure * 0.16 then

              local fragment =
                math.random(4,ACTIVE_LAYERS)

              if layers[fragment]
              and layers[fragment].active then

                local frag_voice =
                  layers[fragment].voice

                softcut.level(
                  frag_voice,
                  1.4
                )

              end

            end

          end

        ------------------------------------------------
        -- DEEP SEA
        ------------------------------------------------

        elseif environment == "deep_sea" then

          if local_pressure > 0.6 then

            if math.random() <
              local_pressure * 0.06 then

              softcut.rate(
                voice,
                0.35 +
                math.random() * 0.2
              )

            end

          end

        ------------------------------------------------
        -- MOUNTAIN
        ------------------------------------------------

        elseif environment == "mountain" then

          if local_pressure > 0.82 then

            if math.random() <
              local_pressure * 0.15 then

              ------------------------------------------------
              -- AVALANCHE EVENT
              ------------------------------------------------

              for j = 1, ACTIVE_LAYERS do

                if layers[j].active then

                  softcut.level(
                    layers[j].voice,
                    math.random() * 2.5
                  )

                  softcut.rate(
                    layers[j].voice,
                    0.6 + math.random()
                  )

                end

              end

            end

          end

        ------------------------------------------------
        -- CAVE
        ------------------------------------------------

        elseif environment == "cave" then

          if local_pressure > 0.55 then

            if math.random() <
              local_pressure * 0.08 then

              local echo_jump =
                math.random() *
                layers[i].loop_end

              local start =
                (voice - 1)
                * MAX_LOOP_LENGTH

              softcut.position(
                voice,
                start + echo_jump
              )

            end

          end

        end

      end

    end

    clock.sleep(0.25)

  end

end

------------------------------------------------
-- ARCHEOLOGY ENGINE
------------------------------------------------

function apply_archeology()

  for i = 1, MAX_LAYERS do

    local voice = layers[i].voice

    if layers[i].active
    and i <= ACTIVE_LAYERS then

      local depth_scale =
        layer_pressure_depth(i)

      local local_pressure =
        excavation_pressure
        * depth_scale

      local remembered_pressure =
        math.max(
          local_pressure,
          layers[i].pressure_memory or 0
        )

      local gain = 1.0 - ((i - 1) * 0.18)

      local pressure =
        remembered_pressure
        * remembered_pressure

      local cutoff = 12000
      local rq = 1.2
      local drift = 0.0

      ------------------------------------------------
      -- DESERT
      ------------------------------------------------

      if environment == "desert" then

        cutoff =
          15000 -
          (pressure * i * 12000)

        rq =
          1.4 + (pressure * 5.0)

        gain =
          gain *
          (1.0 - (pressure * i * 0.34))

        drift =
          pressure * 0.18

        softcut.post_filter_hp(
          voice,
          math.min(1.0,
          pressure * 0.95)
        )

        softcut.post_filter_bp(
          voice,
          pressure * 0.75
        )

      ------------------------------------------------
      -- FOREST
      ------------------------------------------------

      elseif environment == "forest" then

        cutoff =
          10000 -
          (pressure * i * 9600)

        rq =
          0.7 + (pressure * 0.5)

        gain =
          gain *
          (1.0 - (pressure * 0.45))

        drift =
          pressure * 0.02

        softcut.post_filter_hp(
          voice,
          0
        )

        softcut.post_filter_bp(
          voice,
          pressure * 0.06
        )

      ------------------------------------------------
      -- SWAMP
      ------------------------------------------------

      elseif environment == "swamp" then

        cutoff =
          7000 -
          (pressure * i * 6500)

        rq =
          2.8 + (pressure * 4.5)

        gain =
          gain *
          (1.0 - (pressure * 0.08))

        drift =
          pressure * 0.28

        softcut.post_filter_hp(
          voice,
          pressure * 0.03
        )

        softcut.post_filter_bp(
          voice,
          pressure * 0.32
        )

      ------------------------------------------------
      -- RIVER
      ------------------------------------------------

      elseif environment == "river" then

        cutoff =
          14000 -
          (pressure * i * 2500)

        rq =
          1.1 + (pressure * 1.6)

        gain =
          gain *
          (1.0 - (pressure * 0.08))

        drift =
          pressure * 0.34

        softcut.post_filter_hp(
          voice,
          pressure * 0.18
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
          (pressure * i * 4600)

        rq =
          3.2 + (pressure * 6.0)

        gain =
          gain *
          (1.0 - (pressure * 0.04))

        drift =
          pressure * 0.008

        softcut.post_filter_hp(
          voice,
          0
        )

        softcut.post_filter_bp(
          voice,
          pressure * 0.65
        )

      ------------------------------------------------
      -- MOUNTAIN
      ------------------------------------------------

      elseif environment == "mountain" then

        cutoff =
          16000 -
          (pressure * i * 10000)

        rq =
          2.0 + (pressure * 8.0)

        gain =
          gain *
          (1.0 - (pressure * 0.32))

        drift =
          pressure * 0.32

        softcut.post_filter_hp(
          voice,
          pressure * 0.62
        )

        softcut.post_filter_bp(
          voice,
          pressure * 0.82
        )

      ------------------------------------------------
      -- CAVE
      ------------------------------------------------

      elseif environment == "cave" then

        cutoff =
          9000 -
          (pressure * i * 5200)

        rq =
          2.4 + (pressure * 4.2)

        gain =
          gain *
          (1.0 - (pressure * 0.14))

        drift =
          pressure * 0.05

        softcut.post_filter_hp(
          voice,
          pressure * 0.05
        )

        softcut.post_filter_bp(
          voice,
          pressure * 0.45
        )

      end

      if layers[i].dropout then
        gain = gain * 0.12
      end

      softcut.level(
        voice,
        util.clamp(gain,0,2.5)
      )

      softcut.post_filter_fc(
        voice,
        math.max(60, cutoff)
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
-- ARCHEOLOGY DECAY CLOCK
------------------------------------------------

function archeology_decay_clock()

  while true do

    if not burial_active
    and not collapse_crossfade then

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
  screen.text("BEDROCK")

  screen.level(15)
  screen.move(64,60)

  if bedrock_enabled then
    screen.text("ON")
  else
    screen.text("OFF")
  end

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
  -- K1 + K3 = CHANGE ENVIRONMENT
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
  -- K3 = BEDROCK TOGGLE
  ------------------------------------------------

  if n == 3 and z == 1 and not k1_hold then

    bedrock_enabled =
      not bedrock_enabled

    print(
      "bedrock "
      .. tostring(bedrock_enabled)
    )

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
  -- ENC1 = PRESSURE
  ------------------------------------------------

  if n == 1 then

    excavation_pressure =
      util.clamp(
        excavation_pressure
        + (d * 0.01),
        0,
        1
      )

    apply_archeology()

  ------------------------------------------------
  -- ENC2 = REMOVE TIMEOUT
  ------------------------------------------------

  elseif n == 2 then

    REMOVE_LAYER_TIMEOUT =
      util.clamp(
        REMOVE_LAYER_TIMEOUT + d,
        1,
        30
      )

  ------------------------------------------------
  -- ENC3 = ACTIVE LAYERS
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
------------------------------------------------
-- COMMIT BURIAL
------------------------------------------------

function commit_burial()

  local temp = {
    voice = layers[MAX_LAYERS].voice,
    active = layers[MAX_LAYERS].active,
    dropout = layers[MAX_LAYERS].dropout,
    loop_end = layers[MAX_LAYERS].loop_end,
    pressure_memory =
      layers[MAX_LAYERS].pressure_memory
  }

  for i = MAX_LAYERS, 2, -1 do

    layers[i].voice = layers[i-1].voice
    layers[i].active = layers[i-1].active
    layers[i].dropout = layers[i-1].dropout
    layers[i].loop_end = layers[i-1].loop_end
    layers[i].pressure_memory =
      layers[i-1].pressure_memory

  end

  layers[1].voice = temp.voice
  layers[1].active = temp.active
  layers[1].dropout = temp.dropout
  layers[1].loop_end = temp.loop_end
  layers[1].pressure_memory =
    temp.pressure_memory

end
