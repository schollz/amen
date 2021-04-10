# amen

sampler and mangler of loops.

![image](https://user-images.githubusercontent.com/6550035/113587034-1c4f3580-95e3-11eb-9a6b-0274ccd91480.png)

for [my latest album](https://infinitedigits.bandcamp.com/album/be-the-light-be-the-void) I made a lot of breakbeats and some of those breakbeats were informed by norns scripts (like [abacus](https://llllllll.co/t/abacus/37871), [clcks](https://llllllll.co/t/clcks/), [glitchlets](https://llllllll.co/t/clcks/), and [beets](https://llllllll.co/t/beets-1-1-1/30069)). this latest script is a different take on those previous iterations by utilizing supercollider for loop mangling and softcut for loop sampling. supercollider provides a mostly seamless loop slicing engine by allowing crossfades when jumping within loops (preventing pops/clicks) as well as easily allowing lots of effects.

another aim of this script is to make sure things are pretty much always "in sync" / "on beat". the loops are synced up with the norns internal tempo every loop (unless using an effect) and all the effects are queued up to occur on subdivided beats. loops loaded from disk are automatically re-pitched into the current tempo as long as their name contains `bpmX` where `X` is the original bpm of the file.

the name comes from [Gregory Coleman's performance in "Amen, Brother"](https://www.youtube.com/watch?v=5SaFTm2bcac), now a legendary sample used in all sorts of music but especially breakbeat type genres.


## requirements

- norns

## documentation

there are two different modes - a "*sampler mode*"" for making loops and a "*performance mode*" for playing loops back and punching-in effects. switch between the modes using k1. if you don't want to sample a loop you can use the parameters menu to load a loop (just make sure the loop you load has `bpmX` somewhere in the title so that the bpm can be correctly attributed). amen loads in *performance mode* by default.

### performance mode

performance mode is indicated by the "stop" and "start" buttons.

![performance](https://user-images.githubusercontent.com/6550035/113587036-1c4f3580-95e3-11eb-8772-ab1ab995ed5e.png)

you can enter *performance mode* either by pressing k1 while in *sampler mode*, or by loading a file via the parameters (`AMEN > load file`). make sure the file you load has `bpmX` in the name, where `X` is the bpm of the file so that the tempo is matched correctly.

**performance mode controls:**

- k1 switches to *sampler mode*
- k2 activates left effect
- k3 activates right effect
- e1 switches effects
- e2/e3 changes effect probabilities
- OR
- e2 changes loop start (unquantized)
- e3 changes loop end (quantized)
- when stop/start is shown


in this mode you can playback the current loop with all sorts of punch-in effects (its pretty easy to add more effects but to keep cpu usage low, they need to be not super intensive). you can also set the probabilities of these effects to occur automatically. effects stack. current effects:

- scratching
- looping / retrigger
- reverse
- jumps
- slow / tape stop
- low-pass filter
- high-pass filter
- stutter
- strobe / tremelo
- bitcrush
- vinyl / lofi
- timestretching

**unquantized vs quantized loop lengths**: when you see "stop" and "start" you can change the loop lengths manually with e2 and e3. e2 changes the start position and e3 changes the end position. however, its important to note that when you change e2 you are making fine adjustments without quantizing loop length. conversely, when you change e3 it will force the loop to now snap to the nearest beat. so if don't want to snap to a beat, set e2 last, or conversely if you do want to snap to a beat, use e3 after adjusting e2. the beat sync will still be quantized in both cases, but it can be interesting to have (or not have) a quantized loop length.

**startup**: startup will automatically load the last loop you were working with, but not any saved parameters. save/load PSETs normally to save your state.

### sampler mode

sampler mode is indicated by the "rec" and "play" buttons.

![performance](https://user-images.githubusercontent.com/6550035/113587030-1bb69f00-95e3-11eb-92e7-37520fdd24c0.png)

in this mode you can sample stereo audio to make new loops or edit the start/end points of a current loop from *performance mode*.

**sampler mode controls:**

- k1 switches to *performance mode* 
- k2 starts/stops recording
- k3 starts/stops playback of loop
- e1 zooms into loop start
- e2 jogs loop window
- e3 changes loop length

**sampling strategy**: this sampler has plenty of memory (~minutes) so its best to record more than you need and then fit the sample window to what you need after recording is over. to get started, first turn e1 to expand the recording space to a little more than you might need and then press k2 to start/stop recording. when done recording use e2 and e3 to clip just the sample you want to use (e1 is handy again here to zoom in on the beginning to get the right transients).



## download

`;install https://github.com/schollz/amen`

https://github.com/schollz/amen
