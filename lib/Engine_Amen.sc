// Engine_Amen

// Inherit methods from CroneEngine
Engine_Amen : CroneEngine {

    // Amen specific v0.1.0
    var sampleBuffAmen;
    var playerAmen;
    var playerVinyl; 
    var sampleVinyl;
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

        sampleVinyl = Buffer.read(context.server, "/home/we/dust/code/amen/samples/vinyl2.wav"); 

        playerSwap = Array.fill(2, {arg i;
            0;
        });

        SynthDef("vinylSound",{
            | bufnum = 0,amp=0,hpf=800,lpf=4000,rate=1,rateSlew=4,scratch=0,bpm_target=120,t_trig=1|
            var snd,pos;
            amp = Lag.kr(amp,2);
            amp = amp * VarLag.kr(LFNoise0.kr(1).range(0.1,1),2,warp:\sine);
            rate = Lag.kr(rate,rateSlew);
            rate = (scratch<1*rate) + (scratch>0*LFTri.kr(bpm_target/60*2));
            pos = Phasor.ar(
                trig:t_trig,
                rate:BufRateScale.kr(bufnum)*rate,
                end:BufFrames.kr(bufnum),
            );
            snd=BufRd.ar(2,bufnum,pos,
                loop:1,
                interpolation:1
            );
            snd = HPF.ar(snd,hpf);
            snd = LPF.ar(snd,lpf);
            Out.ar(0,snd*amp);
        }).add;

        // two players per buffer (4 players total)
        (0..4).do({arg i; 
            SynthDef("playerAmen"++i,{ 
                arg bufnum, amp=0, t_trig=0,t_trigtime=0, amp_crossfade=0,
                sampleStart=0,sampleEnd=1,samplePos=0,
                rate=1,rateSlew=0,bpm_sample=1,bpm_target=1,
                bitcrush=0,bitcrush_bits=24,bitcrush_rate=44100,
                scratch=0,strobe=0,vinyl=0,
                timestretch=0,timestretchSlowDown=1,timestretchWindowBeats=1,
                pan=0,lpf=20000,lpflag=0,hpf=10,hpflag=0;
    
                // vars
                var snd,pos,timestretchPos,timestretchWindow;
                rate = Lag.kr(rate,rateSlew);
                rate = rate * bpm_target / bpm_sample;
                // scratch effect
                rate = (scratch<1*rate) + (scratch>0*LFTri.kr(bpm_target/60*2));

                pos = Phasor.ar(
                    trig:t_trig,
                    rate:BufRateScale.kr(bufnum)*rate,
                    start:((sampleStart*(rate>0))+(sampleEnd*(rate<0)))*BufFrames.kr(bufnum),
                    end:((sampleEnd*(rate>0))+(sampleStart*(rate<0)))*BufFrames.kr(bufnum),
                    resetPos:samplePos*BufFrames.kr(bufnum)
                );
                timestretchPos = Phasor.ar(
                    trig:t_trigtime,
                    rate:BufRateScale.kr(bufnum)*rate/timestretchSlowDown,
                    start:((sampleStart*(rate>0))+(sampleEnd*(rate<0)))*BufFrames.kr(bufnum),
                    end:((sampleEnd*(rate>0))+(sampleStart*(rate<0)))*BufFrames.kr(bufnum),
                    resetPos:pos
                );
                timestretchWindow = Phasor.ar(
                    trig:t_trig,
                    rate:BufRateScale.kr(bufnum)*rate,
                    start:timestretchPos,
                    end:timestretchPos+((60/bpm_target/timestretchWindowBeats)/BufDur.kr(bufnum)*BufFrames.kr(bufnum)),
                    resetPos:timestretchPos,
                );

                snd=BufRd.ar(2,bufnum,pos,
                    loop:1,
                    interpolation:1
                );
                timestretch=Lag.kr(timestretch,2);
                snd=((1-timestretch)*snd)+(timestretch*BufRd.ar(2,bufnum,
                    timestretchWindow,
                    loop:1,
                    interpolation:1
                ));

                snd = LPF.ar(snd,Lag.kr(lpf,lpflag));
                snd = HPF.ar(snd,Lag.kr(hpf,hpflag));
                // strobe
                snd = ((strobe<1)*snd)+((strobe>0)*snd*LFPulse.ar(60/bpm_target*16));
                // bitcrush
                bitcrush = VarLag.kr(bitcrush,1,warp:\cubed);
                snd = (snd*(1-bitcrush))+(bitcrush*Decimator.ar(snd,VarLag.kr(bitcrush_rate,1,warp:\cubed),VarLag.kr(bitcrush_bits,1,warp:\cubed)));

                // vinyl wow + compressor
                snd=(vinyl<1*snd)+(vinyl>0* Limiter.ar(Compander.ar(snd,snd,0.5,1.0,0.1,0.1,1,2),dur:0.0008));
                snd =(vinyl<1*snd)+(vinyl>0* DelayC.ar(snd,0.01,VarLag.kr(LFNoise0.kr(1),1,warp:\sine).range(0,0.01)));                
                
                // manual panning
                snd = Balance2.ar(snd[0],snd[1],
                    pan+SinOsc.kr(60/bpm_target*16,mul:strobe*0.5),
                    level:Lag.kr(amp,0.2)*Lag.kr(amp_crossfade,0.2)
                );

                SendTrig.kr(Impulse.kr(30),i,A2K.kr(((1-timestretch)*pos)+(timestretch*timestretchPos))/BufFrames.kr(bufnum)/BufRateScale.kr(bufnum));                        

                Out.ar(0,snd)
            }).add; 
        });


        osfun = OSCFunc({ 
            arg msg, time; 
                // [time, msg].postln;
            // voice "1" uses voices 0 and 2 in sc
            if (((msg[2]==0)&&(playerSwap[0]==0))||((msg[2]==2)&&(playerSwap[0]==1)), {
                NetAddr("127.0.0.1", 10111).sendMsg("poscheck",1,msg[3]);  
            },{});

            if (((msg[2]==1)&&(playerSwap[0]==0))||((msg[2]==3)&&(playerSwap[0]==1)), {
                NetAddr("127.0.0.1", 10111).sendMsg("poscheck",2,msg[3]);
            },{});

            // if ((msg[2]==2)*(playerSwap[0]==1), {
            //     NetAddr("127.0.0.1", 10111).sendMsg("poscheck",1,msg[3]);   //sendMsg works out the correct OSC message for you
            // },{});

            // NetAddr("127.0.0.1", 10111).sendMsg("poscheck",msg[2],msg[3]);   //sendMsg works out the correct OSC message for you
            // if (msg[2]==0, {
            //     NetAddr("127.0.0.1", 10111).sendMsg("amp_crossfade",1,playerSwap[0]+1);   //sendMsg works out the correct OSC message for you
            // },{});
            // if (msg[2]==1, {
            //     NetAddr("127.0.0.1", 10111).sendMsg("amp_crossfade",2,playerSwap[1]+1);   //sendMsg works out the correct OSC message for you
            // },{});
        },'/tr', context.server.addr);

        playerAmen = Array.fill(4,{arg i;
            Synth("playerAmen"++i, target:context.xg);
        });

        playerVinyl = Synth("vinylSound",[ \bufnum,sampleVinyl,\amp,0],target:context.xg);

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
            playerVinyl.set(
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
            playerVinyl.set(
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

        this.addCommand("amenhpf","iff", { arg msg;
            // lua is sending 1-index
            playerAmen[msg[1]-1].set(
                \hpf,msg[2],
                \hpflag,msg[3],
            );
            playerAmen[msg[1]+1].set(
                \hpf,msg[2],
                \hpflag,msg[3],
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

        this.addCommand("amenvinyl","if", { arg msg;
            // lua is sending 1-index
            playerAmen[msg[1]-1].set(
                \vinyl,msg[2],
            );
            playerAmen[msg[1]+1].set(
                \vinyl,msg[2],
            );
            playerVinyl.set(
                \amp,msg[2],
            );
        });

        this.addCommand("amenvinylrate","f", { arg msg;
            playerVinyl.set(
                \rate,msg[1],
            );
        });

        
        this.addCommand("amenbitcrush","ifff", { arg msg;
            // lua is sending 1-index
            playerAmen[msg[1]-1].set(
                \bitcrush,msg[2],
                \bitcrush_bits,msg[3],
                \bitcrush_rate,msg[4],
            );
            playerAmen[msg[1]+1].set(
                \bitcrush,msg[2],
                \bitcrush_bits,msg[3],
                \bitcrush_rate,msg[4],
            );
        });

        
        this.addCommand("amentimestretch","iffff", { arg msg;
            // lua is sending 1-index
            playerAmen[msg[1]-1].set(
                \t_trigtime,msg[2],
                \timestretch,msg[3],
                \timestretchSlowDown,msg[4],
                \timestretchWindowBeats,msg[5],
            );
            playerAmen[msg[1]+1].set(
                \t_trigtime,msg[2],
                \timestretch,msg[3],
                \timestretchSlowDown,msg[4],
                \timestretchWindowBeats,msg[5],
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
        playerVinyl.free;
        sampleVinyl.free;
        // ^ Amen specific
    }
}
