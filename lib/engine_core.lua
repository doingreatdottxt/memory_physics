local EngineCore = {}

function EngineCore.setup_voice(id, length)
    softcut.enable(id, 1)
    softcut.buffer(id, 1)
    
    softcut.level(id, 1.0)
    softcut.level_input_cut(1, id, 1.0)
    softcut.level_input_cut(2, id, 1.0)
    
    softcut.loop(id, 1)
    softcut.loop_start(id, 0)
    softcut.loop_end(id, length)
    softcut.rate(id, 1.0)
    softcut.play(id, 1)
    softcut.rec(id, 1)
    
    -- Consumption/Persistence defaults
    softcut.rec_level(id, 1.0)
    softcut.pre_level(id, 0.75) 
    
    softcut.post_filter_lp(id, 1.0)
    softcut.post_filter_fc(id, 12000)
    softcut.fade_time(id, 0.05)
end

function EngineCore.mutate_strata(id, feedback_amt)
    softcut.pre_level(id, feedback_amt)
end

function EngineCore.apply_params(id, p)
    local safe_fc = math.max(20, math.min(20000, p.cutoff))
    softcut.post_filter_fc(id, safe_fc)
    softcut.post_filter_rq(id, p.rq)
    softcut.level(id, p.gain)
    softcut.rate(id, p.rate or 1.0)
    
    -- Stereo Narrowing: Deeper layers collapse to mono
    if p.pan_width then
        local pan = (id % 2 == 0) and p.pan_width or -p.pan_width
        softcut.pan(id, pan)
    end
end

return EngineCore
