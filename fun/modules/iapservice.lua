--- FUN Module: IAP Service
--- Module for working with IAP on top of iap.lua module


local log = require("fun.libs.log")
local event = require("event.event")

local tablex = require("fun.libs.tablex")
local timex = require("fun.libs.timex")

local iap = require("fun.modules.iap.iap")
local iap_events = require("fun.modules.iap.events")
local gamedata = require("fun.modules.gamedata")
local target = require("fun.modules.target")
local wallet = require("fun.modules.wallet")

local logger = log.get_logger("fun.iapservice")

--- @class fun.iapservice.purchase_record
--- @field timestamp number Время покупки в секундах
--- @field usd_price number Цена покупки в USD

--- @class fun.iapservice.lot
--- @field sku string Идентификатор лота
--- @field category string Категория лота, используется для аналитики
--- @field reward string Идентификатор группы наград из token
--- @field usd_price number Цена лота в USD, берётся из gamedata.json! Только для сбора статистики и сегментации пользователей
--- @field product fun.iap.product|nil Продукт, инициализируется после загрузки продуктов из провайдера IAP в функции on_list_products

--- @class fun.iapservice.events.on_purchase_start: event
--- @field trigger fun(_, lot: fun.iapservice.lot, transaction: fun.iap.transaction, metadata: fun.iapservice.runtime.metadata)
--- @field subscribe fun(_, callback: fun(lot: fun.iapservice.lot, transaction: fun.iap.transaction, metadata: fun.iapservice.runtime.metadata), _)

--- @class fun.iapservice.events.on_purchase_end: event
--- @field trigger fun(_, success: boolean, lot: fun.iapservice.lot|nil, transaction: fun.iap.transaction|nil, metadata: fun.iapservice.runtime.metadata|nil, error: table|nil)
--- @field subscribe fun(_, callback: fun(success: boolean, lot: fun.iapservice.lot, transaction: fun.iap.transaction, metadata: fun.iapservice.runtime.metadata, error: table|nil), _)

--- @class fun.iapservice.events.on_purchase_cancelled: event
--- @field trigger fun(_)
--- @field subscribe fun(_, callback: fun(_), _): boolean

--- @class fun.iapservice.events.on_purchase_restored: event - Non-consumable lot owned by the player was restored from the store (no revenue, no reward popup)
--- @field trigger fun(_, lot: fun.iapservice.lot, transaction: fun.iap.transaction)
--- @field subscribe fun(_, callback: fun(lot: fun.iapservice.lot, transaction: fun.iap.transaction), _)

--- @class fun.iapservice.runtime.metadata
--- @field placement string|nil Место где была совершена покупка


--- @class fun.iapservice
local M = {
    runtime = {
        --- Реестр запущенных покупок
        ---@type table<string, fun.iapservice.runtime.metadata> purchases_metadata[sku] = fun.iapservice.runtime.metadata
        purchases_metadata = {},

        --- Реестр соответствия SKU и product_id
        ---@type table<string, string> 
        sku_to_product_id = {},

        --- Список продуктов с ценами, появляется после успешной загрузки от провайдера IAP
        ---@type table<string, fun.iap.product> products[SKU] = fun.iap.product
        products = {},

        --- Список лотов доступных в игре закгружается из конфига
        ---@type table<string, fun.iapservice.lot> lots[SKU] = fun.iapservice.lot
        lots = {}
    },
    state = {
        lifetime_purchases = 0,
        lifetime_revenue = 0,
        ---@type fun.iapservice.purchase_record[]
        purchase_records = {}
    }
}

M.on_purchase_start = event.create()       --[[@as fun.iapservice.events.on_purchase_start]]
M.on_purchase_end = event.create()         --[[@as fun.iapservice.events.on_purchase_end]]
M.on_purchase_cancelled = event.create()    --[[@as fun.iapservice.events.on_purchase_cancelled]]
M.on_purchase_restored = event.create()     --[[@as fun.iapservice.events.on_purchase_restored]]


