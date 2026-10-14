local events = require("event.events")
local druid = require("druid.druid")

local const = require("fun.const")
local fun_druid_style = require("fun.druid.style")

local lang = require("fun.modules.lang")
local fun_sound = require("fun.modules.sound")

--- @class fun.druid
local M = {}

local function on_language_change()
    druid.on_language_change()
end

local function on_window_event_for_druid(event, data)
	druid.on_window_callback(event)
end

function M.fun_init()
	druid.set_text_function(function (text_id, ...)
        return lang.txt(text_id, ...)
    end)

    druid.set_sound_function(function (sound_id)
        fun_sound.play(sound_id)
    end)

    druid.set_default_style(fun_druid_style)

    events.subscribe(const.EVENTS.LANG_UPDATE, on_language_change)
    events.subscribe(const.EVENTS.WINDOW_EVENT, on_window_event_for_druid)
end


return M