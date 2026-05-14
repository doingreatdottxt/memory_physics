local UI = {}

function UI.draw_background(env_name)
    screen.level(1)
    -- Subtle environmental indicators (e.g., a horizon line)
    screen.move(0, 40)
    screen.line(128, 40)
    screen.stroke()
end

function UI.draw_layers(layers, active_count, pressure)
    for i=1, active_count do
        local l = layers[i]
        local y_pos = 10 + (i * 8)
        
        -- Draw "Bedrock" or "Soil" lines based on pressure
        screen.level(l.active and 15 or 2)
        screen.move(10, y_pos)
        
        -- The line length fluctuates based on layer pressure
        local line_end = 10 + (l.pressure_mem * 100)
        screen.line(line_end, y_pos)
        screen.stroke()
        
        -- If a layer is in "dropout", draw a flicker
        if l.is_dropout then
            screen.pixel(line_end + 2, y_pos)
            screen.fill()
        end
    end
end

function UI.draw_pressure_gauge(pressure)
    screen.level(5)
    screen.rect(120, 64, 4, -(pressure * 64))
    screen.fill()
end

return UI
