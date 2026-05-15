local UIManager = {}

function UIManager.draw_layers(layers, active_count, global_pressure)
  for i = 1, 6 do
    local y = 15 + (i * 7)
    if layers[i] and layers[i].duration ~= -1 then
      local p = layers[i].pressure_mem or 0
      local gain_mem = layers[i].gain_mem or 1.0
      local vol = layers[i].current_vol or 0.0
      
      -- Brightness reflects actual audible presence
      local base_brightness = math.floor(p * 5) + 5
      local final_alpha = vol * gain_mem
      
      if final_alpha > 0.05 then
        screen.level(math.floor(base_brightness * final_alpha))
        screen.move(10, y)
        screen.line(110, y)
        screen.stroke()
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
  screen.move(0, 10); screen.text("ARCHAEOLOGY HELP")
  screen.level(4)
  screen.move(0, 25); screen.text("K3: Toggle Auto/Manual")
  screen.move(0, 35); screen.text("K1+K3: Cycle Sync Mode")
  screen.move(0, 55)
  if is_manual then screen.text("K2: START/STOP REC")
  else screen.text("AUTO: AUDIO TRIGGERED") end
end

return UIManager
