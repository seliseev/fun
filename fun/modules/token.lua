local log = require("fun.libs.log")
local token = require("token.token")

local saver = require("fun.modules.saver")
local gamedata = require("fun.modules.gamedata")

local logger = log.get_logger("fun.token")


--- @class fun.token.config
--- @field tokens table<string, token.token_config_data>|nil
--- @field groups table<string, table<string, number>>|nil
--- @field lots table<string, token.lot>|nil

--- @class fun.token
local M = {
}

--- Пересоздает контейнеры из состояния, когда сохранение подменили целиком (например, облачное в yagames)
local function on_state_loaded()
    token.init()
end

function M.fun_init()
    token.set_logger(log.get_logger("token"))

    -- defold-token заменяет таблицу состояния в reset_state/set_state, поэтому после привязки их не вызываем:
    -- saver заполняет эту же таблицу на месте
    saver.bind_save_state("fun.token", token.get_state())

    --- @type fun.token.config|nil
    local token_config = gamedata.get_module_config("token")
    if not token_config then
        logger:warn("\"token\" configuration not found in gamedata")
        token_config = {}
    end

    if token_config.groups then
        token.register_token_groups(token_config.groups)
    end
    if token_config.lots then
        token.register_lots(token_config.lots)
    end
    token.init(token_config.tokens)

    saver.on_state_loaded:subscribe(on_state_loaded)
end

function M.fun_final()
    saver.on_state_loaded:unsubscribe(on_state_loaded)
end

return M
