Engine_MemoryPhysics : CroneEngine {
    var <buffers;
    var <maxLayers = 6;
    var <synthGroup;

    *new { arg context, doneCallback;
        ^super.new(context, doneCallback);
    }

    alloc {
        synthGroup = Group.tail(context.xg);
        
        // Pre-allocate 6 stereo buffers (20s each)
        // This is the exact memory footprint we will use on the Daisy Seed
        buffers = Array.fill(maxLayers, {
            Buffer.alloc(context.server, context.server.sampleRate * 20, 2);
        });

        SynthDef(\StrataLayer, {
            arg buf, out, amp=0, depth=0, gate=1;
            var sig, pressure, noise, env;
            
            // Pressure 0.0 (Surface) to 1.0 (Deep Crust)
            pressure = (depth / (maxLayers - 1)).clip(0, 1);
            
            sig = PlayBuf.ar(2, buf, loop: 1);
            
            // GEOLOGICAL DSP (Daisy-friendly)
            // 1. Muffling: LPF frequency drops as depth increases
            sig = LPF.ar(sig, Math.exp(Line.kr(log(20000), log(200), pressure)));
            
            // 2. Compaction: Simple soft-clipping to simulate pressure
            sig = (sig * (1 + (pressure * 4))).softclip;
            
            // 3. Artifacts: Low-level brown noise leakage at depth
            noise = BrownNoise.ar(pressure * 0.05);
            
            env = EnvGen.kr(Env.asr(0.1, 1, 0.1), gate, doneAction: 2);
            Out.ar(out, (sig + noise) * amp * env);
        }).add;

        context.server.sync;

        // LIFO Shift Logic (The "Burial" process)
        this.addCommand(\shift_layers, "", {
            (maxLayers-1).reverseDo({ arg i;
                buffers[i].copyData(buffers[i-1]);
            });
            buffers[0].zero; // Clear surface for new "formation"
        });

        this.addCommand(\record_start, "", {
            // Buffer 0 is always the recording target (The Surface)
            RecordBuf.ar(In.ar(context.in_b, 2), buffers[0], loop: 0);
        });
    }

    free {
        buffers.do(_.free);
        synthGroup.free;
    }
}
