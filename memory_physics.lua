------------------------------------------------
-- ACTIVE BURIAL
------------------------------------------------

if burial_active then

  local incoming_voice = layers[NUM_LAYERS].voice

  ------------------------------------------------
  -- NEW SURFACE LAYER
  ------------------------------------------------

  if voice == incoming_voice then

    -- during recording:
    -- new layer fully present and recording
    softcut.level(voice, 1.0)

    softcut.post_filter_fc(voice, 12000)

    softcut.rate(voice,1.0)

  ------------------------------------------------
  -- PREVIOUS SURFACE LAYER
  ------------------------------------------------

  elseif voice == burial_source_voice then

    -- OLD behavior:
    -- sinking during recording

    -- NEW behavior:
    -- remains fully exposed while recording

    softcut.level(voice, 1.0)

    softcut.post_filter_fc(voice, 12000)

    softcut.rate(voice,1.0)

  ------------------------------------------------
  -- DEEPER LAYERS
  ------------------------------------------------

  else

    -- deeper layers remain buried
    softcut.level(voice,0)

  end

------------------------------------------------
-- POST-BURIAL MEMORY FADE
------------------------------------------------

elseif burial_release and voice == burial_source_voice then

  -- THIS is now where burial occurs.

  local release = burial_release_progress

  ------------------------------------------------
  -- GRADUAL SINKING
  ------------------------------------------------

  local gain_release = 1.0 - (release * 0.88)

  gain_release = math.max(0.08, gain_release)

  softcut.level(voice, gain_release)

  ------------------------------------------------
  -- SPECTRAL BURIAL
  ------------------------------------------------

  local cutoff = 12000 - (release * 10500)

  softcut.post_filter_fc(voice, cutoff)

  ------------------------------------------------
  -- TEMPORAL SETTLING
  ------------------------------------------------

  local rate = 1.0 - (release * 0.015)

  softcut.rate(voice, rate)

------------------------------------------------
-- NORMAL PLAYBACK
------------------------------------------------

else
