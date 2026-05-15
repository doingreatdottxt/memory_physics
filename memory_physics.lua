-- memory_physics
-- Geological Strata Looper
-- LIFO Buffer Management

engine.name = 'MemoryPhysics'

local physics_state = {
  is_recording = false,
  active_layers = 0,
  max_layers = 6
}

function init()
  -- Reset all buffers on engine boot
  screen_dirty = true
  
  -- Metro for UI
  redraw_timer = metro.init(function() redraw() end, 1/15)
  redraw_timer:start()
  
  print("Memory Physics: Crust Initialized")
end

function form_strata()
  if not physics_state.is_recording then
    -- Move old layers deeper before recording new surface
    engine.shift_layers()
    engine.record_start()
    physics_state.is_recording = true
    if physics_state.active_layers < 6 then
      physics_state.active_layers = physics_state.active_layers + 1
    end
  else
    -- Stop recording/Forming
    physics_state.is_recording = false
  end
end

function key(n, z)
  if n == 2 and z == 1 then -- Key 2: Form/Bury
    form_strata()
  end
end

function redraw()
  screen.clear()
  screen.level(15)
  screen.move(0, 10)
  screen.text("PHYSICS: " .. (physics_state.is_recording and "FORMING" or "STABLE"))
  
  -- Visualize the 6 layers
  for i=1, 6 do
    local depth_level = i <= physics_state.active_layers and 15 or 1
    screen.level(math.floor(depth_level / i))
    screen.rect(10, 60 - (i * 7), 100, 4)
    screen.fill()
  end
  screen.update()
end
