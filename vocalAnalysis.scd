/*
Run a pitch analysis periodically and send values over OSC
*/

// s.options.inDevice_("UMC202HD 192k");
// s.options.outDevice_("UMC202HD 192k");



s.waitForBoot({
	//////////////////////////////////// synth def and busses


	var winenv;
	Bus.clear;
	// a custom envelope
	winenv = Env([0, 1, 0], [0.5, 0.5], [8, -8]);
	z = Buffer.sendCollection(s, winenv.discretize, 1);

	// input

	~inputBus = Bus.audio(s, 1); // audio bus to get input from, either soundin or sfplayer.
	~sfBuffer=Buffer.cueSoundFile(s,"/Users/bloit/Dropbox/hammaniProject_media/audio/chant_julien.wav",0, 1);
	SynthDef(\diskin,{|out=0|
		var sig = DiskIn.ar(1, ~sfBuffer.bufnum);
		Out.ar(out, sig);
		Out.ar(0, sig);
	};
	).add;
	s.sync;
	~player = Synth(\diskin, [\out, ~inputBus.index]);


	~inputCount = 1; // number of mics
	~oscSendPeriod = 0.1; //sec

	// TODO: calibrate this in the app:
	~minFreq = 90;
	~maxFreq = 800;
	~minAmp = 0.001; // amplitude threshold. under that, we consider the input as silence.

	~currentSection = -1;
	~pitchTresh = 0.25; // considered "Hi pitch" above this thresh.
	~ampTresh = 0.04; // considered "Hi amp" above this thresh.

	// function to pick a video section index based on audio analysis
	~decideSection = {|amp=0, freq=0, hasFreq=0|
		var section = -1; // -1 represents the silent category, ie no input from user.
		if (amp>~minAmp, {
			if (amp<~ampTresh,{
				if (freq < ~pitchTresh, {
					// low freq, low amp
					section = 0;
				}, {
					//hi freq, low amp
					section = 1;
				});
			},
			if (freq < ~pitchTresh, {
				// low freq, hi amp
				section = 2;
			}, {
				// hi freq, hi amp
				section = 3;
			});
			);
		},
		);
		section;
	};

	~sectionLabels = ["LO freq - LO amp", "HI freq - LO amp", "LO freq - HI amp", "HI freq - HI amp" ];

	~sectionHistory = Array.fill(10, {|i| -1});

	~pushValueAndGetMedian = {|newVal=0|
		~sectionHistory = ~sectionHistory.shift(1).put(0, newVal);
		~sectionHistory.median.floor;
	};

	// bus arrays, group per audio input
	~meterBusses = Array.new;
	~pitchBusses = Array.new;
	~voicedBusses = Array.new;

	~inputCount.do{|i|
		~meterBusses = ~meterBusses.add(Bus.control(s, 1));
		~pitchBusses = ~pitchBusses.add(Bus.control(s, 1));
		~voicedBusses = ~voicedBusses.add(Bus.control(s, 1));
	};

	// Analyze audio features and copy them in control busses
	SynthDef(\audioAnalyzer, {
		|in=0, meterOut=0, pitchOut=0, voicedOut=0|

		var input, amp, pitch, hasFreq;
		input = In.ar(in,1);
		amp = Amplitude.kr(input, releaseTime: 5);
		# pitch, hasFreq = Pitch.kr(input, minFreq:~minFreq, maxFreq:~maxFreq, downSample:2, median:10);

		pitch = pitch.lag(10);

		Out.kr(meterOut, amp);
		Out.kr(pitchOut, (pitch * hasFreq / ~maxFreq).lag(1));
		// Out.kr(voicedOut, (amp *10* hasFreq.linlin(0, 1, -1, 1)).lag(1));
		Out.kr(voicedOut, hasFreq.lag(1));
	}).add;



	SynthDef(\harmonizer, { |out=0, gate = 1, amp = 1, envbuf,in=0|
		var pan, env;
		// use mouse x to control panning
		pan = MouseX.kr(-1, 1);
		env = EnvGen.kr(
			Env([0, 1, 0], [1, 1], \sin, 1),
			gate,
			levelScale: amp,
			doneAction: Done.freeSelf);
		Out.ar(out,
			GrainIn.ar(2, Impulse.kr(1), 1,SoundIn.ar(in), pan, envbuf) * env)
	}).add;

	s.sync;


	// ~harmo = Synth(\harmonizer);

	// Poll the value of a signal periodically, and send over the value via OSC.
	~uiMachine = NetAddr.new("127.0.0.1", 12000);

	SystemClock.sched(0.0,
		{

			var section;
			~inputCount.do({|i|

				~pitchBusses[i].get({|pitchVal|

					~meterBusses[i].get({|ampVal|

						~voicedBusses[i].get({|voicedVal|
							// pitchVal.postln;

							section = ~decideSection.value(ampVal, pitchVal);

							// filter the section with median filter
							section = ~pushValueAndGetMedian.value(section).asInt;

							// for debug
							"------------".postln;
							"AMP ".post; ampVal.postln;
							"PITCH ".post; pitchVal.postln;
							~sectionLabels[section].postln;


							if (section!=~currentSection, {

								// Trigger a section change
								~uiMachine.sendMsg("/section", section);
								section.class.postln;
								// ~uiMachine.sendMsg("/section", -1);
								"============= SEND SECTION ".post; section.postln;
								~currentSection = section;

								// ici tu changes des trucs comme tu veux sur l'harmonizer en fonction de la section

								/*								~harmo.free;
								~harmo = Synth(\harmonizer);*/


							});

						});
					});
				};
				);
			});

			// wait this amount of time before sending OSC again:
			~oscSendPeriod;
		};
	);

	~player1 = Synth.after(~player, \audioAnalyzer, [\in, 0, \meterOut, ~meterBusses[0], \voicedOut, ~voicedBusses[0], \pitchOut, ~pitchBusses[0] ] );
	// ~player2 = Synth(\audioAnalyzer, [\in, 1, \meterOut, ~meterBusses[1], \voicedOut, ~voicedBusses[1], \pitchOut, ~pitchBusses[1] ] );
}
;
);
