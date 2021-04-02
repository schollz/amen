-- amen v0.0.1
-- get that amen break.
--

local UI=require "ui"
amenbreaks=include("amen/lib/amen")

engine.name="Amen"

function init()
  amen=amenbreaks:new()

  clock.run(redraw_clock) 
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

function rerun()
  norns.script.load(norns.state.script)
end
