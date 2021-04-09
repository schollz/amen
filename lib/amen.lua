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
local TYPE_STROBE=8
local TYPE_VINYL=9
local TYPE_HPF=10

function Amen:new(args)
  local l=setmetatable({},{__index=Amen})
  local args=args==nil and {} or args
  l.debug=args.debug

  -- set engine

  l.voice={}
  for i=1,2 do
    l.voice[i]={
      loop_start=0,
      loop_end=1,
      sample="",
      bpm=60,
      beat=0,
      beats=0,
      beats_loaded=0,
      queue={},
      hard_reset=false,
      disable_reset=false,
      rate=1,
      split=false,
      spin=0,
      sc_pos=0,
      sc_active={1},
    }
  end
  l.voice_loaded=0

  l:setup_midi()
  l:setup_parameters()

  -- setup lattice
  l.metronome_tick=false
  l.bpm_current=0
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
  l.lattice:new_pattern{
    action=function(t)
      l.metronome_tick=not l.metronome_tick
    end,
    division=1/4
  }
  l.lattice:start()

  -- osc input
  osc.event=function(path,args,from)
    l.voice[args[1]].sc_pos=args[2]
    -- if path=="amp_crossfade" then
    --   l.voice[args[1]].sc_active=args[2]
    -- elseif path=="poscheck" then
    --   if args[1]==0 then
    --     l.voice[1].sc_pos[1]=args[2]
    --   elseif args[1]==1 then
    --     l.voice[2].sc_pos[1]=args[2]
    --   elseif args[1]==2 then
    --     l.voice[1].sc_pos[2]=args[2]
    --   elseif args[1]==3 then
    --     l.voice[2].sc_pos[2]=args[2]
    --   end
    --   tab.print(l.voice[1].sc_pos)
    --   print(l.voice[1].sc_active)
    -- end
  end


  return l
end

function Amen:current_pos(i)
  -- return self.voice[i].sc_pos[self.voice[i].sc_active]
  return self.voice[i].sc_pos
end

function Amen:setup_midi()
  local ending=".wav"
  -- initiate midi connections
  self.device={}
  self.device_list={"disabled"}
  for i,dev in pairs(midi.devices) do
    if dev.port~=nil then
      local name=string.lower(dev.name).." "..i
      table.insert(self.device_list,name)
      print("adding "..name.." to port "..dev.port)
      self.device[name]={
        name=name,
        port=dev.port,
        midi=midi.connect(dev.port),
      }
      self.device[name].midi.event=function(data)
        -- if name~=self.device_list[params:get("midi_transport")] then
        --   do return end
        -- end
        local msg=midi.to_msg(data)
        if msg.type=="clock" then do return end end
