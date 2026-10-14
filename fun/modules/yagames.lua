--- FUN Module: yagames
--- Integrates the indiesoftby/defold-yagames SDK with FUN architecture:
--- - calls yagames.init() and yagames.player_init() once the engine starts
--- - pulls full cloud save via yagames.player_get_data on startup and overrides the
---   currently bound saver state if cloud data is newer than the local one
--- - on every local save (saver.on_before_save), pushes the full game state back to
---   yagames.player_set_data so the cloud always mirrors the local save
--- - signals yagames.features_loadingapi_ready() once everything is initialised so the
---   Yandex Games loading screen disappears

local event = require("event.event")

local log = require("fun.libs.log")

local saver = require("fun.modules.saver")
local fun_sound = require("fun.modules.sound")
local lang = require("fun.modules.lang")

local logger = log.get_logger("fun.yagames")

local CLOUD_TIMESTAMP_KEY = "_fun_synced_at"

-- Yandex limits player.setData to 100 requests per 5 minutes, while the local saver
-- autosaves every few seconds. Non-flush pushes are throttled to at most one per interval.
local CLOUD_PUSH_INTERVAL = 10

-- Direct require so Defold's bob picks up the dependency during static analysis and
-- bundles `yagames/yagames.lua` into the build. On non-HTML5 platforms the library
-- transparently switches to its bundled mock implementation, so this require is safe
-- everywhere (`yagames.init(cb)` will print a "running mocked local SDK" notice).
local yagames = require("yagames.yagames")

---@class fun.yagames.events.on_initialized: event Triggered when the Yandex.Games SDK + player are initialised
---@field trigger fun(_)
---@field subscribe fun(_, callback: fun(), _)

---@class fun.yagames.events.on_cloud_loaded: event Triggered after the first cloud pull completes (success or failure)
---@field trigger fun(_, success: boolean, applied: boolean)
---@field subscribe fun(_, callback: fun(success: boolean, applied: boolean), _)

---@class fun.yagames
local M = {
    runtime = {
        is_available = false,           -- true once we know yagames extension is present
        is_sdk_ready = false,           -- true once yagames.init callback succeeded
        is_player_ready = false,        -- true once yagames.player_init callback succeeded
        is_loading_api_ready = false,   -- true once features_loadingapi_ready was sent
        cloud_pending_push = false,     -- guards against overlapping player_set_data calls
        cloud_dirty = false,            -- set when a save happens while a push is in flight
        cloud_dirty_flush = false,      -- the postponed push must be flushed
        cloud_last_push_time = 0,       -- socket.gettime() of the last player_set_data call
        cloud_push_timer = nil,         -- timer handle for a throttled push
        cloud_last_pushed_json = nil,   -- serialized state of the last push, used to skip unchanged pushes
        sdk_ready_callbacks = {},       -- callbacks waiting for yagames.init to succeed
        is_gameplay_active = false,     -- game wants GameplayAPI to be in "started" state
        is_gameplay_started = false,    -- last GameplayAPI marker sent to the SDK
        is_paused = false,              -- platform sent game_api_pause and no game_api_resume yet
    }
}

M.on_initialized = event.create()       --[[@as fun.yagames.events.on_initialized]]
M.on_cloud_loaded = event.create()      --[[@as fun.yagames.events.on_cloud_loaded]]
M.on_pause = event.create()             --[[@as fun.yagames.events.on_initialized]]
M.on_resume = event.create()            --[[@as fun.yagames.events.on_initialized]]

------------------------------------------------
--- Internal helpers
------------------------------------------------

--- Serialize the state without the sync timestamp so unchanged progress can be detected.
---@param state table
---@return string
local function serialize_state(state)
    local timestamp = state[CLOUD_TIMESTAMP_KEY]
    state[CLOUD_TIMESTAMP_KEY] = nil
    local encoded = json.encode(state)
    state[CLOUD_TIMESTAMP_KEY] = timestamp
    return encoded
end

local push_state_to_cloud

--- Mark the cloud copy as outdated and schedule a push after the throttle interval.
---@param flush boolean
local function schedule_push(flush)
    M.runtime.cloud_dirty = true
    M.runtime.cloud_dirty_flush = M.runtime.cloud_dirty_flush or flush
    if M.runtime.cloud_pending_push or M.runtime.cloud_push_timer then
        return
    end

    local delay = math.max(0, CLOUD_PUSH_INTERVAL - (socket.gettime() - M.runtime.cloud_last_push_time))
    M.runtime.cloud_push_timer = timer.delay(delay, false, function()
        M.runtime.cloud_push_timer = nil
        local dirty_flush = M.runtime.cloud_dirty_flush
        M.runtime.cloud_dirty = false
        M.runtime.cloud_dirty_flush = false
        push_state_to_cloud(dirty_flush)
    end)
end

