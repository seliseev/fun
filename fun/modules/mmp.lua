local iap_events = require("fun.modules.iap.events")
local iap_service = require("fun.modules.iapservice")
local ads = require("fun.modules.ads.ads")
local ads_events = require("fun.modules.ads.events")
local ads_service = require("fun.modules.adsservice")
local target = require("fun.modules.target")

local log = require("fun.libs.log")
local logger = log.get_logger("fun.mmp")

--- @class fun.mmp
local M = {
    runtime = {
        is_available = false,
        is_initialized = false,
    }
}

local function provider_name_to_tenjin_name(provider_name)
    if provider_name == ads.PROVIDERS.ADMOB then
        return tenjin.AD_NETWORK_ADMOB
    elseif provider_name == ads.PROVIDERS.YANDEX_GAMES then
        return "unsupported"
    elseif provider_name == ads.PROVIDERS.DUMMY then
        return "unsupported"
    end
    return nil
end


local function on_ad_paid(currency_code, value_micros, precision, ad_unit_id, response_id, mediation_adapter_class_name, ad_source_name)

    local provider_name = ads_service.get_current_provider()
    if not provider_name then
        logger:error("Ads provider not initialized")
        return
    end

    local payload = json.encode({
        currency_code = currency_code,
        value_micros = value_micros,
        precision = precision,
        ad_unit_id = ad_unit_id,
        response_id = response_id,
        mediation_adapter_class_name = mediation_adapter_class_name,
        ad_source_name = ad_source_name,
    })

    tenjin.event_ad_impression(provider_name_to_tenjin_name(provider_name), payload)
end

--- Обработка события завершения покупки
---@param transaction fun.iap.transaction
---@param error table|nil
local function on_purchase_purchased(transaction, error)

    local sku = iap_service.get_sku_for_product_id(transaction.product_id)
    if not sku then
        logger:error("SKU not found", {product_id = transaction.product_id})
        return
    end

    local lot = iap_service.get_lot(sku)
    if not lot then
        logger:error("Lot not found", {sku = sku})
        return
    end

    tenjin.transaction(transaction.product_id, lot.product.currency_code, 1, lot.product.price, transaction.original_json, transaction.signature)

end


function M.fun_pre_init()
    M.runtime.is_available = tenjin ~= nil
    if not M.runtime.is_available then
        logger:warn("Tenjin not available")
        return
    end

    logger:info("Tenjin available")
end

function M.fun_init()
    if not M.runtime.is_available then
        return
    end

    local config = target.get_module_parameter("mmp", "tenjin")
    if not config then
        logger:error("Tenjin config not found")
        return
    end

    tenjin.init(config.api_key)
	tenjin.set_app_store(tenjin.APP_STORE_GOOGLEPLAY)
	tenjin.connect()

    iap_events.on_purchase_purchased:subscribe(on_purchase_purchased)
    ads_events.on_interstitial_paid:subscribe(on_ad_paid)
    ads_events.on_rewarded_paid:subscribe(on_ad_paid)
    ads_events.on_banner_paid:subscribe(on_ad_paid)
end

function M.fun_post_init()

end

function M.fun_update(dt)

end

function M.fun_on_message(message_id, message, sender)

end

function M.fun_final()
    if not M.runtime.is_available then
        return
    end

    iap_events.on_purchase_purchased:unsubscribe(on_purchase_purchased)
    ads_events.on_interstitial_paid:unsubscribe(on_ad_paid)
    ads_events.on_rewarded_paid:unsubscribe(on_ad_paid)
    ads_events.on_banner_paid:unsubscribe(on_ad_paid)
end

return M