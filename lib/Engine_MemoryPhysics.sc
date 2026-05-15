// lib/Engine_MemoryPhysics.sc
// Geological Strata Engine - Memory Physics
// Implements Weathering, Pressure, OSC Auto-Record, and Global Volume

Engine_MemoryPhysics : CroneEngine {
    var <buffers;
    var <synths;
    var <recSynth;
    var <maxLayers = 6;
    
    // Buses
    var <phaseBus, <weatherBus, <pressureBus, <envBus, <volBus;

    *new { arg context, doneCallback;
        ^super.new(context, doneCallback);
    }

    alloc {
        buffers = Array.fill(maxLayers, {
            Buffer.alloc(context.server, context.server.sampleRate * 20, 2);
        });
        
        phaseBus = Bus.control(context.server, maxLayers);
        weatherBus = Bus.control(context.server, 1).set(0.2); 
        pressureBus = Bus.control(context.server, 1).set(0.0);
        envBus = Bus.control(context.server, 1).set(0);
        volBus = Bus.control(context.server, 1).set(1.0); // Enc 1 Global Vol

        SynthDef(\StrataLayer, {
            arg buf, out, amp=1, depth=0, duration=20, phase_out;
            var sig, pressure, base_pressure, lpfFreq, phase, noise, weather_val, env_type, vol;
            
            weather_val = In.kr(weatherBus.index, 1);
            pressure = In.kr(pressureBus.index, 1);
            env_type = In.kr(envBus.index, 1);
            vol = In.kr(volBus.index, 1);

            base_pressure = (depth / (maxLayers - 1));
            pressure = (base_pressure + pressure).clip(0, 1);

            phase = Phasor.ar(0, BufRateScale.kr(buf), 0, duration * BufSampleRate.kr(buf));
            sig = BufRd.ar(2, buf, phase);
            Out.kr(phase_out, phase / (duration * BufSampleRate.kr(buf)));

            // ENVIRONMENT / WEATHER
            noise = Select.ar(env_type, [
                BrownNoise.ar(0.5) * LFDNoise3.kr(0.5).exprange(0.1, 1.0),
                Dust.ar(15) * 0.8,
                PinkNoise.ar(0.3) * SinOsc.kr(0.1).range(0.1, 1.0)
            ]);
            noise = noise * weather_val * (1 - base_pressure) * 0.2;

            // GEOLOGICAL DSP
            lpfFreq = pressure.linexp(0, 1, 20000, 150);
            sig = LPF.ar(sig + noise, lpfFreq.lag(0.5));
            sig = (sig * (1 + (pressure * 3))).softclip;
            
            // Output mapped properly to out argument
            Out.ar(out, sig * (amp * (1 - (base_pressure * 0.6))) * vol);
        }).add;

        // Threshold Tracker: Sends Amplitude to Lua
        SynthDef(\InputTracker, {
            arg in_bus;
            var input = In.ar(in_bus, 2);
            var amp = Amplitude.kr(Mix(input));
            SendReply.kr(Impulse.kr(20), '/in_amp', amp);
        }).add;

        // Dedicated Recorder
        SynthDef(\SurfaceRecorder, {
            arg buf, in_bus;
            RecordBuf.ar(In.ar(in_bus, 2), buf, loop: 0, doneAction: 2);
        }).add;

        context.server.sync;

        // Playback Synths (Explicitly mapped to context.out_b)
        synths = Array.fill(maxLayers, { arg i;
            Synth(\StrataLayer, [
                \buf, buffers[i],
                \out, context.out_b,  // PLAYBACK FIX
                \depth, i,
                \phase_out, phaseBus.index + i
            ], context.xg);
        });

        // Start Tracker
        Synth(\InputTracker, [\in_bus, context.in_b], context.xg);

        // COMMANDS
        this.addCommand(\shift_layers, "", {
            (maxLayers-1).reverseDo({ arg i;
                if (i > 0) { buffers[i].copyData(buffers[i-1]); };
            });
            buffers[0].zero; 
        });

        this.addCommand(\record_start, "", {
            if(recSynth.notNil) { recSynth.free };
            recSynth = Synth(\SurfaceRecorder, [\buf, buffers[0], \in_bus, context.in_b], context.xg);
        });

        this.addCommand(\record_stop, "", {
            if(recSynth.notNil) { recSynth.free; recSynth = nil; };
        });

        this.addCommand(\set_weather, "f", { arg val; weatherBus.set(val); });
        this.addCommand(\set_pressure, "f", { arg val; pressureBus.set(val); });
        this.addCommand(\set_env, "i", { arg val; envBus.set(val); });
        this.addCommand(\set_volume, "f", { arg val; volBus.set(val); });
        this.addCommand(\ready, "", { "Engine Ready".postln; });
    }

    free {
        buffers.do(_.free);
        synths.do(_.free);
        if(recSynth.notNil) { recSynth.free };
        phaseBus.free; weatherBus.free; pressureBus.free; envBus.free; volBus.free;
    }
}
