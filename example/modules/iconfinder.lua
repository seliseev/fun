local gamedata = require("fun.modules.gamedata")
local luax = require("fun.luax")
local log = require("fun.libs.log")
local logger = log.get_logger("game.iconfinder")

---@class game.iconfinder
local M = {
    --- @type table<string, string> List of icons for token ids, key is token id, value is icon path
    icons_list = {}
}

function M.register_icon(token_id, icon_path)
    M.icons_list[token_id] = icon_path
end

function M.get_texture(token_id)
    assert(token_id, "token_id is required")
    if not M.icons_list[token_id] then
        logger:error("Icon for token id '" .. token_id .. "' not found")
        return nil
    end
    local texture_name = luax.string.split(M.icons_list[token_id], ":")[1]
    return hash(texture_name)
end

function M.get_flipbook(token_id)
    assert(token_id, "token_id is required")
    if not M.icons_list[token_id] then
        logger:error("Icon for token id '" .. token_id .. "' not found")
        return nil
    end
    local flipbook_name = luax.string.split(M.icons_list[token_id], ":")[2]
    return hash(flipbook_name)
end

function M.get_icon_for_druid_richtext(token_id)
    assert(token_id, "token_id is required")
    if not M.icons_list[token_id] then
        logger:error("Icon for token id '" .. token_id .. "' not found")
        return nil
    end

    return M.icons_list[token_id]
end


function M.fun_init()
    local icons_list = gamedata.get_module_config("iconfinder", M.icons_list)
    for token_id, icon_path in pairs(icons_list) do
        M.register_icon(token_id, icon_path)
    end
end


return M