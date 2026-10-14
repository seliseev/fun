--- Базовый класс для провайдеров аналитики
--- Использует паттерн наследования через метатаблицы, аналогичный druid.widget

local log = require("fun.libs.log")
local base_provider = require("fun.modules.analytics.base_provider")
local fun_firebase = require("fun.modules.firebase")

local logger = log.get_logger("fun.analytics.fib")

---@class fun.analytics.firebase: fun.analytics.base_provider
local M = {}
-- Наследование от базового класса через метатаблицу
setmetatable(M, { __index = base_provider })

local function firebase_analytics_callback(self, message_id, message)
    if message_id == firebase.analytics.MSG_ERROR then
        -- an error was detected when performing an analytics config operation
        logger:error("Firebase Analytics Config error: ", message.error)
        return
    end

    if message_id == firebase.analytics.MSG_INSTANCE_ID then
        -- result of the firebase.analytics.get_id() call
        logger:debug("Firebase Analytics Config instance_id: ", message.instance_id)
        return
    end
end

local function on_firebase_initialized()
    logger:debug("Firebase initialized, initializing analytics")
    firebase.analytics.set_callback(firebase_analytics_callback)
    firebase.analytics.initialize()

    --- TODO: Когда будем честный запрос GDPR, то нужно будет убрать этот флаг
    firebase.analytics.set_enabled(true)
end

--- Инициализация провайдера
---@param config table|nil Конфигурация провайдера
function M:init(config)
    if not firebase or not firebase.analytics then
        logger:warn("firebase.analytics extension is not available at this platform")
        return
    end

    logger:debug("Initializing Firebase analytics")

    -- Сохраняем конфиг провайдера (если он передан) для возможного будущего использования
    self._provider.config = config or self._provider.config

    -- Инициализацию analytics делаем после инициализации основного firebase
    fun_firebase.on_initialized:subscribe(on_firebase_initialized)
end

--- Покупка, в firebase обрабатывается автоматически, поэтому не нужно логировать это событие
---@param lot fun.iapservice.lot
---@param transaction fun.iap.transaction
---@param placement string|nil Место где была совершена покупка
function M:purchase(lot, transaction, placement)
    
    -- if not firebase or not firebase.analytics then
    --     logger:warn("firebase.analytics extension is not available at this platform")
    --     return
    -- end

    -- if not lot or not lot.product then
    --     logger:warn("purchase: invalid lot or product", { lot = lot })
    --     return
    -- end

    -- placement = placement or "unknown"

    -- -- Согласно документации Firebase Analytics:
    -- --   Event:  FirebaseAnalytics.Event.PURCHASE        -> "purchase"
    -- --   Params: FirebaseAnalytics.Param.VALUE           -> "value"
    -- --           FirebaseAnalytics.Param.CURRENCY        -> "currency"
    -- --           FirebaseAnalytics.Param.ITEM_ID         -> "item_id"
    -- --           FirebaseAnalytics.Param.ITEM_CATEGORY   -> "item_category"
    -- --           FirebaseAnalytics.Param.TRANSACTION_ID  -> "transaction_id"
    -- -- См. https://firebase.google.com/docs/reference/android/com/google/firebase/analytics/FirebaseAnalytics.Event
    -- local value = lot.product.price or lot.usd_price or 0
    -- local currency = lot.product.currency_code or "USD"

    -- firebase.analytics.log_table("purchase", {
    --     value = value,
    --     currency = currency,
    --     item_id = lot.sku,
    --     item_category = lot.category or "unknown",
    --     item_name = lot.sku,
    --     quantity = 1,
    --     transaction_id = transaction and transaction.transaction_id or nil,
    --     placement = placement,
    -- })

    -- logger:debug("purchase: event posted", {
    --     value = value,
    --     currency = currency,
    --     item_id = lot.sku,
    --     item_category = lot.category or "unknown",
    --     item_name = lot.sku,
    --     quantity = 1,
    --     transaction_id = transaction and transaction.transaction_id or nil,
    --     placement = placement,
    -- })
end

--- Показ рекламы с наградой
---@param placement_id string
---@param ad_sdk_name string
function M:ad_rw_show(placement_id, ad_sdk_name)
    if not firebase or not firebase.analytics then
        logger:warn("firebase.analytics extension is not available")
        return
    end

    firebase.analytics.log_table("custom_ad_impression", {
        ad_platform = ad_sdk_name,
        ad_source = ad_sdk_name,
        ad_unit_name = placement_id,
        ad_format = "rewarded"
    })

    logger:debug("ad_rw_show: event posted 'custom_ad_impression'", {
        ad_platform = ad_sdk_name,
        ad_source = ad_sdk_name,
        ad_unit_name = placement_id,
        ad_format = "rewarded"
    })
