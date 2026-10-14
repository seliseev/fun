local log = require("fun.libs.log")

local tablex = require("fun.libs.tablex")

local iap_events = require("fun.modules.iap.events")

local logger = log.get_logger("fun.iap.provider_dummy")

---@class fun.iap.provider.dummy: fun.iap.provider
local IAPProviderDummy = {}
IAPProviderDummy.__index = IAPProviderDummy

---@type fun.iap.product[]
local mock_products = {
    {
        id = "mock_product_1",
        title = "Mock Product 1",
        description = "Mock Product 1 Description",
        price = 1.99,
        price_string = "$1.99",
        currency_code = "USD",
        price_in_cents = 199
    },
    {
        id = "mock_product_2",
        title = "Mock Product 2",
        description = "Mock Product 2 Description",
        price = 4.99,
        price_string = "$4.99",
        currency_code = "USD",
        price_in_cents = 499
    }
}

---@type fun.iap.transaction[]
local mock_transactions = {
    {
        product_id = "mock_product_1",
        state = "mock_state_1",
        transaction_id = "mock_transaction_id_1",
        receipt = "mock_receipt_1"
    },
    {
        product_id = "mock_product_2",
        state = "mock_state_2",
        transaction_id = "mock_transaction_id_2",
        receipt = "mock_receipt_2"
    }
}

local RESPONSE_DELAY = 3

local function generate_random_product(product_id)
    local product = tablex.random(mock_products)
    product = tablex.deepcopy(product)
    product.id = product_id
    return product
end

local function generate_random_transaction(product_id)
    local transaction = tablex.random(mock_transactions)
    transaction = tablex.deepcopy(transaction)
    transaction.product_id = product_id
    return transaction
end

---Инициализация провайдера
function IAPProviderDummy:init()
    
end

---Получить список продуктов
---@param product_ids string[] Массив ID продуктов
function IAPProviderDummy:list_products(product_ids)
    timer.delay(RESPONSE_DELAY, false, function (self, handle, time_elapsed)
        local products = tablex.map(product_ids, generate_random_product)
        iap_events.on_list_products:trigger(true, products, nil)
    end)
end

---Купить продукт
---@param product_id string ID продукта
function IAPProviderDummy:purchase(product_id)
    local transaction = generate_random_transaction(product_id)
    
    timer.delay(0.1, false, function()
        iap_events.on_purchase_start:trigger(transaction)
    end)
    logger:debug("Purchase started", {product_id = product_id})
    
    timer.delay(0.5, false, function()
        logger:debug("test")
    end)

    timer.delay(RESPONSE_DELAY, false, function (self, handle, time_elapsed)
        local success = math.random(0, 100) < 50
        logger:debug("Purchase completed", {product_id = product_id, success = success})
        if success then
            iap_events.on_purchase_purchased:trigger(transaction, nil)
        else
            iap_events.on_purchase_failed:trigger(transaction, {error = "Purchase failed"})
        end
    end)
    
    return true
end

---Восстановить покупки (для iOS и подобных)
function IAPProviderDummy:restore() end

---Завершить транзакцию
---@param transaction_id string
function IAPProviderDummy:finish_transaction(transaction_id) end

---Обработка сообщений (опционально)
function IAPProviderDummy:on_message(message_id, message, sender) end

---Финализация (опционально)
function IAPProviderDummy:final() end


return IAPProviderDummy