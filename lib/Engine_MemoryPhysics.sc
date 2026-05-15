// lib/Engine_MemoryPhysics.sc
// Geological Strata Engine for Memory Physics
// Portability Note: Uses standard UGens compatible with DaisySP basics.

Engine_MemoryPhysics : CroneEngine {
    var <buffers;
    var <maxLayers = 6;

    *new { arg context, doneCallback;
        ^super.new(context, doneCallback);
    }

    alloc {
        // Allocate 6 stereo buffers (20s each)
        // Total memory: ~23MB (Safe for Daisy Seed SDRAM)
        buffers = Array.fill(maxLayers, {
            Buffer.alloc(context.server, context.server.sampleRate * 20, 2);
        });

        SynthDef(\StrataLayer, {
            arg buf, out, amp=0, depth=0, gate=1;
            var sig, pressure, noise, env, lpfFreq;
            
            // Pressure 0.0 (Surface) to 1.0 (Deep Crust)
            pressure = (depth / (maxLayers - 1)).clip(0, 1);
            
            sig = PlayBuf.ar(2, buf, loop: 1);
            
            // --- GEOLOGICAL DSP ---
            
            // 1. Muffling (Pressure vs. Frequency)
            // We map 0.0-1.0 to 20kHz-200Hz exponentially using SC syntax
            lpfFreq = ( (1 - pressure) * (20000.log - 200.log) + 200.log ).exp;
            sig = LPF.ar(sig, lpfFreq.clip(20, 20000));
            
            // 2. Compaction (Saturation)
            // Simulates the 'squish' of the earth.
            sig = (sig * (1 + (pressure * 3))).softclip;
            
            // 3. Fossilization (Artifacts)
            // Subtle brown noise leakage at high pressure.
            noise = BrownNoise.ar(pressure * 0.02);
            
            env = EnvGen.kr(Env.asr(0.1, 1, 0.1), gate, doneAction: 2);
            Out.ar(out, (sig + noise) * amp * env);
        }).add;

        context.server.sync;

        // --- BIBLE COMMANDS ---

        // "Burial": Move everything one layer deeper
        this.addCommand(\shift_layers, "", {
            (maxLayers-1).reverseDo({ arg i;
                if (i > 0) {
                    buffers[i].copyData(buffers[i-1]);
                };
            });
            buffers[0].zero; // Clear the surface for new formation
        });

        this.addCommand(\record_start, "", {
            // Buffer 0 is always the Surface
            { RecordBuf.ar(In.ar(context.in_b, 2), buffers[0], loop: 0, doneAction: 2) }.play;
        });
        
        this.addCommand(\ready, "", { "Memory Physics Engine: Stable".postln; });
    }

    free {
        buffers.do(_.free);
    }
}
