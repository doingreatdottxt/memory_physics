// lib/Engine_MemoryPhysics.sc
Engine_MemoryPhysics : CroneEngine {
    var <buffers, <synths, <recSynth, <maxLayers = 6;
    var <recBuffer; 
    var <phaseBus, <weatherBus, <pressureBus, <envBus, <volBus, <durBus;
    var <baseFcBus, <modFcBus, <baseRqBus, <modRqBus, <driftBus;
    var <durations;
    
    // Global FX and Background Ambient Asset Routing Buses
    var <fxBus, <fxSynth, <monitorSynth, <bgSynth;

    *new { arg context, doneCallback;
        ^super.new(context, doneCallback);
    }

    alloc {
        buffers = Array.fill(maxLayers, {
            Buffer.alloc(context.server, context.server.sampleRate * 20, 2);
        });

        recBuffer = Buffer.alloc(context.server, context.server.sampleRate * 20, 2);

        // Hardware decoupling audio routing bus
        fxBus = Bus.audio(context.server, 2);

        phaseBus = Bus.control(context.server, maxLayers);
        weatherBus = Bus.control(context.server, 1).set(0.2); // 20% at boot per specification
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

        // 1. GENERATIVE ENVIRONMENTAL BACKGROUND AMBIENCE SYNTH
        // Handles "Breeze", "Wind", and "Waves" structural rules from the top of the specification list
        SynthDef(\EnvBackground, { arg out;
            var w_val, env_idx, noise, breeze, wind, waves;
            var b_env, w_env, wav_env, trigger_rate, gate_b, gate_w, gate_wav;

            w_val = In.kr(weatherBus.index, 1);
            env_idx = In.kr(envBus.index, 1);

            // Generative Trigger Clocks running asynchronously
            trigger_rate = w_val.linlin(0, 1, 0.1, 0.8);
            gate_b = Dust.kr(trigger_rate);
            gate_w = Dust.kr(trigger_rate * 0.7);
            gate_wav = Dust.kr(trigger_rate * 0.5);

            // Strict Attack-Sustain-Release Proportion Curves mapped from rulebook percentages
            b_env = EnvGen.kr(Env.asr(0.40, 0.45, 0.15, \sin), gate_b);
            w_env = EnvGen.kr(Env.asr(0.40, 0.45, 0.15, \sin), gate_w);
            wav_env = EnvGen.kr(Env.asr(0.25, 0.40, 0.35, \sin), gate_wav);

            // Audio Asset Synthesis Pipelines
            breeze = PinkNoise.ar(w_val.linlin(0, 1, 0.01, 0.04)) * b_env;
            breeze = BPFilter.ar(breeze, LFNoise1.kr(0.5).exprange(800, 2400), 0.3);
            breeze = Pan2.ar(breeze, LFNoise1.kr(0.2));

            wind = PinkNoise.ar(w_val.linlin(0, 1, 0.02, 0.08)) * w_env;
            wind = BPFilter.ar(wind, LFNoise1.kr(0.3).exprange(400, 1600), 0.4);
            wind = Pan2.ar(wind, LFNoise1.kr(0.1));

            waves = WhiteNoise.ar(w_val.linlin(0, 1, 0.03, 0.12)) * wav_env;
            waves = LPF.ar(waves, LFNoise1.kr(0.2).exprange(200, 900));
            waves = Pan2.ar(waves, LFNoise1.kr(0.15));

            // Biome Matrix Mix Engine
            noise = Select.ar(env_idx % 7, [
                breeze * 0.5,                                      // 0: Grove
                wind * 0.6,                                        // 1: Sand
                wind * 0.8,                                        // 2: Mountain
                breeze * 0.4,                                      // 3: River Bank
                Select.ar(w_val > 0.5, [waves * 0.7, wind * 0.6]), // 4: Sea
                breeze * 0.2,                                      // 5: Swamp
                Silent.ar(2)                                       // 6: Cave
            ]);

            Out.ar(out, noise);
        }).add;

        // 2. MASTER SITE EFFECTS SYNTH PIPELINE
        // Intercepts loop layers and incoming monitors through unified climate logic modifiers
        SynthDef(\MasterFX, { arg in, out;
            var sig, w_val, p_val, env_idx;
            var localIn, wetSig, delayTime, feedback, mod;
            var d_lpf, d_hpf, drive, bits, target_sr;
            var w_gate, layer2_weather;

            sig = In.ar(in, 2);
            w_val = In.kr(weatherBus.index, 1);
            p_val = In.kr(pressureBus.index, 1);
            env_idx = In.kr(envBus.index, 1);

            // --- DESTRUCTIVE ENVIRONMENTAL MODIFIERS MATRIX ---
            // "Rain" Delay (Feedback Loop network processing)
            delayTime = p_val.linexp(0, 1, 0.12, 1.4).lag(0.4);
            feedback = w_val.linlin(0, 1, 0.15, 0.82);
            localIn = LocalIn.ar(2) * feedback;
            mod = LFDNoise3.kr(w_val.linlin(0, 1, 0.1, 3.0)).range(0.97, 1.03);
            wetSig = DelayC.ar(sig + localIn, 2.0, (delayTime * mod).clip(0.01, 2.0));
            wetSig = LPF.ar(wetSig, 4000);
            LocalOut.ar(wetSig);

            // Select wet rain signal relative to environmental conditions
            sig = Select.ar(Select.kr(env_idx % 7, [1, 0, 0, 1, 0, 1, 1]), [
                sig,
                XFade2.ar(sig, wetSig, w_val * 2 - 1)
            ]);

            // --- BIOME SPECIFIC AUDIO FILTERING / DEGRADATION ---
            // "Dry" vs "Damp" Equalization Curves
            d_lpf = Select.kr(env_idx % 7, [
                6000,  // Grove: Damp
                18000, // Sand: Dry
                16000, // Mountain: Dry
                5500,  // River Bank: Damp
                12000, // Sea
                2500,  // Swamp: Very Damp
                3500   // Cave: Damp
            ]);

            d_hpf = Select.kr(env_idx % 7, [
                40,   // Grove
                150,  // Sand: Dry
                200,  // Mountain: Dry
                50,   // River Bank
                80,   // Sea
                30,   // Swamp
                100   // Cave
            ]);

            sig = LPF.ar(sig, d_lpf.lag(0.5));
            sig = HPF.ar(sig, d_hpf.lag(0.5));

            // "Cold" / "Warm" Temperature Distortion Models
            drive = Select.kr(env_idx % 7, [
                1.2, // Grove: Warm
                3.5, // Sand: Hot
                5.0, // Mountain: Cold Distortion
                1.0, // River Bank: Cool
                1.1, // Sea: Cool
                1.5, // Swamp: Warm
                1.0  // Cave
            ]) * p_val.linexp(0, 1, 1, 4);

            sig = (sig * drive).tanh * (1.0 / (drive.sqrt));

            // Pressure Decimation Engine
            bits = p_val.linlin(0, 1, 24, 6).round(1);
            target_sr = p_val.linexp(0, 1, 48000, 12000);
            sig = sig.round(0.5 ** bits);
            sig = Latch.ar(sig, Impulse.ar(target_sr));

            Out.ar(out, sig * In.kr(volBus.index, 1));
        }).add;

        // 3. LIVE INPUT MONITOR
        SynthDef(\InputMonitor, { arg in, out;
            var sig = In.ar(in, 2);
            Out.ar(out, sig);
        }).add;

        // 4. LAYER PLAYBACK ENGINE
        SynthDef(\StrataLayer, { arg buf, out, depth=0, phase_out, dur_idx;
            var sig, phase, duration, rate, layer_vol;
            var drift, layer_weather, crackle, seismic_jitter;
            var w_val, w_gate;

            w_val = In.kr(weatherBus.index, 1);
            duration = In.kr(durBus.index + dur_idx, 1);
            drift = In.kr(driftBus.index, 1);

            // Layer 2 Weather Bleed Rule: Caps at 20% influence when climate expands > 80%
            w_gate = w_val >= 0.8;
            layer_weather = Select.kr(depth, [
                w_val, 
                w_gate * w_val.linlin(0.8, 1.0, 0.0, 0.2)
            ] ++ Array.fill(maxLayers - 2, { 0.0 }));

            crackle = Dust.kr(layer_weather.linlin(0, 1, 0, 45));
            seismic_jitter = TRand.kr(-0.012, 0.012, crackle) * layer_weather;
            rate = 1.0 + (SinOsc.kr(drift * 25) * (layer_weather * drift)) + seismic_jitter;

            phase = Phasor.ar(0, BufRateScale.kr(buf) * rate, 0, duration * BufSampleRate.kr(buf));
            sig = BufRd.ar(2, buf, phase, loop: 1);

            SendReply.kr(Impulse.kr(15), '/layer_phase', [depth, phase / (duration * BufSampleRate.kr(buf))], 998);

            // LIFO Stratum Volume Decay Array
            layer_vol = Select.kr(depth, [1.0, 0.5, 0.2, 0.0, 0.0, 0.0]);

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

        // Establish strict synchronous node execution chains
        Synth(\InputTracker, [\in, context.in_b[0].index], context.xg);
        
        synths = Array.fill(maxLayers, { arg i;
            Synth(\StrataLayer, [\buf, buffers[i], \out, fxBus.index, \depth, i, \dur_idx, i], context.xg);
        });

        monitorSynth = Synth(\InputMonitor, [\in, context.in_b[0].index, \out, fxBus.index], context.xg);
        
        // Background noise mixed into FX bus before final processing
        bgSynth = Synth(\EnvBackground, [\out, fxBus.index], context.xg);
        
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

        this.addCommand(\set_duration, "if", { arg msg;
            durations[msg[1]] = msg[2];
            context.server.sendMsg("/c_set", durBus.index + msg[1], msg[2]);
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
