// lib/Engine_MemoryPhysics.sc
Engine_MemoryPhysics : CroneEngine {
    var <buffers;
    var <maxLayers = 6;

    *new { arg context, doneCallback;
        ^super.new(context, doneCallback);
    }

    alloc {
        // Allocate 6 stereo buffers (20s each) for our strata
        buffers = Array.fill(maxLayers, {
            Buffer.alloc(context.server, context.server.sampleRate * 20, 2);
        });

        SynthDef(\StrataLayer, {
            arg buf, out, amp=0, depth=0, gate=1;
            var sig, pressure, noise, env, lpfFreq;
            
            // Pressure 0.0 (Surface) to 1.0 (Deep Crust)
            pressure = (depth / (maxLayers - 1)).clip(0, 1);
            
            sig = PlayBuf.ar(2, buf, loop: 1);
            
            // GEOLOGICAL DSP
            // 1. Muffling: LPF frequency drops as depth increases. 
            // Corrected syntax: .exp is called directly on the math
            lpfFreq = ( (1 - pressure) * (20000.log - 200.log) + 200.log ).exp;
            sig = LPF.ar(sig, lpfFreq.clip(20, 20000));
            
            // 2. Compaction: Simple soft-clipping to simulate pressure
            sig = (sig * (1 + (pressure * 4))).softclip;
            
            // 3. Artifacts: Low-level brown noise leakage at depth
            noise = BrownNoise.ar(pressure * 0.03);
            
            env = EnvGen.kr(Env.asr(0.1, 1, 0.1), gate, doneAction: 2);
            Out.ar(out, (sig + noise) * amp * env);
        }).add;

        context.server.sync;

        // Burial Logic (LIFO)
        this.addCommand(\shift_layers, "", {
            (maxLayers-1).reverseDo({ arg i;
                if (i > 0) {
                    buffers[i].copyData(buffers[i-1]);
                };
            });
            buffers[0].zero; 
        });

        this.addCommand(\record_start, "", {
            // Buffer 0 is always the Surface (Recording head)
            { RecordBuf.ar(In.ar(context.in_b, 2), buffers[0], loop: 0, doneAction: 2) }.play;
        });
        
        // Handshake for Lua
        this.addCommand(\ready, "", { "Engine Ready".postln; });
    }

    free {
        buffers.do(_.free);
    }
}