--- Push the current bound saver state to Yandex cloud as a single blob.
--- `flush` controls whether the SDK pushes immediately (true) or batches (false).
--- Non-flush pushes are throttled by CLOUD_PUSH_INTERVAL and skipped if nothing changed.
---@param flush boolean
push_state_to_cloud = function(flush)
    if not M.runtime.is_available or not M.runtime.is_player_ready then
        return
    end

    local state = saver.get_state()
    if type(state) ~= "table" then
        logger:warn("Saver state is not a table, skipping cloud push")
        return
    end

    local encoded = serialize_state(state)
    if not flush and encoded == M.runtime.cloud_last_pushed_json then
        return
    end

    if M.runtime.cloud_pending_push then
        -- A push is already in flight - re-push when it completes.
        M.runtime.cloud_dirty = true
        M.runtime.cloud_dirty_flush = M.runtime.cloud_dirty_flush or flush
        return
    end

    if not flush and socket.gettime() - M.runtime.cloud_last_push_time < CLOUD_PUSH_INTERVAL then
        schedule_push(false)
        return
    end

    if M.runtime.cloud_push_timer then
        timer.cancel(M.runtime.cloud_push_timer)
        M.runtime.cloud_push_timer = nil
    end

    -- Stamp the cloud copy with a timestamp so we can resolve conflicts on next launch
    state[CLOUD_TIMESTAMP_KEY] = os.time()

    M.runtime.cloud_pending_push = true
    M.runtime.cloud_last_push_time = socket.gettime()
    M.runtime.cloud_last_pushed_json = encoded
    yagames.player_set_data(state, flush == true, function(_, err)
        M.runtime.cloud_pending_push = false
        if err then
            logger:warn("player_set_data failed", { err = err })
            -- Force the next attempt even if the state stays the same
            M.runtime.cloud_last_pushed_json = nil
            M.runtime.cloud_dirty = true
        else
            logger:trace("player_set_data ok", { flush = flush })
        end
        if M.runtime.cloud_dirty then
            local dirty_flush = M.runtime.cloud_dirty_flush
            M.runtime.cloud_dirty = false
            M.runtime.cloud_dirty_flush = false
            schedule_push(dirty_flush)
        end
    end)
end

--- Apply cloud data to the locally bound saver state and persist it.
--- Cloud data wins unconditionally when it has a newer timestamp than local; if local has no
--- timestamp at all we also accept cloud data because it means the user already has progress
--- and the local save is brand new.
---@param cloud_data table|nil
local function apply_cloud_data(cloud_data)
    if type(cloud_data) ~= "table" or next(cloud_data) == nil then
        logger:debug("Cloud is empty, keeping local state")
        M.on_cloud_loaded:trigger(true, false)
        return
    end

    local local_state = saver.get_state() or {}
    local local_ts = tonumber(local_state[CLOUD_TIMESTAMP_KEY]) or 0
    local cloud_ts = tonumber(cloud_data[CLOUD_TIMESTAMP_KEY]) or 0

    if cloud_ts > 0 and local_ts > cloud_ts then
        logger:info("Local save is newer than cloud, keeping local", { local_ts = local_ts, cloud_ts = cloud_ts })
        M.on_cloud_loaded:trigger(true, false)
        -- Push our newer state up so the cloud catches up
        push_state_to_cloud(false)
        return
    end

    logger:info("Applying cloud save", { local_ts = local_ts, cloud_ts = cloud_ts })
    -- The state about to be applied is already in the cloud, don't push it back on the following save
    M.runtime.cloud_last_pushed_json = serialize_state(cloud_data)
    saver.override_state(cloud_data, true)
    M.on_cloud_loaded:trigger(true, true)
end

------------------------------------------------
--- Public API
------------------------------------------------

--- Returns true if the Yandex.Games SDK extension is present in this build.
---@return boolean
function M.is_available()
    return M.runtime.is_available
end

--- Returns true once yagames.init() has succeeded and SDK methods may be called.
---@return boolean
function M.is_sdk_ready()
    return M.runtime.is_sdk_ready
end

--- Calls `callback` once yagames.init() has succeeded (immediately if it already has).
--- The callback is never called if SDK initialisation fails.
---@param callback fun()
function M.on_sdk_ready(callback)
    if M.runtime.is_sdk_ready then
        callback()
        return
    end
    table.insert(M.runtime.sdk_ready_callbacks, callback)
end

--- Returns true if the Yandex.Games SDK + player subsystem are both fully initialised.
---@return boolean
function M.is_ready()
    return M.runtime.is_sdk_ready and M.runtime.is_player_ready
end

--- Returns the Yandex unique player id, or nil if the SDK is unavailable / player not ready.
---@return string|nil
function M.get_unique_id()
    if not M.runtime.is_available or not M.runtime.is_player_ready then
        return nil
    end
    return yagames.player_get_unique_id()
end

--- Returns true if the current player is authorised on Yandex.
---@return boolean
function M.is_player_authorized()
    if not M.runtime.is_available or not M.runtime.is_player_ready then
        return false
    end
    return yagames.player_is_authorized()
end

--- Force-flushes the local save to Yandex cloud (sets flush=true on player_set_data).
--- Returns true if progress can be stored in the Yandex cloud (player subsystem is ready).
---@return boolean
function M.is_cloud_available()
    return M.runtime.is_available and M.runtime.is_player_ready
end

