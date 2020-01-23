/*
Run a pitch analysis periodically and send values over OSC
*/

s.waitForBoot({
	//////////////////////////////////// synth def and busses

	currentEnvironment.clear;
	"harmonize.scd".loadRelative(true, {"loaded harmonizer".postln});

	Buffer.freeAll;
	Bus.clear;

	// input

	~inputBus = Bus.audio(s, 1); // audio bus to get input from, either soundin or sfplayer.
	SynthDef(\diskin,{|out=0|
		var sig = SoundIn.ar(0);
		Out.ar(out, sig);

	};
	).add;
	s.sync;
	~player = Synth(\diskin, [\out, ~inputBus.index]);


	~inputCount = 1; // number of mics
	~oscSendPeriod = 0.1; //sec

	~minFreq = 90;
	~maxFreq = 2000;

	~minAmp = 0.01; // amplitude threshold. under that, we consider the input as silence.
	~maxVoicedAmp = ~minAmp;
	~maxNoisedAmp = ~minAmp;

	~currentSection = -1;
	~ampTresh_0 = 0.5; // considered "Hi amp" above this thresh.
	~ampTresh_1 = 0.5; // considered "Hi amp" above this thresh.
	~voicedThresh = 0.9; // considered singing above this thresh



	~selectedCategory = 0;
	~harmonizer = Synth(\pitchFollow1, [\which, ~selectedCategory]);


	// function to pick a video section index based on audio analysis
	~decideSection = {|amp=0, freq=0, hasFreq=0|

		var section = -1; // -1 represents the silent category, ie no input from user.
		// amp.postln;
		if (amp > ~minAmp, {

			if (hasFreq > ~voicedThresh, {

				~maxVoicedAmp = ~maxVoicedAmp.max(amp);
				amp = amp.linlin(~minAmp, ~maxVoicedAmp, 0, 1);
				// amp = amp.explin(~minAmp, ~ampTresh_0, ~minAmp, 1);
				postf("VOICED: ampThresh = %, amp = % \n", ~ampTresh_0, amp);
				if (amp < ~ampTresh_0,{


					// voiced, low amp
					section = 0;
				}, {
					// voiced, hi amp
					section = 1;
				});
			}, {

				~maxNoisedAmp = ~maxNoisedAmp.max(amp);
				amp = amp.linlin(~minAmp, ~maxNoisedAmp, 0, 1);
				postf("NOT VOICED: ampThresh = %, amp = % \n", ~ampTresh_1, amp);

				if (amp < ~ampTresh_1,{
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
	~fifoSize = 10;
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
		amp = Amplitude.kr(input);
		amp = amp * 10;
		# pitch, hasFreq = Pitch.kr(input, minFreq:~minFreq, maxFreq:~maxFreq, downSample:2, median:1, clar:1);
		pitch = pitch.lag(5);
		// hasFreq.postln;
		Out.kr(meterOut, amp);
		Out.kr(pitchOut, (pitch * hasFreq / ~maxFreq).lag(1));
		Out.kr(voicedOut, hasFreq);
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

							~selectedCategory = sectionLikelihoods.maxIndex;
							~harmonizer.set(\which, ~selectedCategory);

							// Debug
/*							"------------".postln;
							sectionLikelihoods.postln;*/
							// postf("Category: %\n", ~selectedCategory);

/*							"AMP ".post; ampVal.postln;
							"PITCH ".post; pitchVal.postln;*/
							// "VOICED ".post; voicedVal.postln;


							sectionLikelihoods.size.do({|i|
								~uiMachine.sendMsg("/likelihood", i, sectionLikelihoods[i]);
							});

							// update Processing with the threshold values used for detection, so that there
							// can be a visual feedback during the calibration phase.
							~uiMachine.sendMsg("/ampThresh_0", ~ampTresh_0);
							~uiMachine.sendMsg("/ampThresh_1", ~ampTresh_1);
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
		~ampTresh_0 = msg[1];
		~ampTresh_1 = msg[2];

	}, "/updateThresholds");

	OSCdef.new(\selectedCategory, {|msg|
		var category;
		"OSC IN".postln;
		msg.postln;
		category = msg[1];


	}, "/\selectedCategory");


	~changeAudioPreset = {|index=0|};
}
;
);