end

--- Получение награды за рекламу
---@param placement_id string
---@param ad_sdk_name string
function M:ad_rw_reward_received(placement_id, ad_sdk_name)
    if not firebase or not firebase.analytics then
        logger:warn("firebase.analytics extension is not available")
        return
    end

    -- Логируем выдачу награды за просмотр rewarded‑рекламы
    firebase.analytics.log_table("ad_rw_reward_received", {
        ad_platform = ad_sdk_name,
        ad_unit_name = placement_id,
        ad_format = "rewarded",
    })

    logger:debug("ad_rw_reward_received: event posted 'ad_rw_reward_received'", {
        ad_platform = ad_sdk_name,
        ad_unit_name = placement_id,
        ad_format = "rewarded",
    })
end

--- Ошибка показа рекламы с наградой
---@param placement_id string
---@param ad_sdk_name string
function M:ad_rw_failed_show(placement_id, ad_sdk_name)
    if not firebase or not firebase.analytics then
        logger:warn("firebase.analytics extension is not available")
        return
    end

    firebase.analytics.log_table("ad_impression_failed", {
        ad_platform = ad_sdk_name,
        ad_source = ad_sdk_name,
        ad_unit_name = placement_id,
        ad_format = "rewarded"
    })

    logger:debug("ad_rw_failed_show: event posted 'ad_impression_failed'", {
        ad_platform = ad_sdk_name,
        ad_source = ad_sdk_name,
        ad_unit_name = placement_id,
        ad_format = "rewarded"
    })
end

--- Показ межстраничной рекламы
---@param placement_id string
---@param ad_sdk_name string
function M:ad_inter_show(placement_id, ad_sdk_name)
    if not firebase or not firebase.analytics then
        logger:warn("firebase.analytics extension is not available")
        return
    end

    firebase.analytics.log_table("custom_ad_impression", {
        ad_platform = ad_sdk_name,
        ad_source = ad_sdk_name,
        ad_unit_name = placement_id,
        ad_format = "interstitial"
    })

    logger:debug("ad_inter_show: event posted 'custom_ad_impression'", {
        ad_platform = ad_sdk_name,
        ad_source = ad_sdk_name,
        ad_unit_name = placement_id,
        ad_format = "interstitial"
    })
end

--- Ошибка показа межстраничной рекламы
---@param placement_id string
---@param ad_sdk_name string
function M:ad_inter_failed_show(placement_id, ad_sdk_name)
    if not firebase or not firebase.analytics then
        logger:warn("firebase.analytics extension is not available at this platform")
        return
    end

    firebase.analytics.log_table("ad_impression_failed", {
        ad_platform = ad_sdk_name,
        ad_source = ad_sdk_name,
        ad_unit_name = placement_id,
        ad_format = "interstitial"
    })

    logger:debug("ad_inter_failed_show: event posted 'ad_impression_failed'", {
        ad_platform = ad_sdk_name,
        ad_source = ad_sdk_name,
        ad_unit_name = placement_id,
        ad_format = "interstitial"
    })
end

--- Показ баннерной рекламы
---@param placement_id string
---@param ad_sdk_name string
function M:ad_banner_show(placement_id, ad_sdk_name)
    if not firebase or not firebase.analytics then
        logger:warn("firebase.analytics extension is not available at this platform")
        return
    end

    firebase.analytics.log_table("custom_ad_impression", {
        ad_platform = ad_sdk_name,
        ad_source = ad_sdk_name,
        ad_unit_name = placement_id,
        ad_format = "banner"
    })

    logger:debug("ad_banner_show: event posted 'custom_ad_impression'", {
        ad_platform = ad_sdk_name,
        ad_source = ad_sdk_name,
        ad_unit_name = placement_id,
        ad_format = "banner"
    })
end

--- Ошибка показа баннерной рекламы
---@param placement_id string
---@param ad_sdk_name string
function M:ad_banner_failed_show(placement_id, ad_sdk_name)
    if not firebase or not firebase.analytics then
        logger:warn("firebase.analytics extension is not available at this platform")
        return
    end

    firebase.analytics.log_table("ad_impression_failed", {
        ad_platform = ad_sdk_name,
        ad_source = ad_sdk_name,
        ad_unit_name = placement_id,
        ad_format = "banner",
        ad_type = "banner",
    })

    logger:debug("ad_banner_failed_show: event posted 'ad_impression_failed'", {
        ad_platform = ad_sdk_name,
        ad_source = ad_sdk_name,
        ad_unit_name = placement_id,
        ad_format = "banner"
    })
