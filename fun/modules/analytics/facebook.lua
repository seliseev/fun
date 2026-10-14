local log = require("fun.libs.log")

local target = require("fun.modules.target")
local base_provider = require("fun.modules.analytics.base_provider")

local logger = log.get_logger("fun.analytics.fb")

---@class fun.analytics.facebook.config
---@field auto_log_enabled boolean Автоматический логирование событий включено или нет. Если будет true - то события платежей purchase() будут игнорироваться, т.к. собираются автоматически.


--- @class fun.analytics.facebook: fun.analytics.base_provider
local M = {}

--- Инициализация провайдера
---@param config table|nil Конфигурация провайдера
function M:init(config)
    assert(facebook, "Facebook extension is not available at this platform")

    self._provider.config = config or self._provider.config or target.get_module_parameter("analytics", "facebook")

    -- Инициализация Facebook SDK
    facebook.init()

    -- Включаем использование событий
    facebook.enable_event_usage()

    logger:info("Facebook Analytics initialized")
end

--- Покупка
---@param lot fun.iapservice.lot
---@param transaction fun.iap.transaction
---@param placement string|nil Место где была совершена покупка
function M:purchase(lot, transaction, placement)
    -- logger:info("purchase called", { sku = lot and lot.sku, placement = placement })
    if not facebook then
        logger:warn("purchase: facebook extension not available")
        return
    end

    if self._provider.config and self._provider.config.auto_log_enabled then
        logger:debug("purchase: auto log enabled, skipping")
        return
    end

    local params = {
        [facebook.PARAM_CURRENCY] = lot.product.currency_code or "USD",
        [facebook.PARAM_CONTENT_ID] = lot.sku or "unknown",
        [facebook.PARAM_CONTENT_TYPE] = lot.category or "purchase",
        [facebook.PARAM_NUM_ITEMS] = 1,
    }

    if placement then
        params[facebook.PARAM_SOURCE_APPLICATION] = placement
    end

    local value = lot.product.price or 0
    
    facebook.post_event(facebook.EVENT_PURCHASED, value, params)
    logger:debug("purchase: event posted", { event = "EVENT_PURCHASED", value = value })
end

--- Показ рекламы с наградой (переопределяется в дочерних классах)
---@param placement_id string
---@param ad_sdk_name string
function M:ad_rw_show(placement_id, ad_sdk_name)
    if not facebook then
        logger:warn("ad_rw_show: facebook extension not available")
        return
    end

    local params = {
        [facebook.PARAM_CONTENT_ID] = placement_id,
        [facebook.PARAM_CONTENT_TYPE] = "rewarded_video",
        [facebook.PARAM_DESCRIPTION] = ad_sdk_name or "unknown",
    }

    facebook.post_event("ad_rewarded_show", 0, params)
    logger:debug("ad_rw_show: event posted", { event = "ad_rewarded_show" })
end

--- Получение награды за рекламу (переопределяется в дочерних классах)
---@param placement_id string
---@param ad_sdk_name string
function M:ad_rw_reward_received(placement_id, ad_sdk_name)
    if not facebook then
        logger:warn("ad_rw_reward_received: facebook extension not available")
        return
    end

    local params = {
        [facebook.PARAM_CONTENT_ID] = placement_id,
        [facebook.PARAM_CONTENT_TYPE] = "rewarded_video",
        [facebook.PARAM_DESCRIPTION] = ad_sdk_name or "unknown",
        [facebook.PARAM_SUCCESS] = "true",
    }

    facebook.post_event("ad_rewarded_reward_received", 0, params)
    logger:debug("ad_rw_reward_received: event posted", { event = "ad_rewarded_reward_received" })
end

--- Ошибка показа рекламы с наградой (переопределяется в дочерних классах)
---@param placement_id string
---@param ad_sdk_name string
function M:ad_rw_failed_show(placement_id, ad_sdk_name)
    if not facebook then
        logger:warn("ad_rw_failed_show: facebook extension not available")
        return
    end

    local params = {
        [facebook.PARAM_CONTENT_ID] = placement_id,
        [facebook.PARAM_CONTENT_TYPE] = "rewarded_video",
        [facebook.PARAM_DESCRIPTION] = ad_sdk_name or "unknown",
        [facebook.PARAM_SUCCESS] = "false",
    }

    facebook.post_event("ad_rewarded_failed_show", 0, params)
    logger:debug("ad_rw_failed_show: event posted", { event = "ad_rewarded_failed_show" })
end

--- Показ межстраничной рекламы (переопределяется в дочерних классах)
---@param placement_id string
---@param ad_sdk_name string
function M:ad_inter_show(placement_id, ad_sdk_name)
    if not facebook then
        logger:warn("ad_inter_show: facebook extension not available")
        return
    end

    local params = {
        [facebook.PARAM_CONTENT_ID] = placement_id,
        [facebook.PARAM_CONTENT_TYPE] = "interstitial",
        [facebook.PARAM_DESCRIPTION] = ad_sdk_name or "unknown",
    }

    facebook.post_event("ad_interstitial_show", 0, params)
    
    logger:debug("ad_inter_show: event posted", { event = "ad_interstitial_show" })
