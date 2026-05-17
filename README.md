# 

***-Project Vision - Last In First Out Looper

***-Conceptual Framework -
 Geological "Stratta" form as loops stack. As "Strata" layers are burried they become decreasingly audible. 100% volume at surface layer, 50% volume at layer 2, 20% volume at layer 3. Muted at layer 4,5,and 6. Archeological "Excivation" and "Erosion" of the top layer returns previously burried "Strata" to the audible zone, but modified by the pressures they experienced while burried. Pressure effects increase as "Strata" are burried deeper. 0% at surface layer, 10% at layer 2, 25% at layer 3, 40% at layer 4, 60% at layer 5, 80% at layer 6. Pressure intensity can be overridden using encoder 3 to manually increase or decrease. "Weather" factors effect incoming audio and the surface layer by influencing aspects of the current "Environment". Intensity can be manually adjusted with encoder 2. layer 2 can be effected by "Weather" up to %20 intensity when weather is set above 80%. "Environment" - Creates rules for audio handling. Each "Environment" contains a unique audio handling that represents the conditions of real world biomes.
*** layer shift handling
When a layer changes position, fade in or out to the new layer volume over the length of the layer
***Auto record detection
Listen for input above background noise threshold. Use live continuous recording buffer to ensure new layer recording does not clip start. Record timeout defaults to 2 seconds but should be user definable in Params menu. Clip silence from end of loop after completion.

***Defining "Environment" "Pressure", and "Weather" Effects -

"Breeze" Pink Noise Generator. Subtle semi-randonized frequency, length, panning, and intensity relative to effect intensity. each "Breeze" should use an Attack Sustain Release envelope with an Attack length of 40%, and a release 15% from the end 
"Wind" - Pink Noise Generator. Moderate Semi-randonized frequency, length, panning, and intensity relative to effect intensity. each "Wind" should use an Attack Sustain Release envelope with an Attack length of 40%, and a release 15% from the end 
"Rain" -single return delay effect 
"Dry" - Moderate band pass and high pass filters 
"Damp" - moderate Low Pass and band rejection filter 
"Cold" - moderate distortion and low end noise gate threshold 
"Cool" subtle distortion and low end noise gate threshold 
"Warm" -Subtle time stretching, saturation, and warble 
"Hot" - moderate time stretching, saturation, and warble 
"Storm" - subtle Granular dislocation of audio fragments, increases intensity of existing "Weather" effects when "Weather" is above 80% 
"Deep" - substantial low pass filter 
"Waves" - White Noise Generator. length, panning, and intensity relative to effect intensity. each "Wave" should use an Attack Sustain Release envelope with an Attack length of 25%, and a release 35% from the end 
"Chirps" Randomized 50ms-150ms pitch shifted grains Pitch shift 2-4 octaves up from original audio. 0-2 chirps per second 
"Hollow" Subtle Reverb and Delay

***Effect modifiers -

"Very" - increase 30%

"Some" - Decrease 30%

***-"Environment"s-

"Grove" - Damp, Warm, Chirps, Breeze, Rain when "Weather" is >50%

"Sand" - Dry, Wind, Hot

"Mountain" - Cold, Wind, Dry

"River Bank" - Damp, Rain, Cool, breeze, Chirps

"Sea" - Cool, Waves, Breeze When "Weather" below 50%, Wind when "Weather" above 50%

"Swamp" - Very Damp, Warm, Some Rain, Some Chirp

"Cave" - Hollow, Damp, Rain, Chirp

***Control scheme - 

Key 1 - Shift Key 2 - form / bury (records new top layer and burries previous top layer on completion). Key 3 - Toggle Automatic recording mode on/off (on by default) Shift + key 2 - Cycle "Environment" Shift + key 3 - Excavate (Clears all active layers) Encoder 1 - "Environment" intensity Encoder 2 - Weather intensity (20% at boot) Encoder 3 - Pressure intensity override

***Visual Feedback-

 Header - "STABLE" or "FORMING STRATA" and recording timer Center - "Strata" Stack : 1-6 stacked horizontal pictograms representing the "Strata" buffers as soil layers. Surface layer should have visual cues to the Current "Environment". deeper layer should become increasingly rocky. Playhead: A dot scrolls across each "Strata" pictogram to show the current loop position. Footer - "Weather" level / "Pressure" level , active "Environment"
