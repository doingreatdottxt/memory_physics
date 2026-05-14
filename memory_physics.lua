-- ... (rest of imports)

function start_recording()
  rec_start_time = util.time()
  softcut.position(1, 0)
  softcut.rec(1, 1)
  softcut.rec_level(1, 1.0) -- Write at full volume
  softcut.pre_level(1, 0.0) -- Overwrite existing data on head 1
  is_recording = true
  redraw()
end

function stop_recording()
  local duration = util.time() - rec_start_time
  softcut.rec(1, 0)
  softcut.rec_level(1, 0.0)
  softcut.pre_level(1, 1.0) -- Switch to "preserve" mode
  softcut.loop_end(1, math.max(0.1, duration))
  is_recording = false
  advance_strata()
  redraw()
end

function init()
  softcut.buffer_clear() -- Start clean
  for i = 1, 6 do
    layers[i] = { voice = i, pressure_mem = 0, active = true }
    Soft.setup_voice(i, 60)
  end
  -- ... (rest of init)
end
