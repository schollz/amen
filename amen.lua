-- amen v0.0.1
-- get that amen break.
--

-- amenbreaks=include("amen/lib/amen")

breaker=false
shift=false
beat_num=8
recording=false
recorded=false
playing=false
current_pos={0,0}
current_sc_pos=0
last_pos=0
loop_points={0,0}
window={0,0}
show_message=nil
-- WAVEFORMS
waveform_samples={{}}

function init()
  -- amen=amenbreaks:new()
  -- make folder
  os.execute("mkdir -p ".._path.audio.."amen")

  -- initiate softcut
  audio.level_adc_cut(1)
  audio.level_eng_cut(0)
  audio.level_tape_cut(1)
  softcut.reset()
  for i=1,2 do
    softcut.enable(i,1)
    softcut.pan(i,i*2-3)
    softcut.level_input_cut(i,i,1)
    softcut.play(i,0)
    softcut.rate(i,1)
    softcut.loop_start(i,0)
    softcut.loop_end(i,clock.get_beat_sec()*beat_num*2)
    softcut.loop(i,1)
    softcut.fade_time(i,0)
    softcut.rec_level(i,1)
    softcut.pre_level(i,0)
    softcut.rec(i,0)
    softcut.position(i,0)
    softcut.buffer(i,i)
    softcut.level(i,1)

    softcut.level_slew_time(i,0)
    softcut.pan_slew_time(i,0)
    softcut.rate_slew_time(i,0)
    softcut.recpre_slew_time(i,0)
    softcut.phase_quant(i,0.025)

    softcut.render_buffer(i,0,clock.get_beat_sec()*beat_num*2,128)
  end
  softcut.event_render(function(ch,start,i,s)
    local maxval = 0
    for i,v in ipairs(s) do
      if v > maxval then
        maxval = v 
      end
    end
    for i,v in ipairs(s) do
      s[i] = s[i]/maxval
    end
    -- normalize to 1
    waveform_samples[ch]=s
  end)
  softcut.event_phase(function(i,x)
    -- print(i,x)
    current_pos[i]=x
  end)
  softcut.poll_start_phase()
  loop_points={clock.get_beat_sec()*4,clock.get_beat_sec()*(beat_num+4)}
  window={0,clock.get_beat_sec()*beat_num*2}

  -- start runner
  runner=metro.init()
  runner.time=1/30
  runner.count=-1
  runner.event=runner_f
  runner:start()

  -- osc input
  osc.event=osc_in
end

function recording_start()
  if recording then
    do return end
  end
  print("recording_start")
  recording=true
  for i=1,2 do
    softcut.position(i,window[1])
    softcut.loop_start(i,window[1])
    softcut.loop_end(i,window[2]) -- TODO: calculate based on bpm
    softcut.rec_level(i,1)
    softcut.rec(i,1)
    softcut.play(i,0)
  end
  last_pos=-1
end

function recording_stop()
  if not recording then
    do return end
  end
  print("recording_stop")
  recording=false
  recorded=true
  for i=1,2 do
    softcut.position(i,window[1])
    softcut.rec_level(i,0)
    softcut.rec(i,0)
    softcut.play(i,0)
  end
end

function playback_start()
  if recording then
    do return end
  end
  print("playback_start")
  playing=true
  for i=1,2 do
    softcut.position(i,loop_points[1])
    softcut.loop_start(i,loop_points[1])
    softcut.loop_end(i,loop_points[2])
    softcut.play(i,1)
  end
end

function playback_stop()
  if not playing then
    do return end
  end
  print("playback_stop")
  playing=false
  for i=1,2 do
    softcut.position(i,0)
    softcut.play(i,0)
  end
end


function enc(k,d)
  if not breaker then
    if k==2 then
      local zoom=0.75
      if d<0 then
        zoom=1.5
      end
      local di=zoom*math.abs(loop_points[1]-window[1])
      local di2=zoom*math.abs(loop_points[1]-window[2])
      if di2>di then
        di=di2
      end
      window[1]=loop_points[1]-di
      window[1]=util.clamp(window[1],0,120)
      window[2]=loop_points[1]+di
      for i=1,2 do
        softcut.render_buffer(i,window[1],window[2]-window[1],128)
      end
    elseif k==3 then
      loop_points[1]=util.clamp(loop_points[1]+d/100*(window[2]-window[1]),0,120)
      loop_points[2]=loop_points[1]+clock.get_beat_sec()*beat_num
      for i=1,2 do
        softcut.loop_start(i,loop_points[1])
        softcut.loop_end(i,loop_points[2])
      end
    else
      beat_num=util.clamp(beat_num+sign(d),1,64)
      loop_points[2]=loop_points[1]+clock.get_beat_sec()*beat_num
      for i=1,2 do
        softcut.loop_start(i,loop_points[1])
        softcut.loop_end(i,loop_points[2])
      end
    end
  end
end

