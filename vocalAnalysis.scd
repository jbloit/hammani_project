/*
Run a pitch analysis periodically and send values over OSC
*/

// s.options.inDevice_("UMC202HD 192k");
// s.options.outDevice_("UMC202HD 192k");

s.waitForBoot({
	//////////////////////////////////// synth def and busses
	~inputCount = 1; // number of mics

	~oscSendPeriod = 0.05; //sec

	// TODO: calibrate this in the app:
	~minFreq = 90;
	~maxFreq = 800;
	~minAmp = 0.01; // amplitude threshold. under that, we consider the input as silence.

	~currentSection = -1;

	// function to pick a video section index based on audio analysis
	~decideSection = {|amp=0, freq=0, hasFreq=0|
		var section = -1; // -1 represents the silent category, ie no input from user.
		if (amp>~minAmp, {
			if (amp<0.2,{
				if (freq < 0.5, {
					// low freq, low amp
					section = 0;
				}, {
					//hi freq, low amp
					section = 1;
				});
			},
				if (freq < 0.5, {
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

	Bus.clear;
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
		input = SoundIn.ar(in);
		amp = Amplitude.kr(input, releaseTime: 0.1).lag;
		# pitch, hasFreq = Pitch.kr(input, minFreq:~minFreq, maxFreq:~maxFreq, downSample:2, median:10);

		Out.kr(meterOut, amp);
		Out.kr(pitchOut, (pitch * hasFreq / ~maxFreq).lag(1));
		// Out.kr(voicedOut, (amp *10* hasFreq.linlin(0, 1, -1, 1)).lag(1));
		Out.kr(voicedOut, hasFreq.lag(1));
	}).add;

	s.sync;


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

							// for debug
							// "------------".postln;
							// ampVal.postln;
							// pitchVal.postln;
							// section.postln;

							if (section!=~currentSection, {

								// Trigger a section change
								~uiMachine.sendMsg("/section", section);

								// TODO : trigger  for the audio harmonizer



								~currentSection = section;
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

	~player1 = Synth(\audioAnalyzer, [\in, 0, \meterOut, ~meterBusses[0], \voicedOut, ~voicedBusses[0], \pitchOut, ~pitchBusses[0] ] );
	// ~player2 = Synth(\audioAnalyzer, [\in, 1, \meterOut, ~meterBusses[1], \voicedOut, ~voicedBusses[1], \pitchOut, ~pitchBusses[1] ] );
};
);

