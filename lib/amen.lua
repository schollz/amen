local Formatters=require 'formatters'
local Amen={}

function Amen:new(args)
  local l=setmetatable({},{__index=Amen})
  local args=args==nil and {} or args
  l.debug = args.debug


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

  return l
end

function Amen:load(fname,slot)
  if slot==nil then 
    slot=1
  end
end



return Amen
