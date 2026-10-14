local log = require("fun.libs.log")
local token = require("token.token")

local saver = require("fun.modules.saver")
local gamedata = require("fun.modules.gamedata")

local logger = log.get_logger("fun.token")


--- @class fun.token
local M = {
}

function M.fun_init()
    saver.bind_save_state("fun.token", token.state)

    local token_config = gamedata.get_module_config("token")
    if not token_config then
        logger:warn("\"token\" configuration not found in gamedata")
    end

    token.init(token_config)
end

return M