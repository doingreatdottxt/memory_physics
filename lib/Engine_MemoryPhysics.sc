// lib/Engine_MemoryPhysics.sc
Engine_MemoryPhysics : CroneEngine {
    var <buffers, <synths, <recSynth, <maxLayers = 6;
    var <phaseBus, <weatherBus, <pressureBus, <envBus, <volBus, <durBus;
    var <baseFcBus, <modFcBus, <baseRqBus, <modRqBus, <driftBus;

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
        volBus = Bus.control(context.server, 1).set(1.0);
        durBus = Bus.control(context.server, maxLayers).set(5.0);

        // Environment structural parameter buses mapped from environments.lua
        baseFcBus = Bus.control(context.server, 1).set(8000);
        modFcBus = Bus.control(context.server, 1).set(7500);
        baseRqBus = Bus.control(context.server, 1).set(1.2);
        modRqBus = Bus.control(context.server, 1).set(3.0);
        driftBus = Bus.control(context.server, 1).set(0.005);

        SynthDef(\StrataLayer, { arg buf, out, depth=0, phase_out, dur_idx;
            var sig, pressure, lpf, phase, noise, w_val, env, v, duration;
            var base_fc, mod_fc, base_rq, mod_rq, drift, p_sq, rq, layer_weather, rate;

            w_val = In.kr(weatherBus.index, 1);
            v = In.kr(volBus.index, 1);
            env = In.kr(envBus.index, 1);
            duration = In.kr(durBus.index + dur_idx, 1);

            base_fc = In.kr(baseFcBus.index, 1);
            mod_fc = In.kr(modFcBus.index, 1);
            base_rq = In.kr(baseRqBus.index, 1);
            mod_rq = In.kr(modRqBus.index, 1);
            drift = In.kr(driftBus.index, 1);

            pressure = (In.kr(pressureBus.index, 1) + (depth / (maxLayers - 1))).clip(0, 1);
            p_sq = pressure * pressure;

            // Dynamic playback rate tracking weather seepage per layer index depth
            layer_weather = Select.kr(depth, [
                w_val,
                (w_val >= 0.8).if(w_val * 0.25, 0)
            ] ++ Array.fill(maxLayers - 2, { 0 }));

            rate = 1.0 + (SinOsc.kr(drift * 25) * (layer_weather * drift));

            phase = Phasor.ar(0, BufRateScale.kr(buf) * rate, 0, duration * BufSampleRate.kr(buf));
            sig = BufRd.ar(2, buf, phase, loop: 1);
            Out.kr(phase_out, phase / (duration * BufSampleRate.kr(buf)));

            // Weather Noise Texturing (Summed to Strata Signal)
            noise = Select.ar(env % 3, [
                BrownNoise.ar(0.1),
                Dust.ar(10) * 0.5,
                PinkNoise.ar(0.1)
            ]) * w_val;

            // Filtering and dynamic geology modeling mirroring environments.lua formula
            lpf = (base_fc - (p_sq * mod_fc)).clip(20, 20000);
            rq = base_rq + (p_sq * mod_rq);

            sig = RLPF.ar(sig + noise, lpf.lag(0.2), rq.clip(0.01, 2.0));
            sig = sig * (0.9 - (pressure * 0.4)); // Depth-based attenuation

            Out.ar(out, sig * v);
        }).add;

        // Input monitoring for Auto-Record
        SynthDef(\InputTracker, { arg in;
            SendReply.kr(Impulse.kr(10), '/in_amp', [Amplitude.kr(Mix(In.ar(in, 2)))], 999);
        }).add;

        SynthDef(\SurfaceRecorder, { arg buf, in;
            RecordBuf.ar(In.ar(in, 2), buf, recLevel: 1.0, preLevel: 0.0, loop: 0, doneAction: 2);
        }).add;

        context.server.sync;

        // Fixed: pointing directly to the stereo bus index wrapper without an array offset
        synths = Array.fill(maxLayers, { arg i;
            Synth(\StrataLayer, [\buf, buffers[i], \out, context.out_b.index, \depth, i, \dur_idx, i, \phase_out, phaseBus.index + i], context.xg);
        });

        // context.in_b is an array of mono buses, so index tracking here remains intact
        Synth(\InputTracker, [\in, context.in_b[0].index], context.xg);

        this.addCommand(\shift_layers, "", {
            (maxLayers - 1).reverseDo({ arg i;
                if(i > 0) { buffers[i].copyData(buffers[i - 1]); }
            });
            buffers[0].zero;
        });

        this.addCommand(\set_duration, "if", { arg msg;
            context.server.sendMsg("/c_set", durBus.index + msg[1], msg[2]);
        });

        this.addCommand(\record_start, "", {
            recSynth = Synth(\SurfaceRecorder, [\buf, buffers[0], \in, context.in_b[0].index], context.xg);
        });

        this.addCommand(\record_stop, "", {
            recSynth.free;
        });

        this.addCommand(\set_weather, "f", { arg v; weatherBus.set(v); });
        this.addCommand(\set_pressure, "f", { arg v; pressureBus.set(v); });
        this.addCommand(\set_env, "i", { arg v; envBus.set(v); });
        this.addCommand(\set_volume, "f", { arg v; volBus.set(v); });

        this.addCommand(\set_environment_params, "fffff", { arg msg;
            baseFcBus.set(msg[1]);
            modFcBus.set(msg[2]);
            baseRqBus.set(msg[3]);
            modRqBus.set(msg[4]);
            driftBus.set(msg[5]);
        });
    }
}
