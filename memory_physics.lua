-- memory_physics
-- Geological Strata Looper

engine.name = 'MemoryPhysics'

local physics_state = {
  is_recording = false,
  active_layers = 0,
  max_layers = 6
}

function init()
  -- Clear screen and show status
  screen.clear()
  screen.move(64, 32)
  screen.text_center("STABILIZING CRUST...")
  screen.update()

  -- Give the engine a moment to allocate 23MB of buffers
  clock.run(function()
    clock.sleep(1.0)
    engine.ready()
    print("Memory Physics: System Stable")
  end)

  redraw_timer = metro.init(function() redraw() end, 1/15)
  redraw_timer:start()
end

function form_strata()
  if not physics_state.is_recording then
    engine.shift_layers()
    engine.record_start()
    physics_state.is_recording = true
    if physics_state.active_layers < 6 then
      physics_state.active_layers = physics_state.active_layers + 1
    end
  else
    physics_state.is_recording = false
  end
end

function key(n, z)
  if n == 2 and z == 1 then
    form_strata()
  end
end

function redraw()
  screen.clear()
  
  -- Record Header
  screen.level(physics_state.is_recording and 15 or 3)
  screen.move(128, 10)
  screen.text_right(physics_state.is_recording and "FORMING" or "STABLE")
  
  -- Visualizing the 6 Strata
  for i=1, 6 do
    if i <= physics_state.active_layers then
      screen.level(math.floor(15 / i))
      -- Draw layers from bottom (oldest) up
      screen.rect(10, 60 - (i * 7), 108, 5)
      screen.fill()
    else
      screen.level(1)
      screen.rect(10, 60 - (i * 7), 108, 1)
      screen.stroke()
    end
  end
  
  screen.update()
end
