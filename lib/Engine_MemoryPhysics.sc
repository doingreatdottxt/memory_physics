// lib/Engine_MemoryPhysics.sc
// Geological Strata Engine - Memory Physics
// Portability: Optimized for Daisy Seed (DaisySP) logic

Engine_MemoryPhysics : CroneEngine {
    var <buffers;
    var <maxLayers = 6;

    *new { arg context, doneCallback;
        ^super.new(context, doneCallback);
    }

    alloc {
        // Pre-allocate 6 stereo buffers (20s each)
        // Memory usage: ~23MB. Daisy Seed safe.
        buffers = Array.fill(maxLayers, {
            Buffer.alloc(context.server, context.server.sampleRate * 20, 2);
        });

        SynthDef(\StrataLayer, {
            arg buf, out, amp=0, depth=0, gate=1;
            var sig, pressure, lpfFreq, env;
            
            // Pressure 0.0 (Surface) to 1.0 (Deep Crust)
            pressure = (depth / (maxLayers - 1)).clip(0, 1);
            
            sig = PlayBuf.ar(2, buf, loop: 1);
            
            // --- GEOLOGICAL DSP ---
            
            // 1. Muffling: Linear-to-Exponential mapping
            // Surface (0) = 20kHz, Deep Crust (1) = 200Hz
            lpfFreq = pressure.linexp(0, 1, 20000, 200);
            sig = LPF.ar(sig, lpfFreq.lag(0.2));
            
            // 2. Compaction: Increasing gain into a softclip
            sig = (sig * (1 + (pressure * 2.5))).softclip;
            
            // 3. Erosion/Decay: Amp naturally lowers with depth
            // This falls in line with the "buried sound" idea
            env = EnvGen.kr(Env.asr(0.1, 1, 0.1), gate, doneAction: 2);
            
            Out.ar(out, sig * (amp * (1 - (pressure * 0.5))) * env);
        }).add;

        context.server.sync;

        // --- COMMANDS ---

        this.addCommand(\shift_layers, "", {
            (maxLayers-1).reverseDo({ arg i;
                if (i > 0) {
                    buffers[i].copyData(buffers[i-1]);
                };
            });
            buffers[0].zero; 
        });

        this.addCommand(\record_start, "", {
            { RecordBuf.ar(In.ar(context.in_b, 2), buffers[0], loop: 0, doneAction: 2) }.play;
        });

        this.addCommand(\ready, "", { "Engine Stable".postln; });
    }

    free {
        buffers.do(_.free);
    }
}
