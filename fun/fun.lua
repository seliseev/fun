local event = require("event.event")

local log = require("fun.libs.log")
local luax = require("fun.luax")

local ALL_MODULES = {
    {name = "gamedata", module = require("fun.modules.gamedata")},
    {name = "target", module = require("fun.modules.target")},
    {name = "saver", module = require("fun.modules.saver")},
    {name = "yagames", module = require("fun.modules.yagames")},
    {name = "game", module = require("fun.modules.game")},
    {name = "segmentation", module = require("fun.modules.segmentation")},
    {name = "device", module = require("fun.modules.device")},
    {name = "lang", module = require("fun.modules.lang")},
    {name = "utils", module = require("fun.libs.utils")},
    {name = "druid", module = require("fun.modules.druid")},
    {name = "token", module = require("fun.modules.token")},
    {name = "wallet", module = require("fun.modules.wallet")},
    {name = "levelchest", module = require("fun.modules.levelchest")},
    {name = "iap", module = require("fun.modules.iap.iap")},
    {name = "iapservice", module = require("fun.modules.iapservice")},
    {name = "transitions", module = require("fun.modules.transitions")},
    {name = "ads", module = require("fun.modules.ads.ads")},
    {name = "adsservice", module = require("fun.modules.adsservice")},
    {name = "noads", module = require("fun.modules.noads")},
    {name = "vibrate", module = require("fun.modules.vibrate")},
    {name = "sound", module = require("fun.modules.sound")},
    {name = "analytics", module = require("fun.modules.analytics.analytics")},
    {name = "rateus", module = require("fun.modules.rateus")},
    {name = "firebase", module = require("fun.modules.firebase")},
    {name = "mmp", module = require("fun.modules.mmp")},
}

---@class fun
local FUN = {
    logger = log.get_logger("fun"),

    modules_callbacks = {
        fun_pre_init = {},
        fun_init = {},
        fun_post_init = {},
        fun_update = {},
        fun_final = {},
        fun_on_message = {},
    }
}

--- @class fun.events.on_module_init_status_changed: event - Triggered when a module is initialized
--- @field trigger fun(_, module_name: string)
--- @field subscribe fun(_, callback: fun(module_name: string), _)

--- @class fun.events.on_fun_inited: event - Triggered when all modules registered in FUN are initialized
--- @field trigger fun(_)
--- @field subscribe fun(_, callback: fun(), _)

FUN.on_module_pre_inited = event.create()   --[[@as fun.events.on_module_init_status_changed]]
FUN.on_module_inited = event.create()       --[[@as fun.events.on_module_init_status_changed]]
FUN.on_module_post_inited = event.create()  --[[@as fun.events.on_module_init_status_changed]]

FUN.on_fun_inited = event.create()          --[[@as fun.events.on_fun_inited]]


local function load_modules()
    for _, module_info in ipairs(ALL_MODULES) do
        local fun_module = module_info.module
        for func_name, callbacks in pairs(FUN.modules_callbacks) do
            if fun_module[func_name] then
                table.insert(callbacks, fun_module[func_name])
            end
        end
    end
end

local function call_each_module(func_name, ...)
	for i = 1, #FUN.modules_callbacks[func_name] do
		FUN.modules_callbacks[func_name][i](...)
	end
end

--- Call this to call initialization phase for each module
---@param phase_name string Name of the initialization phase
---@param event_trigger fun.events.on_module_init_status_changed Event to trigger after each module initialization
local function call_init_phase(phase_name, event_trigger)
    -- Вызываем функцию инициализации для каждого модуля последовательно
    for _, module_info in ipairs(ALL_MODULES) do
        local fun_module = module_info.module
        if fun_module[phase_name] then
            fun_module[phase_name]()

            -- Триггерим событие после вызова функции модуля
            event_trigger:trigger(module_info.name)
        end
    end
end


--- Call this to init Fun module
function FUN.init()
    load_modules()
    call_init_phase("fun_pre_init", FUN.on_module_pre_inited)
    call_init_phase("fun_init", FUN.on_module_inited)
    call_init_phase("fun_post_init", FUN.on_module_post_inited)

	FUN.logger:info("Fun init completed")

    timer.delay(0.01, false, function()
        FUN.on_fun_inited:trigger()
    end)
end

---Добавить модуль в систему, вызывать перед Fun.init()
---@param module_name any
---@param package any
function FUN.register_module(module_name, package)
    table.insert(ALL_MODULES, {name = module_name, module = package})
end

--- Call this on main update loop
---@param dt number delta time
function FUN.update(dt)
	call_each_module("fun_update", dt)
end

--- Call this on main message loop
---@param message_id hash
---@param message table
---@param sender url
function FUN.on_message(message_id, message, sender)
    call_each_module("fun_on_message", message_id, message, sender)
end

function FUN.final()
    FUN.logger:info("Fun final started")
    call_each_module("fun_final")
    FUN.logger:info("Fun final completed")
end


return FUN
