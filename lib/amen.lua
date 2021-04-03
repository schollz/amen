local Formatters=require 'formatters'
local lattice=require 'lattice'
local Amen={}

local TYPE_SCRATCH=1
local TYPE_RATE=2
local TYPE_JUMP=3
local TYPE_TAPESTOP=4
local TYPE_SPLIT=5

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


  l:load(1,_path.audio.."amen/loop2_bpm120.wav")
  return l
end

function Amen:setup_parameters()
  -- add parameters
  params:add_group("AMEN",12*2)
  for i=1,2 do
    params:add_separator("loop "..i)
    params:add_file(i.."amen_file","load file",_path.audio.."amen/")
    params:set_action(i.."amen_file",function(v)
      self:load(i,v)
    end)
    params:add {
      type='control',
      id=i.."amen_amp",
      name="amp",
      controlspec=controlspec.new(0,10,'lin',0,1.0,'amp',0.01/10),
      action=function(v)
        engine.amenamp(i,v)
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
        engine.amenlpf(i,v)
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
          self:effect_scratch(i,3)
        else
          self.voice[i].disable_reset=false
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
  end
end

function Amen:emit_note(division,t)
  for i=1,2 do
    if self.voice[i].sample~="" and not self.voice[i].disable_reset then
      if t/32%(self.voice[i].beats*2) == 0 then
        -- randomly reset to get back in sync
        print("reseting")
        engine.amenreset(i)
      end
    end
  end

  -- register changes in the bpm
  if self.bpm_current~=clock.get_tempo() then
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
        -- do for the other voice too if split
        if self.voice[i].split then
          self.process_queue(i+2,q)
        end
      end
    end
  end
  -- enqueue effects randomly
  -- TODO
end

function Amen:process_queue(i,q)
  if q[1]==TYPE_SCRATCH then
    engine.amenscratch(i,q[2])
  elseif q[1]==TYPE_JUMP then
    engine.amenjump(i,q[2])
  elseif q[1]==TYPE_RATE then
    self.voice[i].rate=q[2]
    engine.amenrate(i,q[2],0)
  elseif q[1]==TYPE_TAPESTOP then
    engine.amenrate(i,q[2],clock.get_beat_sec()*8)
  elseif q[1]==TYPE_SPLIT and i<3 then
    -- split only works on first one
    engine.amenpan(i,0.5)
    engine.amenpan(i+2,-0.5)
    self.voice[i].split=true
  end
end

function Amen:effect_scratch(i,val)
  table.insert(self.voice[i].queue,{TYPE_SCRATCH,val})
end

function Amen:effect_jump(i,val)
  table.insert(self.voice[i].queue,{TYPE_JUMP,val})
end

function Amen:effect_tapestop(i,on)
  local rate = 0
  if on then
    rate = self.voice[i].rate
  end
  table.insert(self.voice[i].queue,{TYPE_TAPESTOP,rate})
end

function Amen:effect_rate(i,val)
  table.insert(self.voice[i].queue,{TYPE_RATE,val})
end

function Amen:load(i,fname)
  local ch,samples,samplerate=audio.file_info(fname)
  local duration=samples/samplerate
  print(duration)
  self.voice[i].bpm=tonumber(string.match(fname,'bpm(%d*)'))
  if self.voice[i].bpm==nil or self.voice[i].bpm<1 then
    self.voice[i].bpm=clock.get_tempo()
  end
  self.voice[i].beats=math.floor(util.round(duration/(60/self.voice[i].bpm)))
  self.voice[i].sample=fname
  print("loaded "..fname..": "..self.voice[i].beats.." beats at "..self.voice[i].bpm.."bpm")
  engine.amenbpm(i,self.voice[i].bpm,self.bpm_current)
  engine.amenload(i,fname)
  engine.amenamp(i,0.5)
end



return Amen
