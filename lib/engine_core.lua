local EngineCore = {}

-- Initialize a Softcut voice
function EngineCore.setup_voice(id, length)
    softcut.enable(id, 1)
    softcut.buffer(id, 1)
    
    -- Audio Routing
    softcut.level(id, 1.0)           -- Playback Level
    softcut.level_input_cut(1, id, 1.0) -- Record Level from Input L
    softcut.level_input_cut(2, id, 1.0) -- Record Level from Input R
    
    -- Playback Properties
    softcut.loop(id, 1)
    softcut.loop_start(id, 0)
    softcut.loop_end(id, length)
    softcut.position(id, 0)
    softcut.rate(id, 1.0)
    softcut.play(id, 1)
    
    -- Recording/Archeology Properties
    softcut.rec(id, 1)
    softcut.rec_level(id, 1.0)       -- How much new sound to add
    softcut.pre_level(id, 0.75)      -- Feedback/Overdub (0.75 = gradual decay)
    
    -- Filter Setup
    softcut.post_filter_lp(id, 1.0)
    softcut.post_filter_hp(id, 0.0)
    softcut.post_filter_bp(id, 0.0)
    softcut.post_filter_br(id, 0.0)
    softcut.post_filter_fc(id, 12000)
    softcut.post_filter_rq(id, 2.0)
end

-- Update voice DSP based on Physics/Environment modules
function EngineCore.apply_params(id, p)
    -- Frequency must be clamped to avoid Softcut errors (20Hz - 20kHz)
    local safe_fc = math.max(20, math.min(20000, p.cutoff))
    
    softcut.post_filter_fc(id, safe_fc)
    softcut.post_filter_rq(id, p.rq)
    softcut.level(id, p.gain)
    
    -- Optional: If environment defines a rate (like "Deep Sea" drift)
    if p.rate then
        softcut.rate(id, p.rate)
    end
end

return EngineCore
