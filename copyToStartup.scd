
// Display the list of available audio devices:

"\n****************************************\
Available audio devices on this system: \n".postln;
ServerOptions.devices.postln;
"****************************************\n".postln;


// Select devices for audio input and output:

s = Server.local;
s.options.inDevice_("UMC204HD 192k");
s.options.outDevice_("UMC204HD 192k");
