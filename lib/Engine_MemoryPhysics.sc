Engine_MemoryPhysics : EngineObject {
    var <buffers;
    var <playGroup;
    var <maxLayers = 6;

    *new { arg context, doneCallback;
        ^super.new(context, doneCallback);
    }

    alloc {
        buffers = Array.fill(maxLayers, {
            Buffer.alloc(context.server, context.server.sampleRate * 20, 2);
        });

        playGroup = Group.tail(context.xg);

        // Define the Strata Synth
        SynthDef(\StrataLayer, {
            arg buf, out, amp=1.0, depth=0, gate=1;
            var sig, pressure, crush, muffled;
            
            sig = PlayBuf.ar(2, buf, loop: 1);
            
            // PRESSURE MECHANIC
            // As depth increases (0 to 5), filter closes and bitcrush increases
            pressure = depth / 5.0; 
            
            // Muffling (Low Pass)
            muffled = LPF.ar(sig, 20000 - (pressure * 19500));
            
            // Crushing (Bitcrush/Sample Rate reduction)
            crush = Decimator.ar(muffled, 48000 - (pressure * 40000), 16 - (pressure * 12));
            
            sig = SelectX.ar(pressure.lag(0.5), [sig, crush]);
            
            Out.ar(out, sig * amp * EnvGen.kr(Env.asr(0.1, 1, 0.1), gate, doneAction: 2));
        }).add;

        context.server.sync;

        // Command to shift buffers down
        this.addCommand(\shift_layers, "", {
            // Move buffer 4 to 5, 3 to 4, etc.
            // This is "Burial"
            (maxLayers-1).reverseDo({ arg i;
                buffers[i+1].copyData(buffers[i]);
            });
            buffers[0].zero; // Clear surface for new recording
        });

        this.addCommand(\record_surface, "i", { arg msg;
            // Implementation for recording into buffers[0]
        });
    }

    free {
        buffers.do(_.free);
    }
}
