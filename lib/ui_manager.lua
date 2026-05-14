local UIManager = {}

function UIManager.draw_layers(layers, active_count, global_pressure)
    for i = 1, 6 do
        local y = 15 + (i * 7)
        if layers[i] then
            local p = layers[i].pressure_mem
            screen.level(math.floor(p * 10) + 2)
            screen.move(10, y)
            screen.line(110, y)
            screen.stroke()
            
            screen.level(15)
            screen.pixel(12 + (math.sin(util.time() + i) * 2), y)
            screen.fill()
        end
    end
    
    screen.level(1)
    screen.rect(115, 15, 3, 42)
    screen.stroke()
    screen.level(math.floor(global_pressure * 15))
    local p_h = math.floor(global_pressure * 42)
    screen.rect(115, 57 - p_h, 3, p_h)
    screen.fill()
end

function UIManager.draw_help(is_manual)
    screen.level(15)
    screen.move(0, 10)
    screen.text("ARCHAEOLOGY HELP")
    screen.level(4)
    screen.move(0, 25)
    screen.text("K3: Toggle Auto/Manual")
    screen.move(0, 35)
    screen.text("K1+K3: Cycle Sync")
    screen.move(0, 45)
    screen.text("K2+K3: SYSTEM RESET")
    screen.move(0, 55)
    screen.text("K1+K2: Exit Help")
end

return UIManager
