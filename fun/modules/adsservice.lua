--- FUN Module: Ads Service
--- Module for working with ads on top of ads.lua module
--- 
--- Can:
--- - Show ads with consideration: cooldown, limits
--- - Track ad usage
--- 
--- Ad settings are segmented by cohorts through modules/segmentation.lua

local log = require("fun.libs.log")
local events = require("event.events")
local stately = require("stately.stately")

local const = require("fun.const")
local timex = require("fun.libs.timex")
local tablex = require("fun.libs.tablex")
local event = require("event.event")

local target = require("fun.modules.target")
local segmentation = require("fun.modules.segmentation")
local ads = require("fun.modules.ads.ads")
local saver = require("fun.modules.saver")
local game = require("fun.modules.game")

local logger = log.get_logger("fun.adsservice")

local MODULE_NAME = "adsservice"

local STATE_INIT = hash("init")
local STATE_BANNER_DISABLED = hash("banner_disabled")
local STATE_BANNER_LOADING = hash("banner_loading")
local STATE_BANNER_READY = hash("banner_ready")
local STATE_BANNER_SHOWING = hash("banner_showing")

local ACTION_BANNER_LOAD = hash("banner_load")
local ACTION_BANNER_DISABLE = hash("banner_disable")
local ACTION_BANNER_SHOW = hash("banner_show")
local ACTION_BANNER_LOADED = hash("banner_loaded")
local ACTION_BANNER_HIDE = hash("banner_hide")
local ACTION_BANNER_DESTROY = hash("banner_destroy")

local ADS_RETRY_DELAY = 10 -- секунды
local DAYS_TO_KEEP_SHOW_RECORDS = 30

--- @class fun.adsservice.events.on_interstitial_start: event
--- @field trigger fun(_, placement_id: string)
--- @field subscribe fun(_, callback: fun(placement_id: string), _)

--- @class fun.adsservice.events.on_interstitial_close: event
--- @field trigger fun(_, placement_id: string)
--- @field subscribe fun(_, callback: fun(placement_id: string), _)

--- @class fun.adsservice.events.on_interstitial_paid: event
--- @field trigger fun(_, placement_id: string, currency_code: string, value_micros: number, precision: number)
--- @field subscribe fun(_, callback: fun(placement_id: string, currency_code: string, value_micros: number, precision: number), _)

--- @class fun.adsservice.events.on_rewarded_start: event
--- @field trigger fun(_, placement_id: string)
--- @field subscribe fun(_, callback: fun(placement_id: string), _)

--- @class fun.adsservice.events.on_rewarded_close: event
--- @field trigger fun(_, placement_id: string)
--- @field subscribe fun(_, callback: fun(placement_id: string), _)

--- @class fun.adsservice.events.on_rewarded_reward: event
--- @field trigger fun(_, placement_id: string)
--- @field subscribe fun(_, callback: fun(placement_id: string), _)

--- @class fun.adsservice.events.on_rewarded_paid: event
--- @field trigger fun(_, placement_id: string, currency_code: string, value_micros: number, precision: number)
--- @field subscribe fun(_, callback: fun(placement_id: string, currency_code: string, value_micros: number, precision: number), _)

--- @class fun.adsservice.events.on_banner_refresh: event
--- @field trigger fun(_, width: number, height: number, position: fun.const.ADS_BANNER_POSITION)
--- @field subscribe fun(_, callback: fun(width: number, height: number, position: fun.const.ADS_BANNER_POSITION), _)

--- @class fun.adsservice.events.on_banner_start: event
--- @field trigger fun(_, width: number, height: number, position: fun.const.ADS_BANNER_POSITION)
--- @field subscribe fun(_, callback: fun(width: number, height: number, position: fun.const.ADS_BANNER_POSITION), _)

--- @class fun.adsservice.events.on_banner_close: event
--- @field trigger fun(_)
--- @field subscribe fun(_, callback: fun(_), _)

--- @class fun.adsservice.events.on_banner_paid: event
--- @field trigger fun(_, currency_code: string, value_micros: number, precision: number)
--- @field subscribe fun(_, callback: fun(currency_code: string, value_micros: number, precision: number), _)

