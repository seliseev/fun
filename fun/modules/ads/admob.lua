-- fun/modules/ads/admob.lua
--- Ads provider for AdMob

local log = require("fun.libs.log")

local const = require("fun.const")
local ads_events = require("fun.modules.ads.events")

local logger = log.get_logger("fun.ads.admob")

local banner_positions_converter = {}

---@class fun.ads.provider.admob: fun.ads.provider
local M = {}

--- Callback for AdMob events
---@param self table @The calling script instance
---@param message_id number @One of message types:
---@param message table
local function admob_callback(self, message_id, message)
    if message_id == admob.MSG_INITIALIZATION then
        if message.event == admob.EVENT_COMPLETE then
            logger:debug("AdMob initialization complete")
            ads_events.on_initialized:trigger()

        elseif message.event == admob.EVENT_JSON_ERROR then
            logger:error("Internal NE json error", { message_id = message_id, message = message })
        end
    elseif message_id == admob.MSG_IDFA then
        if message.event == admob.EVENT_STATUS_AUTHORIZED then
            print("EVENT_STATUS_AUTHORIZED: ATTrackingManagerAuthorizationStatusAuthorized")
        elseif message.event == admob.EVENT_STATUS_DENIED then
            print("EVENT_STATUS_DENIED: ATTrackingManagerAuthorizationStatusDenied")
        elseif message.event == admob.EVENT_STATUS_NOT_DETERMINED then
            print("EVENT_STATUS_NOT_DETERMINED: ATTrackingManagerAuthorizationStatusNotDetermined")
        elseif message.event == admob.EVENT_STATUS_RESTRICTED then
            print("EVENT_STATUS_RESTRICTED: ATTrackingManagerAuthorizationStatusRestricted")
        elseif message.event == admob.EVENT_NOT_SUPPORTED then
            print("EVENT_NOT_SUPPORTED: IDFA request not supported on this platform or OS version")
        end
    elseif message_id == admob.MSG_INTERSTITIAL then
        if message.event == admob.EVENT_CLOSED then
            logger:debug("Interstitial AD closed", { message_id = message_id, message = message })
            ads_events.on_interstitial_close:trigger()
        elseif message.event == admob.EVENT_FAILED_TO_SHOW then
            logger:error("Interstitial AD failed to show", { message_id = message_id, message = message })
            ads_events.on_interstitial_close:trigger()
        elseif message.event == admob.EVENT_OPENING then
            logger:debug("Interstitial AD is opening", { message_id = message_id, message = message })
            ads_events.on_interstitial_start:trigger()
        elseif message.event == admob.EVENT_FAILED_TO_LOAD then
            logger:error("Interstitial AD failed to load", { message_id = message_id, message = message })
            ads_events.on_interstitial_failed_to_load:trigger()
        elseif message.event == admob.EVENT_LOADED then
            logger:debug("Interstitial AD loaded", { message_id = message_id, message = message })
            ads_events.on_interstitial_loaded:trigger()
        elseif message.event == admob.EVENT_NOT_LOADED then
            logger:error("Interstitial AD not loaded, can't call show_interstitial() before EVENT_LOADED", { message_id = message_id, message = message })
        elseif message.event == admob.EVENT_IMPRESSION_RECORDED then
            logger:debug("Interstitial AD did record impression", { message_id = message_id, message = message })
        elseif message.event == admob.EVENT_JSON_ERROR then
            logger:error("Internal NE json error", { message_id = message_id, message = message })
        elseif message.event == admob.EVENT_PAID then
            logger:debug("Interstitial AD paid", { message_id = message_id, message = message })

            ads_events.on_interstitial_paid:trigger(
                message.currency_code,
                message.value_micros,
                message.precision,
                message.ad_unit_id,
                message.response_id,
                message.mediation_adapter_class_name,
                message.ad_source_name
            )
        end
    elseif message_id == admob.MSG_REWARDED then
        if message.event == admob.EVENT_CLOSED then
            logger:debug("Rewarded AD closed", { message_id = message_id, message = message })
            ads_events.on_rewarded_close:trigger()
        elseif message.event == admob.EVENT_FAILED_TO_SHOW then
            logger:error("Rewarded AD failed to show", { message_id = message_id, message = message })
            ads_events.on_rewarded_close:trigger()
        elseif message.event == admob.EVENT_OPENING then
            logger:debug("Rewarded AD is opening", { message_id = message_id, message = message })
            ads_events.on_rewarded_start:trigger()
        
        elseif message.event == admob.EVENT_FAILED_TO_LOAD then
            logger:error("Rewarded AD failed to load", { message_id = message_id, message = message })
            ads_events.on_rewarded_failed_to_load:trigger()
        
        elseif message.event == admob.EVENT_LOADED then
            logger:debug("Rewarded AD loaded", { message_id = message_id, message = message })
            ads_events.on_rewarded_loaded:trigger()

        elseif message.event == admob.EVENT_NOT_LOADED then
            logger:error("Rewarded AD not loaded, can't call show_rewarded() before EVENT_LOADED", { message_id = message_id, message = message })
        elseif message.event == admob.EVENT_EARNED_REWARD then
            logger:debug("Rewarded AD earned reward", { message_id = message_id, message = message })
            ads_events.on_rewarded_reward:trigger()
        elseif message.event == admob.EVENT_IMPRESSION_RECORDED then
            logger:debug("Rewarded AD did record impression", { message_id = message_id, message = message })
        elseif message.event == admob.EVENT_PAID then
            logger:debug("Rewarded AD paid", { message_id = message_id, message = message })
            ads_events.on_rewarded_paid:trigger(
                message.currency_code,
                message.value_micros,
                message.precision,
                message.ad_unit_id,
                message.response_id,
                message.mediation_adapter_class_name,
                message.ad_source_name
            )
        elseif message.event == admob.EVENT_JSON_ERROR then
            logger:error("Internal NE json error", { message_id = message_id, message = message })
        end
    elseif message_id == admob.MSG_BANNER then
        if message.event == admob.EVENT_LOADED then
            logger:debug("Banner AD loaded", { message_id = message_id, message = message })
            ads_events.on_banner_loaded:trigger(message.width, message.height)
        elseif message.event == admob.EVENT_OPENING then
            logger:debug("Banner AD is opening", { message_id = message_id, message = message })
            ads_events.on_banner_start:trigger()
        elseif message.event == admob.EVENT_FAILED_TO_LOAD then
            logger:error("Banner AD failed to load", { message_id = message_id, message = message })
            ads_events.on_banner_failed_to_load:trigger()
        elseif message.event == admob.EVENT_CLICKED then
            logger:debug("Banner AD clicked", { message_id = message_id, message = message })
        elseif message.event == admob.EVENT_CLOSED then
            logger:debug("Banner AD closed", { message_id = message_id, message = message })
            ads_events.on_banner_close:trigger()
        elseif message.event == admob.EVENT_DESTROYED then
            logger:debug("Banner AD destroyed", { message_id = message_id, message = message })
            ads_events.on_banner_destroyed:trigger()
        elseif message.event == admob.EVENT_IMPRESSION_RECORDED then
            logger:debug("Banner AD did record impression", { message_id = message_id, message = message })
        elseif message.event == admob.EVENT_PAID then
            logger:debug("Banner AD paid", { message_id = message_id, message = message })
            ads_events.on_banner_paid:trigger(
                message.currency_code,
                message.value_micros,
                message.precision,
                message.ad_unit_id,
                message.response_id,
                message.mediation_adapter_class_name,
                message.ad_source_name
            )
        elseif message.event == admob.EVENT_JSON_ERROR then
            logger:error("Internal NE json error", { message_id = message_id, message = message })
        end
    end
