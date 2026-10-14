--- Animation Tracker
--- Отслеживает активные анимации и уведомляет когда все завершены
--- Используется для блокировки UI во время анимаций и определения момента их завершения

local events = require("event.events")
local log = require("fun.libs.log")

local logger = log.get_logger("fun.animation_tracker")

---@class fun.animation_tracker
---@field active_animations_count integer
---@field animation_started_event string
---@field animation_completed_event string
---@field all_animations_completed_event string
---@field _started_handler function
---@field _completed_handler function
local M = {}


--- Начало анимации - увеличиваем счетчик
---@param self fun.animation_tracker
---@param animation_id string|nil Идентификатор анимации для отладки
local function on_animation_started(self,animation_id)
    self.active_animations_count = self.active_animations_count + 1
    -- logger:debug("Animation started", { 
    --     id = animation_id, 
    --     active_count = self.active_animations_count 
    -- })
end

--- Завершение анимации - уменьшаем счетчик
---@param self fun.animation_tracker
---@param animation_id string|nil Идентификатор анимации для отладки
local function on_animation_completed(self, animation_id)
    self.active_animations_count = self.active_animations_count - 1
    
    -- logger:debug("Animation completed", { 
    --     id = animation_id, 
    --     active_count = self.active_animations_count
    -- })
    
    -- Если все анимации завершены, публикуем событие
    if self.active_animations_count == 0 then
        -- logger:debug("All animations completed")
        events.trigger(self.all_animations_completed_event)
    end
    
    -- Защита от отрицательных значений
    if self.active_animations_count < 0 then
        logger:error("Animation count became negative! This is a bug - check unsubscribe calls")
        self.active_animations_count = 0
    end
end

--- Финализация трекера
---@param self fun.animation_tracker
function M:final()
    events.unsubscribe(self.animation_started_event, on_animation_started)
    events.unsubscribe(self.animation_completed_event, on_animation_completed)
    
    self.active_animations_count = 0
    -- logger:debug("Animation tracker finalized")
end

--- Получить количество активных анимаций
---@param self fun.animation_tracker
---@return integer
function M:get_active_count()
    return self.active_animations_count
end

--- Проверить, есть ли активные анимации
---@param self fun.animation_tracker
---@return boolean
function M:has_active_animations()
    return self.active_animations_count > 0
end

--- Сбросить счетчик (использовать только для тестов или экстренных случаев)
---@param self fun.animation_tracker
function M:reset()
    logger:warn("Animation counter reset forcefully", { old_count = self.active_animations_count })
    self.active_animations_count = 0
end

--- Создать новый экземпляр трекера анимаций
---@param animation_started_event string Идентификатор события начала анимации
---@param animation_completed_event string Идентификатор события завершения анимации
---@param all_animations_completed_event string Идентификатор события завершения всех анимаций
---@return fun.animation_tracker
function M.new(animation_started_event, animation_completed_event, all_animations_completed_event)
    -- Устанавливаем метатаблицу для методов
    local instance = {}
    setmetatable(instance, { __index = M })

    instance.active_animations_count = 0
    instance.animation_started_event = animation_started_event
    instance.animation_completed_event = animation_completed_event
    instance.all_animations_completed_event = all_animations_completed_event

    -- Подписываемся на события анимаций
    events.subscribe(instance.animation_started_event, on_animation_started, instance)
    events.subscribe(instance.animation_completed_event, on_animation_completed, instance)
        
    return instance
end

return M

