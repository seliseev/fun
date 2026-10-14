--- FUN Module: wallet
--- Wrapper over 'token' module with predefined container_id

local token = require("token.token")

local M = {
    CONTAINER_ID = "wallet"
}

---Check if wallet container exists in the system
---@return boolean is_exist True if container exists, false otherwise
function M.is_container_exist()
    return token.is_container_exist(M.CONTAINER_ID)
end

---Create wallet container if it doesn't already exist
---@return boolean True if container was successfully created, false if it already exists
function M.create_container()
    return token.create_container(M.CONTAINER_ID)
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
    token.set_restore_config(M.CONTAINER_ID, token_id, config)
end

---Get the current restoration configuration for a token
---@param token_id string The unique identifier for the token
---@return token.token_restore_config|nil The restoration configuration or nil if not set
function M.get_restore_config(token_id)
    return token.get_restore_config(M.CONTAINER_ID, token_id)
end

---Enable or disable token restoration for a specific token
---@param token_id string The unique identifier for the token
---@param is_enabled boolean Whether restoration should be enabled
function M.set_restore_config_enabled(token_id, is_enabled)
    token.set_restore_config_enabled(M.CONTAINER_ID, token_id, is_enabled)
end

---Check if token restoration is enabled for a specific token
---@param token_id string The unique identifier for the token
---@return boolean|nil True if enabled, false if disabled, nil if no config exists
function M.is_restore_config_enabled(token_id)
    return token.is_restore_config_enabled(M.CONTAINER_ID, token_id)
end

---Remove the restoration configuration for a token
---@param token_id string The unique identifier for the token
---@return boolean True if config was removed, false if it didn't exist
function M.remove_restore_config(token_id)
    return token.remove_restore_config(M.CONTAINER_ID, token_id)
end

---Add tokens to wallet
---@param token_id string The unique identifier for the token
---@param amount number Amount of tokens to add
---@param reason_category string|nil Optional reason category for logging/tracking
---@param reason_id string|nil Optional reason id for logging/tracking
---@param visual_later boolean|nil If true, visual update will be delayed
---@return number New token amount after addition
function M.add(token_id, amount, reason_category, reason_id, visual_later)
    return token.add(M.CONTAINER_ID, token_id, amount, reason_category, reason_id, visual_later)
end

---Add multiple tokens to wallet
---@param tokens table<string, number>|nil Table mapping token IDs to amounts
---@param reason_category string|nil Optional reason category for logging/tracking
---@param reason_id string|nil Optional reason id for logging/tracking
---@param visual_later boolean|nil If true, visual update will be delayed
function M.add_many(tokens, reason_category, reason_id, visual_later)
    token.add_many(M.CONTAINER_ID, tokens, reason_category, reason_id, visual_later)
end

---Set the amount of multiple tokens in wallet
---@param tokens table<string, number>|nil Table mapping token IDs to new amounts
---@param reason_category string|nil Optional reason category for logging/tracking
---@param reason_id string|nil Optional reason id for logging/tracking
---@param visual_later boolean|nil If true, visual update will be delayed
function M.set_many(tokens, reason_category, reason_id, visual_later)
    token.set_many(M.CONTAINER_ID, tokens, reason_category, reason_id, visual_later)
end

---Add tokens from a token group to wallet
---@param token_group_id string The unique identifier for the token group
---@param reason_category string|nil Optional reason category for logging/tracking
---@param reason_id string|nil Optional reason id for logging/tracking
---@param visual_later boolean|nil If true, visual update will be delayed
function M.add_group(token_group_id, reason_category, reason_id, visual_later)
    token.add_group(M.CONTAINER_ID, token_group_id, reason_category, reason_id, visual_later)
end

---Set tokens in wallet to match a token group
---@param token_group_id string The unique identifier for the token group
---@param reason_category string|nil Optional reason category for logging/tracking
---@param reason_id string|nil Optional reason id for logging/tracking
---@param visual_later boolean|nil If true, visual update will be delayed
function M.set_group(token_group_id, reason_category, reason_id, visual_later)
    token.set_group(M.CONTAINER_ID, token_group_id, reason_category, reason_id, visual_later)
end

---Pay tokens from wallet using a token group as the cost
---@param token_group_id string The unique identifier for the token group
---@param reason_category string|nil Optional reason category for logging/tracking
---@param reason_id string|nil Optional reason id for logging/tracking
---@return boolean True if payment was successful, false otherwise
function M.pay_group(token_group_id, reason_category, reason_id)
    return token.pay_group(M.CONTAINER_ID, token_group_id, reason_category, reason_id)
end

---Set a token amount in wallet
---@param token_id string The unique identifier for the token
---@param amount number New amount for the token
---@param reason_category string|nil Optional reason category for logging/tracking
---@param reason_id string|nil Optional reason id for logging/tracking
---@param visual_later boolean|nil If true, visual update will be delayed
---@return number New token amount
function M.set(token_id, amount, reason_category, reason_id, visual_later)
    return token.set(M.CONTAINER_ID, token_id, amount, reason_category, reason_id, visual_later)
