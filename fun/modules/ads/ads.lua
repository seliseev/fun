--- FUN Module: ads
--- Модуль для работы с рекламой


local log = require("fun.libs.log")
local logger = log.get_logger("fun.ads")

local target = require("fun.modules.target")
local ads_events = require("fun.modules.ads.events")


--- @class fun.ads
local M = {}

-- Реэкспорт событий из events.lua
M.on_initialized = ads_events.on_initialized
M.on_rewarded_loaded = ads_events.on_rewarded_loaded
M.on_rewarded_failed_to_load = ads_events.on_rewarded_failed_to_load
M.on_rewarded_start = ads_events.on_rewarded_start
M.on_rewarded_close = ads_events.on_rewarded_close
M.on_rewarded_reward = ads_events.on_rewarded_reward
M.on_rewarded_paid = ads_events.on_rewarded_paid
M.on_interstitial_loaded = ads_events.on_interstitial_loaded
M.on_interstitial_failed_to_load = ads_events.on_interstitial_failed_to_load
M.on_interstitial_start = ads_events.on_interstitial_start
M.on_interstitial_close = ads_events.on_interstitial_close
M.on_interstitial_paid = ads_events.on_interstitial_paid
M.on_banner_loaded = ads_events.on_banner_loaded
M.on_banner_failed_to_load = ads_events.on_banner_failed_to_load
M.on_banner_start = ads_events.on_banner_start
M.on_banner_close = ads_events.on_banner_close
M.on_banner_destroyed = ads_events.on_banner_destroyed
M.on_banner_paid = ads_events.on_banner_paid

M.PROVIDERS = {
    DUMMY = "dummy",
    ADMOB = "admob",
    YANDEX_GAMES = "yandex_games"
}

M.current_provider = nil

-- Ленивая загрузка провайдеров чтобы избежать циклической зависимости
local provider_list = nil
local function get_provider_list()
    if not provider_list then
        provider_list = {
            [M.PROVIDERS.ADMOB] = require("fun.modules.ads.admob"),
            [M.PROVIDERS.YANDEX_GAMES] = require("fun.modules.ads.yandexgames"),
            [M.PROVIDERS.DUMMY] = require("fun.modules.ads.dummy"),
        }
    end
    return provider_list
end

--- Проверяет, инициализирован ли провайдер рекламы
---@return boolean
function M.is_initialized()
    return M.current_provider ~= nil
end


function M.load_rewarded(ad_unit_id)
    if not M.current_provider then
        logger:error("Ads provider not initialized")
        return
    end

    M.current_provider.load_rewarded(ad_unit_id)
end

function M.show_rewarded()
    if not M.current_provider then
        logger:error("Ads provider not initialized")
        return false
    end

    return M.current_provider.show_rewarded()
end

function M.load_interstitial(ad_unit_id)
    logger:debug("Loading interstitial ad", { ad_unit_id = ad_unit_id })
    if not M.current_provider then
        logger:error("Ads provider not initialized")
        return
    end

    M.current_provider.load_interstitial(ad_unit_id)
end

--- Show interstitial ad
function M.show_interstitial()
    if not M.current_provider then
        logger:error("Ads provider not initialized")
        return false
    end

    return M.current_provider.show_interstitial()
end

--- Загружает banner рекламу
--- @param ad_unit_id string id рекламного блока
function M.load_banner(ad_unit_id)
    if not M.current_provider then
        logger:error("Ads provider not initialized")
        return
    end

    M.current_provider.load_banner(ad_unit_id)
end

--- Показывает banner рекламу на основе места показа
---@param position fun.const.ADS_BANNER_POSITION
---@return boolean
function M.show_banner(position)
    if not M.current_provider then
        logger:error("Ads provider not initialized")
        return false
    end

    return M.current_provider.show_banner(position)
end

function M.hide_banner()
    if not M.current_provider then
        logger:error("Ads provider not initialized")
        return
    end

    M.current_provider.hide_banner()
end

function M.destroy_banner()
    if not M.current_provider then
        logger:error("Ads provider not initialized")
        return
    end

    M.current_provider.destroy_banner()
end

function M.fun_init()
    local provider_name = target.get_module_parameter("ads", "provider")
    if not provider_name then
        logger:error("\"ads\": { \"provider\": \"...\" } is missing in target configuration file")
        return
    end

    local providers = get_provider_list()
    M.current_provider = providers[provider_name]
    if not M.current_provider then
        logger:error("Ads provider not found", { provider_name = provider_name })
        return
    end

    local status, error = pcall(function()
        M.current_provider:init()
    end)
    if not status then
        logger:error("Error initializing Ads provider", { provider = provider_name, error = error })
        M.current_provider = nil
        return
    end

    logger:info("ADS initialized. Current provider: \"" .. provider_name .. "\"")
end

function M.fun_final()
    if M.current_provider then
        M.current_provider:final()
    end
end

return M
