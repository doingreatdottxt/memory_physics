Engine_MemoryPhysics : CroneEngine {
    var <buffers;
    var <maxLayers = 6;

    *new { arg context, doneCallback;
        ^super.new(context, doneCallback);
    }

    alloc {
        // Pre-allocate 6 stereo buffers (20s each)
        // Using server.sync to ensure allocation finishes before Lua moves on
        Routine {
            buffers = Array.fill(maxLayers, { |i|
                var b = Buffer.alloc(context.server, context.server.sampleRate * 20, 2);
                context.server.sync;
                ("Memory Physics: Allocated Layer " + (i + 1)).postln;
                b
            });

            SynthDef(\StrataLayer, {
                arg buf, out, amp=0, depth=0, gate=1;
                var sig, pressure, muffled;
                pressure = (depth / (maxLayers - 1)).clip(0, 1);
                sig = PlayBuf.ar(2, buf, loop: 1);
                // Daisy-compatible DSP
                muffled = LPF.ar(sig, Math.exp(Line.kr(log(20000), log(200), pressure)));
                sig = (sig * (1 + (pressure * 2))).softclip;
                Out.ar(out, sig * amp * EnvGen.kr(Env.asr(0.1, 1, 0.1), gate, doneAction: 2));
            }).add;

            context.server.sync;
            
            // Burial Logic
            this.addCommand(\shift_layers, "", {
                (maxLayers-1).reverseDo({ arg i;
                    if(i > 0, {
                        buffers[i].copyData(buffers[i-1]);
                    });
                });
                buffers[0].zero;
            });

            this.addCommand(\record_start, "", {
                // Record into the Surface (Buffer 0)
                { RecordBuf.ar(In.ar(context.in_b, 2), buffers[0], loop: 0, doneAction: 2) }.play;
            });

            // Handshake: tell Lua we are ready
            this.addCommand(\ready, "", { "Engine Ready".postln; });
            
        }.play;
    }

    free {
        buffers.do(_.free);
    }
}
