// Engine_Amen

// Inherit methods from CroneEngine
Engine_Amen : CroneEngine {

    // Amen specific v0.0.1
    var sampleBuffAmen;
    var playerAmen;
    var playerSwap;
    var osfun;
    // Amen ^

    *new { arg context, doneCallback;
        ^super.new(context, doneCallback);
    }

    alloc {
        // Amen specific v0.0.1
        sampleBuffAmen = Array.fill(2, { arg i; 
            Buffer.new(context.server);
        });

        playerSwap = Array.fill(2, {arg i;
            0;
        });

        // two players per buffer (4 players total)
        (0..5).do({arg i; 
            SynthDef("playerAmen"++i,{ 
                arg bufnum, amp=0, t_trig=0, amp_crossfade=0,
                sampleStart=0,sampleEnd=1,samplePos=0,
                rate=1,rateSlew=0,bpm_sample=1,bpm_target=1,
                scratch=0,strobe=0,
                pan=0,lpf=20000,lpflag=0,hpf=10;
    
                // vars
                var snd,pos;
                rate = Lag.kr(rate,rateSlew);
                rate = ((scratch>0)*LFTri.kr(scratch)+(scratch<1)*rate);
                rate = rate * bpm_target / bpm_sample;
                pos = Phasor.ar(
                    trig:t_trig,
                    rate:BufRateScale.kr(bufnum)*rate,
                    start:((sampleStart*(rate>0))+(sampleEnd*(rate<0)))*BufFrames.kr(bufnum),
                    end:((sampleEnd*(rate>0))+(sampleStart*(rate<0)))*BufFrames.kr(bufnum),
                    resetPos:samplePos*BufFrames.kr(bufnum)
                );
                snd=BufRd.ar(2,bufnum,pos,
                    loop:1,
                    interpolation:1
                );
                snd = LPF.ar(snd,Lag.kr(lpf,lpflag));
                snd = HPF.ar(snd,hpf);
                snd = ((strobe<1)*snd)+((strobe>0)*snd*LFPulse.ar(60/bpm_target*16));
                snd = Balance2.ar(snd[0],snd[1],
                    pan+SinOsc.kr(60/bpm_target*16,mul:strobe*0.5),
                    level:amp*Lag.kr(amp_crossfade,0.2)
                );

                if (i.mod(2)==0, {                    
                    SendTrig.kr(Impulse.kr(30),amp_crossfade,A2K.kr(pos)/BufFrames.kr(bufnum)/BufRateScale.kr(bufnum));                        
                },{});

                Out.ar(0,snd)
            }).add; 
        });

        osfun = OSCFunc({ 
            arg msg, time; 
                // [time, msg].postln;
            if (msg[2]>0, {
                NetAddr("127.0.0.1", 10111).sendMsg("poscheck",time,msg[3]);   //sendMsg works out the correct OSC message for you
            },{})
        },'/tr', context.server.addr);

        playerAmen = Array.fill(4,{arg i;
            Synth("playerAmen"++i, target:context.xg);
        });

        this.addCommand("amenrelease","", { arg msg;
            (0..2).do({arg i; 
                sampleBuffAmen[i].free;
                playerAmen[i].set(\amp,0);
                playerAmen[i+2].set(\amp,0);
            });
        });

        this.addCommand("amenload","isi", { arg msg;
            // lua is sending 1-index
            sampleBuffAmen[msg[1]-1].free;
            postln("loading "++msg[3]++" samples of "++msg[2]);
            sampleBuffAmen[msg[1]-1] = Buffer.read(context.server,msg[2],
                numFrames:msg[3]
            );
            playerAmen[msg[1]-1].set(
                \bufnum,sampleBuffAmen[msg[1]-1],
                \rate,0,
                \amp_crossfade,1,
            );
            playerAmen[msg[1]+1].set(
                \bufnum,sampleBuffAmen[msg[1]-1],
                \rate,0,
                \amp_crossfade,0,
                // \amp,0,
            );
        });

        this.addCommand("amenamp","if", { arg msg;
            // lua is sending 1-index
            playerAmen[msg[1]-1].set(
                \amp,msg[2],
            );
            playerAmen[msg[1]+1].set(
                \amp,msg[2],  
            );
        });

        this.addCommand("amenbpm","iff", { arg msg;
            // lua is sending 1-index
            playerAmen[msg[1]-1].set(
                \bpm_sample,msg[2],
                \bpm_target,msg[3],
            );
            playerAmen[msg[1]+1].set(
                \bpm_sample,msg[2],
                \bpm_target,msg[3],
            );
        });

        this.addCommand("amenrate","iff", { arg msg;
            // lua is sending 1-index
            playerAmen[msg[1]-1].set(
                \rate,msg[2],
                \rateSlew,msg[3],
            );
            playerAmen[msg[1]+1].set(
                \rate,msg[2],
                \rateSlew,msg[3],
            );
        });

        this.addCommand("amenloop","ifff", { arg msg;
            // lua is sending 1-index
            playerSwap[msg[1]-1]=1-playerSwap[msg[1]-1];
            playerAmen[msg[1]-1].set(
                \t_trig,playerSwap[msg[1]-1]==0,
                \samplePos,msg[2],
                \sampleStart,msg[3],
                \sampleEnd,msg[4],
                \amp_crossfade,playerSwap[msg[1]-1]==0,
            );
            playerAmen[msg[1]+1].set(
                \t_trig,playerSwap[msg[1]-1]==1,
                \samplePos,msg[2],
                \sampleStart,msg[3],
                \sampleEnd,msg[4],
                \amp_crossfade,playerSwap[msg[1]-1]==1,
            );
        });

        this.addCommand("amenloopnt","ifff", { arg msg;
            // lua is sending 1-index
            playerAmen[msg[1]-1].set(
                \samplePos,msg[2],
                \sampleStart,msg[3],
                \sampleEnd,msg[4],
            );
            playerAmen[msg[1]+1].set(
                \samplePos,msg[2],
                \sampleStart,msg[3],
                \sampleEnd,msg[4],
            );
        });


        this.addCommand("amenreset","i", { arg msg;
            // lua is sending 1-index
            playerAmen[msg[1]-1].set(
                \t_trig,1,
            );
            playerAmen[msg[1]+1].set(
                \t_trig,1,
            );
        });

        this.addCommand("amenreset1","if", { arg msg;
            // lua is sending 1-index
            playerAmen[msg[1]-1].set(
                \t_trig,msg[2]>0,
            );
        });

        this.addCommand("amenscratch","if", { arg msg;
            // lua is sending 1-index
            playerAmen[msg[1]-1].set(
                \scratch,msg[2],
            );
            playerAmen[msg[1]+1].set(
                \scratch,msg[2],
            );
        });

        this.addCommand("amenoff","i", { arg msg;
            // lua is sending 1-index
            playerAmen[msg[1]-1].set(
                \amp,0,
            );
            playerAmen[msg[1]+1].set(
                \amp,0,
            );
        });

        this.addCommand("amenlpf","iff", { arg msg;
            // lua is sending 1-index
            playerAmen[msg[1]-1].set(
                \lpf,msg[2],
                \lpflag,msg[3],
            );
            playerAmen[msg[1]+1].set(
                \lpf,msg[2],
                \lpflag,msg[3],
            );
        });

        this.addCommand("amenhpf","if", { arg msg;
            // lua is sending 1-index
            playerAmen[msg[1]-1].set(
                \hpf,msg[2],
            );
            playerAmen[msg[1]+1].set(
                \hpf,msg[2],
            );
        });

        this.addCommand("amenpan","if", { arg msg;
            // lua is sending 1-index
            playerAmen[msg[1]-1].set(
                \pan,msg[2],
            );
            playerAmen[msg[1]+1].set(
                \pan,msg[2],
            );
        });

        this.addCommand("amenstrobe","if", { arg msg;
            // lua is sending 1-index
            playerAmen[msg[1]-1].set(
                \strobe,msg[2],
            );
            playerAmen[msg[1]+1].set(
                \strobe,msg[2],
            );
        });

        // ^ Amen specific

    }

    free {
        // Amen Specific v0.0.1
        (0..2).do({arg i; sampleBuffAmen[i].free});
        (0..5).do({arg i; playerAmen[i].free});
        osfun.free;
        (0..2).do({arg i; playerSwap[i].free});
        // ^ Amen specific
    }
}
