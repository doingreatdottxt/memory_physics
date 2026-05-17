// lib/Engine_MemoryPhysics.sc
Engine_MemoryPhysics : CroneEngine {
    var <buffers, <synths, <recSynth, <maxLayers = 6;
    var <recBuffer; 
    var <phaseBus, <weatherBus, <pressureBus, <envBus, <volBus, <durBus;
    var <baseFcBus, <modFcBus, <baseRqBus, <modRqBus, <driftBus;
    var <durations;
    
    // NEW: Effects routing
    var <fxBus, <fxSynth, <monitorSynth;

    *new { arg context, doneCallback;
        ^super.new(context, doneCallback);
    }

    alloc {
        buffers = Array.fill(maxLayers, {
            Buffer.alloc(context.server, context.server.sampleRate * 20, 2);
        });

        recBuffer = Buffer.alloc(context.server, context.server.sampleRate * 20, 2);

        // NEW: Audio bus for routing all layers and input into a master FX chain
        fxBus = Bus.audio(context.server, 2);

        phaseBus = Bus.control(context.server, maxLayers);
        weatherBus = Bus.control(context.server, 1).set(0.2); 
        pressureBus = Bus.control(context.server, 1).set(0.0);
        envBus = Bus.control(context.server, 1).set(0);
        volBus = Bus.control(context.server, 1).set(1.0);
        durBus = Bus.control(context.server, maxLayers);
        durBus.setAll(2.0);
        durations = Array.fill(maxLayers, { 2.0 });

        baseFcBus = Bus.control(context.server, 1).set(8000);
        modFcBus = Bus.control(context.server, 1).set(7500);
        baseRqBus = Bus.control(context.server, 1).set(1.2);
        modRqBus = Bus.control(context.server, 1).set(3.0);
        driftBus = Bus.control(context.server, 1).set(0.005);

        // 1. MASTER FX SYNTH
        // Handles "Rain" (Delay), "Cold" (Distortion), and Global Filtering
        SynthDef(\MasterFX, { arg in, out;
            var sig, w_val, p_val, env_idx;
            var delaySig, filterLpf, filterHpf, driveSig;

            sig = In.ar(in, 2);
            w_val = In.kr(weatherBus.index, 1);
            p_val = In.kr(pressureBus.index, 1);
            env_idx = In.kr(envBus.index, 1);

            // -- RAIN EFFECT (Delay) --
            // Applies a single return delay when weather is high
            delaySig = DelayC.ar(sig, 1.0, w_val.linlin(0, 1, 0.1, 0.6));
            sig = sig + (delaySig * w_val * 0.5);

            // -- TEMPERATURE/PRESSURE EFFECTS (Drive & Filtering) --
            driveSig = (sig * p_val.linexp(0, 1, 1, 5)).tanh;
            sig = XFade2.ar(sig, driveSig, p_val * 2 - 1);

            // -- GLOBAL EQ --
            filterLpf = In.kr(baseFcBus.index, 1);
            sig = LPF.ar(sig, filterLpf);

            Out.ar(out, sig * In.kr(volBus.index, 1));
        }).add;

        // 2. LIVE INPUT MONITOR
        // Routes dry incoming audio to the FX bus so you hear it affected before recording
        SynthDef(\InputMonitor, { arg in, out;
            var sig = In.ar(in, 2);
            Out.ar(out, sig);
        }).add;

        // 3. LAYER PLAYBACK
        SynthDef(\StrataLayer, { arg buf, out, depth=0, phase_out, dur_idx;
            var sig, phase, duration, rate, layer_vol;
            var drift, layer_weather, crackle, seismic_jitter;

            duration = In.kr(durBus.index + dur_idx, 1);
            drift = In.kr(driftBus.index, 1);
            layer_weather = In.kr(weatherBus.index, 1);

            crackle = Dust.kr(layer_weather.linlin(0, 1, 0, 45));
            seismic_jitter = TRand.kr(-0.012, 0.012, crackle) * layer_weather;
            rate = 1.0 + (SinOsc.kr(drift * 25) * (layer_weather * drift)) + seismic_jitter;

            phase = Phasor.ar(0, BufRateScale.kr(buf) * rate, 0, duration * BufSampleRate.kr(buf));
            sig = BufRd.ar(2, buf, phase, loop: 1);

            SendReply.kr(Impulse.kr(15), '/layer_phase', [depth, phase / (duration * BufSampleRate.kr(buf))], 998);

            // Layer volume attenuates as it gets buried deeper (per your README specs)
            layer_vol = Select.kr(depth, [1.0, 0.5, 0.2, 0.0, 0.0, 0.0]);

            // Outputs to FX Bus instead of hardware out
            Out.ar(out, sig * layer_vol);
        }).add;

        SynthDef(\InputTracker, { arg in;
            var input_signal = In.ar(in, 2);
            SendReply.kr(Impulse.kr(15), '/in_amp', [Amplitude.kr(Mix.ar(input_signal))], 999);
        }).add;

        SynthDef(\SurfaceRecorder, { arg buf, in;
            RecordBuf.ar(In.ar(in, 2), buf, recLevel: 1.0, preLevel: 0.0, loop: 0, doneAction: 2);
        }).add;

        context.server.sync;

        // Ensure proper node ordering: Track -> Record -> Playback -> Monitor -> FX
        Synth(\InputTracker, [\in, context.in_b[0].index], context.xg);
        
        synths = Array.fill(maxLayers, { arg i;
            // Notice \out is now fxBus.index
            Synth(\StrataLayer, [\buf, buffers[i], \out, fxBus.index, \depth, i, \dur_idx, i], context.xg);
        });

        monitorSynth = Synth(\InputMonitor, [\in, context.in_b[0].index, \out, fxBus.index], context.xg);
        fxSynth = Synth.after(context.xg, \MasterFX, [\in, fxBus.index, \out, context.out_b.index]);

        this.addCommand(\shift_layers, "f", { arg msg;
            var new_dur = msg[1];
            (maxLayers - 1).reverseDo({ arg i;
                if(i > 0) { buffers[i - 1].copyData(buffers[i]); }
            });
            recBuffer.copyData(buffers[0]);
            (maxLayers - 1).reverseDo({ arg i;
                if(i > 0) {
                    durations[i] = durations[i - 1];
                    context.server.sendMsg("/c_set", durBus.index + i, durations[i]);
                }
            });
            durations[0] = new_dur;
            context.server.sendMsg("/c_set", durBus.index, new_dur);
        });

        this.addCommand(\clear_layers, "", {
            buffers.do({ arg b; b.zero; });
            recBuffer.zero;
        });

        this.addCommand(\record_start, "", {
            recBuffer.zero; 
            recSynth = Synth(\SurfaceRecorder, [\buf, recBuffer, \in, context.in_b[0].index], context.xg);
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
