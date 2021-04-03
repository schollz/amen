local Formatters=require 'formatters'
local lattice=require 'lattice'
local Amen={}

local TYPE_SCRATCH=1
local TYPE_RATE=2
local TYPE_JUMP=3
local TYPE_TAPESTOP=4
local TYPE_SPLIT=5
local TYPE_LOOP=6
local TYPE_FILTERDOWN=7

function Amen:new(args)
  local l=setmetatable({},{__index=Amen})
  local args=args==nil and {} or args
  l.debug=args.debug

  -- set engine

  l.voice={}
  for i=1,2 do
    l.voice[i]={
      sample="",
      bpm=60,
      beats=0,
      queue={},
      disable_reset=false,
      rate=1,
      split=false,
      spin=0,
    }
  end

  l:setup_parameters()

  -- setup lattice
  l.bpm_current=0
  l.pulse=0
  l.lattice=lattice:new({
    ppqn=64
  })
  l.timers={}
  l.divisions={16}
  for _,division in ipairs(l.divisions) do
    l.timers[division]={}
    l.timers[division].lattice=l.lattice:new_pattern{
      action=function(t)
        l:emit_note(division,t)
      end,
    division=1/(division/2)}
  end
  l.lattice:start()

  
  return l
end

function Amen:setup_parameters()
  -- add parameters
  params:add_group("AMEN",17*2)
  for i=1,2 do
    params:add_separator("loop "..i)
    params:add_file(i.."amen_file","load file",_path.audio.."amen/")
    params:set_action(i.."amen_file",function(fname)
        local ch,samples,samplerate=audio.file_info(fname)
        self.voice[i].duration=samples/samplerate
        self.voice[i].bpm=tonumber(string.match(fname,'bpm(%d*)'))
        if self.voice[i].bpm==nil or self.voice[i].bpm<1 then
          self.voice[i].bpm=clock.get_tempo()
        end
        self.voice[i].beats=math.floor(util.round(self.voice[i].duration/(60/self.voice[i].bpm)))
        self.voice[i].sample=fname
        print("loaded "..fname..": "..self.voice[i].beats.." beats at "..self.voice[i].bpm.."bpm")
        engine.amenbpm(i,self.voice[i].bpm,self.bpm_current)
        engine.amenload(i,fname)
        self.lattice:hard_restart()
        engine.amenamp(i,params:get(i.."amen_amp"))
    end)
    params:add{
      type='binary',
      name="play",
      id=i..'amen_play',
      behavior='toggle',
      action=function(v)
        print("amen_play "..v)
        if v==1 then
          self:effect_rate(i,1)
          amen.lattice:hard_restart()
        else
          self:effect_rate(i,0)
        end
    end} 
    params:add {
      type='control',
      id=i.."amen_amp",
      name="amp",
      controlspec=controlspec.new(0,10,'lin',0,0.5,'amp',0.01/10),
      action=function(v)
        print("amenamp "..v)
        if self.voice[i].split then 
          engine.amenamp(i,v/2)
          engine.amenamp(i+2,v/2)
        else
          engine.amenamp(i,v)
          engine.amenamp(i+2,0)
        end
    end}
    params:add {
      type='control',
      id=i.."amen_pan",
      name="pan",
      controlspec=controlspec.new(-1,1,'lin',0,0),
      action=function(v)
        engine.amenpan(i,v)
      end}
    params:add {
      type='control',
      id=i..'amen_lpf',
      name='low-pass filter',
      controlspec=controlspec.new(20,20000,'exp',0,20000,'Hz'),
      formatter=Formatters.format_freq,
      action=function(v)
        engine.amenlpf(i,v,0)
      end}
    params:add {
      type='control',
      id=i..'amen_hpf',
      name='high-pass filter',
      controlspec=controlspec.new(20,20000,'exp',0,20,'Hz'),
      formatter=Formatters.format_freq,
      action=function(v)
        engine.amenhpf(i,v)
      end}
        self.debounce_loopstart=nil
    params:add {
      type='control',
      id=i..'amen_loopstart',
      name='loop start',
      controlspec=controlspec.new(0,1,'lin',0,0,'',1/32),
      action=function(v)
        print(i.."amen_loopstart "..v)
        if self.debounce_loopstart ~= nil then 
          clock.cancel(self.debounce_loopstart)
        end
        self.debounce_loopstart=clock.run(function()
          clock.sleep(0.5)
          engine.amenloop(i,params:get(i.."amen_loopstart"),params:get(i.."amen_loopend"))
        end)
    end}
    self.debounce_loopend=nil
    params:add {
      type='control',
      id=i..'amen_loopend',
      name='loop end',
      controlspec=controlspec.new(0,1,'lin',0,1.0,'',1/32),
      action=function(v)
        print(i.."amen_loopend "..v)
        if self.debounce_loopend ~= nil then 
          clock.cancel(self.debounce_loopend)
        end
        self.debounce_loopend=clock.run(function()
          clock.sleep(0.5)
          engine.amenloop(i,params:get(i.."amen_loopstart"),params:get(i.."amen_loopend"))
        end)
    end}

    -- effects
    params:add{
      type='binary',
      name="loop",
      id=i..'amen_loop',
      behavior='momentary',
      action=function(v)
        print(i.."amen_loop "..v)
        if v==1 then
          local s = math.random(params:get(i.."amen_loopstart")*1000,params:get(i.."amen_loopend")*1000-125)
          local e = math.random(s,params:get(i.."amen_loopend")*1000)
          amen:effect_loop(i,s/1000,e/1000)
        else
          amen:effect_loop(i,params:get(i.."amen_loopstart"),params:get(i.."amen_loopend"))
        end
    end} 
    params:add {
      type='control',
      id=i..'amen_loop_prob',
      name='jump prob',
      controlspec=controlspec.new(0,100,'lin',0,0,'%',1/100),
    }
    params:add{
      type='binary',
      name="loop",
      id=i..'amen_jump',
      behavior='trigger',
      action=function(v)
        print(i.."amen_jump "..v)
        self:effect_jump(i,math.random(1,16)/16)
    end} 
    params:add {
      type='control',
      id=i..'amen_jump_prob',
      name='jump prob',
      controlspec=controlspec.new(0,100,'lin',0,0,'%',1/100),
    }
    params:add{
      type='binary',
      name="lpf effect",
      id=i..'amen_lpf_effect',
      behavior='momentary',
      action=function(v)
        print("amen_lpf_effect "..v)
        if v==1 then
          self:effect_filterdown(i,100)
        else
          self:effect_filterdown(i,params:get(i.."amen_lpf"))
        end
    end} 
    params:add {
      type='control',
      id=i..'amen_lpf_prob',
      name='lpf prob',
      controlspec=controlspec.new(0,100,'lin',0,0,'%',1/100),
    }
      params:add{
      type='binary',
      name="tape stop",
      id=i..'amen_tapestop',
      behavior='momentary',
      action=function(v)
        print("amen_tapestop "..v)
        if v==1 then
          self.voice[i].disable_reset=true
          self:effect_tapestop(i,false)
        else
          self.voice[i].disable_reset=false
          self:effect_tapestop(i,true)
        end
    end} 
    params:add {
      type='control',
      id=i..'amen_tapestop_prob',
      name='tape stop prob',
      controlspec=controlspec.new(0,100,'lin',0,0,'%',1/100),
    }
    params:add{
      type='binary',
      name="scratch",
      id=i..'amen_scratch',
      behavior='momentary',
      action=function(v)
        print("amen_scratch "..v)
        if v==1 then
          self.voice[i].disable_reset=true
          self:effect_scratch(i,3)
        else
          self.voice[i].disable_reset=false
          self:effect_scratch(i,0)
        end
    end} 
    params:add {
      type='control',
      id=i..'amen_scratch_prob',
      name='scratch prob',
      controlspec=controlspec.new(0,100,'lin',0,0,'%',1/100),
    }
    params:add{
      type='binary',
      name="reverse",
      id=i..'amen_reverse',
      behavior='toggle',
      action=function(v)
        print("amen_reverse "..v)
        if v==1 then
          self:effect_rate(i,-1)
        else
          self:effect_rate(i,1)
        end
    end} 
    params:add {
      type='control',
      id=i..'amen_reverse_prob',
      name='reverse prob',
      controlspec=controlspec.new(0,100,'lin',0,0,'%',1/100),
    }
  end
