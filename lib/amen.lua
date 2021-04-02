local Formatters=require 'formatters'
local Amen={}

local TYPE_SPIN=1
local TYPE_RATE=2
local TYPE_JUMP=3
local TYPE_TAPESTOP=4
local TYPE_SPLIT=5

function Amen:new(args)
  local l=setmetatable({},{__index=Amen})
  local args=args==nil and {} or args
  l.debug=args.debug

  l.voice={}
  for i=1,2 do
    l.voice[i]={
      sample="",
      bpm=60,
      queue={},
      split=false,
      spin=0,
    }
  end


  -- add parameters
  params:add_group("AMEN",4)
  params:add {
    type='control',
    id="amen_amp",
    name="amp",
  controlspec=controlspec.new(0,10,'lin',0,1.0,'amp')}
  params:add {
    type='control',
    id="amen_pan",
    name="pan",
  controlspec=controlspec.new(-1,1,'lin',0,0)}
  params:add {
    type='control',
    id='amen_lpf',
    name='low-pass filter',
    controlspec=controlspec.new(20,20000,'exp',0,20000,'Hz'),
    formatter=Formatters.format_freq
  }
  params:add {
    type='control',
    id='amen_hpf',
    name='high-pass filter',
    controlspec=controlspec.new(20,20000,'exp',0,20,'Hz'),
    formatter=Formatters.format_freq
  }

  -- setup lattice
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
  l.lattice:start()

  return l
end

function Amen:emit_note(division,t)
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
  if q[1]==TYPE_SPIN then
    engine.amenspin(i,q[2])
  elseif q[1]==TYPE_JUMP then
    engine.amenjump(i,q[2])
  elseif q[1]==TYPE_RATE then
    engine.amenrate(i,-1,0)
  elseif q[1]==TYPE_TAPESTOP then
    engine.amenrate(i,0,clock.get_beat_sec()*4)
  elseif q[1]==TYPE_SPLIT and i<3 then
    -- split only works on first one
    engine.amenpan(i,0.5)
    engine.amenpan(i+2,-0.5)
    self.voice[i].split=true
  end
end

function Amen:spin(i,val)
  table.insert(self.voice[i].queue,{TYPE_SPIN,val})
end

function Amen:jump(i,val)
  table.insert(self.voice[i].queue,{TYPE_JUMP,val})
end

function Amen:tape_stop(i,val)
  table.insert(self.voice[i].queue,{TYPE_TAPESTOP,nil})
end

function Amen:rate(i,val)
  table.insert(self.voice[i].queue,{TYPE_RATE,val})
end

function Amen:load(i,fname)
  if slot==nil then
    slot=1
  end

  engine.amenload(i,fname)
  self.voice[i].bpm=tonumber(string.match(filename,'bpm(%d*)'))
  if self.voice[i].bpm==nil or self.voice[i].bpm<1 then
    self.voice[i].bpm=clock.get_tempo()
  end
  self.voice[i].sample=fname
  engine.amenbpm(i,self.voice[i].bpm,self.bpm_current)
end



return Amen
