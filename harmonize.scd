(
var table;
var mapped, mapped2, diffbuf, diffbuf2;
var difference, difference2;
var tf, tf2;
var miditoname;
var nametomidi;


// define a function to convert a midi note number to a midi note name
miditoname = ({ arg note = 60, style = \American ;
	var offset = 0 ;
	var midi, notes;
	case { style == \French } { offset = -1}
	{ style == \German } { offset = -3} ;
	midi = (note + 0.5).asInteger;
	notes = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];

	(notes[midi%12] ++ (midi.div(12)-1+offset))
});

// define a function to convert a midi note name to a midi note number
nametomidi = ({ arg name = "C4", style = \American ;
	var offset = 0 ; // French usage: +1 ; German usage: +3
	var twelves, ones, octaveIndex, midis;

	case { style == \French } { offset = 1}
	{ style == \German } { offset = 3} ;

	midis = Dictionary[($c->0),($d->2),($e->4),($f->5),($g->7),($a->9),($b->11)];
	ones = midis.at(name[0].toLower);

	if( (name[1].isDecDigit), {
		octaveIndex = 1;
	},{
		octaveIndex = 2;
		if( (name[1] == $#) || (name[1].toLower == $s) || (name[1] == $+), {
			ones = ones + 1;
		},{
			if( (name[1] == $b) || (name[1].toLower == $f) || (name[1] == $-), {
				ones = ones - 1;
			});
		});
	});
	twelves = (name.copyRange(octaveIndex, name.size).asInteger) * 12;

	(twelves + 12 + ones + (offset*12))
});



table = Array.fill(12, {arg i; i + 60}); // [60,61,...,71]
// define a table of mapped notes (Default values)
mapped = ["e4", "a3", "c4", "c4", "c4", "d4", "d4", "e4", "e4", "e4", "f4", "g4"].collect(nametomidi.value(_));
mapped2= ["g3", "g3", "g3", "a3", "a4", "a4", "a4", "b4", "b4", "c4", "d4", "d4"].collect(nametomidi.value(_));


//mapped3 = ["e2", "a2", "c2", "c2", "c2", "d2", "d2", "e2", "e2", "e2", "f2", "g2"].collect(nametomidi.value(_));


// define a table to store the difference between reference and mapped note
difference = Array.fill(table.size, {0});
// define a buffer on the server for consultation from the SynthDef
diffbuf= Buffer.loadCollection(s,table,action:{|msg| msg.postln;});
difference2= Array.fill(table.size, {0});
diffbuf2=Buffer.loadCollection(s,table,action:{|msg| msg.postln;});
tf = List.new(table.size);
tf2 = List.new(table.size);


tf.do({arg item; item.action});
tf2.do({arg item; item.action});

table.do({arg item, i;
	difference2[i] = (table[i] - mapped2[i]).midiratio.reciprocal;
	difference[i] = (table[i] - mapped[i]).midiratio.reciprocal;
});

diffbuf.setn(0,difference);
diffbuf2.setn(0,difference2);


SynthDef.new("pitchFollow1",{ arg which=0;
	var in, amp, freq, hasFreq, out, out1,out2, out3,rev;
	var t, midinum;
	var harmony, harmony2, partials;
	//in  = PlayBuf.ar(1, ~buf,BufRateScale.kr(~buf),loop:1, doneAction: Done.freeSelf);
	in = SoundIn.ar(0);
	amp = Amplitude.kr(in, 0.05, 1);
	# freq, hasFreq = Pitch.kr(in);
	midinum = freq.cpsmidi.round(1);
	//midinum.postln;
	//freq = Lag.kr(midinum.midicps, 0.01);
	//freq = midinum.midicps;
	harmony2= WrapIndex.kr(diffbuf2.bufnum, midinum);
	harmony = WrapIndex.kr(diffbuf.bufnum, midinum);
	partials = [
		0.5,
		1,
		2,
		0.5*harmony,
		1*harmony,
		2*harmony,
		0.5*harmony2,
		1*harmony2,
		2*harmony2,
	];
	out = Mix.new(PitchShift.ar(in, 0.2, partials, 0, 0.001));
	out1 = Mix.new(PitchShift.ar(in, 0.2, partials*0.9, 0, 0.01));
	out2 = Mix.new(PitchShift.ar(in, 0.2, partials*0.8, 0, 0.001));
	out3 = Mix.new(PitchShift.ar(in, 0.2, partials*1.1, 0, 0.01));


	out1 = CombC.ar(out1,0.2,0.2,1.0);
	out2 = out2 + (SinOsc.ar(freq)*0.5);
	out3 =  AllpassL.ar(out3);
	rev = FreeVerb.ar(SelectX.ar(which,[out,out1,out2,out3])/partials.size);
	Out.ar(0,Pan2.ar(rev));
}).add;
)