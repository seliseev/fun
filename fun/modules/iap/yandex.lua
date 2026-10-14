-- fun/modules/iap/yandex.lua
--- IAP provider for Yandex.Games using indiesoftby/defold-yagames SDK.
---
--- Yandex.Games payments work in two stages:
---   * payments_init({signed=false}, cb)        - bootstraps the payments subsystem
---   * payments_get_catalog(cb)                  - returns product prices/titles
---   * payments_purchase({id=...}, cb)           - shows the purchase dialog
---   * payments_consume_purchase(token, cb)      - marks a consumable purchase as used
---   * payments_get_purchases(cb)                - returns all not-yet-consumed purchases
---
--- This provider implements the fun.iap.provider interface so it can be plugged into
--- fun.modules.iap.iap.lua just like the defold (google/appstore) and dummy providers.
---
--- Consumable purchase flow (Yandex requires saving progress before consuming):
---   grant (on_purchase_purchased) -> local save -> cloud flush -> payments_consume_purchase
--- Granted purchase tokens are kept in the save until consumed, so a purchase returned again by
--- payments_get_purchases (e.g. the game was closed before consuming) is never granted twice.
--- Non-consumable purchases (e.g. "noads") stay in payments_get_purchases forever; on startup they
--- are reported via on_purchase_restored, not as new purchases.

local log = require("fun.libs.log")

local tablex = require("fun.libs.tablex")

local saver = require("fun.modules.saver")
local target = require("fun.modules.target")
local iap_events = require("fun.modules.iap.events")
local fun_yagames = require("fun.modules.yagames")

local logger = log.get_logger("fun.iap.yandex")

-- Direct require so Defold's bob picks up the dependency during static analysis and
-- bundles `yagames/yagames.lua` into the build. The library has a mock fallback for
-- non-HTML5 platforms, so requiring it unconditionally is safe.
local yagames_sdk = require("yagames.yagames")

-- Currency icon size requested from payments_get_catalog. "svg" is not supported by image.load.
local CURRENCY_ICON_SIZE = "medium"

---@class fun.iap.provider.yandex: fun.iap.provider
local M = {
    state = {
        ---@type table<string, boolean> purchase tokens that were granted but not consumed yet
        granted_tokens = {}
    }
}
M.__index = M

------------------------------------------------
--- Internal helpers
------------------------------------------------

--- Returns the yagames SDK module, or nil when the dependency is missing.
local function get_sdk()
    return yagames_sdk
end

--- Map a Yandex catalog product into the fun.iap.product schema.
--- Yandex catalog fields: price ("<value> <currency code>"), priceValue, priceCurrencyCode,
--- getPriceCurrencyImage (URL, only when requested in payments_get_catalog options).
---@param product table
---@param currency_icon image.load_result|nil
---@return fun.iap.product
local function convert_to_fun_iap_product(product, currency_icon)
    local price_value = tonumber(product.priceValue) or 0
    return {
        id = product.id,
        title = product.title or product.id,
        description = product.description or "",
        price = price_value,
        price_in_cents = math.floor(price_value * 100 + 0.5),
        price_string = product.price,
        price_value_string = product.priceValue,
        currency_code = product.priceCurrencyCode or "",
        currency_icon = currency_icon,
    }
end

--- Construct a fake transaction for the FUN IAP event flow.
---@param product_id string
---@param state string|nil
---@param purchase table|nil
---@return fun.iap.transaction
local function make_transaction(product_id, state, purchase)
    return {
        product_id = product_id,
        state = state or "purchased",
        transaction_id = purchase and purchase.purchaseToken or nil,
        receipt = purchase and purchase.purchaseToken or nil,
        signature = purchase and purchase.signature or nil,
        original_json = nil,
    }
end

--- Returns true if `product_id` is configured as non-consumable in the current target.
--- Non-consumable products are NOT auto-consumed after purchase (e.g. "no ads").
---@param self fun.iap.provider.yandex
---@param product_id string
---@return boolean
local function is_non_consumable(self, product_id)
    if not self.non_consumable_products then
        return false
    end
    return tablex.contains(self.non_consumable_products, product_id)
