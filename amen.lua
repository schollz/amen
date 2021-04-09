-- amen v0.0.1
-- make and break loops
--
-- llllllll.co/t/amen
--
--
--
--    ▼ instructions below ▼
--
-- MAKER MODE:
-- k1 enters performance mode
-- k2 starts/stops recording
-- k3 starts/stops playback
-- e1 zooms into loop start
-- e2 jogs loop window
-- e3 changes loop length
--
-- BREAKER MODE:
-- k1 enters sampler mode
-- k2 activates left effect
-- k3 activates right effect
-- e1 switches effects
-- e2/e3 changes effect prob
-- OR
-- e2 changes start (unquantized)
-- e3 changes end (quantized)
-- when stop/start is shown

amenbreaks=include("amen/lib/amen")
amengrid=include("amen/lib/amengrid")

local voice=1
local update_render=false
local update_breaker=false
local loaded_in_menu=false
local changed=false
local breaker=false
local shift=false
local beat_num=4
local recording=false
local recorded=false
local playing=false
local current_pos={0,0}
local last_pos=0
local loop_points={0,0}
local window={0,0}
local show_message=nil
local keyson={false,false}
local breaker_select=1
local breaker_options={
  {"stop","start"},
  {"scratch","loop"},
  {"reverse","jump"},
  {"slow","lpf"},
  {"stutter","strobe"},
  {"bitcrush",""},
}
local breaker_option_params={
  bitcrush="amen_bitcrush",
  vinyl="amen_vinyl",
  strobe="amen_strobe",
  scratch="amen_scratch",
  loop="amen_loop",
  reverse="amen_reverse",
  jump="amen_jump",
  slow="amen_tapestop",
  lpf="amen_lpf_effect",
  stutter="amen_stutter",
}
local breaker_option_controls={
  bitcrush={"amen_bitcrush_bits","amen_bitcrush_samplerate"},
}
-- WAVEFORMS
local waveform_samples={{}}
engine.name="Amen"

function init()
  amen=amenbreaks:new()
  ameng=amengrid:new({amen=amen})

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
    local maxval=0
    for i,v in ipairs(s) do
      if v>maxval then
        maxval=v
      end
    end
    for i,v in ipairs(s) do
      s[i]=s[i]/maxval
    end
    -- normalize to 1
    waveform_samples[ch]=s
  end)
  softcut.event_phase(function(i,x)
    -- print(i,x)
    current_pos[i]=x
  end)
  softcut.poll_start_phase()
  loop_points={clock.get_beat_sec()*1,clock.get_beat_sec()*(beat_num+4)}
  window={0,clock.get_beat_sec()*beat_num*2}
  zoom_inout(1)
  zoom_jog(0)

  -- start runner
  runner=metro.init()
  runner.time=1/30
  runner.count=-1
  runner.event=runner_f
  runner:start()

  -- first time: move the default amenbreak to the audio/amen folder and set as default
  if not util.file_exists(_path.audio.."amen/amenbreak_bpm136.wav") then
    os.execute("mkdir -p ".._path.audio.."amen")
    os.execute("cp ".._path.code.."amen/samples/amenbreak_bpm136.wav ".._path.audio.."amen/")
    params:set(voice.."amen_file",_path.audio.."amen/amenbreak_bpm136.wav")
  else
    default_load()
  end

  -- params:set(voice.."amen_file",_path.audio.."amen/loop59_bpm136.wav")
  -- params:set("1amen_file",_path.audio.."amen/amenbreak_bpm136.wav")
  -- params:set("2amen_file",_path.audio.."kolor/bank12/loop_n_hands_bpm120.wav")
  -- engine.amenvinyl(4)
end

function recording_start()
  if recording then
    do return end
  end
  print("recording_start")
  recording=true
  local s=math.min(window[1],loop_points[1])
  local e=math.max(window[2],loop_points[2])
  print("recording between",s,e)
  for i=1,2 do
    softcut.position(i,s)
    softcut.loop_start(i,s)
    softcut.loop_end(i,e)
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
    softcut.position(i,math.min(window[1],loop_points[1]))
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

function zoom_inout(zoom)
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
end

function zoom_jog(jog)
  loop_points[1]=util.clamp(loop_points[1]+jog/100*(window[2]-window[1]),0,120)
  loop_points[2]=loop_points[1]+clock.get_beat_sec()*beat_num
  if not recording then
    for i=1,2 do
      softcut.loop_start(i,loop_points[1])
      softcut.loop_end(i,loop_points[2])
    end
  end
  -- if loop_points[2]>window[2] then
  --   window[1]=window[1]+(loop_points[2]-window[2])
  --   window[2]=loop_points[2]
  --   for i=1,2 do
  --     softcut.render_buffer(i,window[1],window[2]-window[1],128)
  --   end
  -- end
  if loop_points[1]<window[1] then
    window[2]=window[2]+(loop_points[1]-window[1])
    window[1]=loop_points[1]
    for i=1,2 do
      softcut.render_buffer(i,window[1],window[2]-window[1],128)
    end
  end
