-- fun/modules/ads/interface.lua
--- Интерфейс для ADS провайдеров
--- Все провайдеры должны реализовывать эти методы

---@class fun.ads.provider
local M = {}

---Инициализация провайдера
function M.init() end

---Загрузить rewarded видео
--- @param ad_unit_id string id рекламного блока
function M.load_rewarded(ad_unit_id) end

---Показать rewarded видео
---@return boolean @true or false
function M.show_rewarded()
    return false
end

---Загрузить interstitial видео
--- @param ad_unit_id string id рекламного блока
function M.load_interstitial(ad_unit_id) end

---Показать interstitial видео
---@return boolean @true or false
function M.show_interstitial() return false end

---Загружает banner рекламу
---@param ad_unit_id any
function M.load_banner(ad_unit_id) end

---Показать banner
---@param position fun.const.ADS_BANNER_POSITION
function M.show_banner(position) end

---Скрыть banner
function M.hide_banner() end

---Уничтожает banner
function M.destroy_banner() end

---Финализация провайдера
function M.final() end

return M