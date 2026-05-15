-- memory_physics.lua
-- Geological Strata Looper
-- README: Audio as geological record.

engine.name = 'MemoryPhysics'

local physics = {
  recording = false,
  layers_active = 0,
  max_layers = 6,
  level = 1.0
}

function init()
  screen.clear()
  screen.move(64, 32)
  screen.text_center("SURVEYING SITE...")
  screen.update()

  clock.run(function()
    clock.sleep(1.0)
    engine.ready()
    print("Memory Physics: Site Surveyed")
  end)

  redraw_metro = metro.init(function() redraw() end, 1/15)
  redraw_metro:start()
end

function form_new_layer()
  if not physics.recording then
    engine.shift_layers() 
    engine.record_start()
    physics.recording = true
    if physics.layers_active < physics.max_layers then
      physics.layers_active = physics.layers_active + 1
    end
  else
    physics.recording = false
  end
end

function enc(n, d)
  if n == 1 then
    physics.level = util.clamp(physics.level + d/100, 0, 1)
  end
end

function key(n, z)
  if n == 2 and z == 1 then 
    form_new_layer()
  elseif n == 3 and z == 1 then
    -- Archaeological Excavation (Clear all)
    physics.layers_active = 0
    print("Site Cleared")
  end
end

function redraw()
  screen.clear()
  
  -- The Sky (Status)
  screen.level(physics.recording and 15 or 2)
  screen.move(128, 10)
  screen.text_right(physics.recording and "FORMING STRATA" or "SITE STABLE")
  
  -- The Ground (Strata)
  for i=1, 6 do
    local is_active = i <= physics.layers_active
    local depth_visual = math.floor(15 / i)
    
    screen.level(is_active and depth_visual or 1)
    
    -- Draw the Earth
    local y = 62 - (i * 8)
    if is_active then
      screen.rect(10, y, 108, 6)
      screen.fill()
      -- Highlight the surface layer
      if i == 1 then
        screen.level(15)
        screen.move(12, y + 5)
        screen.text("SURFACE")
      end
    else
      screen.move(10, y + 3)
      screen.line(118, y + 3)
      screen.stroke()
    end
  end
  
  screen.update()
end
