-- memory_physics
-- @doingreatdottxt
-- l.1: surface (audible/weather)
-- l.6: deep crust (crushed/muffled)

engine.name = 'MemoryPhysics'

local strata = {}
local max_strata = 6
local loop_sec = 20

function init()
  -- Pre-allocate state for 6 layers
  for i=1,max_strata do
    strata[i] = {
      active = false,
      depth = i,
      pressure = 0,
      erosion = 1.0
    }
  end
  
  -- Inform engine of our constraints
  engine.setup(max_strata, loop_sec)
  
  -- UI Refresh
  screen_dirty = true
  redraw_metro = metro.init(function(stage) redraw() end, 1/15)
  redraw_metro:start()
end

-- The "Form Strata" function (Record New)
function form_new_layer()
  -- 1. Shift all existing layers down (LIFO)
  -- This mimics geological burial
  engine.shift_layers()
  
  -- 2. Update Lua state
  for i=max_strata, 2, -1 do
    strata[i].active = strata[i-1].active
  end
  
  -- 3. Start recording into the "Surface" (Buffer 0 in SC)
  strata[1].active = true
  engine.record_surface(1) -- 1 for start
end

-- Archeological Excavation (Remove Top Layer)
function excavate()
  engine.pop_layer()
  for i=1, max_strata-1 do
    strata[i].active = strata[i+1].active
  end
  strata[max_strata].active = false
end

function enc(n, d)
  if n == 2 then
    -- Weather/Erosion control
  elseif n == 3 then
    -- Pressure/Depth control
  end
end

function key(n, z)
  if n == 2 and z == 1 then
    form_new_layer()
  elseif n == 3 and z == 1 then
    excavate()
  end
end

function redraw()
  screen.clear()
  screen.level(15)
  screen.move(0, 10)
  screen.text("STRATA STACK")
  
  for i=1, max_strata do
    if strata[i].active then
      screen.level(math.floor(15/i)) -- Deeper layers are dimmer
      screen.rect(10, 15 + (i*7), 100, 5)
      screen.fill()
    end
  end
  screen.update()
end
