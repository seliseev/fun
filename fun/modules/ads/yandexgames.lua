-- fun/modules/ads/yandexgames.lua
--- Ads provider for Yandex.Games using indiesoftby/defold-yagames SDK.
---
--- Yandex.Games SDK manages ad placement on its own (no ad unit ids, no preloading),
--- so the load_* methods immediately emit a "loaded" event to keep the existing
--- adsservice.lua state machine happy.

local log = require("fun.libs.log")

local ads_events = require("fun.modules.ads.events")
local fun_yagames = require("fun.modules.yagames")
local fun_sound = require("fun.modules.sound")

local logger = log.get_logger("fun.ads.yagames")

-- Direct require so Defold's bob picks up the dependency during static analysis and
-- bundles `yagames/yagames.lua` into the build. The library has a mock fallback for
-- non-HTML5 platforms, so requiring it unconditionally is safe.
local yagames_sdk = require("yagames.yagames")

---@class fun.ads.provider.yandexgames: fun.ads.provider
local M = {}

------------------------------------------------
--- Internal helpers
------------------------------------------------

--- Returns the yagames SDK module, or nil when the dependency is missing.
local function get_sdk()
    return yagames_sdk
end

--- Banner is treated as a fixed 0x0 ad on Yandex Games because the platform draws it
--- outside of the Defold canvas; the adsservice still needs some numbers though.
local YANDEX_BANNER_WIDTH = 0
local YANDEX_BANNER_HEIGHT = 0

-- Yandex requires the game sound to be off while a fullscreen / rewarded ad is shown (4.7)
local MUTE_REASON_AD = "ad"

------------------------------------------------
--- Lifecycle
------------------------------------------------

function M.init()
    local sdk = get_sdk()
    if not sdk then
        logger:warn("yagames extension is not available, Yandex Ads provider is a no-op")
        return
    end

    -- Yandex Games SDK doesn't expose a separate "ads initialised" callback - ads are
    -- available once yagames.init() (owned by fun.modules.yagames) has succeeded. Every
    -- adv_* call asserts on that, so adsservice must not start loading before it.
    fun_yagames.on_sdk_ready(function()
        logger:debug("Yandex Games SDK is ready, ads initialized")
        ads_events.on_initialized:trigger()
    end)
end

function M.final() end

------------------------------------------------
--- Rewarded
------------------------------------------------

function M.load_rewarded(ad_unit_id)
    -- Yandex Games doesn't require pre-loading rewarded ads, simulate "loaded" so the
    -- state machine in adsservice.lua can transition to "ready".
    ads_events.on_rewarded_loaded:trigger()
end

function M.show_rewarded()
    local sdk = get_sdk()
    if not sdk then
        logger:error("yagames extension is not available, cannot show rewarded ad")
        ads_events.on_rewarded_close:trigger()
        return false
    end

    local was_rewarded = false

    sdk.adv_show_rewarded_video({
        open = function(_)
            logger:debug("Rewarded ad opened")
            fun_sound.set_muted(MUTE_REASON_AD, true)
            ads_events.on_rewarded_start:trigger()
        end,
        rewarded = function(_)
            logger:debug("Rewarded ad earned reward")
            was_rewarded = true
            ads_events.on_rewarded_reward:trigger()
        end,
        close = function(_)
            logger:debug("Rewarded ad closed", { was_rewarded = was_rewarded })
            fun_sound.set_muted(MUTE_REASON_AD, false)
            ads_events.on_rewarded_close:trigger()
        end,
        error = function(_, err)
            logger:error("Error while showing rewarded ad", { err = err })
            fun_sound.set_muted(MUTE_REASON_AD, false)
            ads_events.on_rewarded_close:trigger()
        end
    })

    return true
end

------------------------------------------------
--- Interstitial
------------------------------------------------

function M.load_interstitial(ad_unit_id)
    ads_events.on_interstitial_loaded:trigger()
end

function M.show_interstitial()
    local sdk = get_sdk()
    if not sdk then
        logger:error("yagames extension is not available, cannot show interstitial ad")
        ads_events.on_interstitial_close:trigger()
        return false
    end

    sdk.adv_show_fullscreen_adv({
        open = function(_)
            logger:debug("Interstitial ad opened")
            fun_sound.set_muted(MUTE_REASON_AD, true)
            ads_events.on_interstitial_start:trigger()
        end,
        close = function(_, was_shown)
            logger:debug("Interstitial ad closed", { was_shown = was_shown })
            fun_sound.set_muted(MUTE_REASON_AD, false)
            ads_events.on_interstitial_close:trigger()
        end,
        offline = function(_)
            logger:warn("Interstitial ad: network is offline")
            fun_sound.set_muted(MUTE_REASON_AD, false)
            ads_events.on_interstitial_close:trigger()
        end,
        error = function(_, err)
            logger:error("Error while showing interstitial ad", { err = err })
            fun_sound.set_muted(MUTE_REASON_AD, false)
            ads_events.on_interstitial_close:trigger()
        end
    })

    return true
end

------------------------------------------------
--- Sticky banner
------------------------------------------------

function M.load_banner(ad_unit_id)
    local sdk = get_sdk()
    if not sdk then
        logger:warn("yagames extension is not available, banner unsupported")
        ads_events.on_banner_failed_to_load:trigger()
        return
    end

    sdk.adv_get_banner_adv_status(function(_, err, result)
        if err then
            logger:warn("adv_get_banner_adv_status failed", { err = err })
            ads_events.on_banner_failed_to_load:trigger()
            return
        end

        if result and result.reason == "ADV_IS_NOT_CONNECTED" then
            logger:warn("Yandex sticky banner is not connected for this game")
            ads_events.on_banner_failed_to_load:trigger()
            return
        end

        ads_events.on_banner_loaded:trigger(YANDEX_BANNER_WIDTH, YANDEX_BANNER_HEIGHT)
    end)
end

--- Show sticky banner. The `position` argument is ignored - Yandex Games positions
--- the banner on its own based on Developer Console settings.
---@return boolean
function M.show_banner(position)
    local sdk = get_sdk()
    if not sdk then
        logger:warn("yagames extension is not available, banner unsupported")
        return false
    end

    sdk.adv_show_banner_adv(function(_, err, result)
        if err then
            logger:warn("adv_show_banner_adv failed", { err = err })
            ads_events.on_banner_failed_to_load:trigger()
            return
        end

        if result and not result.stickyAdvIsShowing then
            logger:warn("Sticky banner did not show", { reason = result and result.reason })
            ads_events.on_banner_failed_to_load:trigger()
            return
        end

        ads_events.on_banner_start:trigger()
    end)

    return true
end

function M.hide_banner()
    local sdk = get_sdk()
    if not sdk then
        return
    end

    sdk.adv_hide_banner_adv(function(_, err)
        if err then
            logger:warn("adv_hide_banner_adv failed", { err = err })
        end
        ads_events.on_banner_close:trigger()
    end)
end

function M.destroy_banner()
    local sdk = get_sdk()
    if not sdk then
        ads_events.on_banner_destroyed:trigger()
        return
    end

    sdk.adv_hide_banner_adv(function(_, err)
        if err then
            logger:warn("adv_hide_banner_adv (destroy) failed", { err = err })
        end
        ads_events.on_banner_destroyed:trigger()
    end)
end

return M
