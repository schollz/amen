-- amen v0.0.1
-- get that amen break.
--

local UI=require "ui"
amenbreaks=include("amen/lib/amen")

engine.name="Amen"

primed=false
recording=false

function init()
  amen=amenbreaks:new()

  -- initiate softcut
  softcut.reset()
  for i=1,2 do
    softcut.level(i,1)
    softcut.rec_level(i,1)
    softcut.pre_level(i,0)
    softcut.buffer(i,i)
    softcut.pan(i,util.linlin(1,2,-1,1,i))
    softcut.loop(i,1)
    softcut.loop_start(i,0)
    softcut.loop_end(i,60) -- TODO: calculate based on bpm
    softcut.rec(i,0)
    softcut.enable(i,1)

    softcut.level_slew_time(i,0)
    softcut.rate_slew_time(i,0)
    softcut.recpre_slew_time(i,0)
    softcut.level_eng_cut(1)
    softcut.level_adc_cut(0)
    softcut.level_tape_cut(0)

    softcut.post_filter_dry(i,0.0)
    softcut.post_filter_lp(i,1.0)
    softcut.post_filter_rq(i,1.0)
    softcut.post_filter_fc(i,20100)

    softcut.pre_filter_dry(i,1.0)
    softcut.pre_filter_lp(i,1.0)
    softcut.pre_filter_rq(i,1.0)
    softcut.pre_filter_fc(i,20100)
  end
  for i=3,6 do
    softcut.enable(i,0)
  end

  -- initate recording on incoming audio
  polls={"amp_in_l","amp_in_r"}
  polling={}
  for i,p in ipairs(polls) do
    polling[i]=poll.set(p)
    polling[i].time=1
    polling[i].callback=function(val)
      if val>8/10000 and primed then
        recording_start()
      end
    end
    polling[i].start()
  end

  clock.run(redraw_clock)
end

function recording_start()
  if not primed or recording then
    do return end
  end
  primed=false
  polling[1].time=1
  polling[2].time=1
  recording=true
  engine.recorder_amp(1)
  audio.level_monitor(0)
end

function recording_arm()
  if recording or primed then
    do return end
  end
  primed=true
  polling[1].time=0.02
  polling[2].time=0.02
  engine.recorder_amp(0)
  audio.level_monitor(1)
end


function recording_stop()
  if not recording then
    do return end
  end
  recording=false
  audio.level_eng_cut(0)
end

function enc(k,d)

end

function key(k,z)
end

function redraw_clock() -- our grid redraw clock
  while true do -- while it's running...
    clock.sleep(1/30) -- refresh
    redraw()
  end
end

function redraw()
  screen.clear()

  screen.update()
end

function cleanup()
  softcut.reset()
end

function rerun()
  norns.script.load(norns.state.script)
end
