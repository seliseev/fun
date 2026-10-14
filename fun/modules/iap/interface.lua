--- Интерфейс для IAP провайдеров
--- Все провайдеры должны реализовывать эти методы

---@class fun.iap.provider
local IAPProvider = {}

---Инициализация провайдера
function IAPProvider:init() end

---Получить список продуктов
---@param product_ids string[] Массив ID продуктов
function IAPProvider:list_products(product_ids) end

---Купить продукт
---@param product_id string ID продукта
---@return boolean @true - покупка успешна, false - покупка не успешна, nil - ошибка
function IAPProvider:purchase(product_id) return false end

---Восстановить покупки (для iOS и подобных)
function IAPProvider:restore() end

---Завершить транзакцию
---@param transaction_id string
function IAPProvider:finish_transaction(transaction_id) end


---Финализация (опционально)
function IAPProvider:final() end


return IAPProvider