--- Pushes the local save to Yandex cloud immediately (flush=true), bypassing the throttle.
--- `callback(success)` is called once the SDK confirms the write; `success` is false when
--- the cloud is not available or the write failed.
---@param callback fun(success: boolean)|nil
function M.flush(callback)
    if not M.is_cloud_available() then
        if callback then
            callback(false)
        end
        return
    end

    local state = saver.get_state()
    state[CLOUD_TIMESTAMP_KEY] = os.time()
    M.runtime.cloud_last_push_time = socket.gettime()
    M.runtime.cloud_last_pushed_json = serialize_state(state)
    yagames.player_set_data(state, true, function(_, err)
        if err then
            logger:warn("player_set_data (flush) failed", { err = err })
            M.runtime.cloud_last_pushed_json = nil
        else
            logger:debug("player_set_data (flush) ok")
        end
        if callback then
            callback(err == nil)
        end
    end)
end

--- Signal Yandex Games that the loading screen can be hidden.
--- Safe to call multiple times - subsequent calls are no-ops.
--- Send the GameplayAPI marker matching the requested gameplay state.
local function sync_gameplay_marker()
    if not M.runtime.is_sdk_ready or M.runtime.is_gameplay_active == M.runtime.is_gameplay_started then
        return
    end

    M.runtime.is_gameplay_started = M.runtime.is_gameplay_active
    if M.runtime.is_gameplay_active then
        yagames.features_gameplayapi_start()
    else
        yagames.features_gameplayapi_stop()
    end
    logger:debug("GameplayAPI marker", { started = M.runtime.is_gameplay_started })
end

--- Tell the platform whether the player is actively playing (GameplayAPI.start/stop).
--- Call with true when a level starts / gameplay screen gets focus, false on level end,
--- menus and popups. Safe to call before the SDK is ready and repeatedly with the same value.
---@param active boolean
function M.set_gameplay_active(active)
    M.runtime.is_gameplay_active = active
    sync_gameplay_marker()
end

--- Returns true while the platform has paused the game (ad, purchase dialog, hidden tab).
---@return boolean
function M.is_paused()
    return M.runtime.is_paused
end

--- game_api_pause: ad shown, purchase dialog opened, tab switched or window minimised.
--- Yandex requires muting the sound and pausing gameplay. The platform itself sends
--- GameplayAPI.stop/start around pause/resume.
local function on_game_api_pause()
    logger:debug("game_api_pause")
    M.runtime.is_paused = true
    fun_sound.set_muted("platform_pause", true)
    M.on_pause:trigger()
end

local function on_game_api_resume()
    logger:debug("game_api_resume")
    M.runtime.is_paused = false
    fun_sound.set_muted("platform_pause", false)
    M.on_resume:trigger()
end

function M.signal_loading_ready()
    if not M.runtime.is_available or M.runtime.is_loading_api_ready then
        return
    end

    M.runtime.is_loading_api_ready = true
    -- The game may be ready before yagames.init() has finished; signal once the SDK is up.
    M.on_sdk_ready(function()
        yagames.features_loadingapi_ready()
        logger:debug("features_loadingapi_ready signalled")
    end)
end

------------------------------------------------
--- FUN lifecycle
------------------------------------------------

function M.fun_pre_init()
    if not yagames then
        logger:info("yagames extension is not available on this platform, integration disabled")
        return
    end

    M.runtime.is_available = true
    logger:info("yagames extension detected, starting initialisation")

    yagames.init(function(_, err)
        if err then
            logger:warn("yagames.init failed", { err = err })
            M.on_initialized:trigger()
            return
        end

        M.runtime.is_sdk_ready = true
        logger:info("yagames.init done")

        -- Yandex requires automatic language detection via the SDK (2.14)
        lang.set_platform_lang(yagames.environment().i18n.lang)

        yagames.event_on("game_api_pause", on_game_api_pause)
        yagames.event_on("game_api_resume", on_game_api_resume)
        sync_gameplay_marker()

        local sdk_ready_callbacks = M.runtime.sdk_ready_callbacks
        M.runtime.sdk_ready_callbacks = {}
        for _, callback in ipairs(sdk_ready_callbacks) do
            callback()
        end

        yagames.player_init({}, function(_, player_err)
            if player_err then
                logger:warn("yagames.player_init failed", { err = player_err })
                M.on_initialized:trigger()
                return
            end

            M.runtime.is_player_ready = true
            logger:info("yagames.player_init done", { unique_id = yagames.player_get_unique_id() })
            M.on_initialized:trigger()

            yagames.player_get_data(nil, function(_, data_err, cloud_data)
                if data_err then
                    logger:warn("yagames.player_get_data failed", { err = data_err })
                    M.on_cloud_loaded:trigger(false, false)
                    return
                end
                apply_cloud_data(cloud_data)
            end)
        end)
    end)
end

function M.fun_init()
    if not M.runtime.is_available then
        return
    end
    saver.on_before_save:subscribe(function()
        push_state_to_cloud(false)
    end)
end

function M.fun_post_init()
    
end

function M.fun_final()
    -- Best-effort final flush so we don't lose progress when the game closes.
    M.flush()
end

return M
