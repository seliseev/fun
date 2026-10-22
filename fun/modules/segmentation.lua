local events = require("event.events")
local log = require("fun.libs.log")

local tablex = require("fun.libs.tablex")
local const = require("fun.const")
local timex = require("fun.libs.timex")
local mathx = require("fun.libs.mathx")

local gamedata = require("fun.modules.gamedata")
local saver = require("fun.modules.saver")

local logger = log.get_logger("fun.segmentation")

local SEGMENTATION_UPDATE_INTERVAL = 5 -- секунд

--- @class fun.segmentation.state
--- @field cohort string|nil текущая когорта игрока
--- @field calculated_at number время последнего расчета когорты

--- @class fun.segmentation
local M = {
    --- @type fun.segmentation.state
    state = {
        cohort = nil,
        calculated_at = 0,
    },
    cohort_rules = {}
}


local function calculate_cohort()
    for _, rule in ipairs(M.cohort_rules) do
        if rule.condition() then
            return rule.name
        end
    end
    return "default"
end

--- Регистрирует правило для определения когорты
---@param name string
---@param priority number
---@param condition function
function M.register_cohort(name, priority, condition)
    table.insert(M.cohort_rules, {
        name = name,
        priority = priority,
        condition = condition
    })

    -- Сортируем по приоритету
    table.sort(M.cohort_rules, function(a, b)
        return a.priority > b.priority
    end)

    logger:info("Registered cohort: " .. name .. " with priority " .. priority)
end

--- Возвращает конфигурацию для фичи на основе когорты
---@param module_name string название модуля (например "adsservice")
---@param feature_name string|nil имя подфичи (например "interstitial"), если nil, то возвращается конфигурация для всего модуля
---@param default_config table дефолтная конфигурация
---@return table
function M.get_module_config(module_name, feature_name, default_config)
    assert(module_name, "module_name is required")
    assert(default_config, "default_config is required")

    local cohort_name = M.get_cohort()
    local feature_config = gamedata.get_module_config(module_name, nil)
    if not feature_config then
        logger:warn("No config found for module: " .. module_name)
        return default_config
    end

    -- Если имя подфичи не nil, то опускаемся на уровень ниже
    if feature_name then
        feature_config = feature_config[feature_name]
    end

    if not feature_config then
        logger:warn("No config found for module: " .. module_name .. " feature: " .. tostring(feature_name))
        return default_config
    end

    -- Получаем список соответствия когорт и конфигураций
    local feature_cohort_list = feature_config.cohorts or {}
    local config_name = feature_cohort_list[cohort_name]
    if not config_name then
        logger:warn("No config name found for cohort: " .. cohort_name .. " for module: " .. module_name .. " feature: " .. tostring(feature_name))
        config_name = "default"
    end
    
    local feature_config_list = feature_config.configs
    if not feature_config_list then
        logger:warn("No config list found for module: " .. module_name .. " feature: " .. tostring(feature_name))
        return default_config
    end

    -- Находим конфигурацию для когорты
    local feature_config = feature_config_list[config_name]
    if not feature_config then
        logger:warn("No config found for module: " .. module_name .. " feature: " .. tostring(feature_name) .. " config name: " .. tostring(config_name))
        return default_config
    end

    -- Если конфиг default, возвращаем его дальшен ничего делать не надо
    if config_name == "default" then
        return feature_config
    end

    -- Если конфиг не default, то ищем дефолтную конфигурацию, т.к. надо будет переопределить её
    local feature_defaul_config = feature_config_list["default"]

    -- Если есть специфичная конфигурация, мержим её с дефолтной
    local result = tablex.deepcopy(feature_defaul_config)
    result = tablex.override(feature_config, result)
    return result
end

--- Получает параметр модуля из конфигурации на основе когорты
---@param module_name string название модуля (например "adsservice")
---@param feature_name string|nil имя подфичи (например "interstitial"), если nil, то возвращается конфигурация для всего модуля
---@param parameter_name string название параметра (например "is_enabled")
---@param default_value any|nil значение по умолчанию, которое будет возвращено если параметр не найден
---@return any|nil
function M.get_module_parameter(module_name, feature_name, parameter_name, default_value)
    local config = M.get_module_config(module_name, feature_name, default_value)
    if not config then
        return default_value
    end
    if not config[parameter_name] then
        logger:warn("No parameter found for module: " .. module_name .. " feature: " .. tostring(feature_name) .. " parameter: " .. tostring(parameter_name))
        return default_value
    end
    
    return tablex.deepcopy(config[parameter_name])
end

--- Пересчитывает когорту на основе текущих метрик
---@return string @название когорты
function M.update_cohort()
    local new_cohort = calculate_cohort()
    M.state.calculated_at = timex.get_time()
    if new_cohort ~= M.state.cohort then
        M.state.cohort = new_cohort
        events.trigger(const.EVENTS.SEGMENTATION_COHORT_CHANGED, new_cohort)
    end

    return new_cohort
end

-- Возвращает текущую когорту
---@return string
function M.get_cohort()
    if not M.state.cohort then
        logger:error("Segmentation module not initialized, add \"segmentation\" module to fun.modules")
        return "default"
    end

    return M.state.cohort
end

function M.fun_init()
    saver.bind_save_state("fun.segmentation", M.state)

    -- При первом запуске когорты в сохранении нет, а adsservice и levelchest запрашивают её в своих fun_init.
    -- Сохраненную когорту не пересчитываем: правила когорт регистрируются в fun_init других модулей,
    -- финальный пересчет будет в fun_post_init
    if not M.state.cohort then
        M.update_cohort()
    end
end

function M.fun_post_init()
    -- Определяем когорту при старте
    M.update_cohort()
    logger:info("Segmentation initialized. Current cohort: " .. M.get_cohort())
end

function M.fun_update(dt)
    
    if mathx.diff(timex.get_time(), M.state.calculated_at) >= SEGMENTATION_UPDATE_INTERVAL then
        M.update_cohort()
    end
end

return M