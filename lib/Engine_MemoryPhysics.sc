// lib/Engine_MemoryPhysics.sc
Engine_MemoryPhysics : CroneEngine {
    var <buffers, <synths, <recSynth, <maxLayers = 6;
    var <recBuffer; 
    var <phaseBus, <weatherBus, <pressureBus, <envBus, <volBus, <durBus;
    var <baseFcBus, <modFcBus, <baseRqBus, <modRqBus, <driftBus;
    var <durations;
    
    var <fxBus, <fxSynth, <monitorSynth, <bgSynth;
    var <ampForwarder, <phaseForwarder, <luaAddr;

    *new { arg context, doneCallback;
        ^super.new(context, doneCallback);
    }

    alloc {
        luaAddr = NetAddr("127.0.0.1", 10111);

        buffers = Array.fill(maxLayers, {
            Buffer.alloc(context.server, context.server.sampleRate * 20, 2);
        });

        recBuffer = Buffer.alloc(context.server, context.server.sampleRate * 20, 2);
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

        ampForwarder = OSCFunc({ arg msg;
            luaAddr.sendMsg('/in_amp', msg[3]);
        }, '/in_amp', context.server.addr).fix;

        phaseForwarder = OSCFunc({ arg msg;
            luaAddr.sendMsg('/layer_phase', msg[3], msg[4]);
        }, '/layer_phase', context.server.addr).fix;

        // 1. GENERATIVE ENVIRONMENTAL BACKGROUND AMBIENCE SYNTH
        // Fully updated to track the exact mathematical percentage specifications outlined in the README
        SynthDef(\EnvBackground, { arg out;
            var w_val, env_idx, noise, breeze, wind, waves;
            var b_trig, b_dur, b_env, b_freq, b_pan, b_amp;
            var w_trig, w_dur, w_env, w_freq, w_pan, w_amp;
            var wav_trig, wav_dur, wav_env, wav_freq, wav_pan, wav_amp;

            w_val = In.kr(weatherBus.index, 1);
            env_idx = In.kr(envBus.index, 1);

            // --- BREEZE STRUCTURAL RULES (Grove / River Bank / Swamp) ---
            // Trigger rate expands dynamically with weather intensity
            b_trig = Dust.kr(w_val.linlin(0, 1, 0.08, 0.42));
            // Sample a unique duration for each individual breeze event (3 to 8 seconds)
            b_dur = TRand.kr(3.0, 8.0, b_trig);
            // Envelope specification: 40% Attack, 45% Sustain, 15% Release
            b_env = EnvGen.kr(Env([0, 1, 1, 0], [0.40, 0.45, 0.15], \sin), b_trig, timeScale: b_dur);
            // Latched randomizations capture distinct properties on every single trigger
            b_freq = TExpRand.kr(850, 2100, b_trig).lag(1.2);
            b_pan = TRand.kr(-0.75, 0.75, b_trig).lag(2.0);
            b_amp = TRand.kr(0.45, 1.0, b_trig) * w_val.linlin(0, 1, 0.01, 0.07);
            
            breeze = PinkNoise.ar(b_amp) * b_env;
            breeze = BPF.ar(breeze, b_freq, TRand.kr(0.22, 0.38, b_trig));
            breeze = Pan2.ar(breeze, b_pan);

            // --- WIND STRUCTURAL RULES (Sand / Mountain / Sea) ---
            w_trig = Dust.kr(w_val.linlin(0, 1, 0.05, 0.35));
            w_dur = TRand.kr(5.0, 12.0, w_trig);
            // Envelope specification: 40% Attack, 45% Sustain, 15% Release
            w_env = EnvGen.kr(Env([0, 1, 1, 0], [0.40, 0.45, 0.15], \sin), w_trig, timeScale: w_dur);
            w_freq = TExpRand.kr(320, 1400, w_trig).lag(1.8);
            w_pan = TRand.kr(-0.95, 0.95, w_trig).lag(3.5);
            w_amp = TRand.kr(0.40, 1.0, w_trig) * w_val.linlin(0, 1, 0.02, 0.14);
            
            wind = PinkNoise.ar(w_amp) * w_env;
            wind = BPF.ar(wind, w_freq, TRand.kr(0.35, 0.55, w_trig));
            wind = Pan2.ar(wind, w_pan);

            // --- WAVES STRUCTURAL RULES (Sea Biome Overlay) ---
            wav_trig = Dust.kr(w_val.linlin(0, 1, 0.04, 0.22));
            wav_dur = TRand.kr(6.0, 15.0, wav_trig);
            -- Envelope specification: 25% Attack, 40% Sustain, 35% Release
            wav_env = EnvGen.kr(Env([0, 1, 1, 0], [0.25, 0.40, 0.35], \sin), wav_trig, timeScale: wav_dur);
            // Continuous internal LFO simulates a sweeping aquatic tidal wash motion
            wav_freq = SinOsc.kr(1 / wav_dur).exprange(160, 480);
            wav_pan = LFNoise1.kr(1 / wav_dur).range(-0.7, 0.7);
            wav_amp = w_val.linlin(0, 1, 0.03, 0.16) * wav_env;
            
            waves = WhiteNoise.ar(wav_amp);
            waves = LPF.ar(waves, wav_freq);
            waves = Pan2.ar(waves, wav_pan);

            // Biome Matrix Selector Engine
            noise = Select.ar(env_idx % 7, [
                breeze * 0.6,                                      // 0: Grove
                wind * 0.7,                                        // 1: Sand
                wind * 0.9,                                        // 2: Mountain
                breeze * 0.5,                                      // 3: River Bank
                Select.ar(w_val > 0.5, [waves * 0.8, wind * 0.6]), // 4: Sea
                breeze * 0.3,                                      // 5: Swamp
                Silent.ar(2)                                       // 6: Cave
            ]);

            Out.ar(out, noise);
        }).add;

        // 2. MASTER SITE EFFECTS SYNTH PIPELINE
        SynthDef(\MasterFX, { arg in, out;
            var sig, w_val, p_val, env_idx;
            var localIn, wetSig, delayTime, feedback, mod;
            var d_lpf, d_hpf, baseDrive, drive, driveSig;
            var bits, target_sr, crushSig;

            sig = In.ar(in, 2);
            w_val = In.kr(weatherBus.index, 1);
            p_val = In.kr(pressureBus.index, 1);
            env_idx = In.kr(envBus.index, 1);

            delayTime = w_val.linlin(0, 1, 0.75, 0.32).lag(0.5);
            feedback = w_val.linlin(0, 1, 0.10, 0.78);
            localIn = LocalIn.ar(2) * feedback;
            mod = LFDNoise3.kr(w_val.linlin(0, 1, 0.2, 2.5)).range(0.96, 1.04);
            wetSig = DelayC.ar(sig + localIn, 2.0, (delayTime * mod).clip(0.01, 2.0));
            wetSig = HPF.ar(LPF.ar(wetSig, 3800), 100);
            LocalOut.ar(wetSig);

            sig = Select.ar(Select.kr(env_idx % 7, [1, 0, 0, 1, 0, 1, 1]), [
                sig,
                XFade2.ar(sig, wetSig, w_val * 2 - 1)
            ]);

            d_lpf = Select.kr(env_idx % 7, [6000, 18000, 16000, 5500, 12000, 2500, 3500]);
            d_hpf = Select.kr(env_idx % 7, [40, 150, 200, 50, 80, 30, 100]);
            sig = LPF.ar(sig, d_lpf.lag(0.5));
            sig = HPF.ar(sig, d_hpf.lag(0.5));

            baseDrive = Select.kr(env_idx % 7, [1.2, 3.5, 5.0, 1.0, 1.1, 1.5, 1.0]);
            drive = baseDrive + (p_val * 4.0);
            driveSig = (sig * drive).tanh * (1.0 / (drive.sqrt));
            sig = XFade2.ar(sig, driveSig, p_val.linlin(0, 1, -0.4, 1.0));

            bits = p_val.linlin(0, 1, 24, 6).round(1);
            target_sr = p_val.linexp(0.001, 1, 48000, 11025);
            crushSig = Latch.ar(sig.round(0.5 ** bits), Impulse.ar(target_sr));
            sig = SelectX.ar(p_val > 0, [sig, crushSig]);

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
            var w_val, w_gate, env_idx, p_override, base_pressure, pressure;
            var base_fc, mod_fc, base_rq, mod_rq, lpf, rq, p_sq, noise;
            var drive, bits, target_sr, crushSig, driveSig;

            w_val = In.kr(weatherBus.index, 1);
            env_idx = In.kr(envBus.index, 1);
            p_override = In.kr(pressureBus.index, 1);
            duration = In.kr(durBus.index + dur_idx, 1);
            drift = In.kr(driftBus.index, 1);
            
            base_fc = In.kr(baseFcBus.index, 1);
            mod_fc = In.kr(modFcBus.index, 1);
            base_rq = In.kr(baseRqBus.index, 1);
            mod_rq = In.kr(modRqBus.index, 1);

            base_pressure = Select.kr(depth, [0.0, 0.1, 0.25, 0.4, 0.6, 0.8]);
            pressure = (p_override + base_pressure).clip(0, 1);
            p_sq = pressure * pressure;

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

            noise = Select.ar(env_idx % 7, [
                BrownNoise.ar(0.08), PinkNoise.ar(0.12), WhiteNoise.ar(0.04), 
                PinkNoise.ar(0.06), WhiteNoise.ar(0.1), BrownNoise.ar(0.15), PinkNoise.ar(0.03)
            ]) * layer_weather;
            sig = sig + noise;

            drive = Select.kr(env_idx % 7, [1.2, 3.5, 5.0, 1.0, 1.1, 1.5, 1.0]) * pressure.linexp(0, 1, 1, 4);
            driveSig = (sig * drive).tanh * (1.0 / (drive.sqrt));
            sig = SelectX.ar(pressure > 0, [sig, driveSig]);

            bits = pressure.linlin(0, 1, 24, 6).round(1);
            target_sr = pressure.linexp(0.001, 1, 48000, 12000);
            crushSig = Latch.ar(sig.round(0.5 ** bits), Impulse.ar(target_sr));
            sig = SelectX.ar(pressure > 0, [sig, crushSig]);

            lpf = (base_fc - (p_sq * mod_fc)).clip(40, 19500);
            rq = base_rq + (p_sq * mod_rq);
            sig = RLPF.ar(sig, lpf.lag(0.3), rq.clip(0.04, 2.0));

            layer_vol = Select.kr(depth, [1.0, 0.5, 0.2, 0.0, 0.0, 0.0]);
            Out.ar(out, sig * layer_vol);
        }).add;

        SynthDef(\InputTracker, { arg in;
            var input_signal = In.ar(in, 2);
            var mono_sum = (input_signal[0] + input_signal[1]) * 0.5;
            SendReply.kr(Impulse.kr(15), '/in_amp', [Amplitude.kr(mono_sum)], 999);
        }).add;

        SynthDef(\SurfaceRecorder, { arg buf, in;
            RecordBuf.ar(In.ar(in, 2), buf, recLevel: 1.0, preLevel: 0.0, loop: 0, doneAction: 2);
        }).add;

        context.server.sync;

        Synth(\InputTracker, [\in, context.in_b[0].index], context.xg);
        
        synths = Array.fill(maxLayers, { arg i;
            Synth(\StrataLayer, [\buf, buffers[i], \out, fxBus.index, \depth, i, \dur_idx, i], context.xg);
        });

        monitorSynth = Synth(\InputMonitor, [\in, context.in_b[0].index, \out, fxBus.index], context.xg);
        bgSynth = Synth(\EnvBackground, [\out, fxBus.index], context.xg);
        fxSynth = Synth.after(context.xg, \MasterFX, [\in, fxBus.index, \out, context.out_b.index]);

        this.addCommand(\shift_layers, "f", { arg msg;
            var new_dur = msg[1];
            
            (maxLayers - 2).reverseDo({ arg i;
                buffers[i].copyData(buffers[i + 1]);
                durations[i + 1] = durations[i];
                context.server.sendMsg("/c_set", durBus.index + i + 1, durations[i + 1]);
            });
            
            recBuffer.copyData(buffers[0]);
            durations[0] = new_dur;
            context.server.sendMsg("/c_set", durBus.index, new_dur);
        });

        this.addCommand(\erode_layer, "", {
            (maxLayers - 1).do({ arg i;
                buffers[i + 1].copyData(buffers[i]);
                durations[i] = durations[i + 1];
                context.server.sendMsg("/c_set", durBus.index + i, durations[i]);
            });
            
            buffers[maxLayers - 1].zero;
            durations[maxLayers - 1] = 2.0;
            context.server.sendMsg("/c_set", durBus.index + (maxLayers - 1), 2.0);
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

    free {
        ampForwarder.free;
        phaseForwarder.free;
    }
}