end

---Инициализация провайдера
function M.init()
    assert(admob, "admob extension is not available at this platform")

    banner_positions_converter = {
        [const.ADS_BANNER_POSITION.TOP] = admob.POS_TOP_CENTER,
        [const.ADS_BANNER_POSITION.BOTTOM] = admob.POS_BOTTOM_CENTER,
    }
    logger:debug("AdMob initialization started")
    admob.set_callback(admob_callback)
    admob.initialize()
end

function M.load_rewarded(ad_unit_id)
    if not admob then
        return
    end

    logger:debug("Loading rewarded ad", { ad_unit_id = ad_unit_id })
    admob.load_rewarded(ad_unit_id)
end

---Показать rewarded видео
---@return boolean @true or false
function M.show_rewarded()
    if not admob then
        return false
    end
    
    if admob.is_rewarded_loaded() then
        logger:debug("Showing rewarded ad")
        admob.show_rewarded()
        return true
    end
    logger:debug("Trying to show rewarded ad, but it is not loaded")
    return false
end

function M.load_interstitial(ad_unit_id)
    if not admob then
        return
    end

    logger:debug("Loading interstitial ad", { ad_unit_id = ad_unit_id })
    admob.load_interstitial(ad_unit_id)
end

---Показать interstitial видео
---@return boolean @true or false
function M.show_interstitial()
    if not admob then
        logger:warn("admob extension is not available at this platform")
        return false
    end
    
    if admob.is_interstitial_loaded() then
        logger:debug("Showing interstitial ad")
        admob.show_interstitial()
        return true
    end
    
    logger:debug("Trying to show interstitial ad, but it is not loaded")
    return false
end

function M.load_banner(ad_unit_id)
    if not admob then
        logger:warn("admob extension is not available at this platform")
        return
    end

    logger:debug("Loading banner ad", { ad_unit_id = ad_unit_id })

    admob.load_banner(ad_unit_id)
end

---Показать banner
---@param position fun.const.ADS_BANNER_POSITION
function M.show_banner(position)
    if not admob then
        return false
    end

    if admob.is_banner_loaded() then
        logger:debug("Showing banner ad", { position = position })
        admob.show_banner(banner_positions_converter[position])

        -- т.к. admob сам не сообщает о том, что баннер начинает показываться, то мы тут это делаем
        ads_events.on_banner_start:trigger()
        return true
    end
    logger:debug("Trying to show banner ad, but it is not loaded", { position = position })
    return false
end

---Скрыть banner
function M.hide_banner()
    if not admob then
        return
    end

    admob.hide_banner()
    ads_events.on_banner_close:trigger()
end

function M.destroy_banner()
    if not admob then
        return
    end

    admob.destroy_banner()
end

---Финализация провайдера
function M.final()
    if admob then
        admob.set_callback(nil)
    end
end

return M
