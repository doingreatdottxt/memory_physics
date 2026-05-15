-- memory_physics.lua
-- Geological Strata Looper
-- README: Audio as geological record.

engine.name = 'MemoryPhysics'

local physics = {
  recording = false,
  layers_active = 0,
  max_layers = 6
}

function init()
  screen.clear()
  screen.move(64, 32)
  screen.text_center("PRESSURIZING...")
  screen.update()

  -- Wait for the 23MB buffer allocation to finish
  clock.run(function()
    clock.sleep(1.0)
    engine.ready()
    print("Memory Physics: Ready")
  end)

  redraw_metro = metro.init(function() redraw() end, 1/15)
  redraw_metro:start()
end

function form_new_layer()
  if not physics.recording then
    engine.shift_layers() -- Bury existing audio
    engine.record_start() -- Form new surface
    physics.recording = true
    if physics.layers_active < physics.max_layers then
      physics.layers_active = physics.layers_active + 1
    end
  else
    physics.recording = false
  end
end

function key(n, z)
  if n == 2 and z == 1 then -- Key 2 to Form/Bury
    form_new_layer()
  end
end

function redraw()
  screen.clear()
  
  -- Header
  screen.level(physics.recording and 15 or 3)
  screen.move(0, 10)
  screen.text(physics.recording and "FORMING STRATA..." or "CRUST STABLE")
  
  -- Visualize the layers
  for i=1, 6 do
    local is_active = i <= physics.layers_active
    screen.level(is_active and math.floor(15/i) or 1)
    
    -- Draw layer blocks
    local y = 62 - (i * 8)
    screen.rect(10, y, 108, 6)
    if is_active then screen.fill() else screen.stroke() end
  end
  
  screen.update()
end
