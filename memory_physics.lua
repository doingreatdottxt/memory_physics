-- memory_physics.lua
-- Restoring Loop Length & Overdub Functionality
-- 6 Layers | 20s Max

engine.name = 'MemoryPhysics'

local physics = {
  recording = false,
  start_time = 0,
  duration = 20, -- Default to max
  layers_active = 0,
  max_layers = 6,
  playheads = {0,0,0,0,0,0}
}

function init()
  -- UI Setup
  screen.clear()
  screen.update()

  -- Engine Handshake
  clock.run(function()
    clock.sleep(1.0)
    engine.ready()
  end)

  -- Poll playheads from SC
  poll_timer = metro.init(function()
    -- In a full implementation, use norns.bus.get() here
    redraw()
  end, 1/30)
  poll_timer:start()
end

function toggle_formation()
  if not physics.recording then
    -- START RECORDING
    physics.start_time = util.time()
    engine.shift_layers() 
    engine.record_start(20) -- Max limit
    physics.recording = true
    if physics.layers_active < physics.max_layers then
      physics.layers_active = physics.layers_active + 1
    end
  else
    -- STOP RECORDING / DEFINE DURATION
    physics.recording = false
    physics.duration = math.min(20, util.time() - physics.start_time)
    -- Update engine with the actual loop length
    print("Layer Formed: " .. string.format("%.2f", physics.duration) .. "s")
  end
end

function key(n, z)
  if n == 2 and z == 1 then 
    toggle_formation()
  elseif n == 3 and z == 1 then
    physics.layers_active = 0
  end
end

function redraw()
  screen.clear()
  
  -- Header
  screen.level(physics.recording and 15 or 2)
  screen.move(0, 10)
  screen.text(physics.recording and "RECORDING DURATION: " .. string.format("%.1f", util.time() - physics.start_time) or "CRUST STABLE")
  
  -- Visual Strata
  for i=1, 6 do
    local is_active = i <= physics.layers_active
    local y = 62 - (i * 8)
    
    screen.level(is_active and math.floor(15/i) or 1)
    screen.rect(10, y, 108, 6)
    if is_active then screen.fill() else screen.stroke() end
    
    -- Playhead Indicator (Surface Layer)
    if i == 1 and is_active then
      screen.level(15)
      local play_pos = ((util.time() - physics.start_time) % physics.duration) / physics.duration
      screen.move(10 + (play_pos * 108), y)
      screen.line_rel(0, 6)
      screen.stroke()
    end
  end
  
  screen.update()
end
