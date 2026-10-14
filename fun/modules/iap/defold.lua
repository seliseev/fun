local log = require("fun.libs.log")

local tablex = require("fun.libs.tablex")

local iap_events = require("fun.modules.iap.events")
local logger = log.get_logger("fun.iap.defold")


local product_list_for_gp = {}


---@class fun.iap.provider.defold: fun.iap.provider
local M = {}
M.__index = M

---comment
---@param product table
---@return fun.iap.product
local function convert_to_fun_iap_product(product)
    return {
        id = product.ident,
        title = product.title,
        description = product.description,
        price = product.price,
        price_in_cents = product.price * 100,
        price_string = product.price_string,
        currency_code = product.currency_code,
    }
end

---@param transaction table
---@return fun.iap.transaction
local function convert_to_fun_iap_transaction(transaction)
    return {
        product_id = transaction.ident,
        state = transaction.state,
        transaction_id = transaction.trans_ident,
        receipt = transaction.receipt,
        signature = transaction.signature,
        original_json = transaction.original_json,
    }
end

local function iap_listener(self, transaction, error)
    if error == nil then
        if transaction.state == iap.TRANS_STATE_PURCHASING then
            logger:debug("Purchase state purchasing", {transaction = transaction})
            iap_events.on_purchase_start:trigger(convert_to_fun_iap_transaction(transaction))
        elseif transaction.state == iap.TRANS_STATE_PURCHASED then
            logger:debug("Purchase state purchased", {transaction = transaction})
            iap_events.on_purchase_purchased:trigger(convert_to_fun_iap_transaction(transaction))
        elseif transaction.state == iap.TRANS_STATE_UNVERIFIED then
            logger:debug("Purchase state unverified", {transaction = transaction})
            iap_events.on_purchase_unverified:trigger(convert_to_fun_iap_transaction(transaction))
        elseif transaction.state == iap.TRANS_STATE_FAILED then
            logger:error("Purchase state failed", {transaction = transaction})
            iap_events.on_purchase_failed:trigger(convert_to_fun_iap_transaction(transaction), error)
        elseif transaction.state == iap.TRANS_STATE_RESTORED then
            logger:debug("Purchase state restored", {transaction = transaction})
            iap_events.on_purchase_restored:trigger(convert_to_fun_iap_transaction(transaction))
        end
    else
        -- logger:error("Purchase error", {error = error, transaction = transaction})
        iap_events.on_purchase_error:trigger(error)
    end
end


---Инициализация провайдера
---@param config table Конфигурация
function M:init(config)
    if not iap then
        logger:error("iap extension is not available. Be sure that this platform supports it.")
        return
    end
    iap.set_listener(iap_listener)
end

---Получить список продуктов
---@param product_ids string[] Массив ID продуктов
function M:list_products(product_ids)
    if not iap then
        return
    end
    
    logger:debug("List products", {product_ids = product_ids})
    if #product_ids == 0 then
        logger:warn("Product_ids is empty", {product_ids = product_ids})
        iap_events.on_list_products:trigger(false, {}, { message = "Product_ids is empty" })
        return
    end

    --- Google Play has a limit of 20 products, so we need to split the list into chunks of 20 products, 
    --- and then call the list_products function for each chunk
    --- and collect the results in the product_list_for_gp table
    --- after all chunks are processed, call the callback function with the product_list_for_gp table
    if iap.get_provider_id() == iap.PROVIDER_ID_GOOGLE then
        product_list_for_gp = {}
        local chunks = tablex.chunk(product_ids, 20)
        local expected_chunks = #chunks
        local completed_chunks = 0
        product_list_for_gp = {}

        for _, chunk in ipairs(chunks) do
            iap.list(chunk, function (context, products, error)
                logger:debug("List products callback", {context = context, products = products, error = error})
                completed_chunks = completed_chunks + 1

                if error == nil and products and #products > 0 then
                    tablex.extend(product_list_for_gp, products)
                end

                if completed_chunks == expected_chunks then
                    if #product_list_for_gp > 0 then
                        local products_tmp = tablex.map(product_list_for_gp, convert_to_fun_iap_product)
                        iap_events.on_list_products:trigger(true, products_tmp, nil)
                    else
                        iap_events.on_list_products:trigger(false, {}, { error = "No products from Google Play. Check Play Console/testers/app source." })
                    end
                end
            end)
        end
    else
        iap.list(product_ids, function (context, products, error)
            if error == nil then
                local products_tmp = tablex.map(products, convert_to_fun_iap_product)
                logger:debug("List products Success", {product_ids = product_ids})
                iap_events.on_list_products:trigger(true, products_tmp, nil)
            else
                logger:debug("List products Failed", {product_ids = product_ids})
                iap_events.on_list_products:trigger(false, {}, error)
            end
        end)
    end
end

---Купить продукт
---@param product_id string ID продукта
---@return bool @true - покупка успешна, false - покупка не успешна, nil - ошибка
function M:purchase(product_id)
    if not iap then
        return false
    end

    local result, error = pcall(iap.buy, product_id)
    if not result then
        logger:error("Purchase failed", {error = error})
        return false
    end
    return true
end

---Восстановить покупки, ответ приходит через событие fun.iap.events.on_purchase_restored
function M:restore()
    if not iap then
        return
    end

    iap.restore()
end

---Завершить транзакцию
---@param transaction_id string
function M:finish_transaction(transaction_id) end


---Финализация (опционально)
function M:final() end


return M