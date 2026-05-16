// lib/Engine_MemoryPhysics.sc
Engine_MemoryPhysics : CroneEngine {
    var <buffers, <synths, <recSynth, <maxLayers = 6;
    var <phaseBus, <weatherBus, <pressureBus, <envBus, <volBus, <durBus;
    var <baseFcBus, <modFcBus, <baseRqBus, <modRqBus, <driftBus;
    var <durations; 

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
        
        durBus = Bus.control(context.server, maxLayers);
        durBus.setAll(5.0);
        durations = Array.fill(maxLayers, { 5.0 });

        baseFcBus = Bus.control(context.server, 1).set(8000);
        modFcBus = Bus.control(context.server, 1).set(7500);
        baseRqBus = Bus.control(context.server, 1).set(1.2);
        modRqBus = Bus.control(context.server, 1).set(3.0);
        driftBus = Bus.control(context.server, 1).set(0.005);

        SynthDef(\StrataLayer, { arg buf, out, depth=0, phase_out, dur_idx;
            var sig, pressure, lpf, phase, noise, w_val, env, v, duration;
            var base_fc, mod_fc, base_rq, mod_rq, drift, p_sq, rq, layer_weather, rate;
            var drive, bits, target_sr, crackle, seismic_jitter;

            w_val = In.kr(weatherBus.index, 1);
            v = In.kr(volBus.index, 1);
            env = In.kr(envBus.index, 1);
            duration = In.kr(durBus.index + dur_idx, 1);

            base_fc = In.kr(baseFcBus.index, 1);
            mod_fc = In.kr(modFcBus.index, 1);
            base_rq = In.kr(baseRqBus.index, 1);
            mod_rq = In.kr(modRqBus.index, 1);
            drift = In.kr(driftBus.index, 1);

            // Total pressure is a combination of global override and layer depth index
            pressure = (In.kr(pressureBus.index, 1) + (depth / (maxLayers - 1))).clip(0, 1);
            p_sq = pressure * pressure;

            // Environmental Weather Erosion: Most intense on top layer, slightly bleeds into layer 2
            layer_weather = Select.kr(depth, [
                w_val,
                (w_val >= 0.8).if(w_val * 0.25, 0)
            ] ++ Array.fill(maxLayers - 2, { 0 }));

            // Seismic Cracking: Extreme weather and high pressure cause micro-fractures in loop playback rate
            crackle = Dust.kr(layer_weather.linlin(0, 1, 0, 45) * (pressure + 0.1));
            seismic_jitter = TRand.kr(-0.012, 0.012, crackle) * layer_weather;
            
            rate = 1.0 + (SinOsc.kr(drift * 25) * (layer_weather * drift)) + seismic_jitter;

            phase = Phasor.ar(0, BufRateScale.kr(buf) * rate, 0, duration * BufSampleRate.kr(buf));
            sig = BufRd.ar(2, buf, phase, loop: 1);
            
            // Send normalized playhead phase value back to Norns via OSC at 15Hz
            SendReply.kr(Impulse.kr(15), '/layer_phase', [depth, phase / (duration * BufSampleRate.kr(buf))], 998);

            // Atmospheric Weather Noise Generation
            noise = Select.ar(env % 3, [
                BrownNoise.ar(0.08),
                Dust.ar(12) * 0.4,
                PinkNoise.ar(0.08)
            ]) * layer_weather;

            sig = sig + noise;

            // --- PRESSURE DEGRADATION ENGINE ---
            // 1. Saturation / Compression (Geological Compaction)
            drive = pressure.linexp(0, 1, 1, 6.5);
            sig = (sig * drive).tanh * (1.0 - (pressure * 0.25));

            // 2. Bitcrushing & Sample-Rate Reduction (Crystallization / Compaction Distortion)
            bits = pressure.linlin(0, 1, 24, 5).round(1);
            target_sr = pressure.linexp(0, 1, 48000, 11025);
            sig = sig.round(0.5 ** bits);
            sig = Latch.ar(sig, Impulse.ar(target_sr));

            // 3. Bi-quad Structural Filtering
            lpf = (base_fc - (p_sq * mod_fc)).clip(35, 20000);
            rq = base_rq + (p_sq * mod_rq);
            sig = RLPF.ar(sig, lpf.lag(0.2), rq.clip(0.01, 2.0));

            // Depth-based attenuation matrix
            sig = sig * (0.95 - (pressure * 0.45)); 

            Out.ar(out, sig * v);
        }).add;

        SynthDef(\InputTracker, { arg in;
            SendReply.kr(Impulse.kr(10), '/in_amp', [Amplitude.kr(Mix(In.ar(in, 2)))], 999);
        }).add;

        SynthDef(\SurfaceRecorder, { arg buf, in;
            RecordBuf.ar(In.ar(in, 2), buf, recLevel: 1.0, preLevel: 0.0, loop: 0, doneAction: 2);
        }).add;

        context.server.sync;

        synths = Array.fill(maxLayers, { arg i;
            Synth(\StrataLayer, [\buf, buffers[i], \out, context.out_b.index, \depth, i, \dur_idx, i], context.xg);
        });

        Synth(\InputTracker, [\in, context.in_b[0].index], context.xg);

        this.addCommand(\shift_layers, "", {
            (maxLayers - 1).reverseDo({ arg i;
                if(i > 0) { buffers[i].copyData(buffers[i - 1]); }
            });
            buffers[0].zero;

            (maxLayers - 1).reverseDo({ arg i;
                if(i > 0) {
                    durations[i] = durations[i - 1];
                    context.server.sendMsg("/c_set", durBus.index + i, durations[i]);
                }
            });
            durations[0] = 5.0;
            context.server.sendMsg("/c_set", durBus.index, 5.0);
        });

        this.addCommand(\set_duration, "if", { arg msg;
            durations[msg[1]] = msg[2];
            context.server.sendMsg("/c_set", durBus.index + msg[1], msg[2]);
        });

        this.addCommand(\record_start, "", {
            recSynth = Synth(\SurfaceRecorder, [\buf, buffers[0], \in, context.in_b[0].index], context.xg);
        });

        this.addCommand(\record_stop, "", {
            recSynth.free;
        });

        this.addCommand(\set_weather, "f", { arg msg; weatherBus.set(msg[1]); });
        this.addCommand(\set_pressure, "f", { arg msg; pressureBus.set(msg[1]); });
        this.addCommand(\set_env, "i", { arg msg; envBus.set(msg[1]); });
        this.addCommand(\set_volume, "f", { arg msg; volBus.set(msg[1]); });

        this.addCommand(\set_environment_params, "fffff", { arg msg;
            baseFcBus.set(msg[1]);
            modFcBus.set(msg[2]);
            baseRqBus.set(msg[3]);
            modRqBus.set(msg[4]);
            driftBus.set(msg[5]);
        });
    }
}
