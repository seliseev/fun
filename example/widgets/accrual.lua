local log = require("fun.libs.log")
local druid = require("druid.druid")
local event = require("event.event")

local tablex = require("fun.libs.tablex")
local wallet = require("fun.modules.wallet")
local fun_sound = require("fun.modules.sound")
local vibrate = require("fun.modules.vibrate")

local widget_emitter = require("example.widgets.emitter")

local logger = log.get_logger("game.widgets.accrual")

---@class game.widget.accrual.data
---@field token_targets table<string, userdata> token_id -> target node
---@field token_sound_on_emit table<string, string> token_id -> sound id
---@field token_sound_on_target table<string, string> token_id -> sound id
---@field token_vibrate_on_target table<string, fun.vibrate.PATTERNS> token_id -> vibrate pattern


---@class widget.accrual: druid.widget
local M = {}


---Анимация эмиттеров токенов
---@param self widget.accrual
local function animate(self)
    -- Счетчик завершенных анимаций для каждого токена
    local completed_animations = {}
    local total_animations = 0
    
    -- Подсчитываем количество токенов, для которых нужно запустить анимации
    for token_id, _ in pairs(self.not_synced_tokens) do
        if self.token_targets[token_id] then
            total_animations = total_animations + 1
            completed_animations[token_id] = false
        end
    end
    
    -- Если нет анимаций для запуска, вызываем событие завершения
    if total_animations == 0 then
        self.on_emit_completed:trigger()
        return
    end
    
    -- Функция для проверки завершения всех анимаций
    local function check_all_completed()
        for token_id, completed in pairs(completed_animations) do
            if not completed then
                return false
            end
        end
        self.on_emit_completed:trigger()
    end
    
    for token_id, difference in pairs(self.not_synced_tokens) do
        local target_node = self.token_targets[token_id]
        if target_node then
            local target_position = gui.get_screen_position(target_node)
            local widget = self.widget_token_emitters[token_id]

            widget:emit(difference, target_position, function (number, amount)

                --- Если для начисления токена есть звук, то воспроизводим его
                if self.token_sound_on_target and self.token_sound_on_target[token_id] then
                    fun_sound.play(self.token_sound_on_target[token_id])
                end

                if self.token_vibrate_on_target and self.token_vibrate_on_target[token_id] then
                    vibrate.vibrate(self.token_vibrate_on_target[token_id])
                end

                self.on_emit_to_target(token_id, number, amount, target_node)
                wallet.add_visual(token_id, 1/amount*difference)
                if number == amount then
                    wallet.sync_visual(token_id)
                    -- Отмечаем, что анимация для этого токена завершена
                    completed_animations[token_id] = true
                    check_all_completed()
                end
            end)
        else
            logger:error("target_node not found for token_id: " .. token_id)
            -- Если нет target_node, считаем анимацию завершенной
            completed_animations[token_id] = true
            check_all_completed()
        end
    end
end

---@param data game.widget.accrual.data
function M:init(data)
    assert(data, "data is required")
    assert(data.token_targets, "token_targets is required")

    self.token_targets = data.token_targets
    self.token_sound_on_target = data.token_sound_on_target or {}
    self.token_sound_on_emit = data.token_sound_on_emit or {}
    self.token_vibrate_on_target = data.token_vibrate_on_target or {}

    self.on_emit_to_target = event.create()
    self.on_emit_completed = event.create()

    self.druid = druid.new(self)

    ---@type table<string, game.scenes.hud.widget_token_emitter>
    self.widget_token_emitters = {}
end

function M:on_remove()
    self.on_emit_to_target:clear()
    self.on_emit_completed:clear()
    self.druid:final()
end

function M:update(dt)
    self.druid:update(dt)
end

function M:accrual()
    -- Находим все токены из wallet, которые не синхронизированы с визуальным значением 
    ---@type table<string, number> не синхронизированные токены, token_id -> difference
    self.not_synced_tokens = wallet.get_many_not_synced()
    if tablex.is_empty(self.not_synced_tokens) then
        logger:info("All tokens are synced")
        -- Вызываем событие завершения, даже если начислять нечего
        self.on_emit_completed:trigger()
        return
    end

    --- Для всех не сихнронизированных токенов создаём виджет эмиттера
    for token_id, _ in pairs(self.not_synced_tokens) do
        if not self.widget_token_emitters[token_id] then
            self.widget_token_emitters[token_id] = self.druid:new_widget(widget_emitter, "accrual/emitter_prefab", "root", token_id, self.token_sound_on_emit[token_id])
        end
    end

    animate(self)
end

function M:on_message(message_id, message, sender)
    
end

function M:on_input(action_id, action)
    
end

return M