--- @class fun.adsservice
local M = {
    ---@type table|nil
    target_config = {},

    config = {
        interstitial = {
            is_enabled = true,
            cooldown_after_inter = 10,
            cooldown_after_rewarded = 10,
            limit_per_day = 3,
            unlock_after_level = 10,
            placements = {
                inter_after_level = {
                    unlock_after_level = 10
                },
                inter_before_level = {
                    unlock_after_level = 10
                }
            }
        },
        rewarded = {
            is_enabled = true,
            limit_per_day = 3,
            unlock_after_level = 10
        },
        banner = {
            is_enabled = true,
        },
    },

    runtime = {
        interstitial = {
            current_placement_id = nil,  -- текущий placement_id, для которого показывается реклама
            is_ready = false,            -- флаг, что реклама загружена и готова к показу
        },
        rewarded = {
            current_placement_id = nil,  -- текущий placement_id, для которого показывается реклама
            is_ready = false,            -- флаг, что реклама загружена и готова к показу
        },
        banner = {
            width = 0,                   -- ширина рекламы
            height = 0,                  -- высота рекламы
            position = nil,              -- позиция рекламы
        },
        is_enabled = true,               -- флаг, что реклама включена (используется для дебага)
        is_noads_active = false,         -- флаг, что куплен noads (отключает banner и interstitial)

        get_current_level = function() return 0 end
    },

    state = {
        interstitial = {
            lifetime_shows = 0,             -- общее количество показов межстраничной рекламы за всю жизнь
            lifetime_revenue = 0,           -- общее количество дохода от показов межстраничной рекламы за всю жизнь
            show_records = {}
        },
        rewarded = {
            lifetime_shows = 0,             -- общее количество показов rewarded рекламы за всю жизнь
            lifetime_revenue = 0,           -- общее количество дохода от показов rewarded рекламы за всю жизнь
            show_records = {}
        }
    }
}

M.on_interstitial_start = event.create()     --[[@as fun.adsservice.events.on_interstitial_start]]
M.on_interstitial_close = event.create()     --[[@as fun.adsservice.events.on_interstitial_close]]
M.on_interstitial_paid = event.create()      --[[@as fun.adsservice.events.on_interstitial_paid]]
M.on_rewarded_start = event.create()         --[[@as fun.adsservice.events.on_rewarded_start]]
M.on_rewarded_close = event.create()         --[[@as fun.adsservice.events.on_rewarded_close]]
M.on_rewarded_reward = event.create()        --[[@as fun.adsservice.events.on_rewarded_reward]]
M.on_rewarded_paid = event.create()          --[[@as fun.adsservice.events.on_rewarded_paid]]
M.on_banner_refresh = event.create()         --[[@as fun.adsservice.events.on_banner_refresh]]
M.on_banner_start = event.create()           --[[@as fun.adsservice.events.on_banner_start]]
M.on_banner_close = event.create()           --[[@as fun.adsservice.events.on_banner_close]]
M.on_banner_paid = event.create()            --[[@as fun.adsservice.events.on_banner_paid]]

local function try_to_load_ads()
    if M.config.interstitial.is_enabled then
        ads.load_interstitial(M.target_config.interstitial.unit_id)
    end
    
    if M.config.rewarded.is_enabled then
        ads.load_rewarded(M.target_config.rewarded.unit_id)
    end

    if M.config.banner.is_enabled then
        M.banner_stately.handle_event(ACTION_BANNER_LOAD)
    end
end


local function init_config()
    --- Получаем конфигурацию из gamedata
    M.config.interstitial = segmentation.get_module_config(MODULE_NAME, "interstitial", M.config.interstitial)
    if not M.config.interstitial then
        logger:error('No gamedata configuration found for "adsservice" module "interstitial"')
    end

    M.config.rewarded = segmentation.get_module_config(MODULE_NAME, "rewarded", M.config.rewarded)
    if not M.config.rewarded then
        logger:error('No gamedata configuration found for "adsservice" module "rewarded"')
    end

    M.config.banner = segmentation.get_module_config(MODULE_NAME, "banner", M.config.banner)
    if not M.config.banner then
        logger:error('No gamedata configuration found for "adsservice" module "banner"')
    end
end

