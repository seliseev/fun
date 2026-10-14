local log = require("fun.libs.log")

local tablex = require("fun.libs.tablex")
local target = require("fun.modules.target")
local gamedata = require("fun.modules.gamedata")
local base_provider = require("fun.modules.analytics.base_provider")

local logger = log.get_logger("fun.analytics")

-- Известные провайдеры аналитики
local known_providers = {
    gameanalytics = require("fun.modules.analytics.gameanalytics"),
    facebook = require("fun.modules.analytics.facebook"),
    firebase = require("fun.modules.analytics.firebase"),
    -- Добавь здесь другие провайдеры по мере необходимости
}

--- @class fun.analytics.config
--- @field log_level string Уровень логирования

--- @class fun.analytics
local M = {
    --- @type fun.analytics.config
    default_config = {
        log_level = "WARN"
    },

    --- @type fun.analytics.config|nil
    config = nil,
    
    runtime = {
        providers = {}
    }
}

--- Регистрирует провайдер аналитики
---@param provider_name string Имя провайдера
local function init_provider(provider_name)
    -- Получаем класс провайдера из таблицы известных провайдеров
    local provider_class = known_providers[provider_name]
    if not provider_class then
        logger:warn("Analytics provider not found: " .. provider_name)
        return
    end

    -- Получаем конфигурацию провайдера
    local config = target.get_module_parameter("analytics", provider_name)

    -- Создаем экземпляр провайдера через фабричный метод базового класса
    local provider_instance = base_provider.create_provider(provider_class, config)

    local status, error = pcall(function()
        provider_instance:init(config)
    end)
    
    if not status then
        logger:error("Error initializing analytics provider: " .. provider_name .. ": " .. tostring(error))
        return
    end

    M.runtime.providers[provider_name] = provider_instance
    logger:debug("Analytics provider registered: " .. provider_name)
end


-- Вспомогательная функция для вызова метода у всех провайдеров
local function call_providers(method_name, ...)
    local args = {...}
    local provider_count = 0
    if tablex.is_empty(M.runtime.providers) then
        logger:warn("No providers available. Skipping call of method: " .. method_name)
        return
    end

    for provider_name, provider_instance in pairs(M.runtime.providers) do
        local provider_method = provider_instance[method_name]
        if provider_method and type(provider_method) == "function" then
            provider_count = provider_count + 1

            local success, err = pcall(function()
                provider_method(provider_instance, unpack(args))
            end)
            if not success then
                logger:error("Error calling " .. method_name .. " on provider " .. provider_name .. ": " .. tostring(err))
            end
        end
    end
    if provider_count == 0 then
        logger:error("No providers available for method: " .. method_name)
    end
end

--------------------------------------------------
--- Analytics API functions
--------------------------------------------------

--- Успешно совершена покупка
--- @param lot fun.iapservice.lot
--- @param transaction fun.iap.transaction
--- @param placement string|nil Место, где была совершена покупка
function M.purchase(lot, transaction, placement)
    logger:debug("purchase called", { sku = lot and lot.sku, placement = placement })
    call_providers("purchase", lot, transaction, placement)
end

--- Показано rewarded видео
--- @param placement_id string Место показа rewarded видео
--- @param ad_sdk_name string Имя SDK рекламы: admob, applovin, unity, yandex_games, etc
function M.ad_rw_show(placement_id, ad_sdk_name)
    logger:debug("ad_rw_show called", { placement_id = placement_id, ad_sdk_name = ad_sdk_name })
    call_providers("ad_rw_show", placement_id, ad_sdk_name)
end

--- Получено вознаграждение за rewarded видео
--- @param placement_id string Место показа rewarded видео
--- @param ad_sdk_name string Имя SDK рекламы: admob, applovin, unity, yandex_games, etc
function M.ad_rw_reward_received(placement_id, ad_sdk_name)
    logger:debug("ad_rw_reward_received called", { placement_id = placement_id, ad_sdk_name = ad_sdk_name })
    call_providers("ad_rw_reward_received", placement_id, ad_sdk_name)
end

--- Не удалось показать rewarded видео
--- @param placement_id string Место показа rewarded видео
--- @param ad_sdk_name string Имя SDK рекламы: admob, applovin, unity, yandex_games, etc
function M.ad_rw_failed_show(placement_id, ad_sdk_name)
    logger:debug("ad_rw_failed_show called", { placement_id = placement_id, ad_sdk_name = ad_sdk_name })
    call_providers("ad_rw_failed_show", placement_id, ad_sdk_name)
