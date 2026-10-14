--- Fun IAP module
--- Universal IAP module for all platforms

local log = require("fun.libs.log")
local target = require("fun.modules.target")

local logger = log.get_logger("fun.iap")

---@class fun.iap.product Используется для передачи данных о продукте в событиях fun.iap.events
---@field id string Идентификатор продукта
---@field title string Заголовок продукта
---@field description string Описание продукта
---@field price number Цена продукта
---@field price_in_cents number Цена продукта в центах
---@field price_string string Строковое представление цены продукта сразу с валютой
---@field currency_code string Код валюты
---@field price_value_string string|nil Цена без валюты (Yandex Games: показывается рядом с иконкой валюты)
---@field currency_icon image.load_result|nil Иконка валюты платформы (Yandex Games), если удалось загрузить


---@class fun.iap.transaction Используется для передачи данных о транзакции в событиях fun.iap.events
---@field product_id string Идентификатор продукта
---@field state string|hash Состояние транзакции
---@field transaction_id string|nil Идентификатор транзакции
---@field receipt string|nil Чек покупки
---@field signature string|nil Google Play only. A string containing the signature of the purchase data that was signed with the private key of the developer.
---@field original_json string|nil Android only. The purchase order details in JSON format.

--- @class fun.iap
local M = {
    --- Available IAP providers, see modules/iap.lua
    --- @enum fun.iap.providers
    IAP_PROVIDERS = {
        GOOGLE_PLAY = "googleplay",
        APP_STORE = "appstore",
        YANDEX_GAMES = "yandexgames",
        APP_GALLERY = "appgallery",
        RUSTORE = "rustore",
        XSOLLA = "xsolla",
        DUMMY = "dummy",
    }
}

--- Имя текущего активного провайдера IAP
---@type string|nil
local current_provider_name = nil

--- Текущий активный провайдер IAP
---@type fun.iap.provider
local current_provider = nil

--- Реестр доступных провайдеров
---@type table<string, fun.iap.provider>
local providers = {
    [M.IAP_PROVIDERS.DUMMY] = require("fun.modules.iap.dummy"),
    [M.IAP_PROVIDERS.GOOGLE_PLAY] = require("fun.modules.iap.defold"),
    [M.IAP_PROVIDERS.APP_STORE] = require("fun.modules.iap.defold"),
    [M.IAP_PROVIDERS.YANDEX_GAMES] = require("fun.modules.iap.yandex"),
}

local function validate_provider(provider)
    if not provider then
        logger:error("Provider is nil")
        return false
    end
    local provider_interface = require("fun.modules.iap.interface")
    for key, value in pairs(provider_interface) do
        if type(value) == "function" then
            if type(provider[key]) ~= "function" then
                logger:error("IAP provider missing required method", { method = key })
                return false
            end
        end
    end
    return true
end


---Регистрация провайдера IAP
---@param provider_name string Имя платформы (google, ios, yandex, etc)
---@param provider fun.iap.provider Провайдер с интерфейсом IAP
function M.register_provider(provider_name, provider)
    if not validate_provider(provider) then
        logger:error("Invalid provider", { provider_name = provider_name })
        return
    end

    providers[provider_name] = provider
    logger:debug("IAP provider registered", { provider_name = provider_name })
end


--- Получить список продуктов
---@param product_ids table Массив ID продуктов
function M.list_products(product_ids)
    if not current_provider then
        logger:error("IAP not initialized")
        return
    end

    current_provider:list_products(product_ids)
end


---Покупка продукта
---@param product_id string ID продукта из стора
---@return boolean @true - покупка успешна, false - покупка не успешна, nil - ошибка
function M.purchase(product_id)
    if not current_provider then
        logger:error("IAP not initialized")
        return false
    end

    -- Купить продукт
    return current_provider:purchase(product_id)
end


function M.fun_init()

    --- Проверяем все провайдеры на валидность
    for provider_name, provider in pairs(providers) do
        if not validate_provider(provider) then
            logger:error("Invalid provider", { provider_name = provider_name })
            return
        end
    end

    --- Получаем имя текущего активного провайдера из конфигурации target
    current_provider_name = target.get_module_parameter("iap", "provider")
    if not current_provider_name then
        logger:error("\"iap\": { \"provider\": \"...\" } is missing in target configuration file for current target")
        return
    end

    --- Получаем текущий активный провайдер из реестра провайдеров
    current_provider = providers[current_provider_name]
    if not current_provider then
        logger:error("IAP provider not found", { provider = current_provider_name })
        return
    end

    --- Инициализируем текущий активный провайдер
    local status, error = pcall(function()
        current_provider:init()
    end)
    if not status then
        logger:error("Error initializing IAP provider", { provider = current_provider_name, error = error })
        return
    else
        logger:info("IAP initialized. Current provider: \"" .. current_provider_name .. "\"")
    end
end

return M