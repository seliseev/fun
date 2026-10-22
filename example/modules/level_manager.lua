--- Пример менеджера уровней.
--- В реальной игре здесь живет логика уровней, для примера уровень проходится одной кнопкой.

local events = require("event.events")
local log = require("fun.libs.log")

local timex = require("fun.libs.timex")
local tablex = require("fun.libs.tablex")
local const = require("fun.const")

local saver = require("fun.modules.saver")
local adsservice = require("fun.modules.adsservice")
local game = require("fun.modules.game")

local logger = log.get_logger("example.level_manager")

local RECORDS_TTL = 30 * 24 * 60 * 60 -- храним историю побед за 30 дней

---@class example.level
---@field id integer

--- @class example.level_manager
local M = {
    state = {
        completed_levels = 0,
        level_records = {}
    },
}

---------------------------------------------------
-- Public methods
---------------------------------------------------

--- Текущий уровень
---@return example.level
function M.current_level()
    return { id = M.state.completed_levels + 1 }
end

--- Проходит текущий уровень и вызывает событие LEVEL_WIN
function M.complete()
    local level = M.current_level()

    M.state.completed_levels = M.state.completed_levels + 1
    table.insert(M.state.level_records, {
        timestamp = timex.get_time()
    })
    tablex.remove_if(M.state.level_records, function(record)
        return record.timestamp < timex.get_time() - RECORDS_TTL
    end)

    logger:info("Level completed", { level_id = level.id })
    events.trigger(const.EVENTS.LEVEL_WIN, level)
end

--- Перезапускает текущий уровень
function M.restart()
    events.trigger(const.EVENTS.LEVEL_RESTART, M.current_level())
end

--- Get completed levels
---@param last_n_days integer|nil Number of days, 0 or nil - for all time
---@return integer
function M.get_wins(last_n_days)
    last_n_days = last_n_days or 0
    if last_n_days == 0 then
        return M.state.completed_levels
    end

    return tablex.count_if(M.state.level_records, function(record)
        return record.timestamp >= timex.get_time() - last_n_days * 24 * 60 * 60
    end)
end

--- Get average wins per day for last N days or for all time if last_n_days is 0
---@param last_n_days integer
---@return number
function M.get_avg_wins_per_day(last_n_days)
    local count_wins = M.get_wins(last_n_days)
    local days = last_n_days == 0 and game.get_days_played() or last_n_days

    if days == 0 then
        return 0
    end

    return count_wins / days
end

---------------------------------------------------
-- Fun callbacks
---------------------------------------------------

function M.fun_init()
    saver.bind_save_state("example.level_manager", M.state)

    adsservice.runtime.get_current_level = function()
        return M.current_level().id
    end
end

return M