local function init_banner_statemachine()
    --- Инициализируем стейт машину для баннера
    M.banner_stately = stately.create()
    M.banner_states = {
        init = M.banner_stately.state(STATE_INIT),
        disabled = M.banner_stately.state(STATE_BANNER_DISABLED),
        loading = M.banner_stately.state(STATE_BANNER_LOADING),
        ready = M.banner_stately.state(STATE_BANNER_READY),
        showing = M.banner_stately.state(STATE_BANNER_SHOWING),
    }

    M.banner_stately.transition(M.banner_states.init, M.banner_states.disabled, ACTION_BANNER_DISABLE)
    M.banner_stately.transition(M.banner_states.init, M.banner_states.loading, ACTION_BANNER_LOAD)
    M.banner_stately.transition(M.banner_states.disabled, M.banner_states.loading, ACTION_BANNER_LOAD)
    M.banner_stately.transition(M.banner_states.loading, M.banner_states.ready, ACTION_BANNER_LOADED)
    M.banner_stately.transition(M.banner_states.loading, M.banner_states.disabled, ACTION_BANNER_DISABLE)
    M.banner_stately.transition(M.banner_states.ready, M.banner_states.showing, ACTION_BANNER_SHOW)
    M.banner_stately.transition(M.banner_states.showing, M.banner_states.disabled, ACTION_BANNER_DESTROY)
    M.banner_stately.transition(M.banner_states.showing, M.banner_states.ready, ACTION_BANNER_HIDE)

    M.banner_stately.on_enter(M.banner_states.disabled, function(from_state, message)
        logger:debug("Banner state: on_enter disabled")

        -- Если пришли из состояния showing, то запускаем уничтожение баннера
        if from_state == STATE_BANNER_SHOWING then
            ads.destroy_banner()
            M.runtime.banner.position = nil
            return
        end
    end)
    
    M.banner_stately.on_enter(M.banner_states.loading, function(from_state, message)
        if not M.can_show_banner() then
            msg.post('.', ACTION_BANNER_DISABLE)
            return
        end
        logger:debug("Banner state: on_enter loading")
        ads.load_banner(M.target_config.banner.unit_id)
    end)

    M.banner_stately.on_enter(M.banner_states.ready, function(from_state, message)
        logger:debug("Banner state: on_enter ready from state: " .. from_state)
        if from_state == STATE_BANNER_LOADING then
            M.runtime.banner.width = message.width
            M.runtime.banner.height = message.height
        end

        if from_state == STATE_BANNER_SHOWING then
            ads.hide_banner()
        end
    end)

    M.banner_stately.on_enter(M.banner_states.showing, function(from_state, message)
        logger:debug("Banner state: on_enter showing", { position = message.position })
        M.runtime.banner.position = message.position
        if not ads.show_banner(message.position) then
            logger:error("Failed to show banner", { position = message.position })
            msg.post('.', ACTION_BANNER_DESTROY)
        end
    end)
end


local function on_segmentation_cohort_changed(cohort)
    init_config()
    try_to_load_ads()
end


local function on_new_day()
    try_to_load_ads()
end


local function on_ads_initialized()
    try_to_load_ads()
end


------------------------------------------------
--- Interstitial events
------------------------------------------------

local function on_ads_interstitial_loaded()
    M.runtime.interstitial.is_ready = true
end

local function on_ads_interstitial_failed_to_load()
    --- Если не удалось загрузить рекламу, пробуем еще раз через 2 секунды
    M.runtime.interstitial.is_ready = false
    timer.delay(ADS_RETRY_DELAY, false, function()
        ads.load_interstitial(M.target_config.interstitial.unit_id)
    end)
end

local function on_ads_interstitial_start()
    M.on_interstitial_start:trigger(M.runtime.interstitial.current_placement_id)
end

local function on_ads_interstitial_close()
    -- Логируем статистику
    M.state.interstitial.lifetime_shows = M.state.interstitial.lifetime_shows + 1
    table.insert(M.state.interstitial.show_records, timex.get_time())
    tablex.remove_if(M.state.interstitial.show_records, function(time_in_seconds)
        local diff = timex.get_time() - time_in_seconds
        return timex.convert_to_days(diff) > DAYS_TO_KEEP_SHOW_RECORDS
    end)
   
    local placement_id = M.runtime.interstitial.current_placement_id
    -- Сбрасываем placement_id и флаг готовности рекламы
    M.runtime.interstitial.current_placement_id = nil
    M.runtime.interstitial.is_ready = false
    
    -- Триггерим событие закрытия рекламы
    M.on_interstitial_close:trigger(tostring(placement_id))

    -- Пытаемся загрузить новую рекламу, чтобы не было задержки при следующем показе
    ads.load_interstitial(M.target_config.interstitial.unit_id)