end

--- @param placement_id string
--- @param ad_sdk_name string
function M.ad_inter_show(placement_id, ad_sdk_name)
    logger:debug("ad_inter_show called", { placement_id = placement_id, ad_sdk_name = ad_sdk_name })
    call_providers("ad_inter_show", placement_id, ad_sdk_name)
end

--- @param placement_id string
--- @param ad_sdk_name string
function M.ad_inter_failed_show(placement_id, ad_sdk_name)
    logger:debug("ad_inter_failed_show called", { placement_id = placement_id, ad_sdk_name = ad_sdk_name })
    call_providers("ad_inter_failed_show", placement_id, ad_sdk_name)
end

--- @param placement_id string
--- @param ad_sdk_name string
function M.ad_banner_show(placement_id, ad_sdk_name)
    logger:debug("ad_banner_show called", { placement_id = placement_id, ad_sdk_name = ad_sdk_name })
    call_providers("ad_banner_show", placement_id, ad_sdk_name)
end

--- @param placement_id string
--- @param ad_sdk_name string
function M.ad_banner_failed_show(placement_id, ad_sdk_name)
    logger:debug("ad_banner_failed_show called", { placement_id = placement_id, ad_sdk_name = ad_sdk_name })
    call_providers("ad_banner_failed_show", placement_id, ad_sdk_name)
end

--- 
---@param resource string
---@param amount number
---@param source string|nil
---@param item_id string|nil
function M.resource_added(resource, amount, source, item_id)
    logger:debug("resource_added called", { resource = resource, amount = amount, source = source, item_id = item_id })
    call_providers("resource_added", resource, amount, source, item_id)
end


--- Трата ресурса (переопределяется в дочерних классах)
---@param resource string Идентификатор ресурса, который потратили
---@param amount number Количество ресурса, которое было потрачено
---@param for_what string|nil Категория трат ресурса: start_game, booster, etc
---@param item_id string|nil Идентификатор предмета который получил игрок за эту трату, может быть пустым
function M.resource_spent(resource, amount, for_what, item_id)
    logger:debug("resource_spent called", { resource = resource, amount = amount, for_what = for_what, item_id = item_id })
    call_providers("resource_spent", resource, amount, for_what, item_id)
end


---@param progression_category string
---@param level integer|string
function M.progression_start(progression_category, level)
    logger:debug("progression_start called", { progression_category = progression_category, level = level })
    call_providers("progression_start", progression_category, level)
end


--- 
---@param progression_category string
---@param level integer|string
---@param score number|nil
function M.progression_complete(progression_category, level, score)
    logger:debug("progression_complete called", { progression_category = progression_category, level = level, score = score })
    call_providers("progression_complete", progression_category, level, score)
end

--- 
---@param progression_category string
---@param level integer|string
function M.progression_fail(progression_category, level)
    logger:debug("progression_fail called", { progression_category = progression_category, level = level })
    call_providers("progression_fail", progression_category, level)
end


--- Установка свойства пользователя
---@param property_name string
---@param property_value string|number|boolean|nil
function M.set_user_property(property_name, property_value)
    logger:debug("set_user_property called", { property_name = property_name, property_value = property_value })
    call_providers("set_user_property", property_name, property_value)
end

--- Логирование сообщения
---@param log_level string Уровень логирования
---@param message string Сообщение
function M.log(log_level, message)
    if log.is_valid_level(log_level, M.config.log_level) and not tablex.is_empty(M.runtime.providers) then
	    call_providers("log", log_level, message)
    end
end

--------------------------------------------------
--- Fun lifecycle callbacks
--------------------------------------------------

function M.fun_init()
    local target_config = target.get_module_config("analytics")
    if not target_config then
        logger:warn("\"analytics\": { \"providers\": [\"...\", \"...\", \"...\"] } is missing in target configuration file")
        return
    end

    for _, provider_name in ipairs(tablex.keys(target_config)) do
        local status, err = pcall(init_provider, provider_name)
        if not status then
            logger:error("Error registering analytics provider: " .. tostring(err))
        end
    end

    -- Если включено логирование в конфиге, то добавляем слушатель на логи
    M.config = gamedata.get_module_config("analytics", M.default_config)
    if M.config.log_level then
        log.add_log_listener(M.log)
    end

    logger:info("Analytics initialized")
end


function M.fun_final()
    call_providers("final")
end

return M