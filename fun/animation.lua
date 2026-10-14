local tweener = require("tweener.tweener")

local M = {}

--- Анимация тряски объекта
---@param target_id string|url|userdata|nil
---@param duration float
---@param magnitude float
---@param frequency float
---@param callback function|nil
function M.shake_object(target_id, duration, magnitude, frequency, callback)
    local elapsed = 0
    local original_position = go.get_position(target_id)
    local interval = 1 / frequency

    local function apply_shake()
        if elapsed < duration then
            -- Генерация случайного смещения
            local dx = math.random(-magnitude, magnitude)
            local dy = math.random(-magnitude, magnitude)

            -- Установка новой позиции с учетом смещения
            go.set_position(vmath.vector3(original_position.x + dx, original_position.y + dy, original_position.z), target_id)

            -- Инкремент времени
            elapsed = elapsed + interval

            -- Рекурсивный вызов
            timer.delay(interval, false, apply_shake)
        else
            -- Вернуть объект на оригинальную позицию
            go.set_position(original_position, target_id)

            -- Вызов колбэка (если указан)
            if callback then callback() end
        end
    end

    -- Запуск тряски
    apply_shake()
end

--- Анимация "прыжка" для GUI-элемента
--- @param node userdata
--- @param scale number|nil
function M.gui_bounce(node, scale, callback)
    scale = scale or 1.2
    local overscale = gui.get_scale(node) * scale
    local normalscale = gui.get_scale(node)
    gui.cancel_animations(node, gui.PROP_SCALE) -- на случай, если была анимация

    gui.animate(node, gui.PROP_SCALE, overscale, gui.EASING_OUTBACK, 0.1, 0, function()
        gui.animate(node, gui.PROP_SCALE, normalscale, gui.EASING_INOUTQUAD, 0.1, 0, callback)
    end)
end

function M.gui_shake(node, duration, magnitude, frequency, callback)
    local elapsed = 0
    local original_position = gui.get_position(node)
    local interval = 1 / frequency

    local function apply_shake()
        if elapsed < duration then
            -- Генерация случайного смещения
            local dx = math.random(-magnitude, magnitude)
            local dy = math.random(-magnitude, magnitude)

            -- Установка новой позиции с учетом смещения
            gui.set_position(node, vmath.vector3(original_position.x + dx, original_position.y + dy, original_position.z))

            -- Инкремент времени
            elapsed = elapsed + interval

            -- Рекурсивный вызов
            timer.delay(interval, false, apply_shake)
        else
            -- Вернуть объект на оригинальную позицию
            gui.set_position(node, original_position)

            -- Вызов колбэка (если указан)
            if callback then callback() end
        end
    end

    -- Запуск тряски
    apply_shake()
end

function M.gui_shake_x(node, duration, amplitude, callback)
    local original_pos = gui.get_position(node)
    local step = 0
    local cycles = 2  -- Количество отклонений (влево-вправо)
    local total_steps = cycles * 2
    local step_duration = duration / (total_steps + 1)

    local function shake_step()
        step = step + 1
        if step > total_steps then
            gui.animate(node, gui.PROP_POSITION, original_pos, gui.EASING_INOUTSINE, step_duration, 0, function()
                if callback then callback() end
            end)
            return
        end

        local direction = (step % 2 == 0) and 1 or -1
        local offset_x = original_pos.x + direction * amplitude
        local new_pos = vmath.vector3(offset_x, original_pos.y, original_pos.z)
        gui.animate(node, gui.PROP_POSITION, new_pos, gui.EASING_INOUTSINE, step_duration, 0, shake_step)
    end

    shake_step()
end

function M.gui_blinking_to_transperent(node, duration, callback)
    local original_color = gui.get_color(node)
    local transperent_color = vmath.vector4(original_color.x, original_color.y, original_color.z, 0)

    gui.animate(node, gui.PROP_COLOR, transperent_color, gui.EASING_INOUTSINE, duration, 0, function()
        gui.animate(node, gui.PROP_COLOR, original_color, gui.EASING_INOUTSINE, duration, 0, callback)
    end)
end

function M.gui_blinking_to_opaque(node, duration, callback)
    local original_color = gui.get_color(node)
    local opaque_color = vmath.vector4(original_color.x, original_color.y, original_color.z, 1)

    gui.animate(node, gui.PROP_COLOR, opaque_color, gui.EASING_INOUTSINE, duration, 0, function()
        gui.animate(node, gui.PROP_COLOR, original_color, gui.EASING_INOUTSINE, duration, 0, callback)
    end)
end


local function bezier(start_pos, end_pos, control_point, t)
    local u = 1 - t
    local tt = t*t
    local uu = u*u
    return uu * start_pos + 2 * u * t * control_point + tt * end_pos
end

function M.gui_bezier(easing, node, end_pos, control_point, duration, callback)
    local start_pos = gui.get_position(node)
    easing = easing or gui.EASING_INCIRC

    tweener.tween(easing, 0, 1, duration, function(value, is_final_call)
        local new_pos = bezier(start_pos, end_pos, control_point, value)
        gui.set_position(node, new_pos)	
        if is_final_call and callback then
            callback()
        end
    end)
end

return M