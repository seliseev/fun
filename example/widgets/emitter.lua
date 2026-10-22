local log = require("fun.libs.log")
local luax = require("fun.luax")
local mathx = require("fun.libs.mathx")
local iconfinder = require("example.modules.iconfinder")
local animation = require("fun.animation")

local fun_sound = require("fun.modules.sound")

local logger = log.get_logger("game.widgets.emitter")

---@class game.scenes.hud.widget_token_emitter: druid.widget
local M = {}

---@param self game.scenes.hud.widget_token_emitter
local function emit(self)
    local cloned_icon = gui.clone(self.icon)
    return cloned_icon
end


---@param self game.scenes.hud.widget_token_emitter
---@param token_id string token id
---@param sound_id string|nil sound id
function M:init(token_id, sound_id)
    assert(token_id, "token_id is required")

    self.token_id = token_id
    self.sound_id = sound_id

    self.root = self:get_node("root")
    self.icon = self:get_node("icon")
    self.text = self:get_node("text")

    gui.set_enabled(self.root, false)
    gui.set_enabled(self.icon, false)
    gui.set_enabled(self.text, false)

    local flipbook = iconfinder.get_flipbook(self.token_id)
    if flipbook ~= nil then
        gui.play_flipbook(self.icon, flipbook)
    end
end

local OFFSET_MAX = 30

---Выпускает токены из иконки на цель: появляются через альфу и летят в цель по кривой Безье
---@param amount number rоличестов токенов, которые визуально полетят
---@param target_position vector3 Экранная позиция цели
---@param callback_for_every_icon function|nil колбэк, который вызывается после того, как все токены выпущены
function M:emit(amount, target_position, callback_for_every_icon)
    if amount < 1 then
        logger:error("Amount must be greater or equal to 1")
        return
    end

    local target_position = gui.screen_to_local(self.icon, target_position)
    callback_for_every_icon = callback_for_every_icon or function(a, b) end

    gui.set_enabled(self.root, true)
    
    local amount = math.min(amount, 5)
    local previous_icon = nil
    local count_shown = 0
    
    local icons = {}

    if self.sound_id then
        fun_sound.play(self.sound_id)
    end

    for i = 1, amount do
        local cloned_icon = emit(self)
        table.insert(icons, cloned_icon)
        if previous_icon then
            gui.move_above(cloned_icon, previous_icon)
        end
        local original_position = gui.get_position(cloned_icon)
        local original_scale = gui.get_scale(cloned_icon)
        local random_offset = vmath.vector3(mathx.random(-OFFSET_MAX, OFFSET_MAX), mathx.random(-OFFSET_MAX, OFFSET_MAX), 0)
        local control_point = vmath.vector3((original_position.x + target_position.x) / 2-100, (original_position.y + target_position.y)/2, 0) -- Контрольная точка для изгиба
        
        --- 1. Выставляем в случайную позицию
        gui.set_scale(cloned_icon, original_scale*0)
        gui.set_position(cloned_icon, original_position + random_offset)
        gui.set_enabled(cloned_icon, true)
        gui.set_alpha(cloned_icon, 0)

        --- 2. Анимируем через скейл до оригинального размера
        local delay = (i-1)*0.05
        gui.animate(cloned_icon, "scale", original_scale, gui.EASING_OUTELASTIC, 0.3, delay)
        gui.animate(cloned_icon, "color.w", 1, gui.EASING_LINEAR, 0.3, delay, function()
            count_shown = count_shown + 1

            if count_shown == amount then
                for j = #icons, 1, -1 do
                    local icon = icons[j]
                    timer.delay((#icons - j)*0.05, false, function()
                        animation.gui_bezier(gui.EASING_LINEAR, icon, target_position, control_point, 0.5+(#icons - j + 1)*0.05, function ()
                            gui.set_enabled(icon, false)
                            gui.delete_node(icon)
                            callback_for_every_icon(amount-j+1, amount)
                        end)
                    end)
                    
                end
            end
        end)
        previous_icon = cloned_icon
    end
end

return M