end


local function on_ads_interstitial_paid(currency_code, value_micros, precision)
    M.on_interstitial_paid:trigger(tostring(M.runtime.interstitial.current_placement_id), currency_code, value_micros, precision)
end

------------------------------------------------
--- Rewarded events
------------------------------------------------

local function on_ads_rewarded_loaded()
    M.runtime.rewarded.is_ready = true
end

local function on_ads_rewarded_failed_to_load()
    --- Если не удалось загрузить рекламу, пробуем еще раз через 2 секунды
    M.runtime.rewarded.is_ready = false
    timer.delay(ADS_RETRY_DELAY, false, function()
        ads.load_rewarded(M.target_config.rewarded.unit_id)
    end)
end


local function on_ads_rewarded_start()
    logger:debug("On rewarded start callback")
    M.on_rewarded_start:trigger(M.runtime.rewarded.current_placement_id)
end


local function on_ads_rewarded_close()
    -- Логируем статистику
    M.state.rewarded.lifetime_shows = M.state.rewarded.lifetime_shows + 1
    table.insert(M.state.rewarded.show_records, timex.get_time())
    tablex.remove_if(M.state.rewarded.show_records, function(time_in_seconds)
        local diff = timex.get_time() - time_in_seconds
        return timex.convert_to_days(diff) > DAYS_TO_KEEP_SHOW_RECORDS
    end)

    if M.runtime.rewarded.current_placement_id == nil then
        logger:error("Rewarded ad rewarded, but current_placement_id is nil")
    end

    local placement_id = M.runtime.rewarded.current_placement_id
    
    -- Сбрасываем флаги готовности и placement_id
    M.runtime.rewarded.is_ready = false
    M.runtime.rewarded.current_placement_closed = true
    --- Если реклама была награждена, то сбрасываем placement_id
    if M.runtime.rewarded.current_placement_rewarded then
        M.runtime.rewarded.current_placement_id = nil
    end

    -- Триггерим событие закрытия рекламы
    M.on_rewarded_close:trigger(tostring(placement_id))

    -- Сразу пытаемся загрузить новую рекламу, чтобы не было задержки при следующем показе
    ads.load_rewarded(M.target_config.rewarded.unit_id)
end


local function on_ads_rewarded_reward()
    logger:debug("On rewarded reward callback")
    if M.runtime.rewarded.current_placement_id == nil then
        logger:error("Rewarded ad rewarded, but current_placement_id is nil")
    end
    M.runtime.rewarded.current_placement_rewarded = true
    local placement_id = M.runtime.rewarded.current_placement_id

    --- Если реклама была закрыта, то сбрасываем placement_id
    if M.runtime.rewarded.current_placement_closed then
        M.runtime.rewarded.current_placement_id = nil
    end

    M.on_rewarded_reward:trigger(tostring(placement_id))
end

local function on_ads_rewarded_paid(currency_code, value_micros, precision)
    M.on_rewarded_paid:trigger(tostring(M.runtime.rewarded.current_placement_id), currency_code, value_micros, precision)
end

------------------------------------------------
--- Banner events
------------------------------------------------

local function on_ads_banner_loaded(width, height)
    logger:debug("on_ads_banner_loaded", {width = width, height = height})
    msg.post('.', ACTION_BANNER_LOADED, {width = width, height = height})

    if M.is_banner_showing() then
        logger:debug("on_ads_banner_loaded - trigger refresh", {width = width, height = height})
        M.on_banner_refresh:trigger(M.runtime.banner.width, M.runtime.banner.height, M.runtime.banner.position)
    end
end

local function on_ads_banner_failed_to_load()
    --- Если баннер загружается, то пытаемся еще раз загрузить его
    if M.banner_stately.current_state() == STATE_BANNER_LOADING then
        timer.delay(ADS_RETRY_DELAY, false, function()
            ads.load_banner(M.target_config.banner.unit_id)
        end)
    end