--------------------------------------------------
--- Private functions
--------------------------------------------------


--------------------------------------------------
--- Event callbacks
--------------------------------------------------

local delay_to_list_products = 1 -- секунд
local max_delay_to_list_products = 10 -- секунд

--- Обработка события завершения запроса списка продуктов
---@param success boolean
---@param products fun.iap.product[]
---@param error table|nil
local function on_list_products(success, products, error)
    if success then
        delay_to_list_products = 1

        for _, product in ipairs(products) do
            local sku = M.get_sku_for_product_id(product.id)
            if sku then
                M.runtime.products[sku] = product
                if M.runtime.lots[sku] then
                    M.runtime.lots[sku].product = product
                else
                    logger:warn("Lot not found for SKU", {sku = sku, product_id = product.id})
                end
            else
                logger:warn("Can't find SKU for product ID", {product_id = product.id})
            end
        end
        logger:debug("Products loaded", {products = M.runtime.products})
    else
        logger:error("Failed to load products", {error = error})
        timer.delay(delay_to_list_products, false, function (self, handle, time_elapsed)
            iap.list_products(tablex.values(M.runtime.sku_to_product_id))
            delay_to_list_products = delay_to_list_products + 1
            delay_to_list_products = math.min(delay_to_list_products, max_delay_to_list_products)
        end)
    end
end


--- Обработка события начала покупки
---@param transaction fun.iap.transaction
local function on_purchase_start(transaction)
    logger:info("Purchase started", {transaction = transaction})
    
    local sku = M.get_sku_for_product_id(transaction.product_id)
    if not sku then
        logger:error("SKU not found", {product_id = transaction.product_id})
        return
    end
    
    local lot = M.get_lot(sku)
    if not lot then
        logger:error("Lot not found", {sku = sku})
        return
    end

    M.on_purchase_start:trigger(lot, transaction, M.runtime.purchases_metadata[sku])
end


--- Обработка события завершения покупки
---@param transaction fun.iap.transaction
local function on_purchase_purchased(transaction)
    logger:info("Purchase purchased", {transaction = transaction})

    -- Ищем SKU по product_id
    local sku = M.get_sku_for_product_id(transaction.product_id)
    if not sku then
        logger:error("SKU not found", {product_id = transaction.product_id})
        return
    end

    -- Ищем лот по SKU
    local lot = M.get_lot(sku)
    if not lot then
        logger:error("Lot not found", {sku = sku})
        return
    end

    -- Логируем статистику
    local DAYS_TO_KEEP_PURCHASE_RECORDS = 31
    M.state.lifetime_purchases = M.state.lifetime_purchases + 1
    M.state.lifetime_revenue = M.state.lifetime_revenue + lot.usd_price
    table.insert(M.state.purchase_records, {timestamp = timex.get_time(), usd_price = lot.usd_price})
    tablex.remove_if(M.state.purchase_records, function(record)
        local diff = timex.get_time() - record.timestamp
        return timex.convert_to_days(diff) > DAYS_TO_KEEP_PURCHASE_RECORDS
    end)

    -- Выдаём награды
    wallet.add_group(lot.reward, "iap", sku, true)

    -- Триггерим событие завершения покупки
    M.on_purchase_end:trigger(true, lot, transaction, M.runtime.purchases_metadata[sku])

    M.runtime.purchases_metadata[sku] = nil

    logger:info("Lot purchased", {lot = lot, transaction = transaction})
end


--- Обработка события неудачной покупки
---@param transaction fun.iap.transaction
local function on_purchase_failed(transaction, error)
    -- Ищем SKU по product_id
    local sku = M.get_sku_for_product_id(transaction.product_id)
    if not sku then
        logger:error("SKU not found", {product_id = transaction.product_id})
        return
    end

    M.on_purchase_end:trigger(false, nil, transaction, M.runtime.purchases_metadata[sku], error)

    M.runtime.purchases_metadata[sku] = nil

    logger:info("Purchase failed", {transaction = transaction, error = error})
