// lib/Engine_MemoryPhysics.sc
// Geological Strata Engine - Memory Physics
// Implements Weathering, Pressure Overrides, and Auto-Record Overdubbing

Engine_MemoryPhysics : CroneEngine {
    var <buffers;
    var <synths;
    var <maxLayers = 6;
    
    // Parameter Buses for real-time Lua control
    var <phaseBus, <weatherBus, <pressureBus, <envBus, <autoRecBus;

    *new { arg context, doneCallback;
        ^super.new(context, doneCallback);
    }

    alloc {
        buffers = Array.fill(maxLayers, {
            Buffer.alloc(context.server, context.server.sampleRate * 20, 2);
        });
        
        // Allocate contiguous buses
        phaseBus = Bus.control(context.server, maxLayers);
        weatherBus = Bus.control(context.server, 1).set(0.2); // 20% default
        pressureBus = Bus.control(context.server, 1).set(0.0);
        envBus = Bus.control(context.server, 1).set(0);
        autoRecBus = Bus.control(context.server, 1).set(1.0); // Auto-record ON

        SynthDef(\StrataLayer, {
            arg buf, out, amp=1, depth=0, duration=20, phase_out;
            var sig, pressure, base_pressure, lpfFreq, phase, noise, weather_val, env_type;
            
            weather_val = In.kr(weatherBus.index, 1);
            pressure = In.kr(pressureBus.index, 1);
            env_type = In.kr(envBus.index, 1);

            // Total Pressure = Physical Depth + Encoder Override
            base_pressure = (depth / (maxLayers - 1));
            pressure = (base_pressure + pressure).clip(0, 1);

            // Playback & Playhead Tracking
            phase = Phasor.ar(0, BufRateScale.kr(buf), 0, duration * BufSampleRate.kr(buf));
            sig = BufRd.ar(2, buf, phase);
            Out.kr(phase_out, phase / (duration * BufSampleRate.kr(buf)));

            // --- ENVIRONMENT / WEATHER (Surface Only) ---
            // 0 = Wind (BrownNoise), 1 = Rain/Sand (Dust), 2 = Sea (PinkNoise)
            noise = Select.ar(env_type, [
                BrownNoise.ar(0.5) * LFDNoise3.kr(0.5).exprange(0.1, 1.0),
                Dust.ar(15) * 0.8,
                PinkNoise.ar(0.3) * SinOsc.kr(0.1).range(0.1, 1.0)
            ]);
            // Apply weather only to the surface, scaled by intensity
            noise = noise * weather_val * (1 - base_pressure) * 0.2;

            // --- GEOLOGICAL DSP ---
            lpfFreq = pressure.linexp(0, 1, 20000, 150);
            sig = LPF.ar(sig + noise, lpfFreq.lag(0.5));
            sig = (sig * (1 + (pressure * 3))).softclip;
            
            // Erosion: Deep layers become quieter
            Out.ar(out, sig * (amp * (1 - (base_pressure * 0.6))));
        }).add;

        context.server.sync;

        // Instantiate the 6 layers so they constantly play
        synths = Array.fill(maxLayers, { arg i;
            Synth(\StrataLayer, [
                \buf, buffers[i],
                \depth, i,
                \phase_out, phaseBus.index + i
            ], context.xg);
        });

        // The Recording Head (Surface Overdub)
        SynthDef(\SurfaceRecorder, {
            arg buf, in_bus;
            var input, pre_level, is_auto;
            is_auto = In.kr(autoRecBus.index, 1);
            input = In.ar(in_bus, 2);
            // If Auto is ON, preLevel is 0.5 (Overdub). If OFF, preLevel is 1.0 (Read-only)
            pre_level = Select.kr(is_auto > 0, [1.0, 0.5]); 
            RecordBuf.ar(input, buf, recLevel: is_auto, preLevel: pre_level, loop: 1);
        }).play(context.xg, [\buf, buffers[0], \in_bus, context.in_b]);

        // --- COMMANDS ---
        this.addCommand(\shift_layers, "", {
            (maxLayers-1).reverseDo({ arg i;
                if (i > 0) { buffers[i].copyData(buffers[i-1]); };
            });
            buffers[0].zero; 
        });

        // Setters for Lua
        this.addCommand(\set_weather, "f", { arg val; weatherBus.set(val); });
        this.addCommand(\set_pressure, "f", { arg val; pressureBus.set(val); });
        this.addCommand(\set_env, "i", { arg val; envBus.set(val); });
        this.addCommand(\set_auto, "i", { arg val; autoRecBus.set(val); });
        this.addCommand(\ready, "", { "Engine Ready".postln; });
    }

    free {
        buffers.do(_.free);
        synths.do(_.free);
        phaseBus.free; weatherBus.free; pressureBus.free; envBus.free; autoRecBus.free;
    }
}