end

local function on_ads_banner_start()
    M.on_banner_start:trigger(M.runtime.banner.width, M.runtime.banner.height, M.runtime.banner.position)
end

local function on_ads_banner_close()
    M.on_banner_close:trigger()
end

local function on_ads_banner_destroyed()
    msg.post('.', ACTION_BANNER_LOAD)
end

local function on_ads_banner_paid(currency_code, value_micros, precision)
    M.on_banner_paid:trigger(currency_code, value_micros, precision)
end


------------------------------------------------
--- Public functions
------------------------------------------------

--- Проверяет, можно ли показать межстраничную рекламу на основе placement_id. !Не проверяет готовность рекламы!
---@param placement_id string
---@return boolean
function M.can_show_interstitial(placement_id)
    --- Сначала проверяем глобальные ограничения
    --- Затем проверяем ограничения для placement_id
    --- Возвращаем true, если можно показать рекламу

    if not M.runtime.is_enabled then
        logger:debug("Ads are disabled")
        return false
    end

    if M.runtime.is_noads_active then
        logger:debug("No Ads is active, interstitial disabled")
        return false
    end

    if not M.config.interstitial.is_enabled then
        logger:debug("Interstitial is disabled")
        return false
    end

    if M.runtime.get_current_level() <= M.config.interstitial.unlock_after_level then
        logger:debug("Interstitial is not unlocked yet", { unlock_after_level = M.config.interstitial.unlock_after_level })
        return false
    end

    --- Если текущий placement_id не nil, значит реклама уже показывается, и мы не можем показать её ещё раз
    if M.runtime.interstitial.current_placement_id ~= nil then
        logger:debug("Interstitial already showing for placement_id", { placement_id = M.runtime.interstitial.current_placement_id })
        return false
    end

    --- Если сегодня уже достигли лимита показов в день, то не показываем рекламу
    local today_shows = tablex.count_if(M.state.interstitial.show_records, function(timestamp)
        return timex.is_same_day(timestamp, timex.get_time())
    end)
    if today_shows >= M.config.interstitial.limit_per_day then
        logger:debug("Interstitial limit reached", { limit_per_day = M.config.interstitial.limit_per_day })
        return false
    end

    --- Если время с последнего показа рекламы меньше cooldown_after_inter, то не показываем рекламу
    local last_timestamp = M.state.interstitial.show_records[#M.state.interstitial.show_records]
    if last_timestamp ~= nil and not timex.is_cooldown_reached(last_timestamp, M.config.interstitial.cooldown_after_inter) then
        logger:debug("Interstitial cooldown not reached", { cooldown_after_inter = M.config.interstitial.cooldown_after_inter })
        return false
    end

    --- Если время с последнего показа RW рекламы меньше cooldown_after_rewarded, то не показываем рекламу
    local last_rw_timestamp = M.state.rewarded.show_records[#M.state.rewarded.show_records]
    if last_rw_timestamp ~= nil and not timex.is_cooldown_reached(last_rw_timestamp, M.config.interstitial.cooldown_after_rewarded) then
        logger:debug("Rewarded cooldown not reached", { cooldown_after_rewarded = M.config.interstitial.cooldown_after_rewarded })
        return false
    end
    
    local placement_config = M.config.interstitial.placements[placement_id]
    if placement_config then
        if not placement_config.is_enabled then
            logger:debug("Interstitial placement is disabled", { placement_id = placement_id })
            return false
        end

        if placement_config.unlock_after_level then
            if M.runtime.get_current_level() <= placement_config.unlock_after_level then
                logger:debug("Interstitial placement " .. placement_id .. " is not unlocked yet", { unlock_after_level = placement_config.unlock_after_level })
                return false
            end
        end
    else
        logger:warn("Interstitial placement config not found", { placement_id = placement_id })
    end

    

    return true
end

--- Проверяет, можно ли показать rewarded рекламу на основе placement_id. !Не проверяет готовность рекламы!
---@param placement_id string
---@return boolean
function M.can_show_rewarded(placement_id)
    --- Сначала проверяем клобальные ограничения
    --- Затем проверяем ограничения для placement_id
    --- Возвращаем true, если можно показать рекламу
    
    if not M.runtime.is_enabled then
        logger:debug("Ads are disabled")
        return false
    end

    if not M.config.rewarded.is_enabled then
        logger:debug("Rewarded is disabled")
        return false
    end

    if M.runtime.get_current_level() <= M.config.rewarded.unlock_after_level then
        logger:debug("Rewarded is not unlocked yet", { unlock_after_level = M.config.rewarded.unlock_after_level })
        return false
    end

    --- Если текущий placement_id не nil, значит реклама уже показывается, и мы не можем показать её ещё раз
    if M.runtime.rewarded.current_placement_id ~= nil then
        logger:debug("Rewarded already showing for placement_id", { placement_id = M.runtime.rewarded.current_placement_id })
        return false
    end
    
    --- Если сегодня уже достигли лимита показов в день, то не показываем рекламу
    local today_shows = tablex.count_if(M.state.rewarded.show_records, function(timestamp)
        return timex.is_same_day(timestamp, timex.get_time())
    end)
    if today_shows >= M.config.rewarded.limit_per_day then
        logger:debug("Rewarded limit reached", { limit_per_day = M.config.rewarded.limit_per_day })
        return false
    end

    --- Если есть конфигурация для placement_id, то проверяем ограничения
    local placement_config = M.config.rewarded.placements[placement_id]
    if placement_config then
        if not placement_config.is_enabled then
            logger:debug("RW placement is disabled", { placement_id = placement_id })
            return false
        end

        if placement_config.unlock_after_level then
            if M.runtime.get_current_level() <= placement_config.unlock_after_level then
                logger:debug("RW placement " .. placement_id .. " is not unlocked yet", { unlock_after_level = placement_config.unlock_after_level })
                return false
            end
        end
    else
        logger:warn("RW placement config not found", { placement_id = placement_id })
    end
    return true
end

--- Проверяет, можно ли показать banner рекламу
---@return boolean
function M.can_show_banner()
    --- Сначала проверяем глобальные ограничения
    --- Затем проверяем ограничения для placement_id
    --- Возвращаем true, если можно показать рекламу
    
    if M.runtime.is_noads_active then
        logger:debug("No Ads is active, banner disabled")
        return false
    end

    if not M.target_config.banner or not M.target_config.banner.unit_id then
        logger:debug("Banner unit_id not found in target configuration")
        return false
    end

    if not M.config.banner or not M.config.banner.is_enabled then
        logger:debug("Banner is disabled")
        return false
    end

    return true
end


--- Проверяет доступна ли реклама в принципе
---@return boolean @True если реклама доступна
function M.is_initialized()
    return ads.is_initialized()
end


--- Возвращает имя текущего провайдера рекламы
--- Возвращаемое значение соответствует перечислению `ads.PROVIDERS`
--- (`"dummy"`, `"admob"`, `"yandex_games"`)
---@return string|nil @Имя провайдера или nil, если провайдер не инициализирован
function M.get_current_provider()
    if not ads.is_initialized() then
        return nil
    end
    return target.get_module_parameter("ads", "provider")
end


--- Проверяет, готова ли межстраничная реклама к показа
---@return boolean @True если реклама готова к показу
function M.is_interstitial_ready()
    return M.runtime.interstitial.is_ready
end

--- Проверяет, готова ли rewarded реклама к показа
---@return boolean @True если реклама готова к показу
function M.is_rewarded_ready()
    return M.runtime.rewarded.is_ready
end

--- Показывает межстраничную рекламу на основе placement_id
---@param placement_id string
---@param force boolean|nil @Если true, игнорирует проверки конфига/сегментов/лимитов (для чит-панели). Готовность рекламы всё равно проверяется.
---@return boolean @True если запуск успешно начался
function M.show_interstitial(placement_id, force)
    if not M.is_interstitial_ready() then
        return false
    end

    if not force and not M.can_show_interstitial(placement_id) then
        return false
    end

    if force then
        logger:debug("Force show interstitial ad", { placement_id = placement_id })
    end

    if ads.show_interstitial() then
        M.runtime.interstitial.current_placement_id = placement_id
        return true
    end
    return false
end

--- Показывает rewarded рекламу на основе placement_id
---@param placement_id string
---@param force boolean|nil @Если true, игнорирует проверки конфига/сегментов/лимитов (для чит-панели). Готовность рекламы всё равно проверяется.
---@return boolean @True если запуск успешно начался
function M.show_rewarded(placement_id, force)
    if not M.is_rewarded_ready() then
        return false
    end

    if not force and not M.can_show_rewarded(placement_id) then
        return false
    end

    if force then
        logger:debug("Force show rewarded ad", { placement_id = placement_id })
    end

    if ads.show_rewarded() then
        M.runtime.rewarded.current_placement_id = placement_id
        M.runtime.rewarded.current_placement_closed = false
        M.runtime.rewarded.current_placement_rewarded = false
        logger:debug("show rewarded ad success", { placement_id = placement_id })
        return true
    end
    return false
end

--- Показывает banner рекламу
---@param position fun.const.ADS_BANNER_POSITION
---@param force boolean|nil @Если true, игнорирует проверку runtime.is_enabled (для чит-панели). Готовность баннера всё равно проверяется.
function M.show_banner(position, force)
    if not force and not M.runtime.is_enabled then
        logger:debug("Ads are disabled, skipping banner show")
        return false
    end

    if force then
        logger:debug("Force show banner ad", { position = position })
    end

    if M.is_banner_ready() then
        M.banner_stately.handle_event(ACTION_BANNER_SHOW, {position = position})
        return true
    end

    M.banner_stately.handle_event(ACTION_BANNER_LOAD)
    return false
end

--- Скрывает banner рекламу
function M.hide_banner()
    M.banner_stately.handle_event(ACTION_BANNER_HIDE)
end

--- Отключает рекламу
function M.disable_ads()
    M.runtime.is_enabled = false

    M.hide_banner()
end

--- Включает рекламу
function M.enable_ads()
    M.runtime.is_enabled = true
end

--- Устанавливает состояние noads (отключает banner и interstitial, но не rewarded)
---@param is_active boolean @True если noads активен
function M.set_noads_active(is_active)
    M.runtime.is_noads_active = is_active
    if is_active then
        logger:info("No Ads activated, hiding banner")
        M.hide_banner()
    else
        logger:info("No Ads deactivated, showing banner")
    end
end

--- Проверяет, активен ли noads
---@return boolean @True если noads активен
function M.is_noads_active()
    return M.runtime.is_noads_active
end

--- Проверяет, готова ли banner реклама к показу
---@return boolean @True если реклама готова к показу
function M.is_banner_ready()
    return M.banner_stately.current_state() == STATE_BANNER_READY
end

function M.is_banner_showing()
    return M.banner_stately.current_state() == STATE_BANNER_SHOWING
end

function M.get_banner_position()
    return M.runtime.banner.position
end

function M.get_banner_width()
    return M.runtime.banner.width
end

function M.get_banner_height()
    return M.runtime.banner.height
end

------------------------------------------------
--- Statistics functions
------------------------------------------------

--- Get average number of watched rewarded ads per day
---@param last_n_days integer Number of days to get average number of rewarded ads for, if 0 - get average number of rewarded ads for all time
---@return number|nil @Average number of rewarded ads per day
function M.get_avg_rw_per_day(last_n_days)
    last_n_days = last_n_days or 0
    if last_n_days == 0 then
        if game.get_days_played() == 0 then
            return M.state.rewarded.lifetime_shows
        end
        return M.state.rewarded.lifetime_shows / game.get_days_played()
    end
    local rw_shows = tablex.count_if(M.state.rewarded.show_records, function(timestamp)
        return timex.convert_to_days(timex.get_time() - timestamp) <= last_n_days
    end)
    return rw_shows / last_n_days
end


------------------------------------------------
--- FUN Callback functions
------------------------------------------------

function M.fun_init()

    --- Получаем конфигурацию для текущей платформы
    M.target_config = target.get_module_config(MODULE_NAME)
    if not M.target_config then
        logger:error("No target configuration found for \"adsservice\" module")
        return
    end

    init_config()
    init_banner_statemachine()

    saver.bind_save_state("fun.adsservice", M.state)

    --- Подписка на глобальные события (не связанные с ads)
    M.global_subscribed_events = {
        { event = const.EVENTS.NEW_DAY, callback = on_new_day },
        { event = const.EVENTS.SEGMENTATION_COHORT_CHANGED, callback = on_segmentation_cohort_changed },
    }

    logger:info("Ads Service initialized")
end

function M.fun_post_init()
    M.banner_stately.start(M.banner_states.init)
    
    --- Подписка на события ads модуля
    ads.on_initialized:subscribe(on_ads_initialized)
    ads.on_interstitial_loaded:subscribe(on_ads_interstitial_loaded)
    ads.on_interstitial_failed_to_load:subscribe(on_ads_interstitial_failed_to_load)
    ads.on_interstitial_start:subscribe(on_ads_interstitial_start)
    ads.on_interstitial_close:subscribe(on_ads_interstitial_close)
    ads.on_interstitial_paid:subscribe(on_ads_interstitial_paid)
    ads.on_rewarded_loaded:subscribe(on_ads_rewarded_loaded)
    ads.on_rewarded_failed_to_load:subscribe(on_ads_rewarded_failed_to_load)
    ads.on_rewarded_start:subscribe(on_ads_rewarded_start)
    ads.on_rewarded_close:subscribe(on_ads_rewarded_close)
    ads.on_rewarded_reward:subscribe(on_ads_rewarded_reward)
    ads.on_rewarded_paid:subscribe(on_ads_rewarded_paid)
    ads.on_banner_loaded:subscribe(on_ads_banner_loaded)
    ads.on_banner_failed_to_load:subscribe(on_ads_banner_failed_to_load)
    ads.on_banner_start:subscribe(on_ads_banner_start)
    ads.on_banner_close:subscribe(on_ads_banner_close)
    ads.on_banner_destroyed:subscribe(on_ads_banner_destroyed)
    ads.on_banner_paid:subscribe(on_ads_banner_paid)

    --- Подписка на глобальные события
    for _, event_data in ipairs(M.global_subscribed_events) do
        events.subscribe(event_data.event, event_data.callback)
    end
end

function M.fun_on_message(message_id, message, sender)
    --- Менять состояние баннера можно так же через сообщения
    if tablex.contains({ACTION_BANNER_DESTROY, ACTION_BANNER_SHOW, ACTION_BANNER_LOAD, ACTION_BANNER_LOADED, ACTION_BANNER_HIDE}, message_id) then
        M.banner_stately.handle_event(message_id, message)
    end
end

function M.fun_final()
    --- Отписка от событий ads модуля
    ads.on_initialized:unsubscribe(on_ads_initialized)
    ads.on_interstitial_loaded:unsubscribe(on_ads_interstitial_loaded)
    ads.on_interstitial_failed_to_load:unsubscribe(on_ads_interstitial_failed_to_load)
    ads.on_interstitial_start:unsubscribe(on_ads_interstitial_start)
    ads.on_interstitial_close:unsubscribe(on_ads_interstitial_close)
    ads.on_interstitial_paid:unsubscribe(on_ads_interstitial_paid)
    ads.on_rewarded_loaded:unsubscribe(on_ads_rewarded_loaded)
    ads.on_rewarded_failed_to_load:unsubscribe(on_ads_rewarded_failed_to_load)
    ads.on_rewarded_start:unsubscribe(on_ads_rewarded_start)
    ads.on_rewarded_close:unsubscribe(on_ads_rewarded_close)
    ads.on_rewarded_reward:unsubscribe(on_ads_rewarded_reward)
    ads.on_rewarded_paid:unsubscribe(on_ads_rewarded_paid)
    ads.on_banner_loaded:unsubscribe(on_ads_banner_loaded)
    ads.on_banner_failed_to_load:unsubscribe(on_ads_banner_failed_to_load)
    ads.on_banner_start:unsubscribe(on_ads_banner_start)
    ads.on_banner_close:unsubscribe(on_ads_banner_close)
    ads.on_banner_destroyed:unsubscribe(on_ads_banner_destroyed)
    ads.on_banner_paid:unsubscribe(on_ads_banner_paid)
    --- Отписка от глобальных событий
    for _, event_data in ipairs(M.global_subscribed_events) do
        events.unsubscribe(event_data.event, event_data.callback)
    end
    ads.destroy_banner()
end

return M