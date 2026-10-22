--- FUN Module: wallet
--- Wrapper over 'token' module with predefined container_id

local event = require("event.event")
local token = require("token.token")

local M = {
    CONTAINER_ID = "wallet"
}

--- @class fun.wallet.reason
--- @field category string|nil
--- @field id string|nil

--- @class fun.wallet.events.on_change: event - Triggered when a token amount in wallet is changed
--- @field trigger fun(_, token_id: string, amount: number, delta: number, reason_category: string|nil, reason_id: string|nil)
--- @field subscribe fun(_, callback: fun(token_id: string, amount: number, delta: number, reason_category: string|nil, reason_id: string|nil), _)

M.on_change = event.create() --[[@as fun.wallet.events.on_change]]


---@return token.container
local function get_container()
    return token.container(M.CONTAINER_ID)
end

--- defold-token accepts single "reason", wallet keeps it as table to restore category and id in on_change
---@param reason_category string|nil
---@param reason_id string|nil
---@return fun.wallet.reason|nil
local function make_reason(reason_category, reason_id)
    if reason_category == nil and reason_id == nil then
        return nil
    end
    return { category = reason_category, id = reason_id }
end

---@param container_id string
---@param token_id string
---@param amount number
---@param reason fun.wallet.reason|string|nil
---@param delta number
local function on_token_change(container_id, token_id, amount, reason, delta)
    if container_id ~= M.CONTAINER_ID then
        return
    end

    local reason_category, reason_id
    if type(reason) == "table" then
        reason_category, reason_id = reason.category, reason.id
    else
        reason_category = reason
    end

    M.on_change:trigger(token_id, amount, delta, reason_category, reason_id)
end

---Check if wallet container exists in the system
---@return boolean is_exist True if container exists, false otherwise
function M.is_container_exist()
    return token.is_container_exist(M.CONTAINER_ID)
end

---Create wallet container if it doesn't already exist
---@return boolean True if container was successfully created, false if it already exists
function M.create_container()
    if M.is_container_exist() then
        return false
    end
    get_container()
    return true
end

---Delete wallet container and all associated tokens
function M.delete_container()
    token.delete_container(M.CONTAINER_ID)
end

---Clear all tokens from wallet container but keep the container itself
function M.clear_container()
    token.clear_container(M.CONTAINER_ID)
end

---Configure automatic token restoration over time
---@param token_id string The unique identifier for the token
---@param config token.token_restore_param Configuration for token restoration
function M.set_restore_config(token_id, config)
    get_container():set_restore_config(token_id, config)
end

---Get the current restoration configuration for a token
---@param token_id string The unique identifier for the token
---@return token.token_restore_config|nil The restoration configuration or nil if not set
function M.get_restore_config(token_id)
    return get_container():get_restore_config(token_id)
end

---Enable or disable token restoration for a specific token
---@param token_id string The unique identifier for the token
---@param is_enabled boolean Whether restoration should be enabled
function M.set_restore_config_enabled(token_id, is_enabled)
    get_container():set_restore_config_enabled(token_id, is_enabled)
end

---Check if token restoration is enabled for a specific token
---@param token_id string The unique identifier for the token
---@return boolean|nil True if enabled, false if disabled, nil if no config exists
function M.is_restore_config_enabled(token_id)
    return get_container():is_restore_config_enabled(token_id)
end

---Remove the restoration configuration for a token
---@param token_id string The unique identifier for the token
---@return boolean True if config was removed, false if it didn't exist
function M.remove_restore_config(token_id)
    return get_container():remove_restore_config(token_id)
end

---Add tokens to wallet
---@param token_id string The unique identifier for the token
---@param amount number Amount of tokens to add
---@param reason_category string|nil Optional reason category for logging/tracking
---@param reason_id string|nil Optional reason id for logging/tracking
---@param visual_later boolean|nil If true, visual update will be delayed
---@return number New token amount after addition
function M.add(token_id, amount, reason_category, reason_id, visual_later)
    return get_container():add(token_id, amount, make_reason(reason_category, reason_id), visual_later)
end

