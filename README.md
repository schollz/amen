# amen

quantized loops with punch-in effects + sampler.

![image](https://user-images.githubusercontent.com/6550035/113587034-1c4f3580-95e3-11eb-9a6b-0274ccd91480.png)

for [my latest album](https://infinitedigits.bandcamp.com/album/be-the-light-be-the-void) I made a lot of breakbeats and some of those breakbeats were informed by norns scripts (like [abacus](https://llllllll.co/t/abacus/37871), [clcks](https://llllllll.co/t/clcks/), [glitchlets](https://llllllll.co/t/clcks/), and [beets](https://llllllll.co/t/beets-1-1-1/30069)). this latest script is a different take on those previous iterations by utilizing supercollider for loop splicing and softcut for recording. supercollider provides a really seamless loop slicing engine by even having crossfades when jumping in a loop to prevent pops (although no crossfading on a single loop turnover like in softcut) and it allows really easy plugging in effects.

## requirements

- norns


## documentation

there are two different modes - a "*maker*" mode for making loops and a "*breaker*" mode for playing loops back and adding effects. switch between the modes using k1. if you don't want to sample a loop you can use the parameters menu to load a loop (just make sure the loop you load has `bpmX` somewhere in the title so that the bpm can be correctly attributed).

### maker mode

maker mode is indicated by the "rec" and "play" buttons.

![breaker](https://user-images.githubusercontent.com/6550035/113587030-1bb69f00-95e3-11eb-92e7-37520fdd24c0.png)

in this mode you can sample new loops or edit the start/end points of a current loop.

- k1 switches to *breaker mode* 
- k2 starts/stops recording
- k3 starts/stops playback of loop
- e1 zooms into loop start
- e2 jogs loop window
- e3 changes loop length

_note:_ you can also enter *breaker mode* by loading a file via the parameters (`AMEN > load file`). make sure the file you load has `bpmX` in the name, where `X` is the bpm of the file.

### breaker mode

breaker mode is indicated by the "stop" and "start" buttons.

![breaker](https://user-images.githubusercontent.com/6550035/113587036-1c4f3580-95e3-11eb-8772-ab1ab995ed5e.png)


in this mode you can playback the current loop with all sorts of punch-in effects including:

- scratching
- looping / retrigger
- reverse
- jumps
- slow / tape stop
- low-pass filter
- stutter
- strobe / tremelo
- bitcrush
- vinyl / lofi

its pretty easy to add more effects (but to keep cpu usage low, they need to be not super intensive).

in the parameters menu you can also adjust probabilities of the effects for automatically activating.


- k1 switches to *maker mode*
- k2 activates left effect
- k3 activates right effect
- e1 switches effects
- e2/e3 changes effect probabilities
- OR
- e2 changes loop start (unquantized)
- e3 changes loop end (quantized)
- when stop/start is shown

**unquantized vs quantized loop lengths**: when you see "stop" and "start" you can change the loop lengths manually with e2 and e3. e2 changes the start position and e3 changes the end position. however, its important to note thatn when you change e2 you are making fine adjustments without quantizing and when you change e3 it will snap to the nearest beat. so if don't want to snap to a beat, set e2 last, or conversely if you do want to snap to a beat, use e3 after adjusting e2. the beat sync will still be quantized in both cases, but it can be interesting to have (or not have) a quantized loop length.

## download

`;install https://github.com/schollz/amen`

https://github.com/schollz/amen
