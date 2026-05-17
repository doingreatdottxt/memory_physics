-- memory_physics.lua
-- Last In First Out Looper with Geological Strata Layer Physics
--
-- E1: Environment Intensity (50% default)
-- E2: Weather Intensity (20% default)
-- E3: Pressure Override
--
-- K2: Manual Layer Formation (Hold to Record, Release to Bury)
-- K3: Toggle Automatic Recording Trigger Mode
-- Shift + K2: Cycle Active Biome Environment
-- Shift + K3: Force Top Layer Archaelogical Excavation

engine.name = 'MemoryPhysics'

local envs = include("lib/environments")
local physics_helper = include("lib/physics")

local MAX_TIME = 10.0  -- Dynamic loop ceiling specification
local MULTIPLIERS = {1/32, 1/16, 1/8, 1/4, 1/2, 1, 2, 4, 8}

local state = {
  recording = false,
  start_time = 0,
  duration = 2.0,
  layers_active = 0,
  max_layers = 6,
  shift_held = false,
  silence_frames = 0,
  surface_cycles = 0,
  last_surface_phase = 0.0,
  cycle_armed = false,
  
  -- Rhythm detection data registers
  onset_timestamps = {},
  last_onset_time = 0
}

local layer_phases = {0.0, 0.0, 0.0, 0.0, 0.0, 0.0}
local redraw_metro  -- Explicit local declaration isolates execution environment paths

function init()
  setup_params()
  
  -- Handle incoming fast polling from SuperCollider tracking responders
  osc.event = function(path, args, from)
    if path == "/in_amp" then
      if params:get("auto_record") == 2 then
        local amp = args[1]
        if not state.recording and amp > params:get("threshold") then
          toggle_formation()
        elseif state.recording then
          if amp < (params:get("threshold") * 0.5) then
            state.silence_frames = state.silence_frames + 1
            if state.silence_frames > (params:get("release_time") * 15) then
              toggle_formation()
              state.silence_frames = 0
            end
          else
            state.silence_frames = 0
          end
        end
      end
      
    elseif path == "/audio_onset" then
      local now = util.time()
      state.last_onset_time = now
      if state.recording then
        table.insert(state.onset_timestamps, now)
      end
      
    elseif path == "/layer_phase" then
      local layer_idx = math.floor(args[1] + 1)
      local phase_val = args[2]
      if layer_idx >= 1 and layer_idx <= state.max_layers then
        layer_phases[layer_idx] = phase_val
        
        -- Tracks erosion cycle decay routines when loops pass boundary thresholds
        if layer_idx == 1 and state.layers_active > 0 and not state.recording then
          if phase_val > 0.75 then
            state.cycle_armed = true
          elseif phase_val < 0.15 and state.cycle_armed then
            state.cycle_armed = false
            state.surface_cycles = state.surface_cycles + 1
            if state.surface_cycles >= 5 then
              engine.erode_layer()
              state.layers_active = math.max(0, state.layers_active - 1)
              state.surface_cycles = 0
            end
          end
          state.last_surface_phase = phase_val
        end
      end
    end
  end

  redraw_metro = metro.init(function() redraw() end, 1/15)
  redraw_metro:start()
end

