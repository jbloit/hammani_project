/*
Run a pitch analysis periodically and send values over OSC
*/

// s.options.inDevice_("UMC202HD 192k");
// s.options.outDevice_("UMC202HD 192k");
s.options.inDevice_("Fireface UC Mac (23669936)");
s.options.outDevice_("Fireface UC Mac (23669936)");

s.waitForBoot({
	//////////////////////////////////// synth def and busses

	Buffer.freeAll;
	Bus.clear;

	// input

	~inputBus = Bus.audio(s, 1); // audio bus to get input from, either soundin or sfplayer.
	~sfBuffer=Buffer.cueSoundFile(s,"/Users/bloit/Dropbox/hammaniProject_media/audio/chant_julien.wav",0, 1);
	SynthDef(\diskin,{|out=0|
		var sig = SoundIn.ar(0);
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

	~minAmp = 0.02; // amplitude threshold. under that, we consider the input as silence.
	~currentSection = -1;
	~pitchTresh = 0.25; // considered "Hi pitch" above this thresh.
	~ampTresh = 0.4; // considered "Hi amp" above this thresh.
	~blowThresh = 0.2; // noise considered to be blowing (as opposed to clapping) above this thresh.
	~voicedThresh = 0.8; // considered singing above this thresh

	// function to pick a video section index based on audio analysis
	~decideSection = {|amp=0, freq=0, hasFreq=0|
		var section = -1; // -1 represents the silent category, ie no input from user.
		if (amp>~minAmp, {

			if (hasFreq > ~voicedThresh, {
				if (amp<~ampTresh,{
					// voiced, low amp
					section = 0;
				}, {
					// voiced, hi amp
					section = 1;
				});
			}, {
				if (amp<~ampTresh,{
					// soft noise
					section = 2;
				}, {
					// loud noise
					section = 3;
				});
			});
		},
		);
		section;
	};

	~sectionHistory = Array.fill(10, {|i| -1});

	// Init fifos, for holding decision history
	~fifoSize = 50;
	~fifos = Array.newClear(4);
	~fifos[0] = Array.fill(~fifoSize, {|i| 0});
	~fifos[1] = Array.fill(~fifoSize, {|i| 0});
	~fifos[2] = Array.fill(~fifoSize, {|i| 0});
	~fifos[3] = Array.fill(~fifoSize, {|i| 0});


	~pushValueAndGetSumArray = {|section=0|
		// shift fifos, push out old values
		4.do({|i|
			~fifos[i] = ~fifos[i].shift(1);
		});

		if(section > -1,{
			~fifos[section].put(0,1); // store 1 in the fifo of the detected section
		}
		);

		// return likelihoods
		~fifos.collect({|row| row.sum / row.size})
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

		var input, amp, pitch, hasFreq, onsets, chain;
		input = In.ar(in,1);
		amp = Amplitude.kr(input, releaseTime: 5);
		# pitch, hasFreq = Pitch.kr(input, minFreq:~minFreq, maxFreq:~maxFreq, downSample:2, median:10);
		pitch = pitch.lag(5);

		Out.kr(meterOut, amp.lag(5));
		Out.kr(pitchOut, (pitch * hasFreq / ~maxFreq).lag(1));
		Out.kr(voicedOut, hasFreq.lag(2));
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
							var sectionLikelihoods;
							section = ~decideSection.value(ampVal, pitchVal, voicedVal);

							// filter the section with median filter
							sectionLikelihoods = ~pushValueAndGetSumArray.value(section);

							// Debug
							"------------".postln;
							sectionLikelihoods.postln;

/*							"AMP ".post; ampVal.postln;
							"PITCH ".post; pitchVal.postln;
							"VOICED ".post; voicedVal.postln;*/


							sectionLikelihoods.size.do({|i|
								~uiMachine.sendMsg("/likelihood", i, sectionLikelihoods[i]);
							});

							// update Processing with the threshold values used for detection, so that there
							// can be a visual feedback during the calibration phase.
							~uiMachine.sendMsg("/ampThresh", ~ampTresh);
							~uiMachine.sendMsg("/voicedThresh", ~voicedThresh);
						});
					});
				};
				);
			});

			// wait this amount of time before sending OSC again:
			~oscSendPeriod;
		};
	);

	~player1 = Synth.after(~player, \audioAnalyzer, [\in, ~inputBus.index, \meterOut, ~meterBusses[0], \voicedOut, ~voicedBusses[0], \pitchOut, ~pitchBusses[0] ] );


	OSCdef.new(\updathresholds, {|msg|
		"OSC IN".postln;
		msg.postln;
		~ampTresh = msg[1];
		~voicedThresh = msg[2];

	}, "/updateThresholds");

	OSCdef.new(\selectedCategory, {|msg|
		var category;
		"OSC IN".postln;
		msg.postln;
		category = msg[1];


	}, "/updateThresholds");


	~changeAudioPreset = {|index=0|};
}
;
);
