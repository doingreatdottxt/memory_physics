local EngineCore = {}

function EngineCore.setup_voice(id, length)
  softcut.enable(id, 1)
  softcut.buffer(id, 1)
  softcut.level(id, 1.0)
  
  -- MASTER RECORDING SWITCH: Must be 1 for audio to enter Softcut
  audio.level_adc_cut(1) 
  
  -- Patching hardware inputs to this voice
  softcut.level_input_cut(1, id, 1.0)
  softcut.level_input_cut(2, id, 1.0)

  softcut.loop(id, 1)
  softcut.loop_start(id, 0)
  softcut.loop_end(id, length)
  softcut.play(id, 1)
  softcut.rec(id, 1)
  
  -- Initial recording levels (muted until record is triggered)
  softcut.rec_level(id, 0.0) 
  softcut.pre_level(id, 0.75) 
  softcut.fade_time(id, 0.1)
end

function EngineCore.apply_params(id, p)
  -- Safety clamp for cutoff
  local safe_fc = math.max(20, math.min(20000, p.cutoff))
  softcut.post_filter_fc(id, safe_fc)
  softcut.post_filter_rq(id, p.rq)
  softcut.level(id, p.gain)
  softcut.rate(id, p.rate)
  
  -- STEREO BALANCE: Scaled to 75% of maximum width
  local pan_val = (id % 2 == 0) and (p.pan_width * 0.75) or -(p.pan_width * 0.75)
  softcut.pan(id, util.clamp(pan_val, -1.0, 1.0))
end

return EngineCore
