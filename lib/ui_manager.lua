local UIManager = {}

function UIManager.draw_layers(layers, active_count, global_pressure)
  -- Draw the 6 horizontal strata lines
  for i = 1, 6 do
    local y = 15 + (i * 7)
    if layers and layers[i] then
      local p = layers[i].pressure_mem or 0
      local gain = layers[i].gain_mem or 0
      
      -- Brightness = (Pressure Level) * (Life/Gain Level)
      local base_level = math.floor(p * 10) + 2
      screen.level(math.floor(base_level * gain))
      
      screen.move(10, y)
      screen.line(110, y)
      screen.stroke()
      
      -- Draw artifacts that also dim with the layer
      if gain > 0.1 then
        screen.level(math.floor(15 * gain))
        screen.pixel(12 + (math.sin(util.time() + i) * 2), y)
        screen.fill()
      end
    end
  end
  
  -- Pressure Meter
  screen.level(1)
  screen.rect(115, 15, 3, 42)
  screen.stroke()
  
  screen.level(math.floor(global_pressure * 15))
  local bar_height = math.floor(global_pressure * 42)
  screen.rect(115, 57 - bar_height, 3, bar_height)
  screen.fill()
end

function UIManager.draw_help(is_manual)
  screen.level(15)
  screen.move(0, 10)
  screen.text("ARCHAEOLOGY HELP")
  screen.level(4)
  screen.move(0, 25); screen.text("K3: Toggle Auto/Manual")
  screen.move(0, 35); screen.text("K1+K3: Cycle Sync Mode")
  screen.move(0, 55)
  if is_manual then screen.text("K2: START/STOP REC")
  else screen.text("AUTO: AUDIO TRIGGERED") end
end

return UIManager
