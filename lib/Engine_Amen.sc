// Engine_Amen

// Inherit methods from CroneEngine
Engine_Amen : CroneEngine {

	// Amen specific
	var sampleBuffAmen;
	var samplerPlayerAmen;
	// Amen ^

	// recorder specific
	var sampleBuffRecorder;
	var synthRecorder;
	// recorder ^

	*new { arg context, doneCallback;
		^super.new(context, doneCallback);
	}

	alloc {
	
		// recorder specific
		sampleBuffRecorder = Array.fill(2, { arg i;
			Buffer.alloc(context.server,48000*0.03,1);
		});

	    synthRecorder = { arg delay=0.03, volume=0.0;
	      var input = SoundIn.ar([0, 1]);
	      BufDelayC.ar([bufnum1,bufnum2], input, delayTime:0.03, mul:volume)
	    }.play(context.server);

	    this.addCommand("recorder_amp", "f", { arg msg; synthRecorder.set(\volume, msg[1]);});
		// recorder ^

		// Amen specific
		sampleBuffAmen = Array.fill(2, { arg i; 
			Buffer.new(context.server);
		});

		// two players per buffer (4 players total)
		(0..5).do({arg i; 
			SynthDef("playerAmen"++i,{ 
				arg bufnum, amp=0, t_trig=0,
				sampleStart=0,sampleEnd=1,
				rate=1,rateSlew=0,bpm_current=1,bpm_target=1,
				spin=0,
				pan=0,lpf=20000,hpf=10;
	
				// vars
				var snd;
				rate = Lag.kr(rate,rateSlew);
				rate = ((spin>0)*LFTri.kr(spin)+(spin<1)*rate);
				rate = rate * bpm_target / bpm_current;
				snd=BufRd.ar(2,bufnum,
					Phasor.ar(
						trig:t_trig,
						rate:BufRateScale.kr(bufnum)*rate,
						start:((sampleStart*(rate>0))+(sampleEnd*(rate<0)))*BufFrames.kr(bufnum),
						end:((sampleEnd*(rate>0))+(sampleStart*(rate<0)))*BufFrames.kr(bufnum),
						resetPos:((sampleStart*(rate>0))+(sampleEnd*(rate<0)))*BufFrames.kr(bufnum)
					)
					loop:1,
					interpolation:1
				);
		        snd = LPF.ar(snd,lpf);
		        snd = HPF.ar(snd,hpf);
		        snd = Balance2.ar(in[0],in[1],pan);
				Out.ar(0,snd)
			}).add;	
		});

		samplerPlayerAmen = Array.fill(2,{arg i;
			Synth("player"++i, target:context.xg);
		});

		this.addCommand("amenrelease","", { arg msg;
			(0..199).do({arg i; sampleBuffAmen[i].free});
		});
		this.addCommand("amenload","is", { arg msg;
			// lua is sending 1-index
			sampleBuffAmen[msg[1]-1].free;
			sampleBuffAmen[msg[1]-1] = Buffer.read(context.server,msg[2]);
		});

		this.addCommand("amenamp","if", { arg msg;
			// lua is sending 1-index
			samplerPlayerAmen[msg[1]-1].set(
				\amp,msg[2],
			);
		});

		this.addCommand("amenrate","iff", { arg msg;
			// lua is sending 1-index
			samplerPlayerAmen[msg[1]-1].set(
				\rate,msg[2],
				\rateSlew,msg[3],
			);
		});

		this.addCommand("amenloop","iff", { arg msg;
			// lua is sending 1-index
			samplerPlayerAmen[msg[1]-1].set(
				\t_trig,1,
				\sampleStart,msg[2],
				\sampleEnd,msg[2],
			);
		});

		this.addCommand("amenspin","if", { arg msg;
			// lua is sending 1-index
			samplerPlayerAmen[msg[1]-1].set(
				\spin,msg[2],
			);
		});

		this.addCommand("amenoff","i", { arg msg;
			// lua is sending 1-index
			samplerPlayerAmen[msg[1]-1].set(
				\amp,0,
			);
		});

		this.addCommand("amenlpf","i", { arg msg;
			// lua is sending 1-index
			samplerPlayerAmen[msg[1]-1].set(
				\lpf,msg[2],
			);
		});

		this.addCommand("amenhpf","i", { arg msg;
			// lua is sending 1-index
			samplerPlayerAmen[msg[1]-1].set(
				\hpf,msg[2],
			);
		});

		this.addCommand("amenpan","i", { arg msg;
			// lua is sending 1-index
			samplerPlayerAmen[msg[1]-1].set(
				\pan,msg[2],
			);
		});

		// ^ Amen specific

	}

	free {
		// Amen Specific
		(0..2).do({arg i; sampleBuffAmen[i].free});
		(0..5).do({arg i; samplerPlayerAmen[i].free});
		// ^ Amen specific

		// recorder specific
		(0..2).do({arg i; sampleBuffRecorder[i].free});
		synthRecorder.free;
		// recorder ^
	}
}