-- OP-1 fix for transport
        if msg.type=='start' or msg.type=='continue' then
          print(name.." starting clock")
          for i=1,2 do
            local fname=params:get(i.."amen_file")
            if fname:sub(-#ending)==ending then
              params:set(i.."amen_play",1)
            end
          end
        elseif msg.type=="stop" then
          for i=1,2 do
            local fname=params:get(i.."amen_file")
            if fname:sub(-#ending)==ending then
              params:set(i.."amen_play",0)
            end
          end
        end
      end
    end
  end
end

function Amen:setup_parameters()
  self.param_names={"amen_file","amen_play","amen_amp","amen_pan","amen_lpf","amen_hpf","amen_loopstart","amen_loopend","amen_loop","amen_loop_prob","amen_stutter","amen_stutter_prob","amen_jump","amen_jump_prob","amen_lpf_effect","amen_lpf_effect_prob","amen_hpf_effect","amen_hpf_effect_prob","amen_tapestop","amen_tapestop_prob","amen_scratch","amen_scratch_prob","amen_reverse","amen_reverse_prob","amen_strobe","amen_strobe_prob","amen_vinyl","amen_vinyl_prob","amen_bitcrush","amen_bitcrush_prob","amen_expandjump","amen_quantize_loopend","amen_loop_beats","amen_sync_per_loop","amen_bitcrush_bits","amen_bitcrush_samplerate","amen_timestretch","amen_timestretch_prob","amen_timestretch_slow","amen_timestretch_window"}
  local ending=".wav"
  -- add parameters

  params:add_group("AMEN",40*2+3)
  params:add {
    type='control',
    id="amen_crossfade",
    name="crossfade",
    controlspec=controlspec.new(0,1,'lin',0,0.5,'',0.01/1),
    action=function(v)
      params:set("1amen_amp",v)
      params:set("2amen_amp",1-v)
    end
  }
  params:add_separator("loop")
  params:add{type="number",id="amen_loop_num",name="loop #",min=1,max=2,default=1,action=function(v)
    for _,param_name in ipairs(self.param_names) do
      for i=1,2 do
        if i==v then
          params:show(i..param_name)
        else
          params:hide(i..param_name)
        end
      end
    end
    _menu.rebuild_params()
    local fname=params:get(v.."amen_file")
    if fname:sub(-#ending)==ending then
      self.voice_loaded=v
    end
  end}
  for i=1,2 do
    params:add_file(i.."amen_file","load file",_path.audio.."amen/")
    params:set_action(i.."amen_file",function(fname)
      if fname:sub(-#ending)~=ending then
        do return end
      end
      local ch,samples,samplerate=audio.file_info(fname)
      self.voice[i].bpm=tonumber(string.match(fname,'bpm(%d*)'))
      if self.voice[i].bpm==nil or self.voice[i].bpm<1 then
        self.voice[i].bpm=clock.get_tempo()
      end
      self.voice[i].duration=samples/samplerate
      self.voice[i].samples=samples
      self.voice[i].samplerate=samplerate
      self.voice[i].beats_loaded=util.round(self.voice[i].duration/(60/self.voice[i].bpm))
      self.voice[i].beats=self.voice[i].beats_loaded
      self.voice[i].duration_loaded=self.voice[i].beats*(60/self.voice[i].bpm)
      if self.voice[i].duration_loaded>self.voice[i].duration then
        self.voice[i].duration_loaded=self.voice[i].duration_loaded
      end
      self.voice[i].samples_loaded=util.round(self.voice[i].samplerate*self.voice[i].duration_loaded)
      if self.voice[i].samples_loaded>self.voice[i].samples then
        self.voice[i].samples_loaded=self.voice[i].samples
      end
      self.voice[i].sample=fname
      tab.print(self.voice[i])
      print("loaded "..fname..": "..self.voice[i].beats.." beats at "..self.voice[i].bpm.."bpm")
      engine.amenbpm(i,self.voice[i].bpm,self.bpm_current)
      engine.amenload(i,fname,self.voice[i].samples_loaded)
      engine.amenamp(i,params:get(i.."amen_amp"))
      params:set(i.."amen_play",0)
      self.voice_loaded=i -- trigger for loading images
      _menu.redraw()
    end)
    params:add{
      type='binary',
      name="play",
      id=i..'amen_play',
      behavior='toggle',
      action=function(v)
        print("amen_play "..v)
        if v==1 then
          engine.amenrate(i,1,0)
          self.lattice:hard_restart()
        else
          self:loop(i,params:get(i.."amen_loopstart"))
          engine.amenrate(i,0,1/30)
        end
      end
    }
    params:add{type="number",id=i.."amen_sync_per_loop",name="sync per loop",min=1,max=16,default=1}
    params:add {
      type='control',
      id=i.."amen_amp",
      name="amp",
      controlspec=controlspec.new(0,10,'lin',0,1.0,'amp',0.01/10),
      action=function(v)
        print("amenamp "..v)
        engine.amenamp(i,v)
      end
    }
    params:add {
      type='control',
      id=i.."amen_pan",
      name="pan",
      controlspec=controlspec.new(-1,1,'lin',0,0),
      action=function(v)
        engine.amenpan(i,v)
      end
    }
    params:add {
      type='control',
      id=i..'amen_lpf',
      name='low-pass filter',
      controlspec=controlspec.new(20,20000,'exp',0,20000,'Hz'),
      formatter=Formatters.format_freq,
      action=function(v)
        engine.amenlpf(i,v,0)
      end
    }
    params:add {
      type='control',
      id=i..'amen_hpf',
      name='high-pass filter',
      controlspec=controlspec.new(20,20000,'exp',0,20,'Hz'),
      formatter=Formatters.format_freq,
      action=function(v)
        engine.amenhpf(i,v,0.5)
      end
    }
    self.debounce_loopstart=nil
    params:add {
      type='control',
      id=i..'amen_loopstart',
      name='loop start',
      controlspec=controlspec.new(0,1,'lin',0,0,'',1/32),
      action=function(v)
        print(i.."amen_loopstart "..v)
        if self.debounce_loopstart~=nil then
          clock.cancel(self.debounce_loopstart)
        end
        self.debounce_loopstart=clock.run(function()
          clock.sync(1)
          engine.amenloopnt(i,params:get(i.."amen_loopstart"),params:get(i.."amen_loopstart"),params:get(i.."amen_loopend"))
        end)
      end
    }
    self.debounce_loopend=nil
    params:add {
      type='control',
      id=i..'amen_loopend',
      name='loop end',
      controlspec=controlspec.new(0,1,'lin',0,1.0,'',1/32),
      action=function(v)
        print(i.."amen_loopend "..v)
        if self.debounce_loopend~=nil then
          clock.cancel(self.debounce_loopend)
        end
        self.debounce_loopend=clock.run(function()
          clock.sync(1)
          self.voice[i].beats=util.round(self.voice[i].beats_loaded*(v-params:get(i.."amen_loopstart")))
          if self.voice[i].beats<1 then
            self.voice[i].beats=1
          end
          if params:get(i.."amen_quantize_loopend")==2 then
            params:set(i.."amen_loopend",params:get(i.."amen_loopstart")+self.voice[i].beats/self.voice[i].beats_loaded,true)
          end
          engine.amenloopnt(i,params:get(i.."amen_loopstart"),params:get(i.."amen_loopstart"),params:get(i.."amen_loopend"))
        end)
      end
    }
    self.debounce_loopend=nil
    params:add_option(i.."amen_quantize_loopend","quantize loopend",{"no","yes"},1)

    -- effects
    params:add{
      type='binary',
      name="loop",
      id=i..'amen_loop',
      behavior='momentary',
      action=function(v)
        print(i.."amen_loop "..v)
        if v==1 then
          local pos=self:current_pos(i)
          local s=pos-(params:get(i.."amen_loop_beats")*clock.get_beat_sec())/self.voice[i].duration_loaded
          if s<0 then
            s=s+params:get(i.."amen_loopend")
          end
          local e=pos+0.001
          engine.amenloopnt(i,s,s,e)
          -- self:effect_loop(i,s,e)
          self.voice[i].disable_reset=true
        else
          engine.amenloopnt(i,params:get(i.."amen_loopstart"),params:get(i.."amen_loopstart"),params:get(i.."amen_loopend"))
          self.voice[i].hard_reset=true
          self.voice[i].disable_reset=false
        end
      end
    }
    params:add {
      type='control',
      id=i..'amen_loop_beats',
      name='loop beats',
      controlspec=controlspec.new(0.125,8,'lin',0,2,'beats',0.125/(8-0.125)),
    }
    params:add {
      type='control',
      id=i..'amen_loop_prob',
      name='loop prob',
      controlspec=controlspec.new(0,100,'lin',0,0,'%',1/100),
    }
    params:add{
      type='binary',
      name="stutter",
      id=i..'amen_stutter',
      behavior='momentary',
      action=function(v)
        print(i.."amen_stutter "..v)
        if v==1 then
          local s=self:current_pos(i)
          local e=s+math.random(30,100)/self.voice[i].duration_loaded/1000
          print("stutter",s,e)
          self:effect_loop(i,s,e)
        else
          self.voice[i].hard_reset=true
        end
      end
    }
    params:add {
      type='control',
      id=i..'amen_stutter_prob',
      name='stutter prob',
      controlspec=controlspec.new(0,100,'lin',0,0,'%',1/100),
    }
    params:add{
      type='binary',
      name="jump",
      id=i..'amen_jump',
      behavior='trigger',
      action=function(v)
        if v==1 then
          print(i.."amen_jump "..v)
          self:effect_jump(i,math.random(1,16)/16)
        end
      end
    }
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
      end
    }
    params:add {
      type='control',
      id=i..'amen_lpf_effect_prob',
      name='lpf prob',
      controlspec=controlspec.new(0,100,'lin',0,0,'%',1/100),
    }
    params:add{
      type='binary',
      name="hpf effect",
      id=i..'amen_hpf_effect',
      behavior='momentary',
      action=function(v)
        print("amen_hpf_effect "..v)
        if v==1 then
          self:effect_filterup(i,6000,4)
        else
          self:effect_filterup(i,params:get(i.."amen_hpf"),4)
        end
      end
    }
    params:add {
      type='control',
      id=i..'amen_hpf_effect_prob',
      name='hpf prob',
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
          self.voice[i].hard_reset=true
          self:effect_tapestop(i,true)
        end
      end
    }
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
          self:effect_scratch(i,math.random(30,60)/10)
        else
          self.voice[i].disable_reset=false
          self.voice[i].hard_reset=true
          self:effect_scratch(i,0)
        end
      end
    }
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
      end
    }
    params:add {
      type='control',
      id=i..'amen_reverse_prob',
      name='reverse prob',
      controlspec=controlspec.new(0,100,'lin',0,0,'%',1/100),
    }
    params:add{
      type='binary',
      name="strobe",
      id=i..'amen_strobe',
      behavior='toggle',
      action=function(v)
        print("amen_strobe "..v)
        if v==1 then
          self:effect_strobe(i,1)
        else
          self:effect_strobe(i,0)
        end
      end
    }
    params:add {
      type='control',
      name='strobe prob',
      id=i..'amen_strobe_prob',
      controlspec=controlspec.new(0,100,'lin',0,0,'%',1/100),
    }
    params:add{
      type='binary',
      name="vinyl",
      id=i..'amen_vinyl',
      behavior='toggle',
      action=function(v)
        print("amen_vinyl "..v)
        if v==1 then
          self:effect_vinyl(i,1)
        else
          self:effect_vinyl(i,0)
        end
      end
    }
    params:add {
      type='control',
      name='vinyl prob',
      id=i..'amen_vinyl_prob',
      controlspec=controlspec.new(0,100,'lin',0,0,'%',1/100),
    }
    params:add{
      type='binary',
      name="bitcrush",
      id=i..'amen_bitcrush',
      behavior='toggle',
      action=function(v)
        print("amen_bitcrush "..v)
        if v==1 then
          self:effect_bitcrush(i,1)
        else
          self:effect_bitcrush(i,0)
        end
      end
    }
    params:add {
      type='control',
      name='bitcrush bits',
      id=i..'amen_bitcrush_bits',
      controlspec=controlspec.new(6,24,'lin',0,12,'bits',1/(24-6)),
      action=function(v)
        self:bitcrush()
      end
    }
    params:add {
      type='control',
      name='bitcrush samplerate',
      id=i..'amen_bitcrush_samplerate',
      controlspec=controlspec.new(20,20000,'exp',0,4000,'Hz'),
      formatter=Formatters.format_freq,
      action=function(v)
        self:bitcrush()
      end
    }
    params:add {
      type='control',
      name='bitcrush prob',
      id=i..'amen_bitcrush_prob',
      controlspec=controlspec.new(0,100,'lin',0,0,'%',1/100),
    }
    params:add{
      type='binary',
      name="timestretch",
      id=i..'amen_timestretch',
      behavior='toggle',
      action=function(v)
        self:timestretch()
      end
    }
    params:add {
      type='control',
      name='timestretch slow',
      id=i..'amen_timestretch_slow',
      controlspec=controlspec.new(1,16,'lin',0,2,'x',0.25/(16-1)),
      action=function(v)
        self:timestretch()
      end
    }
    params:add {
      type='control',
      name='timestretch window',
      id=i..'amen_timestretch_window',
      controlspec=controlspec.new(0.125,16,'lin',0,2,'beats',0.125/(16-0.125)),
      action=function(v)
        self:timestretch()
      end
    }
    params:add {
      type='control',
      name='timestretch prob',
      id=i..'amen_timestretch_prob',
      controlspec=controlspec.new(0,100,'lin',0,0,'%',1/100),
    }
    params:add{
      type='control',
      name='expand/jump',
      id=i..'amen_expandjump',
      controlspec=controlspec.new(0,1,'lin',0,0,'%',0.001/1),
      action=function(v)
        -- if outside the loop, then set the loop
        -- if inside the loop then jump
        if v<params:get(i.."amen_loopstart") then
          params:set(i.."amen_loopstart",v)
        elseif v>params:get(i.."amen_loopend") then
          params:set(i.."amen_loopend",v)
        else
          -- self:effect_jump(i,v)
          self:loop(i,v)
        end
      end
    }
  end

  for _,param_name in ipairs(self.param_names) do
    for i=1,2 do
      if i==1 then
        params:show(i..param_name)
      else
        params:hide(i..param_name)
      end
    end
  end

end

function Amen:bitcrush()
  engine.amenbitcrush(i,
    params:get(i.."amen_bitcrush"),
    params:get(i.."amen_bitcrush_bits"),
    params:get(i.."amen_bitcrush_samplerate"),
  )
end

function Amen:timestretch()
  engine.amenbitcrush(i,
    params:get(i.."amen_timestretch"),
    params:get(i.."amen_timestretch_slow"),
    params:get(i.."amen_timestretch_window"),
  )
end

function Amen:loop(i,pos,s,e)
  engine.amenloop(i,pos,s or params:get(i.."amen_loopstart"),e or params:get(i.."amen_loopend"))
  clock.run(function()
    clock.sleep(0.1)
    engine.amenloopnt(i,s or params:get(i.."amen_loopstart"),s or params:get(i.."amen_loopstart"),e or params:get(i.."amen_loopend"))
  end)
end

function Amen:emit_note(division,t)
  -- keep the sample one beat
  for i=1,2 do
    if params:get(i.."amen_play")==1 and self.voice[i].sample~="" and not self.voice[i].disable_reset then
      print(t/32%(self.voice[i].beats*2))
      self.voice[i].beat=t/32%(self.voice[i].beats*2)/2
      local loopPos=self.voice[i].beat/self.voice[i].beats_loaded
      -- self:loop(i,t/32%(self.voice[i].beats*2)/(self.voice[i].beats*2))
      if self.voice[i].hard_reset==true then
        self.voice[i].hard_reset=false
        self:loop(i,loopPos)
      end
      -- add option to sync every X loops (==0 is one whole loop)
      if t/32%math.ceil(self.voice[i].beats_loaded*2/params:get(i.."amen_sync_per_loop"))==0 then
        -- reset to get back in sync
        print("syncing loop")
	self:loop(i,loopPos)
        --engine.amenreset(i)
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
        print("dequeing",i,q[1])
        self:process_queue(i,q)
      end
    end
  end

  -- enqueue effects randomly
  for i=1,2 do
    if params:get(i.."amen_play")==1 then
      if params:get(i.."amen_loop_prob")/100/8>math.random() then
        params:set(i.."amen_loop",1)
        clock.run(function()
          clock.sleep(math.random(50,400)/100)
          params:set(i.."amen_loop",0)
        end)
      end
      if params:get(i.."amen_jump_prob")/100/8>math.random() then
        params:set(i.."amen_jump",1)
        params:set(i.."amen_jump",0)
      end
      if params:get(i.."amen_lpf_effect_prob")/100/8>math.random() then
        params:set(i.."amen_lpf_effect",1)
        clock.run(function()
          clock.sleep(math.random(100,200)/100)
          params:set(i.."amen_lpf_effect",0)
        end)
      end
      if params:get(i.."amen_tapestop_prob")/100/8>math.random() then
        params:set(i.."amen_tapestop",1)
        clock.run(function()
          clock.sleep(math.random(0,7)/10)
          params:set(i.."amen_tapestop",0)
        end)
      end
      if params:get(i.."amen_scratch_prob")/100/8>math.random() then
        params:set(i.."amen_scratch",1)
        clock.run(function()
          clock.sleep(math.random(0,30)/10)
          params:set(i.."amen_scratch",0)
        end)
      end
      if params:get(i.."amen_reverse_prob")/100/8>math.random() then
        params:set(i.."amen_reverse",1)
        clock.run(function()
          clock.sleep(math.random(0,30)/10)
          params:set(i.."amen_reverse",0)
        end)
      end
      if params:get(i.."amen_strobe_prob")/100/8>math.random() then
        params:set(i.."amen_strobe",1)
        clock.run(function()
          clock.sleep(math.random(0,30)/10)
          params:set(i.."amen_strobe",0)
        end)
      end
      if params:get(i.."amen_stutter_prob")/100/8>math.random() then
        params:set(i.."amen_stutter",1)
        clock.run(function()
          clock.sleep(math.random(100,500)/1000)
          params:set(i.."amen_stutter",0)
        end)
      end
      if params:get(i.."amen_vinyl_prob")/100/8>math.random() then
        params:set(i.."amen_vinyl",1)
        clock.run(function()
          clock.sleep(math.random(1000,5000)/1000)
          params:set(i.."amen_vinyl",0)
        end)
      end
      if params:get(i.."amen_bitcrush_prob")/100/8>math.random() then
        params:set(i.."amen_bitcrush",1)
        clock.run(function()
          clock.sleep(math.random(100,3000)/1000)
          params:set(i.."amen_bitcrush",0)
        end)
      end
      if params:get(i.."amen_timestretch_prob")/100/8>math.random() then
        params:set(i.."amen_timestretch",1)
        clock.run(function()
          clock.sleep(math.random(100,3000)/1000)
          params:set(i.."amen_timestretch",0)
        end)
      end
    end
  end
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
    self:loop(i,q[2])
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
  elseif q[1]==TYPE_LOOP then
    if q[5]~=nil then
      engine.amenloop(i,q[5],q[2],q[3])
    else
      engine.amenloop(i,q[2],q[2],q[3])
    end
    if q[4]~=nil and q[4]>0 then
      clock.run(function()
        clock.sync(q[4])
        print("reseting loop")
        self:loop(i,params:get(i.."amen_loopstart"))
      end)
    end
  elseif q[1]==TYPE_FILTERDOWN then
    print(i.." TYPE_FILTERDOWN")
    engine.amenlpf(i,q[2],2)
  elseif q[1]==TYPE_HPF then
    print(i.." TYPE_HPF")
    engine.amenhpf(i,q[2],2)
  elseif q[1]==TYPE_STROBE then
    print(i.." TYPE_STROBE "..q[2])
    engine.amenstrobe(i,q[2])
  elseif q[1]==TYPE_VINYL then
    print("TYPE_VINYL "..q[2])
    engine.amenvinyl(i,q[2])
    if q[2]==1 then
      engine.amenlpf(i,6000,2)
      engine.amenhpf(i,600,2)
      engine.amenamp(i,0.5*params:get(i.."amen_amp"))
    else
      engine.amenlpf(i,params:get(i.."amen_lpf"),2)
      engine.amenhpf(i,params:get(i.."amen_hpf"),2)
      engine.amenamp(i,params:get(i.."amen_amp"))
    end
  elseif q[1]==TYPE_BITCRUSH then
    print("TYPE_BITCRUSH "..q[2])
    if q[2]==1 then
      self:bitcrush()
    else
      engine.amenbitcrush(i,0,24,20000)
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
  local rate=0
  if on then
    rate=self.voice[i].rate
  end
  table.insert(self.voice[i].queue,{TYPE_TAPESTOP,rate,duration})
end

function Amen:effect_rate(i,val,duration)
  table.insert(self.voice[i].queue,{TYPE_RATE,val,duration})
end

function Amen:effect_loop(i,loopStart,loopEnd,duration,newstart)
  table.insert(self.voice[i].queue,{TYPE_LOOP,loopStart,loopEnd,duration,newstart})
end

function Amen:effect_filterdown(i,fc,duration)
  table.insert(self.voice[i].queue,{TYPE_FILTERDOWN,fc,duration})
end

function Amen:effect_filterup(i,fc,duration)
  table.insert(self.voice[i].queue,{TYPE_HPF,fc,duration})
end

function Amen:effect_split(i,on)
  table.insert(self.voice[i].queue,{TYPE_SPLIT,on})
end

function Amen:effect_strobe(i,v)
  table.insert(self.voice[i].queue,{TYPE_STROBE,v})
end

function Amen:effect_vinyl(i,v)
  table.insert(self.voice[i].queue,{TYPE_VINYL,v})
end

function Amen:effect_bitcrush(i,v)
  table.insert(self.voice[i].queue,{TYPE_BITCRUSH,v})
end




return Amen





