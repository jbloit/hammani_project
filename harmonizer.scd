// Execute the following in order
(
// allocate a Buffer
s = Server.local;
b = Buffer.alloc(s, 44100 * 1.0, 1); // a four second 1 channel Buffer
)

Buffer.freeAll;
(
var winenv = Env([0.5, 1, 0.5], [1, 1], [8, -8]);
z = Buffer.sendCollection(s, winenv.discretize, 1);
SynthDef(\harmonizer, { |envbuf = -4, gate = 1|
	var pointer, pitch;
	var env  = EnvGen.ar(Env.adsr,gate,doneAction:2);
	// pointer - move from beginning to end of soundfile over 15 seconds
	pointer = LFSaw.ar(1/15).range(0, 1);
	// control pitch with MouseX
	pitch = Mix.ar([0.5,1,1.5,2]);
	Out.ar(0, Warp1.ar(
		numChannels:1,
		bufnum:b,
		pointer:pointer,
		freqScale:1,
		windowSize:0.1,
		envbufnum:envbuf,
		overlaps:32,
		windowRandRatio:0.1,
		interp:2
	)*env/4)
}).add

);

(
Tdef(\loo2p,{loop{
	1.wait;
	SynthDef(\help_RecordBuf, { arg out = 0, bufnum = 0;
		var input;
		input=SoundIn.ar(0);
		RecordBuf.ar(input, bufnum, doneAction: Done.freeSelf, loop: 0);
	}).play(s,[\out, 0, \bufnum, b]);

	~harmonizer= Synth(\harmonizer);
	~harmonizer2.set(\gate,0);

	4.wait;
	Synth(\help_RecordBuf);


	~harmonizer2= Synth(\harmonizer);
	~harmonizer.set(\gate,0);
	4.wait;
}}).play
);
