local pattern_time = require("pattern")
local AmenGrid={}


function AmenGrid:new(args)
  local m=setmetatable({},{__index=AmenGrid})
  local args=args==nil and {} or args
  m.amen=args.amen -- A REQUIRED ARG
  m.grid_on=args.grid_on==nil and true or args.grid_on

  -- initiate the grid
  m.g=grid.connect()
  m.g.key=function(x,y,z)
    if m.grid_on then
      m:grid_key(x,y,z)
    end
  end
  print("grid columns: "..m.g.cols)

  -- setup visual
  m.visual={}
  for i=1,8 do
    m.visual[i]={}
    for j=1,m.grid_width do
      m.visual[i][j]=0
    end
  end

  -- keep track of pressed buttons
  m.pressed_buttons={}

  -- grid refreshing
  m.grid_refresh=metro.init()
  m.grid_refresh.time=0.1
  m.grid_refresh.event=function()
    if m.grid_on then
      m:grid_redraw()
    end
  end
  m.grid_refresh:start()

  return m
end


function AmenGrid:grid_key(x,y,z)
  self:key_press(y,x,z==1)
  self:grid_redraw()
end

function AmenGrid:key_press(row,col,on)
  if on then
    self.pressed_buttons[row..","..col]=self:current_time()
  else
    self.pressed_buttons[row..","..col]=nil
  end

  if row<7 and on then
    -- change position
    self:expandjump(row,col)
  end
end

function AmenGrid:expandjump(row,col)
  local voice=1
  if col > 8 then 
    voice = 2
    col = col - 8
  end

  local val1=nil
  local val2=nil
  for k,_ in pairs(self.pressed_buttons) do
    row,col=k:match("(%d+),(%d+)")    
    local val =  ((row-1)*8+(col-1))/47
    if voice==2 then 
      val = ((row-1)*8+(col-9))/47
    end
    if voice==1 and row<7 and col<9 then
      if val1==nil then 
        val1=val
      else
        val2=val
      end
    elseif voice==2 and row<7 and col>8 then
      if val1==nil then 
        val1=val
      else
        val2=val
      end
    end
  end
  if val2 ~= nil and val2<val1 then 
    local val = val1
    val1=val2
    val2=val
  end
  if val2 ~= nil then 
    params:set(voice.."amen_loopstart",val1)
    params:set(voice.."amen_loopend",val2)
  else
    params:set(voice.."amen_expandjump",val1)
  end
end

function AmenGrid:get_visual()
  -- clear visual
  for row=1,8 do
    for col=1,self.grid_width do
      self.visual[row][col]=self.visual[row][col]-1
      if self.visual[row][col] < 0 then 
        self.visual[row][col]=0
      end
    end
  end

  -- illuminate current loop points
  for voice=1,2 do 
    local s=params:get(voice.."amen_loopstart")
    local e=params:get(voice.."amen_loopend")
    local row1,col1=self:pos_to_row_col(s)
    local row2,col2=self:pos_to_row_col(s)
    for row=1,8 do
      for col=1,self.grid_width do
        if row==row1 and col >= col1 then
          self.visual[row][col]=10
        elseif row==row2 and col<=col2 then
          self.visual[row][col]=10
        elseif row>row1 and row<row2 then
          self.visual[row][col]=10
        end          
      end
    end
  end


  -- illuminate current position
  for voice=1,2 do 
    local row,col=self:pos_to_row_col(self.amen.voice[voice].sc_pos)
    self.visual[row][col]=12
  end

   -- illuminate currently pressed button
  for k,_ in pairs(self.pressed_buttons) do
    row,col=k:match("(%d+),(%d+)")
    self.visual[tonumber(row)][tonumber(col)]=15
  end

  return self.visual
end

function AmenGrid:pos_to_row_col(pos)
  local row=math.floor((pos-1)/3)+1
  local col=pos-(row-1)*3+1
  return row,col
end


function AmenGrid:num_to_pos(num)
  -- convert 0-1 to grid between row,col [1,1] and [6,8]
  local row = math.floor(num*48/8)
  local col = 48*num-8*(row-1)
  return row,col
end

function AmenGrid:grid_redraw()
  self.g:all(0)
  local gd=self:get_visual()
  local s=1
  local e=self.grid_width
  local adj=0
  for row=1,8 do
    for col=s,e do
      if gd[row][col]~=0 then
        self.g:led(col+adj,row,gd[row][col])
      end
    end
  end
  self.g:refresh()
end

return AmenGrid
