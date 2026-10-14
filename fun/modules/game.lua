--- FUN Module: game
--- Module for basic game functions
--- Like exit, reboot, open url etc

local log = require("fun.libs.log")
local events = require("event.events")

local const = require("fun.const")
local time_string = require("fun.libs.time_string")
local timex = require("fun.libs.timex")
local tablex = require("fun.libs.tablex")

local saver = require("fun.modules.saver")
local device = require("fun.modules.device")

local logger = log.get_logger("fun.game")

---@class fun.game
local M = {
	state = {
		game_start_count = 0,
		game_start_dates = {},
		first_start_time = 0,
		last_play_date = 0,
		last_play_timepoint = 0,
		played_time = 0
	},

	runtime = {
		window_original_width = 640,
		window_original_height = 960,
		window_stretch_x = 0,
		window_stretch_y = 0,
	}
}


local function check_session()
	local current_date = timex.get_date_code()
	if M.state.last_play_date ~= current_date then
		M.state.last_play_date = current_date
		events.trigger(const.EVENTS.NEW_DAY)
	end
end


local function on_window_event(self, event, data)
	if event == window.WINDOW_EVENT_RESIZED then
		local window_width, window_height = window.get_size()
		M.runtime.window_stretch_x = window_width / M.runtime.window_original_width
		M.runtime.window_stretch_y = window_height / M.runtime.window_original_height
	end

	events.trigger(const.EVENTS.WINDOW_EVENT, event, data)

	if event == window.WINDOW_EVENT_FOCUS_GAINED then
		check_session()
		events.trigger(const.EVENTS.GAME_FOCUS)
	end
end

----------------------------------------
--- Public functions
----------------------------------------

--- Reboot the game
--- @param delay number|nil Delay before reboot, in seconds
function M.reboot(delay, arg1, arg2)
	delay = delay or 0

	timer.delay(delay, false, function()
		if html5 then
			html5.run('document.location.reload();')
		else
			msg.post("@system:", "reboot", { arg1 = arg1, arg2 = arg2 })
		end
	end)
end


--- Exit from the game
--- @param code number|nil The exit code
function M.exit(code)
	code = code or 0
	msg.post("@system:", "exit", { code = code })
end


--- Check game on debug mode
function M.is_debug()
	return sys.get_engine_info().is_debug
end


--- Get window stretch
--- @return number window_stretch_x
--- @return number window_stretch_y
function M.get_window_stretch()
	return M.runtime.window_stretch_x, M.runtime.window_stretch_y
end


--- Get current time in string format
--- @return string|nil @Time format in iso e.g. "2019-09-25T01:48:19Z"
function M.get_current_time_string(time)
	return time_string.get_ISO(time or timex.get_time())
end


--- Get days since first game launch
---@return number @Days since first game launch
function M.get_days_played()
	local play_time = timex.get_time() - M.state.first_start_time
	return timex.convert_to_days(play_time)
end

function M.get_last_play_time()
	return M.state.last_play_timepoint
end

--- Check if game is first launch
---@return boolean @True, если игра запускается в первый раз
function M.is_first_launch()
	return M.state.game_start_count == 1
end

function M.is_played_between(timestamp_start, timestamp_end)
	local records = tablex.count_if(M.state.game_start_dates, function(timestamp)
		return timestamp >= timestamp_start and timestamp <= timestamp_end
	end)
	return records > 0
end


function M.fun_init()
	math.randomseed(os.time())
	math.random()

	local tmp_width, tmp_height = window.get_size()
	M.runtime.window_original_width = tmp_width
	M.runtime.window_original_height = tmp_height

	saver.bind_save_state("fun.game", M.state)

	if device.is_mobile() then
		window.set_dim_mode(window.DIMMING_OFF)
	end
end


function M.fun_post_init()
    local SAVE_DAYS_COUNT = 30

	M.state.game_start_count = M.state.game_start_count + 1
	table.insert(M.state.game_start_dates, timex.get_time())
	tablex.remove_if(M.state.game_start_dates, function(time_in_seconds)
		local diff = timex.get_time() - time_in_seconds
		return timex.convert_to_days(diff) > SAVE_DAYS_COUNT
	end)
    
	if M.state.first_start_time == 0 then
		M.state.first_start_time = timex.get_time()
	end
    
	if M.state.last_play_date == 0 then
		M.state.last_play_date = timex.get_date_code()
	end

	check_session()
	window.set_listener(on_window_event)
end


function M.fun_update(dt)
    
	M.state.played_time = M.state.played_time + dt
	M.state.last_play_timepoint = timex.get_time()
	check_session()
end


return M
