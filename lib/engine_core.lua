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
    
    -- Layer Cake/Consumption defaults
    softcut.rec_level(id, 1.0)
    softcut.pre_level(id, 0.75) -- The "Persistence" of the memory
    
    softcut.post_filter_lp(id, 1.0)
    softcut.post_filter_fc(id, 12000)
end

-- New logic: Bouncing filtered audio back into the buffer for permanent mutation
function EngineCore.mutate_strata(id, feedback_amt)
    softcut.pre_level(id, feedback_amt)
end

function EngineCore.apply_params(id, p)
    local safe_fc = math.max(20, math.min(20000, p.cutoff))
    softcut.post_filter_fc(id, safe_fc)
    softcut.post_filter_rq(id, p.rq)
    softcut.level(id, p.gain)
    
    -- Stereo Narrowing (for Layer Cake Mode)
    if p.pan_width then
        softcut.pan(id, (id % 2 == 0) and p.pan_width or -p.pan_width)
    end
end

return EngineCore