end

---Get the current amount of a token in wallet
---@param token_id string The unique identifier for the token
---@param default_value any Value to return if the token doesn't exist
---@return number|any Current token amount or default_value if not found
function M.get(token_id, default_value)
    return token.get(M.CONTAINER_ID, token_id, default_value)
end

---Get all tokens from wallet
---@return table<string, number>|nil Table mapping token IDs to amounts, or nil if container doesn't exist
function M.get_many()
    return token.get_many(M.CONTAINER_ID)
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
    return token.pay(M.CONTAINER_ID, token_id, amount, reason_category, reason_id, visual_later)
end

---Pay multiple tokens from wallet
---@param tokens table<string, number> Table mapping token IDs to amounts to pay
---@param reason_category string|nil Optional reason category for logging/tracking
---@param reason_id string|nil Optional reason id for logging/tracking
---@param visual_later boolean|nil If true, visual update will be delayed
---@return boolean True if all payments were successful, false otherwise
function M.pay_many(tokens, reason_category, reason_id, visual_later)
    return token.pay_many(M.CONTAINER_ID, tokens, reason_category, reason_id, visual_later)
end

---Check if there are enough tokens to pay a specific amount
---@param token_id string The unique identifier for the token
---@param amount number Amount to check for
---@return boolean True if enough tokens are available, false otherwise
function M.is_enough(token_id, amount)
    return token.is_enough(M.CONTAINER_ID, token_id, amount)
end

---Check if a token has zero amount
---@param token_id string The unique identifier for the token
---@return boolean True if token amount is zero, false otherwise
function M.is_empty(token_id)
    return token.is_empty(M.CONTAINER_ID, token_id)
end

---Check if a token is at its maximum allowed amount
---@param token_id string The unique identifier for the token
---@return boolean True if token is at maximum, false otherwise
function M.is_max(token_id)
    return token.is_max(M.CONTAINER_ID, token_id)
end

---Check if there are enough tokens to pay multiple costs
---@param tokens table<string, number>|nil Table mapping token IDs to amounts to check
---@return boolean True if enough of all tokens are available, false otherwise
function M.is_enough_many(tokens)
    return token.is_enough_many(M.CONTAINER_ID, tokens)
end

---Check if there are enough tokens to pay for a token group
---@param token_group_id string The unique identifier for the token group
---@return boolean True if enough of all tokens in group are available, false otherwise
function M.is_enough_group(token_group_id)
    return token.is_enough_group(M.CONTAINER_ID, token_group_id)
end

---Add time to a token's infinity state (where it can be spent without limit)
---@param token_id string The unique identifier for the token
---@param seconds number Number of seconds to add to infinity time
function M.add_infinity_time(token_id, seconds)
    token.add_infinity_time(M.CONTAINER_ID, token_id, seconds)
end

---Check if a token is currently in infinity state
---@param token_id string The unique identifier for the token
---@return boolean True if token is in infinity state, false otherwise
function M.is_infinity(token_id)
    return token.is_infinity(M.CONTAINER_ID, token_id)
end

---Get remaining time in seconds for a token's infinity state
---@param token_id string The unique identifier for the token
---@return number Seconds remaining in infinity state, 0 if not in infinity state
function M.get_infinity_time(token_id)
    return token.get_infinity_time(M.CONTAINER_ID, token_id)
end

---Set the time for a token's infinity state
---@param token_id string The unique identifier for the token
---@param time number End time for infinity state in seconds
function M.set_infinity_time(token_id, time)
    token.set_infinity_time(M.CONTAINER_ID, token_id, time)
end

---Get time remaining until next automatic token restore
---@param token_id string The unique identifier for the token
---@return number|nil Seconds until next restore, or nil if no restore config
function M.get_time_to_restore(token_id)
    return token.get_time_to_restore(M.CONTAINER_ID, token_id)
end

---Reset visual debt of tokens to match actual value
---@param token_id string The unique identifier for the token
function M.sync_visual(token_id)
    return token.sync_visual(M.CONTAINER_ID, token_id)
end

---Add visual debt to a token (for animations, etc.)
---@param token_id string The unique identifier for the token
---@param amount number Amount to add to visual counter
function M.add_visual(token_id, amount)
    return token.add_visual(M.CONTAINER_ID, token_id, amount)
end

---Get current visual amount of a token (including debt)
---@param token_id string The unique identifier for the token
---@return number Visual amount of the token (never negative)
function M.get_visual(token_id)
    return token.get_visual(M.CONTAINER_ID, token_id)
end

---Get the total accumulated amount of a specific token
---@param token_id string Token id
---@return number The total amount of tokens ever acquired (regardless of spending)
function M.get_total_sum(token_id)
    return token.get_total_sum(M.CONTAINER_ID, token_id)
end

function M.fun_post_init()
    token.create_container(M.CONTAINER_ID)
end

return M