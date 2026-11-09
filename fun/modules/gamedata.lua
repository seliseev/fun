--- FUN Module: gamedata
--- Модуль для работы с конфигурацией игры из файла gamedata.json

local log = require("fun.libs.log")
local tablex = require("fun.libs.tablex")
local utils = require("fun.libs.utils")

local logger = log.get_logger("fun.gamedata")

---@class fun.gamedata
local M = {}

-- Конфигурация gamedata из файла json
---@type table|nil
local gamedata = nil

-- Хэш встроенного файла: кэш баланса с сервера действует, пока файл тот же (до новой версии игры)
---@type string|nil
local builtin_hash = nil

-- Версия баланса с сервера в кэше; nil - только встроенный файл
---@type string|nil
local remote_version = nil

local function get_remote_path()
    return sys.get_save_file(sys.get_config_string("project.title"), "gamedata_remote")
end

--- Сохранить баланс с сервера. Применится со следующего запуска: модули читают конфигурацию при инициализации.
--- Разделы data заменяют одноименные разделы встроенного файла целиком.
---@param data table Конфигурации модулей: имя модуля → конфигурация
---@param version string Версия баланса
function M.set_remote(data, version)
    sys.save(get_remote_path(), { base = builtin_hash, version = version, data = data })
    remote_version = version
end

--- Версия баланса с сервера, сохраненного для этой версии игры; nil, если его нет
---@return string|nil
function M.get_remote_version()
    return remote_version
end

--- Получить конфигурацию модуля из конфигурации gamedata
---@param module_name string Имя модуля (iap, ads, etc)
---@param default_config any|nil Значение по умолчанию, которое будет возвращено если конфигурация не найдена. Также с этой дефолтной конфигурацией сравнивается конфигурация из gamedata.json
---@return any|nil
function M.get_module_config(module_name, default_config)
    if not gamedata then
        logger:warn("gamedata.lua is not initialized successfully")
        return tablex.deepcopy(default_config)
    end

    if not gamedata[module_name] then
        logger:warn("Can't find module configuration in gamedata.lua", { module_name = module_name })
        return tablex.deepcopy(default_config)
    end

    -- Если дефолтная конфигурация не nil, то сравниваем её с конфигурацией из gamedata.json
    if default_config ~= nil then
        local is_equal, error_msg = tablex.is_equal(default_config, gamedata[module_name])
        if not is_equal then
            logger:warn("Module configuration in gamedata.lua is not equal to default configuration, error_msg: " .. error_msg)
            return tablex.deepcopy(default_config)
        end
    end

    return tablex.deepcopy(gamedata[module_name])
end


--- Получить параметр модуля из конфигурации gamedata
---@param module_name string Имя модуля (iap, ads, etc)
---@param parameter_name string Имя параметра модуля
---@param default_value any|nil Значение по умолчанию, которое будет возвращено если параметр не найден
---@return any|nil
function M.get_module_parameter(module_name, parameter_name, default_value)
    if not gamedata then
        logger:warn("gamedata.lua is not initialized successfully")
        return tablex.deepcopy(default_value)
    end

    if not gamedata[module_name] then
        logger:warn("Can't find module configuration in gamedata.lua", { module_name = module_name })
        return tablex.deepcopy(default_value)
    end

    if not gamedata[module_name][parameter_name] then
        logger:warn("Can't find parameter in module configuration in gamedata.lua", { module_name = module_name, parameter_name = parameter_name })
        return tablex.deepcopy(default_value)
    end

    return tablex.deepcopy(gamedata[module_name][parameter_name])
end


function M.fun_pre_init()
    -- Получаем путь к файлу с конфигурацией gamedata из game.project
    local file_path = sys.get_config_string("fun.gamedata_path")
    if not file_path then
        logger:error("Gamedata path not specified in game.project")
        return
    end

    -- Загружаем конфигурацию gamedata из файла
    gamedata = utils.load_json(file_path)
    if not gamedata then
        logger:error("Error loading gamedata: " .. file_path)
        return
    end

    builtin_hash = hash_to_hex(hash(sys.load_resource(file_path)))
    local ok, remote = pcall(sys.load, get_remote_path())
    if ok and remote.base == builtin_hash and remote.data then
        for module_name, config in pairs(remote.data) do
            gamedata[module_name] = config
        end
        remote_version = remote.version
        logger:info("Gamedata remote applied", { version = remote_version })
    end

    -- Логируем инициализацию gamedata
    logger:info("Gamedata initialized from file: \"" .. file_path .. "\"")
end

return M