function key(k,z)
  if k==1 and z==1 then
    breaker = not breaker
    if breaker then 
      -- zoom in
      window[1]=loop_points[1]
      window[2]=loop_points[2]
      for i=1,2 do
        softcut.render_buffer(i,window[1],window[2]-window[1],128)
      end
      if playing then
        playback_stop()
      elseif recording then 
        recording_stop()
      end
      if recorded then
        save_loop()
      end
    end
  end
  if breaker then

  else
    if k==2 and z==1 then
      if not recording then
        recording_start()
      elseif recording then
        recording_stop()
      end
    elseif k==3 and z==1 then
      if recording then
        recording_stop()
      end
      if not playing then
        playback_start()
      else
        playback_stop()
      end
    end
  end
end

function runner_f(c) -- our grid redraw clock
  if recording then
    for i=1,2 do
      softcut.render_buffer(i,window[1],window[2]-window[1],128)
    end
    if last_pos>current_pos[1] then
      recording_stop()
    end
    last_pos=current_pos[1]
  end
  redraw()
end

function redraw()
  screen.clear()
  screen.level(15)
  screen.move(2,8)
  if breaker then
    screen.text("breaker")
  else
    if playing then
      screen.text("maker "..beat_num.." beat loop   [playing]")
    elseif recording then
      screen.text("maker "..beat_num.." beat loop [recording]")
    else
      screen.text("maker "..beat_num.." beat loop ")
    end
  end

  waveform_height=40
  waveform_center=38
  local lp={}
  lp[1]=util.round(util.linlin(window[1],window[2],1,128,loop_points[1]))
  lp[2]=util.round(util.linlin(window[1],window[2],1,128,loop_points[2]))
  local pos=util.round(util.linlin(window[1],window[2],1,128,current_pos[1]))
  if waveform_samples[1]~=nil and waveform_samples[2]~=nil then
    for j=1,2 do
      for i,s in ipairs(waveform_samples[j]) do
        local height=util.clamp(0,waveform_height,util.round(math.abs(s)*waveform_height))
        screen.level(10)
        if i<lp[1] or i>lp[2] then
          screen.level(5)
        end
        if math.abs(pos-i)<2 then
          screen.level(15)
        end
        screen.move(i,waveform_center)
        screen.line_rel(0,(j*2-3)*height/2)
        screen.stroke()
      end
    end
  end
  if not breaker then
    for i=1,2 do
      if lp[i]~=128 then
        screen.level(15)
        screen.move(lp[i],10)
        screen.line_rel(0,80)
        screen.stroke()
      end
    end
  end


  if show_message~=nil then
    screen.level(0)
    x=64
    y=28
    w=string.len(show_message)*6
    screen.rect(x-w/2,y,w,10)
    screen.fill()
    screen.level(15)
    screen.rect(x-w/2,y,w,10)
    screen.stroke()
    screen.move(x,y+7)
    screen.text_center(show_message)
  end
  screen.update()
end

function sign(x)
  if x>0 then
    return 1
  elseif x<0 then
    return-1
  else
    return 0
  end
end

function cleanup()
  softcut.reset()
end

function rerun()
  norns.script.load(norns.state.script)
end


function print_message(message)
  clock.run(function()
    show_message=message
    redraw()
    clock.sleep(2)
    show_message=nil
    redraw()
  end)
end


function osc_in(path,args,from)
  current_sc_pos=args[2]
end


function _list_files(d,files,recursive)
  -- list files in a flat table
  if d=="." or d=="./" then
    d=""
  end
  if d~="" and string.sub(d,-1)~="/" then
    d=d.."/"
  end
  folders={}
  if recursive then
    local cmd="ls -ad "..d.."*/ 2>/dev/null"
    local f=assert(io.popen(cmd,'r'))
    local out=assert(f:read('*a'))
    f:close()
    for s in out:gmatch("%S+") do
      if not (string.match(s,"ls: ") or s=="../" or s=="./") then
        files=_list_files(s,files,recursive)
      end
    end
  end
  do
    local cmd="ls -p "..d
    local f=assert(io.popen(cmd,'r'))
    local out=assert(f:read('*a'))
    f:close()
    for s in out:gmatch("%S+") do
      table.insert(files,d..s)
    end
  end
  return files
end

function list_files(d,recurisve)
  if recursive==nil then
    recursive=false
  end
  return _list_files(d,{},recursive)
end

function save_loop()
  local current_max=0
  for _, fname in ipairs(list_files(_path.audio.."amen")) do
    local loop_num=tonumber(string.match(fname,'loop(%d*)'))
    if loop_num>current_max then
      current_max=loop_num
    end
  end
  current_max = current_max + 1
  fname="loop"..current_max.."_bpm"..math.floor(clock.get_tempo())..".wav"
  softcut.buffer_write_stereo(_path.audio.."amen/"..fname,window[1],window[2]-window[1])
  print_message("loop: "..fname)  
end