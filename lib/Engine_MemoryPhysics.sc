// lib/Engine_MemoryPhysics.sc
// Geological Strata Engine - Bible Version 2.1

Engine_MemoryPhysics : CroneEngine {
    var <buffers, <synths, <recSynth, <maxLayers = 6;
    var <phaseBus, <weatherBus, <pressureBus, <envBus, <volBus;

    *new { arg context, doneCallback; ^super.new(context, doneCallback); }

    alloc {
        buffers = Array.fill(maxLayers, { Buffer.alloc(context.server, context.server.sampleRate * 20, 2); });
        
        phaseBus = Bus.control(context.server, maxLayers);
        weatherBus = Bus.control(context.server, 1).set(0.2); 
        pressureBus = Bus.control(context.server, 1).set(0.0);
        envBus = Bus.control(context.server, 1).set(0);
        volBus = Bus.control(context.server, 1).set(1.0);

        SynthDef(\StrataLayer, {
            arg buf, out, amp=1, depth=0, duration=20, phase_out;
            var sig, pressure, base_p, lpf, phase, noise, w_val, env, v;
            w_val = In.kr(weatherBus.index, 1);
            pressure = (In.kr(pressureBus.index, 1) + (depth/(maxLayers-1))).clip(0, 1);
            env = In.kr(envBus.index, 1);
            v = In.kr(volBus.index, 1);

            phase = Phasor.ar(0, BufRateScale.kr(buf), 0, duration * BufSampleRate.kr(buf));
            sig = BufRd.ar(2, buf, phase);
            Out.kr(phase_out, phase / (duration * BufSampleRate.kr(buf)));

            noise = Select.ar(env, [BrownNoise.ar(0.5), Dust.ar(15), PinkNoise.ar(0.3)]) * w_val * (1-(depth/(maxLayers-1))) * 0.1;
            sig = LPF.ar(sig + noise, pressure.linexp(0, 1, 20000, 150).lag(0.5));
            Out.ar(out, sig.softclip * v * (1 - (depth * 0.1)));
        }).add;

        SynthDef(\InputTracker, { arg in; SendReply.kr(Impulse.kr(20), '/in_amp', Amplitude.kr(Mix(In.ar(in, 2)))); }).add;
        SynthDef(\SurfaceRecorder, { arg buf, in; RecordBuf.ar(In.ar(in, 2), buf, loop: 0, doneAction: 2); }).add;

        context.server.sync;

        synths = Array.fill(maxLayers, { arg i; 
            Synth(\StrataLayer, [\buf, buffers[i], \out, context.out_b, \depth, i, \phase_out, phaseBus.index + i], context.xg); 
        });
        Synth(\InputTracker, [\in, context.in_b], context.xg);

        this.addCommand(\shift_layers, "", { (maxLayers-1).reverseDo({ arg i; if(i>0){ buffers[i].copyData(buffers[i-1]) } }); buffers[0].zero; });
        this.addCommand(\record_start, "", { recSynth = Synth(\SurfaceRecorder, [\buf, buffers[0], \in, context.in_b], context.xg); });
        this.addCommand(\record_stop, "", { recSynth.free; });
        this.addCommand(\set_weather, "f", { arg v; weatherBus.set(v); });
        this.addCommand(\set_pressure, "f", { arg v; pressureBus.set(v); });
        this.addCommand(\set_env, "i", { arg v; envBus.set(v); });
        this.addCommand(\set_volume, "f", { arg v; volBus.set(v); });
    }
}
