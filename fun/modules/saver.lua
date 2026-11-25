local event = require("event.event")
local saver = require("saver.saver")
local log = require("fun.libs.log")

local logger = log.get_logger("fun.saver")

---@class fun.saver
local M = {}


--- @class fun.saver.on_before_save: event - Triggered before saving the game state
--- @field trigger fun(_)
--- @field subscribe fun(_, callback: fun(), _)
M.on_before_save = event.create()   --[[@as fun.saver.on_before_save]]


--- @class fun.saver.on_state_loaded: event - Triggered after loading the game state from any source (local file or cloud)
--- @field trigger fun(_)
--- @field subscribe fun(_, callback: fun(), _)
M.on_state_loaded = event.create()  --[[@as fun.saver.on_state_loaded]]


function M.bind_save_state(table_key_id, table_reference)
    saver.bind_save_state(table_key_id, table_reference)
end

function M.get_value(key_id, default_value)
    return saver.get_value(key_id, default_value)
end

---Сохраняет значение в сохраненном файле
---@param key_id string Идентификатор ключа
---@param value any Значение
function M.set_value(key_id, value)
    saver.set_value(key_id, value)
end

function M.is_value_exists(key_id)
    return saver.is_value_exists(key_id)
end

function M.save()
    logger:info("Saving game state")
    return saver.save_game_state()
end

function M.clear()
    saver.load_game_state("deleted")
    saver.save_game_state()
end

--- Returns the entire current game state table (reference to internal table)
---@return table game_state
function M.get_state()
    return saver.get_game_state()
end

--- Recursively replace the contents of the existing bound tables with values from `source`.
--- This preserves table references that other modules already hold (e.g. wallet.state, iapservice.state)
--- so newly loaded data (e.g. from cloud) propagates without re-binding.
---@param source table The new state to merge into the current bound tables.
local function deep_override(target, source)
    if type(target) ~= "table" or type(source) ~= "table" then
        return
    end
    for k in pairs(target) do
        if source[k] == nil then
            target[k] = nil
        end
    end
    for k, v in pairs(source) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then
                target[k] = {}
            end
            deep_override(target[k], v)
        else
            target[k] = v
        end
    end
end

--- Overrides the contents of the currently bound game state with `new_state` while keeping table references intact.
--- After calling this, all modules that captured `M.state` references will see the updated values.
--- Top-level sections missing in `new_state` are kept as is: an older save (e.g. cloud data from a previous
--- game version) doesn't know about sections added later, and removing them would detach the bound tables
--- of new modules from the game state, so their progress would never be saved again.
---@param new_state table The new state to override the current game state with.
---@param persist boolean|nil If true, immediately writes the merged state to disk.
function M.override_state(new_state, persist)
    if type(new_state) ~= "table" then
        logger:warn("override_state: ignored, new_state is not a table")
        return
    end
    local current = saver.get_game_state()
    for key, value in pairs(new_state) do
        if type(value) == "table" then
            if type(current[key]) ~= "table" then
                current[key] = {}
            end
            deep_override(current[key], value)
        else
            current[key] = value
        end
    end
    M.on_state_loaded:trigger()
    if persist then
        saver.save_game_state()
    end
end

--- Log current save data
function M.debug()
    logger:info("Save Path: " .. saver.get_save_path("token"))
    logger:info("Save Data:")
    pprint(saver.get_game_state())
end


function M.fun_pre_init()
    saver.init()
    saver.before_save_callback = function()
        M.on_before_save:trigger()
    end
end

function M.fun_post_init()
    M.debug()
end

return M