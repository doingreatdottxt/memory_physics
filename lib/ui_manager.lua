local UIManager = {}

function UIManager.draw_layers(layers, active_count, global_pressure)
  for i = 1, 6 do
    local y = 15 + (i * 7)
    if layers[i] and layers[i].duration ~= -1 then
      local p = layers[i].pressure_mem or 0
      local alpha = (layers[i].current_vol or 0) * (layers[i].gain_mem or 1)
      if alpha > 0.05 then
        screen.level(math.floor((math.floor(p * 5) + 5) * alpha))
        screen.move(10, y); screen.line(110, y); screen.stroke()
      end
    end
  end
  screen.level(1); screen.rect(115, 15, 3, 42); screen.stroke()
  screen.level(math.floor(global_pressure * 15))
  local bh = math.floor(global_pressure * 42)
  screen.rect(115, 57 - bh, 3, bh); screen.fill()
end

function UIManager.draw_help(is_manual)
  screen.level(15); screen.move(0, 10); screen.text("ARCHAEOLOGY HELP")
  screen.level(4)
  screen.move(0, 25); screen.text("K3: Toggle Auto/Manual")
  screen.move(0, 35); screen.text("K1+K3: Cycle Sync Mode")
  if is_manual then screen.move(0, 55); screen.text("K2: START/STOP REC") end
end

return UIManager