end

function enc(k,d)
  if not breaker then
    if k==1 then
      local zoom=0.75
      if d<0 then
        zoom=1.5
      end
      zoom_inout(zoom)
    elseif k==2 then
      zoom_jog(d)
      if amen.voice[voice].sample~="" then
        changed=true
      end
    else
      beat_num=util.clamp(beat_num+sign(d),1,64)
      loop_points[2]=loop_points[1]+clock.get_beat_sec()*beat_num
      if loop_points[2]>window[2] then
        window[2]=loop_points[2]
        for i=1,2 do
          softcut.render_buffer(i,window[1],window[2]-window[1],128)
        end
      end
      if not recording then
        for i=1,2 do
          softcut.loop_start(i,loop_points[1])
          softcut.loop_end(i,loop_points[2])
        end
      end
      if amen.voice[1].sample~="" then
        changed=true
      end
    end
  else
    if k==1 then
      breaker_select=util.wrap(breaker_select+sign(d),1,#breaker_options)
    else
      dial_effect(k,d)
    end
  end
end

function dial_effect(k,d)
  local sel1=breaker_options[breaker_select][1]
  if sel1=="stop" then
    -- update the loop stop/start positions
    if k==2 then
      params:delta(voice.."amen_loopend",d)
    else
      params:delta(voice.."amen_loopend",d)
    end
  elseif breaker_option_controls[sel1]~=nil then
    -- this effect has breakout controls, update those
    params:delta(voice..breaker_option_controls[sel1][k-1],d)
  else
    -- update the probability percentage
    local sel=breaker_options[breaker_select][k-1]
    if breaker_option_params[sel]~=nil then
      params:delta(voice..breaker_option_params[sel].."_prob",d)
    end
  end
end

function key(k,z)
  if k>1 then
    keyson[k-1]=z==1
  end

  if k==1 and z==1 then
    breaker=not breaker
    update_breaker=true
  end
  if breaker then
    if k>1 then
      local sel=breaker_options[breaker_select][k-1]
      if sel=="reverse" then
        params:set(voice.."amen_reverse",z)
      elseif sel=="scratch" then
        params:set(voice.."amen_scratch",z)
      elseif sel=="slow" then
        params:set(voice.."amen_tapestop",z)
      elseif sel=="jump" and z==1 then
        params:set(voice.."amen_jump",1)
        params:set(voice.."amen_jump",0)
      elseif sel=="loop" then
        params:set(voice.."amen_loop",z)
      elseif sel=="start" and z==1 then
        params:set(voice.."amen_play",0)
        params:set(voice.."amen_play",1)
      elseif sel=="stop" and z==1 then
        params:set(voice.."amen_play",0)
      elseif sel=="lpf" then
        params:set(voice.."amen_lpf_effect",z)
      elseif sel=="stutter" then
        params:set(voice.."amen_stutter",z)
      elseif sel=="strobe" and z==1 then
        params:delta(voice.."amen_strobe",1)
      elseif sel=="bitcrush" and z==1 then
        params:delta(voice.."amen_bitcrush",1)
      elseif sel=="vinyl" and z==1 then
        params:delta(voice.."amen_vinyl",1)
      end
    end
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
  -- do rendering
  if update_render or recording then
    update_render=false
    for i=1,2 do
      softcut.render_buffer(i,window[1],window[2]-window[1],128)
    end
  end

  -- recording stops if it turns over
  if recording then
    if last_pos>current_pos[1] then
      recording_stop()
    end
    last_pos=current_pos[1]
  end

  -- switching voice or loading new sample
  if amen.voice_loaded>0 then
    voice=amen.voice_loaded
    amen.voice_loaded=0

    -- load the sample into softcut for visualization
    softcut.buffer_clear()
    softcut.buffer_read_stereo(amen.voice[voice].sample,0,0,amen.voice[voice].duration_loaded)
    local duration=amen.voice[voice].samples_loaded/48000
    window={0,duration}
    loop_points={0,duration}
    update_render=true

    if not breaker then
      breaker=true -- automatically go into breaker mode
      update_breaker=true
    end
    default_save()
  end

  if update_breaker then
    update_breaker=false
    if breaker then
      -- enter breaker mode
      breaker_select=1 --reset options on breaker
      if recorded or changed then
        transfer_loop_to_breaker()
        recorded=false
        changed=false
      end
    else
      params:set("1amen_play",0)
      params:set("2amen_play",0)
      -- if amen.voice[voice].sample~="" then
      --   params:set("clock_tempo",amen.voice[voice].bpm)
      -- end
    end
  end

  if breaker and amen.voice[voice].beats~=beat_num then
    beat_num=amen.voice[voice].beats
  end
  redraw()
end

function redraw()
  screen.clear()
  screen.level(15)
  metro_icon(-2,3)
  screen.move(12,8)
  if breaker then
    screen.text(math.floor(amen.voice[voice].beat+1).."/"..amen.voice[voice].beats)
    for i=1,2 do
      local keyon=keyson[i]
      local sel=breaker_options[breaker_select][i]
      if sel~="" then
        local p=breaker_option_params[sel]
        if p~=nil then
          keyon=params:get(voice..p)==1
        end
        x,y,w=box_text(70+41*(i-1),1,sel,keyon)
        if p~=nil then
          -- show prob in a line below the box
          screen.move(x,y+11)
          screen.line(x+w*params:get(voice..p.."_prob")/100,y+11)
          screen.stroke()
          screen.move(x,y+12)
          screen.line(x+w*params:get(voice..p.."_prob")/100,y+12)
          screen.stroke()
        end
        -- if it has controls, show them
        if breaker_option_controls[sel]~=nil then
          local s = params:get(voice..breaker_option_controls[sel][1])
          s = s.." / "..params:get(voice..breaker_option_controls[sel][2])
          box_text(70+41,1,s)
        end
      end
    end
  else
    screen.text(math.floor(clock.get_tempo()).."/"..beat_num.." beats")
    box_text(80,1,"rec",recording)
    box_text(105,1,"play",playing)
  end

  waveform_height=40
  waveform_center=38
  local lp={}
  lp[1]=util.round(util.linlin(window[1],window[2],1,128,loop_points[1]))
  lp[2]=util.round(util.linlin(window[1],window[2],1,128,loop_points[2]))
  if breaker then
    lp[1]=util.round(util.linlin(0,1,1,128,params:get(voice.."amen_loopstart")))
    lp[2]=util.round(util.linlin(0,1,1,128,params:get(voice.."amen_loopend")))
  end
  if loop_points[2]>window[2] then
    lp[2]=129
  end
  local pos=util.round(util.linlin(window[1],window[2],1,128,current_pos[1]))
  if breaker then
    pos=util.round(util.linlin(0,1,1,128,amen:current_pos(voice)))
  end
  if waveform_samples[1]~=nil and waveform_samples[2]~=nil then
    for j=1,2 do
      for i,s in ipairs(waveform_samples[j]) do
        local height=util.clamp(0,waveform_height,util.round(math.abs(s)*waveform_height))
        screen.level(13)
        if i<lp[1] or i>lp[2] then
          screen.level(4)
        end
        if math.abs(pos-i)<2 then
          if j==1 then
            screen.level(5)
            screen.move(i,14)
            screen.line(i,59)
            screen.stroke()
          end
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
      screen.level(15)
      screen.move(lp[i],12)
      screen.line_rel(0,80)
      screen.stroke()
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

function box_text(x,y,s,invert)
  screen.level(0)
  if invert==true then
    screen.level(15)
  end
  w=screen.text_extents(s)+7
  if s=="start" then
    w=w+1
  end
  screen.rect(x-w/2,y,w,10)
  screen.fill()
  screen.level(5)
  if invert==true then
    screen.level(0)
  end
  screen.rect(x-w/2,y,w,10)
  screen.stroke()
  screen.move(x,y+6)
  screen.text_center(s)
  if invert==true then
    screen.level(15)
  end
  return x-w/2,y,w
end

function metro_icon(x,y)
  screen.move(x+2,y+5)
  screen.line(x+7,y)
  screen.line(x+12,y+5)
  screen.line(x+3,y+5)
  screen.stroke()
  screen.move(x+7,y+3)
  screen.line(amen.metronome_tick and (x+4) or (x+10),y)
  screen.stroke()
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

function ls_loop_files()
  local current_max=0
  local num_files=0
  for _,fname in ipairs(list_files(_path.audio.."amen")) do
    num_files=num_files+1
    local loop_num=tonumber(string.match(fname,'loop(%d*)'))
    if loop_num~=nil and loop_num>current_max then
      current_max=loop_num
    end
  end
  current_max=current_max+1
  return current_max,num_files
end

function transfer_loop_to_breaker()
  if playing then
    playback_stop()
  elseif recording then
    recording_stop()
  end

  current_max,num_files=ls_loop_files()
  fname="loop"..current_max.."_bpm"..math.floor(clock.get_tempo())..".wav"
  print("saving loop between points "..loop_points[1].." and "..loop_points[2])
  softcut.buffer_write_stereo(_path.audio.."amen/"..fname,loop_points[1],loop_points[2]-loop_points[1])
  

  print_message(fname)

  -- give it some time to save
  local path_to_file=_path.audio.."amen/"..fname
  clock.run(function()
    clock.sleep(1)
    if loop_name~="" then
      params:set(voice.."amen_file",path_to_file)
    end
    recorded=false
  end)
end

function default_load()
  if util.file_exists(_path.data.."amen/last_file") then
    local f=io.open(_path.data.."amen/last_file","rb")
    local content=f:read("*all")
    f:close()
    print(content)
    if content~=nil and util.file_exists(content) then
      params:set(voice.."amen_file",content)
    end
  else
    params:set(voice.."amen_file",_path.audio.."amen/amenbreak_bpm136.wav")
  end
end

function default_save()
  f=io.open(_path.data.."amen/last_file","w")
  f:write(params:get(voice.."amen_file"))
  f:close()
end

