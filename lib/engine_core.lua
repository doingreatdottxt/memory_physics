local EngineCore = {}

function EngineCore.setup_voice(id, length)
  softcut.enable(id, 1)
  softcut.buffer(id, 1)
  softcut.level(id, 1.0)
  softcut.loop(id, 1)
  softcut.loop_start(id, 0)
  softcut.loop_end(id, length)
  softcut.play(id, 1)
  softcut.rec(id, 1)
  
  -- ROUTING FIX: 
  -- 1. Enable global hardware input to softcut
  audio.level_adc_cut(1) 
  
  -- 2. Route hardware Input 1 (Left) and Input 2 (Right) to this voice
  -- Even if you use a mono input, routing both ensures signal reaches the head
  softcut.level_input_cut(1, id, 1.0)
  softcut.level_input_cut(2, id, 1.0)

  softcut.rec_level(id, 0.0) 
  softcut.pre_level(id, 0.75) 
  softcut.fade_time(id, 0.1)
end

function EngineCore.apply_params(id, p)
  softcut.post_filter_fc(id, p.cutoff)
  softcut.post_filter_rq(id, p.rq)
  softcut.level(id, p.gain)
  softcut.rate(id, p.rate)
  
  local pan_val = (id % 2 == 0) and p.pan_width or -p.pan_width
  softcut.pan(id, util.clamp(pan_val, -1.0, 1.0))
end

return EngineCore
