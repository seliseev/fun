-- fun/modules/ads/dummy.lua
--- Dummy ADS provider
--- 

local ads_events = require("fun.modules.ads.events")

---@class fun.ads.provider.dummy: fun.ads.provider
local M = {}

---Инициализация провайдера
function M.init()
    timer.delay(1, false, function()
        ads_events.on_initialized:trigger()
    end)
end

---Загрузить rewarded видео
--- @param ad_unit_id string id рекламного блока
function M.load_rewarded(ad_unit_id)
    timer.delay(0.5, false, function()
        ads_events.on_rewarded_loaded:trigger()
    end)
end

---Показать rewarded видео
---@return boolean @true or false
function M.show_rewarded()
    timer.delay(0.1, false, function()
        ads_events.on_rewarded_start:trigger()
        timer.delay(1, false, function()
            ads_events.on_rewarded_close:trigger()
            ads_events.on_rewarded_reward:trigger()
        end)
    end)
    return true
end

---Загрузить interstitial видео
--- @param ad_unit_id string id рекламного блока
function M.load_interstitial(ad_unit_id)
    timer.delay(0.5, false, function()
        ads_events.on_interstitial_loaded:trigger()
    end)
end

---Показать interstitial видео
---@return boolean @true or false
function M.show_interstitial()
    timer.delay(0.1, false, function()
        ads_events.on_interstitial_start:trigger()
        timer.delay(1, false, function()
            ads_events.on_interstitial_close:trigger()
        end)
    end)
    return true
end


---Загружает banner рекламу
---@param ad_unit_id any
function M.load_banner(ad_unit_id)
    timer.delay(0.5, false, function()
        ads_events.on_banner_loaded:trigger(320, 50)
    end)
end


---Показать banner
---@param position fun.const.ADS_BANNER_POSITION
function M.show_banner(position)
    timer.delay(0.5, false, function()
        ads_events.on_banner_start:trigger()
    end)
    return true
end

---Скрыть banner
function M.hide_banner()
    timer.delay(0.5, false, function()
        ads_events.on_banner_close:trigger()
    end)
end

---Уничтожает banner
function M.destroy_banner() end

---Финализация провайдера
function M.final() end

return M