end


--- Обработка события восстановления покупки
---@param transaction fun.iap.transaction
local function on_purchase_restored(transaction)
    logger:info("Purchase restored", {transaction = transaction})

    local sku = M.get_sku_for_product_id(transaction.product_id)
    if not sku then
        logger:error("SKU not found", {product_id = transaction.product_id})
        return
    end

    local lot = M.get_lot(sku)
    if not lot then
        logger:error("Lot not found", {sku = sku})
        return
    end

    M.on_purchase_restored:trigger(lot, transaction)
end


--- Обработка события непроверенной покупки
--- Награду не выдаём, но покупку завершаем неуспешно: иначе игра ждёт on_purchase_end вечно,
--- а лот остаётся в реестре запущенных покупок и его нельзя купить снова
---@param transaction fun.iap.transaction
local function on_purchase_unverified(transaction)
    logger:info("Purchase unverified", {transaction = transaction})

    local sku = M.get_sku_for_product_id(transaction.product_id)
    local metadata = sku and M.runtime.purchases_metadata[sku]
    if sku then
        M.runtime.purchases_metadata[sku] = nil
    end
    M.on_purchase_end:trigger(false, nil, transaction, metadata, {reason = "unverified"})
end

local function on_purchase_error(error)
    logger:error("Purchase error", {error = error})

    --- reason = 1 means "user cancelled purchase"
    if error.reason == 1 then
        M.on_purchase_cancelled:trigger()
    else
        -- Транзакции нет, но игра ждёт конца покупки: завершаем её неуспешно
        M.on_purchase_end:trigger(false, nil, nil, nil, error)
    end

    -- в случае ошибки мы не знаем какая именно транзакция сломалась, поэтому очищаем реестр запущенных покупок
    M.runtime.purchases_metadata = {}
end

--------------------------------------------------
--- IAP Service API
--------------------------------------------------

--- Возвращает информацию о лоте
---@param sku string @Идентификатор лота
---@return fun.iapservice.lot|nil
function M.get_lot(sku)
    return M.runtime.lots[sku]
end

--- Получить SKU продукта по реальному ID продукта
---@param product_id string
---@return string|nil
function M.get_sku_for_product_id(product_id)
    for sku, pid in pairs(M.runtime.sku_to_product_id) do
        if product_id == pid then
            return sku
        end
    end
    return nil
end


--- Купить лот. Запускает процесс покупки лота
---@param sku string @Идентификатор лота
---@param placement string|nil @Место где была совершена покупка
function M.purchase(sku, placement)

    --- Ищем лот по SKU
    local lot = M.get_lot(sku)
    if not lot then
        logger:error("Lot not found", {sku = sku})
        return
    end

    --- Проверяем, что продукт лота инициализирован (ответ приходит от платёжного провайдера в функции on_list_products)
    if not lot.product then
        logger:warn("Lot product not initialized", {sku = sku})
        return
    end

    --- Проверяем, что покупка не запущена уже
    if M.runtime.purchases_metadata[sku] then
        logger:warn("Purchase already started", {sku = sku})
        return
    end

    --- Запускаем покупку
    if iap.purchase(lot.product.id) then
        M.runtime.purchases_metadata[sku] = {
            placement = placement
        }
    end
end


function M.get_avg_transaction_value_lt()
    if M.state.lifetime_purchases == 0 then
        return 0
    end
    return M.state.lifetime_revenue / M.state.lifetime_purchases
end

