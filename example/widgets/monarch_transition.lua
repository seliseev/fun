local event = require("event.event")
local transitions = require "monarch.transitions.gui"
local monarch = require "monarch.monarch"

local luax = require("fun.luax")
local log = require("fun.libs.log")

local logger = log.get_logger("widgets.monarch_transition")


local function color_fade_in(node, to, easing, duration, delay, cb)
	local to = gui.get_color(node)
	local old_w = to.w
	to.w = 0
	gui.set_color(node, to)
	to.w = old_w
	gui.animate(node, gui.PROP_COLOR, to, easing, duration, delay, cb)
end

local function color_fade_out(node, from, easing, duration, delay, cb)
	local to = gui.get_color(node)
	-- to.w = 1.0
	-- gui.set_color(node, to)
	to.w = 0
	gui.animate(node, gui.PROP_COLOR, to, easing, duration, delay, cb)
end

local function scale_fade_out(node, from, easing, duration, delay, cb)
	gui.set_scale(node, from.scale)
	-- cb вызываем один раз (на анимации цвета): monarch считает по одному завершению на переход
	gui.animate(node, gui.PROP_SCALE, luax.vmath.VECTOR_ZERO, easing, duration, delay)

	local to = gui.get_color(node)
	to.w = 1
	gui.set_color(node, to)
	to.w = 0
	gui.animate(node, gui.PROP_COLOR, to, easing, duration, delay, cb)
end

local function scale_fade_in(node, to, easing, duration, delay, cb)
	gui.set_scale(node, luax.vmath.VECTOR_ZERO)
	-- cb вызываем один раз (на анимации цвета): monarch считает по одному завершению на переход
	gui.animate(node, gui.PROP_SCALE, to.scale, easing, duration, delay)

	local to = gui.get_color(node)
	to.w = 0
	gui.set_color(node, to)
	to.w = 1
	gui.animate(node, gui.PROP_COLOR, to, easing, duration, delay, cb)
end


--- Переход ноды, выключенной к моменту перехода, завершается сразу. Анимации выключенных нод не идут,
--- и monarch ждал бы их callback вечно: экран зависал (например, HUD после покупки NoAds прячет noads/root,
--- банк прячет блок видео при исчерпанном лимите)
---@param transition_fn function
---@return function
local function skip_disabled(transition_fn)
	return function(node, data, easing, duration, delay, cb)
		if not gui.is_enabled(node, true) then
			if cb then
				cb()
			end
			return
		end
		transition_fn(node, data, easing, duration, delay, cb)
	end
end

--- Переходы экрана описываются кодом в init экрана:
---
---     local T = widget_monarch_transition.transitions
---     local transition = self.druid:new_widget(widget_monarch_transition, nil, nil, SCREEN_ID)
---     transition:set("background", widget_monarch_transition.in_out({ T.color_fade_in }, { T.color_fade_out }))
---     transition:set("root", { show_in = { T.scale_fade_in, easing = gui.EASING_OUTBACK }, show_out = { T.scale_fade_out } })
---
--- Отсутствующая нода роняет экран сразу в init (gui.get_node), а не молча пропадает из анимации.
---@class widget.monarch_transition: druid.widget
---@field screen_id hash
---@field transition table Экземпляр monarch.transitions.gui
---@field nodes node[] Ноды с переходами по умолчанию, в порядке добавления
---@field steps table<node, widget.monarch_transition.steps> Переходы по умолчанию
---@field overrides table<hash, table<node, widget.monarch_transition.steps>> Отличия для перехода с/на конкретный экран
---@field event_transition_done event
---@field event_will_show event
---@field event_will_hide event
local M = {}

---@alias widget.monarch_transition.type "show_in"|"show_out"|"back_in"|"back_out"

--- Шаг перехода: `{ fn, easing = ..., duration = ..., delay = ... }`, fn - функция из M.transitions
---@class widget.monarch_transition.step
---@field [1] function
---@field easing number|nil По умолчанию gui.EASING_LINEAR
---@field duration number|nil По умолчанию 0.2
---@field delay number|nil По умолчанию 0

---@class widget.monarch_transition.steps
---@field show_in widget.monarch_transition.step|nil
---@field show_out widget.monarch_transition.step|nil
---@field back_in widget.monarch_transition.step|nil
---@field back_out widget.monarch_transition.step|nil

local TYPES = { "show_in", "show_out", "back_in", "back_out" }
local DEFAULT_DURATION = 0.2

M.transitions = {
	slide_in_left = skip_disabled(transitions.slide_in_left),
	slide_in_right = skip_disabled(transitions.slide_in_right),
	slide_in_top = skip_disabled(transitions.slide_in_top),
	slide_in_bottom = skip_disabled(transitions.slide_in_bottom),
	slide_out_right = skip_disabled(transitions.slide_out_right),
	slide_out_left = skip_disabled(transitions.slide_out_left),
	slide_out_top = skip_disabled(transitions.slide_out_top),
	scale_in = skip_disabled(transitions.scale_in),
	scale_out = skip_disabled(transitions.scale_out),
	slide_out_bottom = skip_disabled(transitions.slide_out_bottom),
	color_fade_in = skip_disabled(color_fade_in),
	color_fade_out = skip_disabled(color_fade_out),
	fade_in = skip_disabled(transitions.fade_in),
	fade_out = skip_disabled(transitions.fade_out),
	scale_fade_out = skip_disabled(scale_fade_out),
	scale_fade_in = skip_disabled(scale_fade_in),
}