function setup_params()
  params:add_group("MEMORY PHYSICS QUANTIZATION", 11)
  
  params:add_control("main_vol", "GLOBAL VOLUME", controlspec.new(0, 2, 'lin', 0.01, 1.0))
  params:set_action("main_vol", function(x) engine.set_volume(x) end)
  
  params:add_option("auto_record", "RECORD TRIGGER MODE", {"MANUAL [K2]", "AUTOMATIC [AMP]"}, 2)
  params:add_control("threshold", "AUTO THRESHOLD", controlspec.new(0.001, 1.0, 'exp', 0.001, 0.05))
  params:add_control("release_time", "AUTO TIMEOUT RELEASE (S)", controlspec.new(0.1, 5.0, 'lin', 0.1, 2.0))
  
  -- Quantization configuration parameters
  params:add_option("quant_mode", "QUANTIZATION STYLE", {"FREE", "CLOCK FOLLOW", "BAR MODE"}, 1)
  params:add_control("bar_length", "BAR SYSTEM BEDROCK", controlspec.new(0.1, MAX_TIME, 'lin', 0.01, 2.0, "s"))
  params:hide("bar_length")

  params:add_option("environment", "ACTIVE ECOSYSTEM BIOME", envs.list, 3)
  params:set_action("environment", function(x)
    local env_name = envs.list[x]
    local d = envs.data[env_name]
    engine.set_env(x - 1)
    if d then
      engine.set_environment_params(d.base_fc, d.mod_fc, d.base_rq, d.mod_rq, d.drift)
    end
  end)

  params:add_control("env_intensity", "ENVIRONMENT INTENSITY", controlspec.new(0, 1, 'lin', 0.01, 0.5))
  params:set_action("env_intensity", function(x) engine.set_env_intensity(x) end)
  
  params:add_control("weather", "WEATHER SEEPAGE INTENSITY", controlspec.new(0, 1, 'lin', 0.01, 0.2))
  params:set_action("weather", function(x) engine.set_weather(x) end)
  
  params:add_control("pressure", "PRESSURE MANIFEST OVERRIDE", controlspec.new(0, 1, 'lin', 0.01, 0))
  params:set_action("pressure", function(x) engine.set_pressure(x) end)
  
  params:add_trigger("excavate", "EXCAVATE ENTIRE SITE")
  params:set_action("excavate", function()
    state.layers_active = 0
    state.surface_cycles = 0
    state.cycle_armed = false
    params:set("bar_length", 2.0)
    engine.clear_layers()
  end)
  
  params:bang()
end