--- Get average transaction value for last N days
---@param last_n_days integer|nil Number of days to get average transaction value for, if 0 - get average transaction value for all time
---@return number @Average transaction value for last N days
function M.get_avg_transaction_value(last_n_days)
    last_n_days = last_n_days or 0
    if last_n_days == 0 then
        return M.get_avg_transaction_value_lt()
    end
    local records = tablex.get_if(M.state.purchase_records, function(record)
        return timex.convert_to_days(timex.get_time() - record.timestamp) <= last_n_days
    end)
    if #records == 0 then
        return 0
    end

    local total_value = 0
    for _, record in ipairs(records) do
        total_value = total_value + record.usd_price
    end
    return total_value / #records
end

function M.get_revenue_lt()
    return M.state.lifetime_revenue
end

--- Get revenue for last N days or for all time if last_n_days is 0
---@param last_n_days integer Number of days to get revenue for, if 0 - get revenue for all time
---@return integer|nil @Revenue for last N days in $ or for all time if last_n_days is 0
function M.get_revenue(last_n_days)
    last_n_days = last_n_days or 0
    if last_n_days == 0 then
        return M.get_revenue_lt()
    end
    local records = tablex.get_if(M.state.purchase_records, function(record)
        return timex.convert_to_days(timex.get_time() - record.timestamp) <= last_n_days
    end)

    local total_value = 0
    for _, record in ipairs(records) do
        total_value = total_value + record.usd_price
    end
    return total_value
end

--------------------------------------------------
--- FUN Functions
--------------------------------------------------

-- function _validate_gamedata()
--     local config_iapservice = gamedata.get_module_config("iapservice")
--     if not config_iapservice then
--         logger:error("\"iapservice\" configuration not found in gamedata")
--         return
--     end
--     if not config_iapservice.lots then
--         logger:error("\"iapservice\": {\"lots\":[]} are missing in gamedata")
--         return
--     end

--     for i = 1, #config_iapservice.lots do
--         assert(config_iapservice.lots[i].sku, "Store lot 'sku' is missing in gamedata.json")
--         assert(config_iapservice.lots[i].reward, "Store lot reward is missing in gamedata.json")
--     end
-- end

function M.fun_init()
    -- Загружаем продукты из конфигурации target'а
    M.runtime.sku_to_product_id = target.get_module_parameter("iapservice", "products")
    if not M.runtime.sku_to_product_id then
        logger:error("IAP Service products are missing in target configuration")
        return
    end
    
    --- Загружаем список лотов из конфиграции
    local lots_config = gamedata.get_module_parameter("iapservice", "lots", nil)
    if lots_config then
        for _, lot in ipairs(lots_config) do
            M.runtime.lots[lot.sku] = lot
        end
    else
        logger:warn("Lots are missing in gamedata")
    end

    -- Подписываемся на событие завершения покупки
    iap_events.on_list_products:subscribe(on_list_products)
    iap_events.on_purchase_start:subscribe(on_purchase_start)
    iap_events.on_purchase_purchased:subscribe(on_purchase_purchased)
    iap_events.on_purchase_failed:subscribe(on_purchase_failed)
    iap_events.on_purchase_restored:subscribe(on_purchase_restored)
    iap_events.on_purchase_unverified:subscribe(on_purchase_unverified)
    iap_events.on_purchase_error:subscribe(on_purchase_error)

    logger:info("IAP Service initialized. Products count: " .. tablex.length(M.runtime.sku_to_product_id))
end

function M.fun_post_init()
    iap.list_products(tablex.values(M.runtime.sku_to_product_id))
end

function M.fun_final()
    iap_events.on_list_products:unsubscribe(on_list_products)
    iap_events.on_purchase_start:unsubscribe(on_purchase_start)
    iap_events.on_purchase_purchased:unsubscribe(on_purchase_purchased)
    iap_events.on_purchase_failed:unsubscribe(on_purchase_failed)
    iap_events.on_purchase_restored:unsubscribe(on_purchase_restored)
    iap_events.on_purchase_unverified:unsubscribe(on_purchase_unverified)
    iap_events.on_purchase_error:unsubscribe(on_purchase_error)
end

return M