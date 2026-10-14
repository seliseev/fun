local log = require("fun.libs.log")

local device = require("fun.modules.device")
local target = require("fun.modules.target")
local base_provider = require("fun.modules.analytics.base_provider")

local logger = log.get_logger("fun.analytics.ga")

--- @class fun.analytics.gameanalytics: fun.analytics.base_provider
local M = {}

local AD_ACTION = {
    CLICKED = "Clicked",
    SHOW = "Show",
    FAILED_TO_SHOW = "FailedShow",
    REWARD_RECEIVED = "RewardReceived",
}

local AD_TYPE = {
    VIDEO = "Video",
    REWARDED_VIDEO = "RewardedVideo",
    PLAYABLE = "Playable",
    INTERSTITIAL = "Interstitial",
    OFFERWALL = "OfferWall",
    BANNER = "Banner",
}

local LEVEL_TO_SEVERITY_MAP = {
    ["TRACE"] = "Debug",
    ["DEBUG"] = "Debug",
    ["INFO"] = "Info",
    ["WARN"] = "Warning",
    ["ERROR"] = "Error",
    ["FATAL"] = "Critical",
}


--- Инициализация провайдера
---@param config table|nil Конфигурация провайдера
function M:init(config)
    assert(gameanalytics, "GameAnalytics extension is not available at this platform")

    self._provider.config = config or self._provider.config or target.get_module_parameter("analytics", "gameanalytics")

    if not config or not config.game_key or not config.secret_key then
        logger:error("\"analytics\": { \"gameanalytics\": { \"game_key\": \"...\", \"secret_key\": \"...\" } } is missing in target configuration file")
        return
    end
    
    ---@type table<string, function>
    self.custom_dimenstion_cast = {}
    if config.custom_dimensions_01 then
        self.custom_dimenstion_cast[config.custom_dimensions_01] = gameanalytics.setCustomDimension01
    end
    
    if config.custom_dimensions_02 then
        self.custom_dimenstion_cast[config.custom_dimensions_02] = gameanalytics.setCustomDimension02
    end
    
    if config.custom_dimensions_03 then
        self.custom_dimenstion_cast[config.custom_dimensions_03] = gameanalytics.setCustomDimension03
    end

    gameanalytics.initialize()

    logger:info("GameAnalytics initialized")
end


--- @param lot fun.iapservice.lot
--- @param transaction fun.iap.transaction
--- @param placement string|nil Место где была совершена покупка
function M:purchase(lot, transaction, placement)
    if not gameanalytics then
        logger:warn("gameanalytics extension is not available at this platform")
        return
    end

    placement = placement or "unknown"
    logger:debug("purchase called", { sku = lot and lot.sku, placement = placement })

    if device.is_android() then
        gameanalytics.addBusinessEvent {
            currency = lot.product.currency_code,
            amount = lot.product.price_in_cents,
            itemType = lot.category or "unknown",
            itemId = lot.sku,
            cartType = placement,
            receipt = transaction.receipt,
            signature = transaction.signature
        }
        logger:info("purchase: business event added (Android)")
    elseif device.is_ios() then
        logger:error("purchase: iOS not implemented")
    else
        logger:error("purchase: unsupported platform")
    end
end


--- @param placement_id string
--- @param ad_sdk_name string
function M:ad_rw_show(placement_id, ad_sdk_name)
    if not gameanalytics then
        logger:warn("gameanalytics extension is not available at this platform")
        return
    end

    gameanalytics.addAdEvent {
        adAction = AD_ACTION.SHOW,
        adType = AD_TYPE.REWARDED_VIDEO,
        adSdkName = ad_sdk_name,
        adPlacement = placement_id
    }
    
    logger:debug("ad_rw_show: event added", { placement_id = placement_id, ad_sdk_name = ad_sdk_name })
end


--- @param placement_id string
--- @param ad_sdk_name string
function M:ad_rw_reward_received(placement_id, ad_sdk_name)
    if not gameanalytics then
        logger:warn("gameanalytics extension is not available at this platform")
        return
    end

    logger:debug("ad_rw_reward_received called", { placement_id = placement_id, ad_sdk_name = ad_sdk_name })
    
    gameanalytics.addAdEvent {
        adAction = AD_ACTION.REWARD_RECEIVED,
        adType = AD_TYPE.REWARDED_VIDEO,
        adSdkName = ad_sdk_name,
        adPlacement = placement_id
    }
end


--- @param placement_id string
--- @param ad_sdk_name string
function M:ad_rw_failed_show(placement_id, ad_sdk_name)
    if not gameanalytics then
        logger:warn("gameanalytics extension is not available at this platform")
        return
    end

    logger:debug("ad_rw_failed_show called", { placement_id = placement_id, ad_sdk_name = ad_sdk_name })
    
    gameanalytics.addAdEvent {
        adAction = AD_ACTION.FAILED_TO_SHOW,
        adType = AD_TYPE.REWARDED_VIDEO,
        adSdkName = ad_sdk_name,
        adPlacement = placement_id
    }
end


--- @param placement_id string
--- @param ad_sdk_name string
function M:ad_inter_show(placement_id, ad_sdk_name)
    if not gameanalytics then
        logger:warn("gameanalytics extension is not available at this platform")
        return
    end

    logger:debug("ad_inter_show called", { placement_id = placement_id, ad_sdk_name = ad_sdk_name })
    
    gameanalytics.addAdEvent {
        adAction = AD_ACTION.SHOW,
        adType = AD_TYPE.INTERSTITIAL,
        adSdkName = ad_sdk_name,
        adPlacement = placement_id
    }
end


