local event = require("event.event")
local log = require("fun.libs.log")

local target = require("fun.modules.target")

local logger = log.get_logger("fun.modules.firebase")


---@class fun.modules.firebase
local M = {
    config = nil
}

M.on_initialized = event.create()
M.on_installation_id = event.create()
M.on_installation_auth_token = event.create()
M.on_error = event.create()


local function firebase_callback(self, message_id, message)
    if message_id == firebase.MSG_INITIALIZED then
        -- firebase is ready to use!
        logger:debug("Firebase initialized")

        -- installation auth token can be used for configuring test devices for A/B tests
        firebase.get_installation_auth_token()
        -- retrieve Firebase installation ID for example, to create segments of app installs for BiqQuery import,
        -- or toperform testing during Firebase In-App Messaging development,
        -- you can identify and target the correct devices using the corresponding Firebase installation IDs.
        firebase.get_installation_id()
        M.on_initialized:trigger()
    elseif message_id == firebase.MSG_INSTALLATION_ID then
        logger:debug("Firebase installation ID", { id = message.id })
        M.on_installation_id:trigger(message.id)
    elseif message_id == firebase.MSG_INSTALLATION_AUTH_TOKEN then
        logger:debug("Firebase installation auth token", { token = message.token })
        M.on_installation_auth_token:trigger(message.token)
    elseif message_id == firebase.MSG_ERROR then
        logger:error("Firebase error", { error = message.error })
        M.on_error:trigger(message.error)
    end
end


function M.fun_pre_init()
    if not firebase then
        logger:warn("firebase extension is not available at this platform")
        return
    end
    firebase.set_callback(firebase_callback)
end


function M.fun_init()
    if not firebase then
        return
    end
end

function M.fun_post_init()
    if not firebase then
        return
    end
    logger:debug("Firebase initializing")

    firebase.initialize()
end

return M