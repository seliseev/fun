--- Fun vibrate module
--- Обёртка над нативной библиотекой defold-haptic (https://github.com/seliseev/defold-haptic).
--- Библиотека необязательна: без неё и на платформах без хаптика вызовы ничего не делают.
local event = require("event.event")
local log = require("fun.libs.log")

local saver = require("fun.modules.saver")

local logger = log.get_logger("fun.vibrate")

---@class haptic
---@field IMPACT_LIGHT number
---@field IMPACT_MEDIUM number
---@field IMPACT_HEAVY number
---@field NOTIFICATION_SUCCESS number
---@field NOTIFICATION_WARNING number
---@field NOTIFICATION_ERROR number
---@field is_supported fun(): boolean
---@field impact fun(style: number|nil)
---@field notification fun(type: number|nil)
---@field selection fun()
---@field vibrate fun(duration_ms: number|nil)

---@type haptic|nil
local haptic = haptic

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


---@type table<fun.vibrate.PATTERNS, fun()>
local PLAYERS = {}

if haptic then
    PLAYERS[M.PATTERNS.LIGHT] = function() haptic.impact(haptic.IMPACT_LIGHT) end
    PLAYERS[M.PATTERNS.MEDIUM] = function() haptic.impact(haptic.IMPACT_MEDIUM) end
    PLAYERS[M.PATTERNS.HEAVY] = function() haptic.impact(haptic.IMPACT_HEAVY) end
    PLAYERS[M.PATTERNS.SUCCESS] = function() haptic.notification(haptic.NOTIFICATION_SUCCESS) end
    PLAYERS[M.PATTERNS.WARNING] = function() haptic.notification(haptic.NOTIFICATION_WARNING) end
    PLAYERS[M.PATTERNS.ERROR] = function() haptic.notification(haptic.NOTIFICATION_ERROR) end
end


--- Запустить вибрацию
---@param vibrate_pattern fun.vibrate.PATTERNS
function M.vibrate(vibrate_pattern)
    if not M._state.is_enabled or not haptic then
        return
    end

    local play = PLAYERS[vibrate_pattern]
    if not play then
        logger:error("Undefined pattern: " .. tostring(vibrate_pattern))
        return
    end

    play()
end


--- Проверить, может ли устройство вибрировать
---@return boolean
function M.is_supported()
    return haptic ~= nil and haptic.is_supported()
end


--- Проверить, включена ли вибрация для пользователя
---@return boolean
function M.is_enabled()
    return M._state.is_enabled
end


--- Установить, включена ли вибрация для пользователя
---@param is_enabled boolean
function M.set_enabled(is_enabled)
    if M._state.is_enabled == is_enabled then
        return
    end

    M._state.is_enabled = is_enabled
    M.on_vibrate_enabled_changed:trigger(is_enabled)
end


function M.fun_init()
    saver.bind_save_state("fun.vibrate", M._state)

    if not haptic then
        logger:debug("Haptic library is not found, vibration is disabled")
    end
end

return M