end

------------------------------------------------
--- Provider lifecycle
------------------------------------------------

---Инициализация провайдера
function M:init()
    saver.bind_save_state("fun.iap.yandex", M.state)

    self.non_consumable_products = target.get_module_parameter("iap", "non_consumable_products") or {}
    self.pending_purchases = {} -- product_id -> true while a purchase dialog is open
    self.payments_ready = false

    local sdk = get_sdk()
    if not sdk then
        logger:error("yagames extension is not available, Yandex IAP is disabled")
        return
    end

    -- payments_init asserts that yagames.init() has finished, which happens asynchronously
    -- in fun.modules.yagames, so wait for it.
    fun_yagames.on_sdk_ready(function()
        sdk.payments_init({ signed = false }, function(_, err)
            if err then
                logger:error("yagames.payments_init failed", { err = err })
                return
            end

            self.payments_ready = true
            logger:info("Yandex payments initialised")

            -- Process any purchases that were not consumed in a previous session.
            self:restore()
        end)
    end)
end

---Финализация (опционально)
function M:final() end

------------------------------------------------
--- Catalog
------------------------------------------------

--- Get the catalog from Yandex and emit fun.iap on_list_products event.
--- Note: Yandex returns the full catalog regardless of `product_ids`.
---@param product_ids string[]
function M:list_products(product_ids)
    local sdk = get_sdk()
    if not sdk then
        iap_events.on_list_products:trigger(false, {}, { error = "yagames extension is not available" })
        return
    end

    if not self.payments_ready then
        -- Try again once payments_init has finished
        logger:debug("Payments not ready yet, deferring list_products")
        timer.delay(0.5, false, function()
            self:list_products(product_ids)
        end)
        return
    end

    sdk.payments_get_catalog({ getPriceCurrencyImage = CURRENCY_ICON_SIZE }, function(_, err, catalog)
        if err then
            logger:error("payments_get_catalog failed", { err = err })
            iap_events.on_list_products:trigger(false, {}, { error = err })
            return
        end

        local icon_url = catalog[1] and catalog[1].getPriceCurrencyImage
        self:load_currency_icon(icon_url, function()
            local products = {}
            for _, product in ipairs(catalog) do
                table.insert(products, convert_to_fun_iap_product(product, self.currency_icon))
            end

            logger:debug("Yandex catalog received", { count = #products, has_currency_icon = self.currency_icon ~= nil })
            iap_events.on_list_products:trigger(true, products, nil)
        end)
    end)
end

--- Download the portal currency icon once and cache it as an image.load result.
--- `callback` is called in any case; on failure self.currency_icon stays nil.
---@param url string|nil
---@param callback fun()
function M:load_currency_icon(url, callback)
    if self.currency_icon or not url then
        callback()
        return
    end

    http.request(url, "GET", function(_, _, response)
        if response.status == 200 then
            self.currency_icon = image.load(response.response)
        end
        if not self.currency_icon then
            logger:warn("Failed to load currency icon", { url = url, status = response.status })
        end
        callback()
    end)
end

------------------------------------------------
--- Purchase flow
------------------------------------------------

--- Consume a granted purchase once the progress is stored in the cloud.
--- If the cloud write fails the purchase stays unconsumed and is retried on the next launch
--- (its token is remembered in the save, so it will not be granted again).
---@param self fun.iap.provider.yandex
---@param product_id string
---@param purchase_token string
local function consume_after_save(self, product_id, purchase_token)
    fun_yagames.flush(function(success)
        if not success and fun_yagames.is_cloud_available() then
            logger:warn("Cloud save failed, purchase will be consumed on next launch", { product_id = product_id })
            return
        end

        get_sdk().payments_consume_purchase(purchase_token, function(_, err)
            if err then
                logger:warn("payments_consume_purchase failed", { err = err, product_id = product_id })
                return
            end
            logger:info("Purchase consumed", { product_id = product_id })
            M.state.granted_tokens[purchase_token] = nil
            saver.save()
        end)
    end)
end

--- Process a successful purchase (new or returned by payments_get_purchases).
--- Yandex returns the product reference via either `productID` or `product.id` depending on the
--- API method (purchase vs get_purchases), so we accept both.
---@param self fun.iap.provider.yandex
---@param purchase table @Yandex purchase object: { purchaseToken, productID|product = { id }, ... }
---@param is_restore boolean @true when the purchase comes from payments_get_purchases
local function on_purchase_success(self, purchase, is_restore)
    local product_id = purchase.productID or (purchase.product and purchase.product.id)
    if not product_id then
        logger:error("Yandex purchase has no productID", { purchase = purchase })
        return
    end

    if is_non_consumable(self, product_id) then
        local state = is_restore and "restored" or "purchased"
        local transaction = make_transaction(product_id, state, purchase)
        if is_restore then
            iap_events.on_purchase_restored:trigger(transaction)
        else
            iap_events.on_purchase_purchased:trigger(transaction)
            saver.save()
            fun_yagames.flush()
        end
        return
    end

    local purchase_token = purchase.purchaseToken
    if M.state.granted_tokens[purchase_token] then
        logger:info("Purchase already granted, consuming", { product_id = product_id })
    else
        M.state.granted_tokens[purchase_token] = true
        iap_events.on_purchase_purchased:trigger(make_transaction(product_id, "purchased", purchase))
        saver.save()
    end

    consume_after_save(self, product_id, purchase_token)
end

---Купить продукт
---@param product_id string
---@return boolean
function M:purchase(product_id)
    local sdk = get_sdk()
    if not sdk or not self.payments_ready then
        logger:error("Cannot purchase, Yandex payments are not ready", { product_id = product_id })
        iap_events.on_purchase_error:trigger({ error = "Yandex payments are not ready" })
        return false
    end

    if self.pending_purchases[product_id] then
        logger:warn("Purchase already in progress", { product_id = product_id })
        return false
    end
    self.pending_purchases[product_id] = true

    iap_events.on_purchase_start:trigger(make_transaction(product_id, "purchasing", nil))

    sdk.payments_purchase({ id = product_id }, function(_, err, purchase)
        self.pending_purchases[product_id] = nil

        if err then
            -- Yandex error strings include "cancelled by user" when the player closes the dialog.
            local err_str = tostring(err):lower()
            local cancelled = err_str:find("cancel", 1, true) ~= nil
            logger:warn("payments_purchase failed", { err = err, product_id = product_id, cancelled = cancelled })
            if cancelled then
                iap_events.on_purchase_error:trigger({ reason = 1, error = err })
            else
                iap_events.on_purchase_failed:trigger(make_transaction(product_id, "failed", nil), { error = err })
            end
            return
        end

        if not purchase then
            logger:error("payments_purchase returned no purchase", { product_id = product_id })
            iap_events.on_purchase_failed:trigger(make_transaction(product_id, "failed", nil), { error = "Empty purchase" })
            return
        end

        on_purchase_success(self, purchase, false)
    end)

    return true
end

------------------------------------------------
--- Restore / unprocessed purchases
------------------------------------------------

--- Process purchases returned by payments_get_purchases: unconsumed consumables (e.g. the game
--- was closed in the middle of a purchase) are granted and consumed, non-consumables are restored.
--- Yandex moderation requires this check on every launch.
function M:restore()
    local sdk = get_sdk()
    if not sdk or not self.payments_ready then
        return
    end

    sdk.payments_get_purchases(function(_, err, response)
        if err then
            logger:warn("payments_get_purchases failed", { err = err })
            return
        end

        for _, purchase in ipairs(response.purchases) do
            on_purchase_success(self, purchase, true)
        end
    end)
end

---Завершить транзакцию - на Yandex это делается через consume_purchase, см. on_purchase_success
---@param transaction_id string
function M:finish_transaction(transaction_id) end

return M
