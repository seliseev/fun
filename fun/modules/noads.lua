--- FUN Module: No Ads
--- Module for "No Ads" purchase offer
--- When purchased, disables banner and interstitial ads, but rewarded ads continue to work
--- Uses wallet with noads token (1 = purchased, 0 = not purchased)

local log = require("fun.libs.log")
local event = require("event.event")

local wallet = require("fun.modules.wallet")
local adsservice = require("fun.modules.adsservice")
local iapservice = require("fun.modules.iapservice")

local logger = log.get_logger("fun.noads")

local TOKEN_ID = "noads"
local SKU = "noads"

--- @class fun.noads.events.on_noads_purchased: event
--- @field trigger fun(_)
--- @field subscribe fun(_, callback: fun(), _)

--- @class fun.noads
local M = {}

M.on_noads_purchased = event.create() --[[@as fun.noads.events.on_noads_purchased]]


--------------------------------------------------
--- Private functions
--------------------------------------------------

--- Apply noads state to adsservice based on wallet value
local function apply_noads_state()
    local is_purchased = M.is_purchased()

    adsservice.set_noads_active(is_purchased)

    if is_purchased then
        logger:info("No Ads is active, banner and interstitial disabled")
    else
        logger:info("No Ads is inactive, all ads enabled")
    end
end


--- Handle IAP purchase completion
---@param success boolean
---@param lot fun.iapservice.lot|nil
---@param transaction fun.iap.transaction
---@param metadata fun.iapservice.runtime.metadata
---@param error table|nil
local function on_iap_purchase_end(success, lot, transaction, metadata, error)
    if not success then
        return
    end

    if not lot then
        return
    end

    if lot.sku ~= SKU then
        return
    end

    logger:info("No Ads purchased successfully")

    -- Set noads token to 1 in wallet
    wallet.set(TOKEN_ID, 1, "iap", SKU)

    -- Apply noads state
    apply_noads_state()

    -- Trigger event
    M.on_noads_purchased:trigger()
end


--- Handle restore of the owned "No Ads" purchase (e.g. new device or cleared save)
---@param lot fun.iapservice.lot
---@param transaction fun.iap.transaction
local function on_iap_purchase_restored(lot, transaction)
    if lot.sku ~= SKU or M.is_purchased() then
        return
    end

    logger:info("No Ads restored")
    wallet.set(TOKEN_ID, 1, "iap_restore", SKU)
    apply_noads_state()
end


--------------------------------------------------
--- Public API
--------------------------------------------------

--- Check if "No Ads" has been purchased
---@return boolean @True if noads is purchased
function M.is_purchased()
    return wallet.get(TOKEN_ID, 0) == 1
end


--- Get the lot information for "No Ads" purchase
---@return fun.iapservice.lot|nil @Lot information or nil if not configured
function M.get_lot()
    return iapservice.get_lot(SKU)
end


--- Start the purchase flow for "No Ads"
---@param placement string|nil @Optional placement identifier for analytics
---@return boolean @True if purchase started successfully
function M.purchase(placement)
    if M.is_purchased() then
        logger:warn("No Ads already purchased")
        return false
    end

    local lot = M.get_lot()
    if not lot then
        logger:error("No Ads lot not found in iapservice")
        return false
    end

    iapservice.purchase(SKU, placement or "noads")
    return true
end


--- Manually grant "No Ads" (for testing, promotions, etc.)
---@param reason_category string|nil @Reason category for analytics
---@param reason_id string|nil @Reason id for analytics
function M.grant(reason_category, reason_id)
    if M.is_purchased() then
        logger:warn("No Ads already purchased")
        return
    end

    logger:info("Granting No Ads", { reason_category = reason_category, reason_id = reason_id })

    wallet.set(TOKEN_ID, 1, reason_category or "grant", reason_id or "noads")

    apply_noads_state()

    M.on_noads_purchased:trigger()
end


--- Reset the "No Ads" purchase state (for testing purposes)
function M.reset()
    wallet.set(TOKEN_ID, 0, "reset", "noads")
    apply_noads_state()
end


--------------------------------------------------
--- FUN Callback functions
--------------------------------------------------

function M.fun_init()
    -- Subscribe to IAP purchase events
    iapservice.on_purchase_end:subscribe(on_iap_purchase_end)
    iapservice.on_purchase_restored:subscribe(on_iap_purchase_restored)

    logger:info("No Ads module initialized")
end


function M.fun_post_init()
    -- Apply noads state after all modules are initialized
    apply_noads_state()
end


function M.fun_final()
    iapservice.on_purchase_end:unsubscribe(on_iap_purchase_end)
    iapservice.on_purchase_restored:unsubscribe(on_iap_purchase_restored)
end


return M