---Add multiple tokens to wallet
---@param tokens table<string, number>|nil Table mapping token IDs to amounts
---@param reason_category string|nil Optional reason category for logging/tracking
---@param reason_id string|nil Optional reason id for logging/tracking
---@param visual_later boolean|nil If true, visual update will be delayed
function M.add_many(tokens, reason_category, reason_id, visual_later)
    get_container():add_many(tokens, make_reason(reason_category, reason_id), visual_later)
end

---Set the amount of multiple tokens in wallet
---@param tokens table<string, number>|nil Table mapping token IDs to new amounts
---@param reason_category string|nil Optional reason category for logging/tracking
---@param reason_id string|nil Optional reason id for logging/tracking
---@param visual_later boolean|nil If true, visual update will be delayed
function M.set_many(tokens, reason_category, reason_id, visual_later)
    get_container():set_many(tokens, make_reason(reason_category, reason_id), visual_later)
end

---Add tokens from a token group to wallet
---@param token_group_id string The unique identifier for the token group
---@param reason_category string|nil Optional reason category for logging/tracking
---@param reason_id string|nil Optional reason id for logging/tracking
---@param visual_later boolean|nil If true, visual update will be delayed
function M.add_group(token_group_id, reason_category, reason_id, visual_later)
    get_container():add_group(token_group_id, make_reason(reason_category, reason_id), visual_later)
end

---Set tokens in wallet to match a token group
---@param token_group_id string The unique identifier for the token group
---@param reason_category string|nil Optional reason category for logging/tracking
---@param reason_id string|nil Optional reason id for logging/tracking
---@param visual_later boolean|nil If true, visual update will be delayed
function M.set_group(token_group_id, reason_category, reason_id, visual_later)
    get_container():set_group(token_group_id, make_reason(reason_category, reason_id), visual_later)
end

---Pay tokens from wallet using a token group as the cost
---@param token_group_id string The unique identifier for the token group
---@param reason_category string|nil Optional reason category for logging/tracking
---@param reason_id string|nil Optional reason id for logging/tracking
---@return boolean True if payment was successful, false otherwise
function M.pay_group(token_group_id, reason_category, reason_id)
    return get_container():pay_group(token_group_id, make_reason(reason_category, reason_id))
end

---Set a token amount in wallet
---@param token_id string The unique identifier for the token
---@param amount number New amount for the token
---@param reason_category string|nil Optional reason category for logging/tracking
---@param reason_id string|nil Optional reason id for logging/tracking
---@param visual_later boolean|nil If true, visual update will be delayed
---@return number New token amount
function M.set(token_id, amount, reason_category, reason_id, visual_later)
    return get_container():set(token_id, amount, make_reason(reason_category, reason_id), visual_later)
end

---Get the current amount of a token in wallet
---@param token_id string The unique identifier for the token
---@param default_value any Value to return if the token doesn't exist
---@return number|any Current token amount or default_value if not found
function M.get(token_id, default_value)
    if not M.is_container_exist() then
        return default_value
    end
    return get_container():get(token_id)
end

---Get all tokens from wallet
---@return table<string, number>|nil Table mapping token IDs to amounts, or nil if container doesn't exist
function M.get_many()
    if not M.is_container_exist() then
        return nil
    end
    return get_container():get_many()
end

---Get all tokens from wallet that are not synced with visual value
---@return table<string, number> @Table mapping token IDs to amounts of not synced tokens
function M.get_many_not_synced()
    local all_wallet_tokens = M.get_many()
    if not all_wallet_tokens then
        return {}
    end
    local not_synced_tokens = {}
    for token_id, amount in pairs(all_wallet_tokens) do
        if amount ~= M.get_visual(token_id) then
            not_synced_tokens[token_id] = amount - M.get_visual(token_id)
        end
    end
    return not_synced_tokens
end

---Pay a specific amount of tokens from wallet
---@param token_id string The unique identifier for the token
---@param amount number Amount to pay/subtract
---@param reason_category string|nil Optional reason category for logging/tracking
---@param reason_id string|nil Optional reason id for logging/tracking
---@param visual_later boolean|nil If true, visual update will be delayed
---@return boolean True if payment was successful, false if not enough tokens
function M.pay(token_id, amount, reason_category, reason_id, visual_later)
    return get_container():pay(token_id, amount, make_reason(reason_category, reason_id), visual_later)