--- Одинаковые шаги для показа (show_in, back_in) и скрытия (show_out, back_out)
---@param step_in widget.monarch_transition.step
---@param step_out widget.monarch_transition.step
---@return widget.monarch_transition.steps
function M.in_out(step_in, step_out)
	return { show_in = step_in, back_in = step_in, show_out = step_out, back_out = step_out }
end


---@param self widget.monarch_transition
---@param node node
---@param transition_type widget.monarch_transition.type
---@param step widget.monarch_transition.step
local function register(self, node, transition_type, step)
	self.transition[transition_type](node, step[1], step.easing or gui.EASING_LINEAR, step.duration or DEFAULT_DURATION, step.delay or 0)
end


--- Перерегистрирует переходы с учетом отличий для соседнего экрана. Monarch не удаляет зарегистрированные
--- переходы, только обновляет их, поэтому отличия берутся лишь для типов, которые есть в переходах по умолчанию
---@param self widget.monarch_transition
---@param neighbor_screen_id hash|nil
local function apply(self, neighbor_screen_id)
	local overrides = neighbor_screen_id and self.overrides[neighbor_screen_id] or {}
	for _, node in ipairs(self.nodes) do
		local steps = self.steps[node]
		local node_overrides = overrides[node] or {}
		for _, transition_type in ipairs(TYPES) do
			if steps[transition_type] then
				register(self, node, transition_type, node_overrides[transition_type] or steps[transition_type])
			end
		end
	end
end


---@param screen_id hash
function M:init(screen_id)
	monarch.add_listener(msg.url())

	self.screen_id = screen_id
	self.nodes = {}
	self.steps = {}
	self.overrides = {}

	self.event_transition_done = event.create()
	self.event_will_show = event.create()
	self.event_will_hide = event.create()

	self.transition = transitions.create()

	-- Безопасно регистрируем переход, обрабатывая случай, когда экран еще не зарегистрирован
	local success, err = pcall(function()
		monarch.on_transition(screen_id, self.transition)
	end)
	if not success then
		logger:warn("Failed to register transition for screen " .. tostring(screen_id) .. ": " .. tostring(err) .. ". Screen may not be registered yet.")
	end
end

function M:on_remove()
	monarch.remove_listener(msg.url())
	self.event_transition_done:clear()
	self.event_will_show:clear()
	self.event_will_hide:clear()
end


--- Задает переходы ноды. С neighbor_screen_id - отличия для перехода с/на этот экран
--- (шаги, которых нет в переходах ноды по умолчанию, игнорируются)
---@param node node|string
---@param steps widget.monarch_transition.steps
---@param neighbor_screen_id hash|nil
---@return widget.monarch_transition
function M:set(node, steps, neighbor_screen_id)
	if type(node) == "string" then
		node = gui.get_node(node)
	end

	if neighbor_screen_id then
		self.overrides[neighbor_screen_id] = self.overrides[neighbor_screen_id] or {}
		self.overrides[neighbor_screen_id][node] = steps
		return self
	end

	if not self.steps[node] then
		table.insert(self.nodes, node)
	end
	self.steps[node] = steps
	for _, transition_type in ipairs(TYPES) do
		if steps[transition_type] then
			register(self, node, transition_type, steps[transition_type])
		end
	end
	return self
end


--- Shows the specified node
---@param node userdata - The node to fade in
function M:show(node, transition, easing, duration, delay)
	assert(node, "Node is required")
	easing = easing or gui.EASING_LINEAR
	duration = duration or 0.2
	delay = delay or 0
	transition = transition or M.transitions.slide_in_left

	self.transition
		.show_in(node, transition, easing, duration, delay)
		.back_in(node, transition, easing, duration, delay)
end

--- Hides the specified node
---@param node userdata - The node to fade out
function M:hide(node, transition, easing, duration, delay)
	assert(node, "Node is required")
	easing = easing or gui.EASING_LINEAR
	duration = duration or 0.2
	delay = delay or 0
	transition = transition or M.transitions.slide_out_right

	self.transition
		.show_out(node, transition, easing, duration, delay)
		.back_out(node, transition, easing, duration, delay)
end

--- Handles messages sent to this widget
---@param message_id hash
---@param message table
---@param sender url
function M:on_message(message_id, message, sender)
	-- Listener получает события всех экранов, реагируем только на свой
	if message_id == monarch.SCREEN_TRANSITION_IN_FINISHED and message.screen == self.screen_id then
		self.event_transition_done:trigger()

	elseif message_id == monarch.TRANSITION.SHOW_OUT or message_id == monarch.TRANSITION.BACK_OUT then
		if next(self.overrides) then
			apply(self, message.next_screen)
		end
		self.event_will_hide:trigger(message.next_screen)

	elseif message_id == monarch.TRANSITION.SHOW_IN or message_id == monarch.TRANSITION.BACK_IN then
		if next(self.overrides) then
			apply(self, message.previous_screen)
		end
		self.event_will_show:trigger(message.previous_screen)
	end
end

return M