--- @param placement_id string
--- @param ad_sdk_name string
function M:ad_inter_failed_show(placement_id, ad_sdk_name)
    if not gameanalytics then
        logger:warn("gameanalytics extension is not available at this platform")
        return
    end

    gameanalytics.addAdEvent {
        adAction = AD_ACTION.FAILED_TO_SHOW,
        adType = AD_TYPE.INTERSTITIAL,
        adSdkName = ad_sdk_name,
        adPlacement = placement_id
    }

    logger:debug("ad_inter_failed_show: event posted", { placement_id = placement_id, ad_sdk_name = ad_sdk_name })
end


--- @param placement_id string
--- @param ad_sdk_name string
function M:ad_banner_show(placement_id, ad_sdk_name)
    if not gameanalytics then
        logger:warn("gameanalytics extension is not available at this platform")
        return
    end

    gameanalytics.addAdEvent {
        adAction = AD_ACTION.SHOW,
        adType = AD_TYPE.BANNER,
        adSdkName = ad_sdk_name,
        adPlacement = placement_id
    }

    logger:debug("ad_banner_show: event posted", { placement_id = placement_id, ad_sdk_name = ad_sdk_name })
end


--- @param placement_id string
--- @param ad_sdk_name string
function M:ad_banner_failed_show(placement_id, ad_sdk_name)
    if not gameanalytics then
        logger:warn("gameanalytics extension is not available at this platform")
        return
    end
    
    gameanalytics.addAdEvent {
        adAction = AD_ACTION.FAILED_TO_SHOW,
        adType = AD_TYPE.BANNER,
        adSdkName = ad_sdk_name,
        adPlacement = placement_id
    }
    
    logger:debug("ad_banner_failed_show: event posted", { placement_id = placement_id, ad_sdk_name = ad_sdk_name })
end


--- 
---@param resource string
---@param amount number
---@param source string
---@param item_id string|nil
function M:resource_added(resource, amount, source, item_id)
    if not gameanalytics then
        logger:warn("gameanalytics extension is not available at this platform")
        return
    end

    item_id = item_id or ""
    logger:debug("resource_added called", { resource = resource, amount = amount, source = source, item_id = item_id })

    gameanalytics.addResourceEvent {
        flowType = "Source",
        currency = resource,
        amount = amount,
        itemType = source,
        itemId = source
    }
end


---
---@param resource string
---@param amount number
---@param for_what string Категория трат ресурса: start_game, booster, etc
---@param item_id string|nil Идентификатор предмета, может быть пустым
function M:resource_spent(resource, amount, for_what, item_id)
    if not gameanalytics then
        logger:warn("gameanalytics extension is not available at this platform")
        return
    end
    item_id = item_id or ""

    gameanalytics.addResourceEvent {
        flowType = "Sink",
        currency = resource,
        amount = amount,
        itemType = for_what,
        itemId = item_id
    }
    logger:debug("resource_spent: event posted", { resource = resource, amount = amount, for_what = for_what, item_id = item_id })
end


--- 
---@param progression_category string
---@param level integer|string
function M:progression_start(progression_category, level)
    if not gameanalytics then
        logger:warn("gameanalytics extension is not available at this platform")
        return
    end
    
    level = tostring(level)
    gameanalytics.addProgressionEvent {
        progressionStatus = "Start",
        progression01 = progression_category,
        progression02 = level,
    }
    logger:debug("progression_start: event posted", { progression_category = progression_category, level = level })
end


--- 
---@param progression_category string
---@param level integer|string
---@param score number|nil
function M:progression_complete(progression_category, level, score)
    if not gameanalytics then
        logger:warn("gameanalytics extension is not available at this platform")
        return
    end
    
    local level_str = tostring(level)
    local value = score or 0
    
    gameanalytics.addProgressionEvent {
        progressionStatus = "Complete",
        progression01 = progression_category,
        progression02 = level_str,
        score = value
    }
    
    logger:debug("progression_complete: event posted", { progression_category = progression_category, level = level, score = score })
end


--- 
---@param progression_category string
---@param level integer|string
function M:progression_fail(progression_category, level)
    if not gameanalytics then
        logger:warn("gameanalytics extension is not available at this platform")
        return
    end

    
    level = tostring(level)
    gameanalytics.addProgressionEvent {
        progressionStatus = "Fail",
        progression01 = progression_category,
        progression02 = level,
    }
    
    logger:debug("progression_fail: event posted", { progression_category = progression_category, level = level })
end


--- Установка свойства пользователя
--- В gameanalytics есть только 3 custom dimensions, поэтому мы ограничиваемся ими
--- Чтобы работал этот метод, нужно добавить property_name в targets.json которым соответствует custom_dimensions_01, custom_dimensions_02, custom_dimensions_03 
--- Все остальные property_name будут игнорироваться и логироваться как warning
--- например: 
--- "custom_dimensions_01": "language",
--- "custom_dimensions_02": "cohort"
--- "custom_dimensions_03": "payer"
---@param property_name string
---@param property_value string|number|boolean|nil
function M:set_user_property(property_name, property_value)
    if not gameanalytics then
        logger:warn("gameanalytics extension is not available at this platform")
        return
    end

    if not self.custom_dimenstion_cast[property_name] then
        logger:warn("set_user_property: custom dimension not found", { property_name = property_name })
        return
    end

    self.custom_dimenstion_cast[property_name](property_value)

    logger:debug("set_user_property: gameanalytics user property set", { property_name = property_name, property_value = property_value })
end

--- Логирование сообщения
---@param log_level string Уровень логирования
---@param message string Сообщение
function M:log(log_level, message)
    if not gameanalytics then
        return
    end

    gameanalytics.addErrorEvent {
        severity = LEVEL_TO_SEVERITY_MAP[log_level],
        message = message
    }
end

-- Наследование от базового класса через метатаблицу
setmetatable(M, { __index = base_provider })

return M