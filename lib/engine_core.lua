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
  softcut.rec_level(id, 0.0) -- Controlled by recording logic
  softcut.pre_level(id, 0.75) -- Subtle decay of old "strata"
  softcut.fade_time(id, 0.1)
end

function EngineCore.apply_params(id, p)
  softcut.post_filter_fc(id, p.cutoff)
  softcut.post_filter_rq(id, p.rq)
  softcut.level(id, p.gain)
  softcut.rate(id, p.rate)
  softcut.pan(id, (id % 2 == 0) and p.pan_width or -p.pan_width)
end

return EngineCore