end

--- Ошибка показа межстраничной рекламы (переопределяется в дочерних классах)
---@param placement_id string
---@param ad_sdk_name string
function M:ad_inter_failed_show(placement_id, ad_sdk_name)
    if not facebook then
        logger:warn("ad_inter_failed_show: facebook extension not available")
        return
    end

    local params = {
        [facebook.PARAM_CONTENT_ID] = placement_id,
        [facebook.PARAM_CONTENT_TYPE] = "interstitial",
        [facebook.PARAM_DESCRIPTION] = ad_sdk_name or "unknown",
        [facebook.PARAM_SUCCESS] = "false",
    }

    facebook.post_event("ad_interstitial_failed_show", 0, params)
    
    logger:debug("ad_inter_failed_show: event posted", { event = "ad_interstitial_failed_show" })
end

--- Показ баннерной рекламы (переопределяется в дочерних классах)
---@param placement_id string
---@param ad_sdk_name string
function M:ad_banner_show(placement_id, ad_sdk_name)
    if not facebook then
        logger:warn("ad_banner_show: facebook extension not available")
        return
    end

    local params = {
        [facebook.PARAM_CONTENT_ID] = placement_id,
        [facebook.PARAM_CONTENT_TYPE] = "banner",
        [facebook.PARAM_DESCRIPTION] = ad_sdk_name or "unknown",
    }

    facebook.post_event("ad_banner_show", 0, params)

    logger:debug("ad_banner_show: event posted", { event = "ad_banner_show" })
end

--- Ошибка показа баннерной рекламы (переопределяется в дочерних классах)
---@param placement_id string
---@param ad_sdk_name string
function M:ad_banner_failed_show(placement_id, ad_sdk_name)
    if not facebook then
        logger:warn("ad_banner_failed_show: facebook extension not available")
        return
    end

    local params = {
        [facebook.PARAM_CONTENT_ID] = placement_id,
        [facebook.PARAM_CONTENT_TYPE] = "banner",
        [facebook.PARAM_DESCRIPTION] = ad_sdk_name or "unknown",
        [facebook.PARAM_SUCCESS] = "false",
    }

    facebook.post_event("ad_banner_failed_show", 0, params)

    logger:debug("ad_banner_failed_show: event posted", { event = "ad_banner_failed_show" })
end

--- Добавление ресурса
---@param resource string
---@param amount number
---@param source string
---@param item_id string|nil
function M:resource_added(resource, amount, source, item_id)
    logger:info("resource_spent: event not implemented")
end

--- Трата ресурса
---@param resource string
---@param amount number
---@param source string
---@param source_category string
function M:resource_spent(resource, amount, source, source_category)
    logger:info("resource_spent: event not implemented")
end

--- Начало прогрессии
---@param progression_category string
---@param level integer|string
function M:progression_start(progression_category, level)
    if not facebook then
        logger:warn("progression_start: facebook extension not available")
        return
    end

    local params = {
        [facebook.PARAM_CONTENT_ID] = progression_category or "unknown",
        [facebook.PARAM_CONTENT_TYPE] = "progression",
        [facebook.PARAM_LEVEL] = tostring(level or "0"),
    }

    facebook.post_event("progression_start", 0, params)
    
    logger:debug("progression_start: event posted", { event = "progression_start" })
end

--- Завершение прогрессии
---@param progression_category string
---@param level integer|string
---@param score number|nil
function M:progression_complete(progression_category, level, score)
    if not facebook then
        logger:warn("progression_complete: facebook extension not available")
        return
    end

    local params = {
        [facebook.PARAM_CONTENT_ID] = progression_category or "unknown",
        [facebook.PARAM_CONTENT_TYPE] = "progression",
        [facebook.PARAM_LEVEL] = tostring(level or "0"),
        [facebook.PARAM_SUCCESS] = "true",
    }

    local value = score or 0
    facebook.post_event(facebook.EVENT_ACHIEVED_LEVEL, value, params)
    
    logger:debug("progression_complete: event posted", { event = "EVENT_ACHIEVED_LEVEL", value = value })
end


--- Провал прогрессии
---@param progression_category string
---@param level integer|string
function M:progression_fail(progression_category, level)
    if not facebook then
        logger:warn("progression_fail: facebook extension not available")
        return
    end

    local params = {
        [facebook.PARAM_CONTENT_ID] = progression_category or "unknown",
        [facebook.PARAM_CONTENT_TYPE] = "progression",
        [facebook.PARAM_LEVEL] = tostring(level or "0"),
        [facebook.PARAM_SUCCESS] = "false",
    }

    facebook.post_event("progression_fail", 0, params)

    logger:debug("progression_fail: event posted", { event = "progression_fail" })
end


--- Установка свойства пользователя
---@param property_name string
---@param property_value string|number|boolean|nil
function M:set_user_property(property_name, property_value)
    if not facebook then
        logger:warn("set_user_property: facebook extension not available")
        return
    end

    logger:debug("set_user_property: event not implemented")
end

-- Наследование от базового класса через метатаблицу
setmetatable(M, { __index = base_provider })

return M

