--- Fun Target module
--- Загружает конфигурацию target'ов из файла json на основе параметра fun.target в game.project
--- и предоставляет методы для получения конфигурации target'а и его параметров

local log = require("fun.libs.log")

local const = require("fun.const")
local tablex = require("fun.libs.tablex")

local utils = require("fun.libs.utils")
local logger = log.get_logger("fun.target")

---@class fun.target
local M = {
    runtime = {
        target = nil,
        name = nil
    },
    config = nil
}

--- Получить текущий target
---@return string|nil
function M.get_current_target_name()
    if not M.runtime.name then
        logger:error("Target not initialized")
        return nil
    end
    return M.runtime.name
end

--- Получить конфигурацию модуля из конфигурации target'а
---@param module_name string Имя модуля (iap, ads, etc)
---@return table|nil
function M.get_module_config(module_name)
    if not M.runtime.target then
        logger:error("Target not initialized")
        return nil
    end

    if not M.runtime.target[module_name] then
        logger:warn("No configuration for current target in JSON configuration file", { target_name = M.runtime.name, module_name = module_name })
        return nil
    end

    return M.runtime.target[module_name]
end


--- Получить параметр модуля из конфигурации target'а
---@param module_name string @Имя модуля (iap, ads, etc)
---@param parameter_name string @Название параметра модуля
---@return any|nil
function M.get_module_parameter(module_name, parameter_name)
    if not M.runtime.target then
        logger:error("Target not initialized")
        return nil
    end

    if not M.runtime.target[module_name] then
        logger:warn("No configuration for current target in JSON configuration file", { target_name = M.runtime.name, module_name = module_name })
        return nil
    end

    return tablex.deepcopy(M.runtime.target[module_name][parameter_name])
end


function M.fun_pre_init()
    -- Получаем путь к файлу с конфигурацией target'ов из game.project
    local file_path = sys.get_config_string("fun.targets_data_path")
    if not file_path then
        logger:error("Targets data path not specified in game.project")
        return
    end

    -- Загружаем конфигурацию target'ов из файла
    M.config = utils.load_json(file_path)
    if not M.config then
        logger:error("Error loading targets data: " .. file_path)
        return
    end

    -- Читаем target из game.project
    M.runtime.name = sys.get_config_string("fun.target")

    -- Если не указан, указываем development
    if not M.runtime.name or M.runtime.name == "" then
        logger:warn("Target not specified in game.project, using '" .. const.TARGETS.DEVELOPMENT .. "'")
        M.runtime.name = const.TARGETS.DEVELOPMENT
    end

    -- Получаем конфигурацию target'а
    M.runtime.target = M.config[M.runtime.name]
    if not M.runtime.target then
        logger:error("Targent not found in json configuration file", { target_name = M.runtime.name, file_path = file_path })
        return
    end
    
    -- Логируем инициализацию target'а
    logger:info("Target initialized. Current target: \"" .. M.runtime.name .. "\" from file: " .. file_path)
end

return M