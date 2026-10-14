--- Fun vibrate module
local event = require("event.event")
local log = require("fun.libs.log")

local tablex = require("fun.libs.tablex")
local device = require("fun.modules.device")
local saver = require("fun.modules.saver")

local logger = log.get_logger("fun.vibrate")

---@type taptic_engine
local taptic_engine = taptic_engine

---@class fun.vibrate
local M = {
    ---@enum fun.vibrate.PATTERNS
    PATTERNS = {
        LIGHT = 1,
        MEDIUM = 2,
        HEAVY = 3,
        SUCCESS = 4,
        WARNING = 5,
        ERROR = 6
    },

    _state = {
        is_enabled = true
    }
}

--- @class fun.vibrate.events.on_vibrate_enabled_changed: event
--- @field trigger fun(_, is_enabled: boolean)
--- @field subscribe fun(_, callback: fun(is_enabled: boolean), _)
M.on_vibrate_enabled_changed = event.create() --[[@as fun.vibrate.events.on_vibrate_enabled_changed]]


local ANDROID_PATTERNS_CONVERTOR = {
    [M.PATTERNS.LIGHT] = {0, 30},
    [M.PATTERNS.MEDIUM] = {0, 50},
    [M.PATTERNS.HEAVY] = {0, 70},
    [M.PATTERNS.SUCCESS] = {0, 50, 60, 60},
    [M.PATTERNS.WARNING] = {0, 80},
    [M.PATTERNS.ERROR] = {0, 60, 40, 60}
}

local IOS_PATTERNS_CONVERTOR = {
    [M.PATTERNS.LIGHT] = 1,
    [M.PATTERNS.MEDIUM] = 2,
    [M.PATTERNS.HEAVY] = 3,
    [M.PATTERNS.SUCCESS] = 1,
    [M.PATTERNS.WARNING] = 2,
    [M.PATTERNS.ERROR] = 3
}

local function call_android_vibrate(pattern)

    if vibrate then
        vibrate.vibrate(ANDROID_PATTERNS_CONVERTOR[pattern])
    end
end

local function call_ios_taptic_engine(pattern)
    if taptic_engine and taptic_engine.isSupported() then
        if tablex.contains({M.PATTERNS.LIGHT, M.PATTERNS.MEDIUM, M.PATTERNS.HEAVY}, pattern) then
            taptic_engine.impact(IOS_PATTERNS_CONVERTOR[pattern])
        elseif tablex.contains({M.PATTERNS.SUCCESS, M.PATTERNS.WARNING, M.PATTERNS.ERROR}, pattern) then
            taptic_engine.notification(IOS_PATTERNS_CONVERTOR[pattern])
        else
            logger:error("Undefined pattern: " .. pattern)
        end
    end
end


--- Запустить вибрацию
---@param vibrate_pattern fun.vibrate.PATTERNS
function M.vibrate(vibrate_pattern)
    if not M._state.is_enabled then
        return
    end

    if device.is_android() then
        call_android_vibrate(vibrate_pattern)
    end

    if device.is_ios() then
        call_ios_taptic_engine(vibrate_pattern)
    end
end


--- Проверть включена ли вибрация для пользователя
---@return boolean
function M.is_enabled()
    return M._state.is_enabled
end


--- Установить включена ли вибрация для пользователя
---@param is_enabled boolean
function M.set_enabled(is_enabled)
    M._state.is_enabled = is_enabled
end


function M.fun_init()
    saver.bind_save_state("fun.vibrate", M._state)
end

return M