--- Fun sound module
local event = require("event.event")
local events = require("event.events")
local log = require("fun.libs.log")


local const = require("fun.const")
local luax = require("fun.luax")
local tablex = require("fun.libs.tablex")
local mathx = require("fun.libs.mathx")

local saver = require("fun.modules.saver")

local logger = log.get_logger("fun.sound")

---@class fun.sound
local M = {
    runtime = {
		props = { gain = 1, speed = 1},
		times = {},
		last_gains = {},
		fades = {},
		---@type table<string, boolean> причины, по которым весь звук игры выключен (реклама, пауза платформы, потеря фокуса)
		mute_reasons = {},
	},
    state = {
        sound_gain = 1,
        music_gain = 1,
    },
	config = {
		repeat_threshold = 0.01,
		sound_go = "main:/sfx#",
		music_go = "main:/sfx#",
	}
}

--- @class fun.sound.events.on_sound_gain_changed: event
--- @field trigger fun(_, gain: number)
--- @field subscribe fun(_, callback: fun(gain: number), _)

--- @class fun.sound.events.on_music_gain_changed: event
--- @field trigger fun(_, gain: number)
--- @field subscribe fun(_, callback: fun(gain: number), _)

M.on_sound_gain_changed = event.create() --[[@as fun.sound.events.on_sound_gain_changed]]
M.on_music_gain_changed = event.create() --[[@as fun.sound.events.on_music_gain_changed]]


--- Получить URL звука по идентификатору звука
---@param sound_id string
---@return string
local function get_sound_url(sound_id)
	return M.config.sound_go .. sound_id
end

local function get_music_url(music_id)
	return M.config.music_go .. music_id
end


--- Установить громкость звука
---@param sound_id string
---@param gain number
local function set_gain(sound_id, gain)
	sound.set_gain(get_sound_url(sound_id), gain)
	M.runtime.last_gains[sound_id] = gain
end


--- Воспроизвести звук
---@param sound_id string
---@param gain number|nil
---@param speed number|nil
function M.play(sound_id, gain, speed)
	gain = gain or 1
	speed = speed or 1

	if M.state.sound_gain == 0 then
		return
	end

	local sound_times = M.runtime.times

	if sound_times[sound_id] and (socket.gettime() - sound_times[sound_id]) < M.config.repeat_threshold then
		return
	end

	M.runtime.props.gain = gain
	M.runtime.props.speed = speed
	sound.play(get_sound_url(sound_id), M.runtime.props)

	sound_times[sound_id] = socket.gettime()
end


--- Play the random sound from sound names array
---@param sound_ids string[]
---@param gain number|nil
---@param speed number|nil
function M.play_random(sound_ids, gain, speed)
	M.play(tablex.random(sound_ids), gain, speed)
end


--- Stop sound playing
---@param sound_id string
function M.stop(sound_id)
	sound.stop(get_sound_url(sound_id))
end


--- Start playing music
---@param music_id string
---@param gain number|nil
---@param on_end_play_callback function|nil
function M.play_music(music_id, gain, on_end_play_callback)
	logger:debug("play_music", { music_id = music_id, gain = gain })

	M.stop_music()

	gain = gain or 1.0

	M.current_music = music_id
	set_gain(M.current_music, gain)

	sound.play(get_music_url(M.current_music), { gain = gain }, on_end_play_callback)
end


--- Остановить музыку
function M.stop_music()
	if M.current_music then
		sound.stop(get_music_url(M.current_music))
		M.current_music = nil
	end
end


--- Затухание звука с одной громкости на другую
---@param sound_id string
---@param to number
---@param time number
function M.fade(sound_id, to, time)
	local from = M.runtime.last_gains[sound_id] or 1
	set_gain(sound_id, from)

	local gain = from
	local delta = math.abs(to - from)
	local step = delta * (1/60) / time

	table.insert(M.runtime.fades, {
		sound_id = sound_id,
		gain = gain,
		step = step,
		to = to,
	})
end


--- Затухание музыки с одной громкости на другую
---@param to number
---@param time number
---@param callback function
function M.fade_music(to, time, callback)
	if M.current_music then
		M.fade(M.current_music, to, time or 1)
		if callback then
			timer.delay(time, false, callback)
		end
	else
		if callback then
			callback()
		end
	end
end


--- Остановить все звуки в игре
function M.stop_all()
	M.stop_music()
	-- TODO: Implement sounds
end


--- Set music gain
---@param value number between 0 and 1
function M.set_music_gain(value)
	value = value or 0
	value = mathx.clamp(value, 0, 1)
	M.state.music_gain = value
	sound.set_group_gain(hash("music"), M.state.music_gain)

	M.on_music_gain_changed:trigger(M.state.music_gain)
end


--- Set sound gain. Value must be between 0 and 1. It's change "sound" group gain
---@param value number
function M.set_sound_gain(value)
	value = value or 0
	value = mathx.clamp(value, 0, 1)
	M.state.sound_gain = value
	sound.set_group_gain(hash("sound"), M.state.sound_gain)

	M.on_sound_gain_changed:trigger(M.state.sound_gain)
end


--- Получить громкость музыки
---@return number
function M.get_music_gain()
	return M.state.music_gain
end


--- Получить громкость звука
---@return number
function M.get_sound_gain()
	return M.state.sound_gain
end


--- Проверить, включена ли музыка
---@return boolean
function M.is_music_enabled()
	return M.state.music_gain > 0
end


--- Проверить, включен ли звук
---@return boolean
function M.is_sound_enabled()
	return M.state.sound_gain > 0
end

--- Выключить/включить весь звук игры (группа "master") по указанной причине.
--- Звук возвращается, только когда сняты все причины, поэтому пересекающиеся паузы
--- (реклама + потеря фокуса) не включают звук раньше времени. Настройки игрока не меняются.
---@param reason string
---@param muted boolean
function M.set_muted(reason, muted)
	M.runtime.mute_reasons[reason] = muted or nil
	local is_muted = next(M.runtime.mute_reasons) ~= nil
	sound.set_group_gain(hash("master"), is_muted and 0 or 1)
	logger:debug("set_muted", { reason = reason, muted = muted, is_muted = is_muted })
end


local function on_window_event(window_event, data)
	if window_event == window.WINDOW_EVENT_FOCUS_LOST then
		M.set_muted("focus", true)
	elseif window_event == window.WINDOW_EVENT_FOCUS_GAINED then
		M.set_muted("focus", false)
	end
end


function M.update_group_gains()
	sound.set_group_gain(hash("music"), mathx.clamp(M.state.music_gain, 0, 1))
	sound.set_group_gain(hash("sound"), mathx.clamp(M.state.sound_gain, 0, 1))
end

function M.fun_init()
	saver.bind_save_state("fun.sound", M.state)
	events.subscribe(const.EVENTS.WINDOW_EVENT, on_window_event)

	-- logger:debug("sound.set_group_gain", { music_gain = M.state.music_gain, sound_gain = M.state.sound_gain })
	-- sound.set_group_gain(hash("music"), mathx.clamp(M.state.music_gain, 0, 1))
	-- sound.set_group_gain(hash("sound"), mathx.clamp(M.state.sound_gain, 0, 1))
end


function M.fun_update(dt)
	local fades = M.runtime.fades
	for index = #fades, 1, -1 do
		local fade_data = fades[index]

		fade_data.gain = mathx.step(fade_data.gain, fade_data.to, fade_data.step)
		set_gain(fade_data.sound_id, fade_data.gain)
		if fade_data.gain == fade_data.to then
			table.remove(fades, index)
		end
	end
end


return M