end

--- Добавление ресурса
---@param resource string
---@param amount number
---@param source string
---@param item_id string|nil
function M:resource_added(resource, amount, source, item_id)
    if not firebase or not firebase.analytics then
        logger:warn("firebase.analytics extension is not available at this platform")
        return
    end

    -- Соответствие рекомендованному ивенту:
    --   FirebaseAnalytics.Event.EARN_VIRTUAL_CURRENCY -> "earn_virtual_currency"
    --   Params: VIRTUAL_CURRENCY_NAME("virtual_currency_name"), VALUE("value")
    -- См. https://firebase.google.com/docs/reference/android/com/google/firebase/analytics/FirebaseAnalytics.Event
    firebase.analytics.log_table("earn_virtual_currency", {
        virtual_currency_name = resource,
        value = amount
    })

    logger:debug("resource_added: event posted 'earn_virtual_currency'", {
        virtual_currency_name = resource,
        value = amount
    })
end

--- Трата ресурса
---@param resource string Идентификатор ресурса, который потратили
---@param amount number Количество ресурса, которое было потрачено
---@param for_what string Категория трат ресурса: start_game, booster, etc
---@param item_id string|nil Идентификатор предмета который получил игрок за эту трату, может быть пустым
function M:resource_spent(resource, amount, for_what, item_id)
    if not firebase or not firebase.analytics then
        logger:warn("firebase.analytics extension is not available")
        return
    end

    -- Соответствие рекомендованному ивенту:
    --   FirebaseAnalytics.Event.SPEND_VIRTUAL_CURRENCY -> "spend_virtual_currency"
    
    local item_name = for_what
    if item_id then
        item_name = item_name .. "_" .. item_id
    end

    firebase.analytics.log_table("spend_virtual_currency", {
        virtual_currency_name = resource,
        value = amount,
        item_name = item_name
    })

    logger:debug("resource_spent: event posted 'spend_virtual_currency'", {
        virtual_currency_name = resource,
        value = amount,
        item_name = item_name
    })
end

--- Начало прогрессии
---@param progression_category string
---@param level integer|string
function M:progression_start(progression_category, level)
    if not firebase or not firebase.analytics then
        logger:warn("firebase.analytics extension is not available")
        return
    end

    -- Рекомендованный ивент:
    --   FirebaseAnalytics.Event.LEVEL_START -> "level_start"
    firebase.analytics.log_table("level_start", {
        level = tostring(level)
    })

    logger:debug("progression_start: event posted 'level_start'", {
        level = tostring(level)
    })
end

--- Завершение прогрессии
---@param progression_category string
---@param level integer|string
---@param score number|nil
function M:progression_complete(progression_category, level, score)
    if not firebase or not firebase.analytics then
        logger:warn("firebase.analytics extension is not available")
        return
    end

    -- Рекомендованный ивент:
    --   FirebaseAnalytics.Event.LEVEL_END -> "level_end"
    firebase.analytics.log_table("level_end", {
        level = tostring(level),
        success = true,
    })

    logger:debug("progression_complete: event posted 'level_end'", {
        level = tostring(level),
        success = true,
    })
end

--- Провал прогрессии
---@param progression_category string
---@param level integer|string
function M:progression_fail(progression_category, level)
    if not firebase or not firebase.analytics then
        logger:warn("firebase.analytics extension is not available")
        return
    end

    firebase.analytics.log_table("level_end", {
        level = tostring(level),
        success = false,
    })

    logger:debug("progression_fail: event posted 'level_end'", {
        level = tostring(level),
        success = false,
    })
end


--- Установка свойства пользователя
---@param property_name string
---@param property_value string|number|boolean|nil
function M:set_user_property(property_name, property_value)
    if not firebase or not firebase.analytics then
        logger:warn("firebase.analytics extension is not available")
        return
    end

    firebase.analytics.set_user_property(property_name, tostring(property_value))

    logger:debug("set_user_property: firebase user property set", {
        property_name = property_name,
        property_value = property_value,
    })
end

--- Логирование сообщения
---@param log_level string Уровень логирования
---@param message string Сообщение
function M:log(log_level, message)
    --- Сделать при помощи crashlytics
end

--- Финализация провайдера (переопределяется в дочерних классах)
function M:final()
    if not firebase or not firebase.analytics then
        return
    end

    -- Снимаем callback, чтобы не держать лишние ссылки
    firebase.analytics.set_callback(nil)
    fun_firebase.on_initialized:unsubscribe(on_firebase_initialized)
end

return M