end

function Amen:emit_note(division,t)
  -- keep the sample one beat
  for i=1,2 do
    if self.voice[i].sample~="" and not self.voice[i].disable_reset then
      if t/32%(self.voice[i].beats*2) == 0 then
        -- reset to get back in sync
        engine.amenreset(i)
        if self.voice[i].split then 
          engine.amenreset(i+2)
        end
      end
    end
  end

  -- register changes in the bpm
  if self.bpm_current~=clock.get_tempo() then
    print("updating tempo "..self.bpm_current.."->"..clock.get_tempo())
    self.bpm_current=clock.get_tempo()
    for i=1,2 do
      if self.voice[i].sample~="" then
        engine.amenbpm(i,self.voice[i].bpm,self.bpm_current)
        engine.amenbpm(i+2,self.voice[i].bpm,self.bpm_current)
      end
    end
  end
  -- dequeue effects
  for i=1,2 do
    if self.voice[i].sample~="" then
      if #self.voice[i].queue>0 then
        local q=table.remove(self.voice[i].queue,1)
        self:process_queue(i,q)
      end
    end
  end
  -- enqueue effects randomly
  -- TODO
end

function Amen:process_queue(i,q)
  if q[1]==TYPE_SCRATCH then
    engine.amenscratch(i,q[2])
    if q[3]~=nil then
      clock.run(function()
        clock.sync(q[3])
        engine.amenscratch(i,0)
      end)
    end
  elseif q[1]==TYPE_JUMP then
    engine.amenjump(i,q[2])
  elseif q[1]==TYPE_RATE then
    local original_rate=self.voice[i].rate
    self.voice[i].rate=q[2]
    engine.amenrate(i,q[2],0)
    if q[3]~=nil then
      clock.run(function()
        clock.sync(q[3])
        engine.amenrate(i,original_rate,0)
        self.voice[i].rate=original_rate
      end)
    end
  elseif q[1]==TYPE_TAPESTOP then
    engine.amenrate(i,q[2],2)
    if q[3]~=nil then
      clock.run(function()
        clock.sync(q[3])
        engine.amenrate(i,self.voice[i].rate,4)
      end)
    end
  elseif q[1]==TYPE_SPLIT and i==1 or i==2 then
    -- split only works on first one
    if q[2] then
      engine.amenpan(i,0.5)
      engine.amenpan(i+2,-0.5)
      self.voice[i].split=true
    else
      engine.amenpan(i,0)
      self.voice[i].split=false
    end
    if self.voice[i].split then 
      engine.amenamp(i,params:get(i.."amen_amp")/2)
      engine.amenamp(i+2,params:get(i.."amen_amp")/2)
    else
      engine.amenamp(i,params:get(i.."amen_amp"))
      engine.amenamp(i+2,0)
    end
  elseif q[1]==TYPE_LOOP then
    engine.amenloop(i,q[2],q[3])
    if q[4]~=nil and q[4]>0 then
      clock.run(function()
        clock.sync(q[4])
        print("reseting loop")
        engine.amenloop(i,params:get(i.."amen_loopstart"),params:get(i.."amen_loopend"))
      end)
    end  
  elseif q[1]==TYPE_FILTERDOWN then
    if q[3] then
      engine.amenlpf(i,q[2],2)
    else
      engine.amenlpf(i,params:get(i.."amen_lpf"),2)
    end    
  end
end

function Amen:effect_scratch(i,val,duration)
  table.insert(self.voice[i].queue,{TYPE_SCRATCH,val,duration})
end

function Amen:effect_jump(i,val)
  table.insert(self.voice[i].queue,{TYPE_JUMP,val})
end

function Amen:effect_tapestop(i,on,duration)
  local rate = 0
  if on then
    rate = self.voice[i].rate
  end
  table.insert(self.voice[i].queue,{TYPE_TAPESTOP,rate,duration})
end

function Amen:effect_rate(i,val,duration)
  table.insert(self.voice[i].queue,{TYPE_RATE,val,duration})
end

function Amen:effect_loop(i,loopStart,loopEnd,duration)
  table.insert(self.voice[i].queue,{TYPE_LOOP,loopStart,loopEnd,duration})
end

function Amen:effect_filterdown(i,fc,duration)
  table.insert(self.voice[i].queue,{TYPE_FILTERDOWN,fc,duration})
end

function Amen:effect_split(i,on)
  table.insert(self.voice[i].queue,{TYPE_SPLIT,on})
end


return Amen
