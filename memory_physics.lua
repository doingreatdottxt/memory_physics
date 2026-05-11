------------------------------------------------
-- KEYS
------------------------------------------------

local k1_hold = false

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

    ------------------------------------------------
    -- K2 MANUAL MODE
    ------------------------------------------------

    else

      manual_record_control()

    end

  end

end

------------------------------------------------
-- ENCODERS
------------------------------------------------

local softcut_master_level = 1.0

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

------------------------------------------------
-- REDRAW
------------------------------------------------

function redraw()

  screen.clear()

  screen.level(15)
  screen.move(10,12)
  screen.text("ARCHEOLOGY")

  ------------------------------------------------
  -- MODE
  ------------------------------------------------

  screen.level(10)
  screen.move(10,24)
  screen.text("MODE")

  screen.level(15)
  screen.move(64,24)
  screen.text(record_mode)

  ------------------------------------------------
  -- STATUS
  ------------------------------------------------

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

  ------------------------------------------------
  -- PRESSURE
  ------------------------------------------------

  screen.level(10)
  screen.move(10,48)
  screen.text("PRESS")

  screen.level(15)
  screen.move(64,48)
  screen.text(
    string.format("%.2f",
    excavation_pressure)
  )

  ------------------------------------------------
  -- TIMEOUT
  ------------------------------------------------

  screen.level(10)
  screen.move(10,60)
  screen.text("TIMEOUT")

  screen.level(15)
  screen.move(64,60)
  screen.text(
    string.format("%.1fs",
    REMOVE_LAYER_TIMEOUT)
  )

  ------------------------------------------------
  -- LAYERS
  ------------------------------------------------

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
