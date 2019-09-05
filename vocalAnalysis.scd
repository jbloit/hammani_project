/*
Run a pitch analysis periodically and send values over OSC
*/

// s.options.inDevice_("UMC202HD 192k");
// s.options.outDevice_("UMC202HD 192k");



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
	~minAmp = 0.002; // amplitude threshold. under that, we consider the input as silence.

	~currentSection = -1;
	~pitchTresh = 0.25; // considered "Hi pitch" above this thresh.
	~ampTresh = 0.4; // considered "Hi amp" above this thresh.
	~blowAmp = 0.2; // noise considered to be blowing (as opposed to clapping) above this thresh.
	~voicedThresh = 0.8; // considered singing above this thresh

	// function to pick a video section index based on audio analysis
	~decideSection = {|amp=0, freq=0, hasFreq=0, tempo=0|
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
				if (amp<~blowAmp,{
					// clapping
					section = 2;
				}, {
					// blowing
					section = 3;
				});
			});
		},
		);
		section;
	};



	~sectionLabels = ["LO freq - LO amp", "HI freq - LO amp", "LO freq - HI amp", "HI freq - HI amp" ];

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
	~beatBusses = Array.new;

	~inputCount.do{|i|
		~meterBusses = ~meterBusses.add(Bus.control(s, 1));
		~pitchBusses = ~pitchBusses.add(Bus.control(s, 1));
		~voicedBusses = ~voicedBusses.add(Bus.control(s, 1));
		~beatBusses = ~beatBusses.add(Bus.control(s, 1));
	};

	// Analyze audio features and copy them in control busses
	SynthDef(\audioAnalyzer, {
		|in=0, meterOut=0, pitchOut=0, voicedOut=0, beatOut=0|

		var input, amp, pitch, hasFreq, onsets, chain;
		input = In.ar(in,1);
		amp = Amplitude.kr(input, releaseTime: 5);
		# pitch, hasFreq = Pitch.kr(input, minFreq:~minFreq, maxFreq:~maxFreq, downSample:2, median:10);
		pitch = pitch.lag(10);

		chain = FFT(LocalBuf(512), input);
		onsets = Onsets.kr(chain, 0.2, \rcomplex);

		Out.kr(meterOut, amp.lag(10));
		Out.kr(pitchOut, (pitch * hasFreq / ~maxFreq).lag(1));
		Out.kr(voicedOut, hasFreq.lag(2));
		Out.kr(beatOut, Timer.kr(onsets) );
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

						~beatBusses[i].get({|beatVal|

							~voicedBusses[i].get({|voicedVal|
								// pitchVal.postln;
								var sectionLikelihoods;
								section = ~decideSection.value(ampVal, pitchVal, voicedVal, beatVal);

								// filter the section with median filter
								sectionLikelihoods = ~pushValueAndGetSumArray.value(section);
								sectionLikelihoods.postln;

								// for debug
								"------------".postln;
								"AMP ".post; ampVal.postln;
								"PITCH ".post; pitchVal.postln;
								"VOICED ".post; voicedVal.postln;
								"TEMPO ".post; beatVal.postln;
								~sectionLabels[section].postln;

								sectionLikelihoods.size.do({|i|
									~uiMachine.sendMsg("/likelihood", i, sectionLikelihoods[i]);
								});
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

	~player1 = Synth.after(~player, \audioAnalyzer, [\in, ~inputBus.index, \meterOut, ~meterBusses[0], \voicedOut, ~voicedBusses[0], \pitchOut, ~pitchBusses[0], \beatOut, ~beatBusses[0] ] );
	// ~player2 = Synth(\audioAnalyzer, [\in, 1, \meterOut, ~meterBusses[1], \voicedOut, ~voicedBusses[1], \pitchOut, ~pitchBusses[1] ] );
}
;
);