-- Rhythm engine: extracts the median delta time from playing transients
local function extract_rhythmic_pulse()
  if #state.onset_timestamps < 2 then return nil end
  local deltas = {}
  for i = 2, #state.onset_timestamps do
    local diff = state.onset_timestamps[i] - state.onset_timestamps[i-1]
    if diff > 0.15 then -- Debounce double-trigger anomalies
      table.insert(deltas, diff)
    end
  end
  if #deltas == 0 then return nil end
  table.sort(deltas)
  return deltas[math.ceil(#deltas / 2)] -- Pull the median structural tempo pulse
end

function calculate_quantized_duration(raw_dur)
  local mode = params:get("quant_mode")
  local final_dur = raw_dur

  if mode == 1 then
    -- FREE MODE: Constrained only by hardware allocation ceiling
    final_dur = math.min(raw_dur, MAX_TIME)

  elseif mode == 2 then
    -- ASSISTED CLOCK FOLLOW MODE: Cross-reference clock grid against real audio transients
    local beat_sec = 60 / (params:get("clock_tempo") or 120)
    local beats = math.floor((raw_dur / beat_sec) + 0.5)
    
    -- If an audio accent happened right before button release, use it to shift alignment
    local time_since_last_transient = util.time() - state.last_onset_time
    if time_since_last_transient < 0.200 and time_since_last_transient > 0 then
      local transient_adjusted_dur = raw_dur - time_since_last_transient
      beats = math.floor((transient_adjusted_dur / beat_sec) + 0.5)
    end
    
    beats = math.max(1, beats)
    final_dur = math.min(beats * beat_sec, MAX_TIME)

  elseif mode == 3 then
    -- ASSISTED BAR MODE
    if state.layers_active == 0 then
      -- First layer baseline calculation assisted by pulse tracking
      local detected_pulse = extract_rhythmic_pulse()
      if detected_pulse then
        local estimated_beats = math.floor((raw_dur / detected_pulse) + 0.5)
        estimated_beats = math.max(1, estimated_beats)
        final_dur = math.min(estimated_beats * detected_pulse, MAX_TIME)
      else
        final_dur = math.min(raw_dur, MAX_TIME)
      end
      params:set("bar_length", final_dur)
    else
      -- Subsequent layers: Snap cleanly onto sub-divisions or macro multiples
      local master_bar = params:get("bar_length")
      local best_diff = math.huge
      local best_dur = master_bar

      for _, mult in ipairs(MULTIPLIERS) do
        local test_dur = master_bar * mult
        if test_dur <= MAX_TIME then
          local diff = math.abs(raw_dur - test_dur)
          if diff < best_diff then
            best_diff = diff
            best_dur = test_dur
          end
        end
      end
      final_dur = best_dur
    end
  end

  if final_dur < 0.1 then final_dur = 0.1 end
  return final_dur
end

function toggle_formation()
  if not state.recording then
    state.surface_cycles = 0
    state.last_surface_phase = 0.0
    state.cycle_armed = false
    state.onset_timestamps = {} -- Flush rhythm tracking log array
    state.start_time = util.time()
    engine.record_start()
    state.recording = true
  else
    state.recording = false
    local measured_dur = util.time() - state.start_time
    
    state.duration = calculate_quantized_duration(measured_dur)
    
    engine.record_stop()
    engine.shift_layers(state.duration)
    state.layers_active = math.min(state.max_layers, state.layers_active + 1)
  end
end

function key(n, z)
  if n == 1 then
    state.shift_held = (z == 1)
  elseif n == 2 and z == 1 then
    if state.shift_held then
      params:set("environment", util.wrap(params:get("environment") + 1, 1, #envs.list))
    else
      toggle_formation()
    end
  elseif n == 3 and z == 1 then
    if state.shift_held then
      if state.layers_active > 0 then
        engine.erode_layer()
        state.layers_active = state.layers_active - 1
        state.surface_cycles = 0
        state.cycle_armed = false
      end
    else
      params:set("auto_record", params:get("auto_record") == 1 and 2 or 1)
    end
  end
end

function enc(n, d)
  if n == 1 then
    params:delta("env_intensity", d)
  elseif n == 2 then
    params:delta("weather", d)
  elseif n == 3 then
    params:delta("pressure", d)
  end
end

function cleanup()
  if redraw_metro then
    redraw_metro:stop()
  end
end

function redraw()
  screen.clear()
  screen.level(state.recording and 15 or 3)
  screen.move(0, 8)
  
  local msg = state.recording and "FORMING STRATA" or "STABLE"
  screen.text(msg .. " [" .. string.format("%.2f", state.duration) .. "s] C:" .. state.surface_cycles .. "/5")
  
  local current_env = envs.list[params:get("environment")]
  
  for i = 1, 6 do
    local y = 14 + (i * 7)
    if i <= state.layers_active then
      screen.level(math.floor(math.max(1, 11 - (i * 1.5))))
      if i == 1 then
        screen.move(10, y + 3)
        screen.line(118, y + 3)
        screen.stroke()
        if current_env == "Grove" or current_env == "Swamp" then
          screen.move(25, y + 1) screen.line_rel(0, 2)
          screen.move(70, y + 1) screen.line_rel(0, 2)
          screen.move(105, y + 1) screen.line_rel(0, 2)
          screen.stroke()
        elseif current_env == "Mountain" or current_env == "Sand" or current_env == "Cave" then
          screen.move(40, y + 3) screen.line_rel(2, -2) screen.line_rel(2, 2)
          screen.move(85, y + 3) screen.line_rel(2, -2) screen.line_rel(2, 2)
          screen.stroke()
        elseif current_env == "Sea" or current_env == "River Bank" then
          screen.move(30, y + 2) screen.line_rel(3, 0)
          screen.move(75, y + 2) screen.line_rel(3, 0)
          screen.stroke()
        end
      else
        for x = 10, 118, 4 do
          local offset = (x % (3 * i)) == 0 and (math.floor(i * 0.5)) or 0
          screen.move(x, y + 3 + offset)
          screen.line_rel(3, 0)
          screen.stroke()
        end
      end
      local p = layer_phases[i] or 0.0
      screen.level(math.floor(math.max(4, 16 - (i * 2))))
      screen.rect(10 + (p * 108), y + 2, 2, 2)
      screen.fill()
    else
      screen.level(1)
      screen.move(20, y + 3)
      screen.line(100, y + 3)
      screen.stroke()
    end
  end
  
  screen.level(3)
  screen.move(0, 62)
  local styles = {"FREE", "CLOCK FOLLOW", "BAR MODE"}
  screen.text(current_env .. " (" .. styles[params:get("quant_mode")] .. ") | E:" .. math.floor(params:get("env_intensity") * 100) .. "% W:" .. math.floor(params:get("weather") * 100) .. "%")
  screen.update()
end
