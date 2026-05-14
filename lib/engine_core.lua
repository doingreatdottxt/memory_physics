local EngineCore = {}

function EngineCore.setup_voice(id, length)
    softcut.enable(id, 1)
    softcut.buffer(id, 1)
    softcut.level(id, 1.0)
    softcut.loop(id, 1)
    softcut.loop_start(id, 0)
    softcut.loop_end(id, length)
    softcut.position(id, 0)
    softcut.play(id, 1)
    -- Enable filters
    softcut.post_filter_lp(id, 1.0)
end

function EngineCore.apply_params(id, p)
    softcut.post_filter_fc(id, p.cutoff)
    softcut.post_filter_rq(id, p.rq)
    softcut.level(id, p.gain)
    if p.rate then softcut.rate(id, p.rate) end
end

return EngineCore
