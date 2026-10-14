--- Базовый класс для провайдеров аналитики
--- Использует паттерн наследования через метатаблицы, аналогичный druid.widget

local log = require("fun.libs.log")

local logger = log.get_logger("fun.analytics.base_provider")

---@class fun.analytics.base_provider
---@field _provider table
---@field init fun(self: fun.analytics.base_provider, config: table|nil)
---@field purchase fun(self: fun.analytics.base_provider, lot: any, transaction: any, placement: string|nil)
---@field ad_rw_show fun(self: fun.analytics.base_provider, placement_id: string, ad_sdk_name: string)
---@field ad_rw_reward_received fun(self: fun.analytics.base_provider, placement_id: string, ad_sdk_name: string)
---@field ad_rw_failed_show fun(self: fun.analytics.base_provider, placement_id: string, ad_sdk_name: string)
---@field ad_inter_show fun(self: fun.analytics.base_provider, placement_id: string, ad_sdk_name: string)
---@field ad_inter_failed_show fun(self: fun.analytics.base_provider, placement_id: string, ad_sdk_name: string)
---@field ad_banner_show fun(self: fun.analytics.base_provider, placement_id: string, ad_sdk_name: string)
---@field ad_banner_failed_show fun(self: fun.analytics.base_provider, placement_id: string, ad_sdk_name: string)
---@field resource_added fun(self: fun.analytics.base_provider, resource: string, amount: number, source: string, source_category: string)
---@field resource_spent fun(self: fun.analytics.base_provider, resource: string, amount: number, source: string, source_category: string)
---@field progression_start fun(self: fun.analytics.base_provider, progression_category: string, level: integer|string)
---@field progression_complete fun(self: fun.analytics.base_provider, progression_category: string, level: integer|string, score: number|nil)
---@field progression_fail fun(self: fun.analytics.base_provider, progression_category: string, level: integer|string)
---@field final fun(self: fun.analytics.base_provider)
local M = {}

--- Метатаблица для базового класса
local BASE_METATABLE = { __index = M }

--- Создание нового провайдера аналитики
---@param provider_name string Имя провайдера
---@return table
function M.create(provider_name)
    local new_class = setmetatable({}, {
        __index = M,
        __call = function(cls, ...)
            local self = setmetatable({
                _provider = {
                    name = provider_name or "Analytics Provider",
                }
            }, {
                __index = cls
            })
            return self
        end
    })
    
    return new_class
end

--- Создание экземпляра провайдера
---@param provider_class table Класс провайдера
---@param config table|nil Конфигурация провайдера
---@return fun.analytics.base_provider
function M.create_provider(provider_class, config)
    local instance = setmetatable({}, {
        __index = setmetatable(provider_class, BASE_METATABLE)
    })
    
    instance._provider = {
        name = instance._provider and instance._provider.name or "Analytics Provider",
        config = config
    }
        
    return instance
end

--- Получить имя провайдера
---@return string
function M:get_name()
    return self._provider.name
end

--- Получить конфигурацию провайдера
---@return table|nil
function M:get_config()
    return self._provider.config
end

--- Инициализация провайдера (переопределяется в дочерних классах)
---@param config table|nil Конфигурация провайдера
function M:init(config)
    -- Переопределяется в дочерних классах
end

--- Покупка (переопределяется в дочерних классах)
---@param lot fun.iapservice.lot
---@param transaction fun.iap.transaction
---@param placement string|nil Место где была совершена покупка
function M:purchase(lot, transaction, placement)
    -- Переопределяется в дочерних классах
end

--- Показ рекламы с наградой (переопределяется в дочерних классах)
---@param placement_id string
---@param ad_sdk_name string
function M:ad_rw_show(placement_id, ad_sdk_name)
    -- Переопределяется в дочерних классах
end

--- Получение награды за рекламу (переопределяется в дочерних классах)
---@param placement_id string
---@param ad_sdk_name string
function M:ad_rw_reward_received(placement_id, ad_sdk_name)
    -- Переопределяется в дочерних классах
end

--- Ошибка показа рекламы с наградой (переопределяется в дочерних классах)
---@param placement_id string
---@param ad_sdk_name string
function M:ad_rw_failed_show(placement_id, ad_sdk_name)
    -- Переопределяется в дочерних классах
end

--- Показ межстраничной рекламы (переопределяется в дочерних классах)
---@param placement_id string
---@param ad_sdk_name string
function M:ad_inter_show(placement_id, ad_sdk_name)
    -- Переопределяется в дочерних классах
end

--- Ошибка показа межстраничной рекламы (переопределяется в дочерних классах)
---@param placement_id string
---@param ad_sdk_name string
function M:ad_inter_failed_show(placement_id, ad_sdk_name)
    -- Переопределяется в дочерних классах
end

--- Показ баннерной рекламы (переопределяется в дочерних классах)
---@param placement_id string
---@param ad_sdk_name string
function M:ad_banner_show(placement_id, ad_sdk_name)
    -- Переопределяется в дочерних классах
end

--- Ошибка показа баннерной рекламы (переопределяется в дочерних классах)
---@param placement_id string
---@param ad_sdk_name string
function M:ad_banner_failed_show(placement_id, ad_sdk_name)
    -- Переопределяется в дочерних классах
end

--- Добавление ресурса (переопределяется в дочерних классах)
---@param resource string
---@param amount number
---@param source string
---@param item_id string|nil
function M:resource_added(resource, amount, source, item_id)
    -- Переопределяется в дочерних классах
end

--- Трата ресурса (переопределяется в дочерних классах)
---@param resource string Идентификатор ресурса, который потратили
---@param amount number Количество ресурса, которое было потрачено
---@param for_what string Категория трат ресурса: start_game, booster, etc
---@param item_id string|nil Идентификатор предмета который получил игрок за эту трату, может быть пустым
function M:resource_spent(resource, amount, for_what, item_id)
    -- Переопределяется в дочерних классах
end

--- Начало прогрессии (переопределяется в дочерних классах)
---@param progression_category string
---@param level integer|string
function M:progression_start(progression_category, level)
    -- Переопределяется в дочерних классах
end

--- Завершение прогрессии (переопределяется в дочерних классах)
---@param progression_category string
---@param level integer|string
---@param score number|nil
function M:progression_complete(progression_category, level, score)
    -- Переопределяется в дочерних классах
end

--- Провал прогрессии (переопределяется в дочерних классах)
---@param progression_category string
---@param level integer|string
function M:progression_fail(progression_category, level)
    -- Переопределяется в дочерних классах
end

--- Установка свойства пользователя (переопределяется в дочерних классах)
---@param property_name string
---@param property_value string|number|boolean
function M:set_user_property(property_name, property_value)
    -- Переопределяется в дочерних классах
end

--- Логирование сообщения (переопределяется в дочерних классах)
---@param log_level string Уровень логирования
---@param message string Сообщение
function M:log(log_level, message)
    -- Переопределяется в дочерних классах
end

--- Финализация провайдера (переопределяется в дочерних классах)
function M:final()
    -- Переопределяется в дочерних классах
end

return M

