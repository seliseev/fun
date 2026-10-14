local log = require("fun.libs.log")
local timex = require("fun.libs.timex")
local tablex = require("fun.libs.tablex")
local saver = require("fun.modules.saver")
local gamedata = require("fun.modules.gamedata")

local logger = log.get_logger("fun.rateus")

---@class fun.rateus.config
---@field is_enabled boolean @True if module is enabled, false otherwise
---@field show_limit number @Max number of times the custom window can be shown
---@field cooldown_seconds number @Cooldown time in seconds between showing the custom window
---@field cooldown_levels number @Cooldown in levels between showing the custom window
---@field show_after_level number @Show window after this level


--- @class fun.rateus
local M = {
    state = {
        shown_count = 0,
        last_shown_time = 0,
        last_shown_level = 0,
        rated = false
    },
    ---@type fun.rateus.config
    config = {
        is_enabled = true,
        show_limit = 3,
        cooldown_seconds = 1800,
        cooldown_levels = 10,
        show_after_level = 10
    },
    runtime = {
        ---@type fun(): number|nil
        get_current_level = nil
    }
}

---@return boolean @True if system window can be shown, false otherwise
function M.can_show_system()
    if (review and review.is_supported()) then
        return true
    end
    return false
end


---@return boolean @True if custom window can be shown, false otherwise
function M.can_show_custom()
    if not M.config.is_enabled then
        return false
    end

    -- If the user has rated the game, the custom window will not be shown again
    if M.state.rated then
        return false
    end

    if M.state.shown_count >= M.config.show_limit then
        return false
    end

    if not timex.is_cooldown_reached(M.state.last_shown_time, M.config.cooldown_seconds) then
        return false
    end

    if not M.can_show_system() then
        return false
    end

    if not M.runtime.get_current_level then
        logger:warn("get_current_level function is not set")
        return false
    end

    local current_level = M.runtime.get_current_level()
    if not current_level then
        logger:warn("get_current_level returned nil")
        return false
    end

    if current_level < M.config.show_after_level then
        return false
    end

    local level_diff = current_level - M.state.last_shown_level
    if level_diff < M.config.cooldown_levels then
        return false
    end

    return true
end

--- Shows custom window
--- @param force boolean|nil @Force show window even if it's not possible
--- @return boolean @True if window was shown, false otherwise
function M.show_custom(force)
    if not M.can_show_custom() and not force then
        return false
    end

    M.state.shown_count = M.state.shown_count + 1
    M.state.last_shown_time = timex.get_time()
    
    if M.runtime.get_current_level then
        local current_level = M.runtime.get_current_level()
        if current_level then
            M.state.last_shown_level = current_level
        else
            logger:warn("get_current_level returned nil, keeping previous level")
        end
    else
        logger:warn("get_current_level function is not set, keeping previous level")
    end

    return true
end

--- Sets rated status, if true, the custom window will not be shown again
---@param rated boolean True if the user has rated the game, false otherwise
function M.set_rated(rated)
    M.state.rated = rated
end

--- Gets rated status
---@return boolean @Rated status
function M.get_rated()
    return M.state.rated
end

--- Shows system window
function M.show_system()
    if (review and review.is_supported()) then
        review.request_review()
    else
        logger:warn("Review is not supported on this platform")
    end
end

--- Sets get current level function
---@param get_current_level nil|fun(): number @Get current level function
function M.set_get_current_level(get_current_level)
    M.runtime.get_current_level = get_current_level
end


function M.fun_init()
    saver.bind_save_state("fun.rateus", M.state)
    M.config = gamedata.get_module_config("rateus", M.config)

    logger:info("Rateus module initialized")
    logger:info("Rateus state: " .. tablex.tostring(M.state))
    logger:info("Rateus config: " .. tablex.tostring(M.config))
end


return M