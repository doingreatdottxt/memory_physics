// lib/Engine_MemoryPhysics.sc
Engine_MemoryPhysics : CroneEngine {
    var <buffers;
    var <maxLayers = 6;
    var <bus;

    *new { arg context, doneCallback;
        ^super.new(context, doneCallback);
    }

    alloc {
        // 6 Stereo Buffers (20s each)
        buffers = Array.fill(maxLayers, {
            Buffer.alloc(context.server, context.server.sampleRate * 20, 2);
        });
        
        // Bus for playhead tracking
        bus = Bus.control(context.server, maxLayers);

        SynthDef(\StrataLayer, {
            arg buf, out, amp=0, depth=0, duration=20, gate=1, phase_bus;
            var sig, pressure, lpfFreq, env, phase;
            
            // LIFO Pressure (0 = Surface, 1 = Deep)
            pressure = (depth / (maxLayers - 1)).clip(0, 1);
            
            // Custom Loop Length using Phasor
            phase = Phasor.ar(0, BufRateScale.kr(buf), 0, duration * BufSampleRate.kr(buf));
            sig = BufRd.ar(2, buf, phase);
            
            // Send playhead position back to bus
            Out.kr(phase_bus, phase / (duration * BufSampleRate.kr(buf)));
            
            // GEOLOGICAL DSP
            lpfFreq = pressure.linexp(0, 1, 20000, 150);
            sig = LPF.ar(sig, lpfFreq.lag(0.5));
            sig = (sig * (1 + (pressure * 3))).softclip;
            
            env = EnvGen.kr(Env.asr(0.1, 1, 0.5), gate, doneAction: 2);
            Out.ar(out, sig * (amp * (1 - (pressure * 0.4))) * env);
        }).add;

        context.server.sync;

        // COMMANDS
        this.addCommand(\shift_layers, "", {
            (maxLayers-1).reverseDo({ arg i;
                if (i > 0) { buffers[i].copyData(buffers[i-1]); };
            });
            buffers[0].zero; 
        });

        this.addCommand(\record_start, "f", { arg msg;
            // Record into Surface (Buffer 0) with Overdub/Feedback capability
            { 
                var input = In.ar(context.in_b, 2);
                RecordBuf.ar(input, buffers[0], recLevel: 1.0, preLevel: 0.5, loop: 1);
            }.play;
        });

        this.addCommand(\ready, "", { "Engine Restored".postln; });
    }

    free {
        buffers.do(_.free);
        bus.free;
    }
}