end

---Pay multiple tokens from wallet
---@param tokens table<string, number> Table mapping token IDs to amounts to pay
---@param reason_category string|nil Optional reason category for logging/tracking
---@param reason_id string|nil Optional reason id for logging/tracking
---@param visual_later boolean|nil If true, visual update will be delayed
---@return boolean True if all payments were successful, false otherwise
function M.pay_many(tokens, reason_category, reason_id, visual_later)
    return get_container():pay_many(tokens, make_reason(reason_category, reason_id), visual_later)
end

---Check if there are enough tokens to pay a specific amount
---@param token_id string The unique identifier for the token
---@param amount number Amount to check for
---@return boolean True if enough tokens are available, false otherwise
function M.is_enough(token_id, amount)
    return get_container():is_enough(token_id, amount)
end

---Check if a token has zero amount
---@param token_id string The unique identifier for the token
---@return boolean True if token amount is zero, false otherwise
function M.is_empty(token_id)
    return get_container():is_empty(token_id)
end

---Check if a token is at its maximum allowed amount
---@param token_id string The unique identifier for the token
---@return boolean True if token is at maximum, false otherwise
function M.is_max(token_id)
    return get_container():is_max(token_id)
end

---Check if there are enough tokens to pay multiple costs
---@param tokens table<string, number>|nil Table mapping token IDs to amounts to check
---@return boolean True if enough of all tokens are available, false otherwise
function M.is_enough_many(tokens)
    return get_container():is_enough_many(tokens)
end

---Check if there are enough tokens to pay for a token group
---@param token_group_id string The unique identifier for the token group
---@return boolean True if enough of all tokens in group are available, false otherwise
function M.is_enough_group(token_group_id)
    return get_container():is_enough_group(token_group_id)
end

---Add time to a token's infinity state (where it can be spent without limit)
---@param token_id string The unique identifier for the token
---@param seconds number Number of seconds to add to infinity time
function M.add_infinity_time(token_id, seconds)
    get_container():add_infinity_time(token_id, seconds)
end

---Check if a token is currently in infinity state
---@param token_id string The unique identifier for the token
---@return boolean True if token is in infinity state, false otherwise
function M.is_infinity(token_id)
    return get_container():is_infinity(token_id)
end

---Get remaining time in seconds for a token's infinity state
---@param token_id string The unique identifier for the token
---@return number Seconds remaining in infinity state, 0 if not in infinity state
function M.get_infinity_time(token_id)
    return get_container():get_infinity_time(token_id)
end

---Set the time for a token's infinity state
---@param token_id string The unique identifier for the token
---@param time number End time for infinity state in seconds
function M.set_infinity_time(token_id, time)
    get_container():set_infinity_time(token_id, time)
end

---Get time remaining until next automatic token restore
---@param token_id string The unique identifier for the token
---@return number|nil Seconds until next restore, or nil if no restore config
function M.get_time_to_restore(token_id)
    return get_container():get_time_to_restore(token_id)
end

---Reset visual debt of tokens to match actual value
---@param token_id string The unique identifier for the token
function M.sync_visual(token_id)
    return get_container():sync_visual(token_id)
end

---Add visual debt to a token (for animations, etc.)
---@param token_id string The unique identifier for the token
---@param amount number Amount to add to visual counter
function M.add_visual(token_id, amount)
    return get_container():add_visual(token_id, amount)
end

---Get current visual amount of a token (including debt)
---@param token_id string The unique identifier for the token
---@return number Visual amount of the token (never negative)
function M.get_visual(token_id)
    return get_container():get_visual(token_id)
end

---Get the total accumulated amount of a specific token
---@param token_id string Token id
---@return number The total amount of tokens ever acquired (regardless of spending)
function M.get_total_sum(token_id)
    return get_container():get_total_sum(token_id)
end

function M.fun_init()
    token.on_token_change:subscribe(on_token_change)
end

function M.fun_post_init()
    M.create_container()
end

function M.fun_final()
    token.on_token_change:unsubscribe(on_token_change)
end

return M