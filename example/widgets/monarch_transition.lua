local event = require("event.event")
local transitions = require "monarch.transitions.gui"
local monarch = require "monarch.monarch"

local luax = require("fun.luax")
local log = require("fun.libs.log")
local tablex = require("fun.libs.tablex")

local fun_transitions = require("fun.modules.transitions")
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
	gui.animate(node, gui.PROP_SCALE, luax.vmath.VECTOR_ZERO, easing, duration, delay, cb)
	
	local to = gui.get_color(node)
	to.w = 1
	gui.set_color(node, to)
	to.w = 0
	gui.animate(node, gui.PROP_COLOR, to, easing, duration, delay, cb)
end

local function scale_fade_in(node, to, easing, duration, delay, cb)
	gui.set_scale(node, luax.vmath.VECTOR_ZERO)
	gui.animate(node, gui.PROP_SCALE, to.scale, easing, duration, delay, cb)
		
	local to = gui.get_color(node)
	to.w = 0
	gui.set_color(node, to)
	to.w = 1
	gui.animate(node, gui.PROP_COLOR, to, easing, duration, delay, cb)
end


---@class widget.monarch_transition: druid.widget
local M = {}

M.transitions = {
	slide_in_left = transitions.slide_in_left,
	slide_in_right = transitions.slide_in_right,
	slide_in_top = transitions.slide_in_top,
	slide_in_bottom = transitions.slide_in_bottom,
	slide_out_right = transitions.slide_out_right,
	slide_out_left = transitions.slide_out_left,
	slide_out_top = transitions.slide_out_top,
	scale_in = transitions.scale_in,
	scale_out = transitions.scale_out,
	slide_out_bottom = transitions.slide_out_bottom,
	color_fade_in = color_fade_in,
	color_fade_out = color_fade_out,
	fade_in = transitions.fade_in,
	fade_out = transitions.fade_out,
	scale_fade_out = scale_fade_out,
	scale_fade_in = scale_fade_in,
}


--- Initializes the transition widget
---@param screen_id hash
---@param node any
function M:init(screen_id, node)
	monarch.add_listener(msg.url())

	self.screen_id = screen_id

    self.event_transition_done = event.create()
    self.event_will_show = event.create()
	self.event_will_hide = event.create()

    self.transition = transitions.create(node)

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

function M:scale_in_out(node, easing, duration, delay)
	easing = easing or gui.EASING_LINEAR
	duration = duration or 0.2
	delay = delay or 0
	self.transition
        .show_in(node, self.transitions.scale_in, easing, duration, delay)
        .show_out(node, self.transitions.scale_out, easing, duration, delay)
end

function M:fade_in_out(node, easing, duration, delay)
	easing = easing or gui.EASING_LINEAR
	duration = duration or 0.2
	delay = delay or 0
	self.transition
        .show_in(node, self.transitions.fade_in, easing, duration, delay)
        .show_out(node, self.transitions.fade_out, easing, duration, delay)
end

function M:transition_in_out(node, transition_in, transition_out, easing, duration, delay)
	easing = easing or gui.EASING_LINEAR
	duration = duration or 0.2
	delay = delay or 0
	self.transition
        .show_in(node, transition_in, easing, duration, delay)
        .show_out(node, transition_out, easing, duration, delay)
end

--- Shows the specified node
---@param node userdata - The node to fade in
function M:show(node, transition, easing, duration, delay)
    assert(node, "Node is required")
    easing = easing or gui.EASING_LINEAR
    duration = duration or 0.2
    delay = delay or 0
    transition = transition or transitions.slide_in_left

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
    transition = transition or transitions.slide_out_right

    self.transition
        .show_out(node, transition, easing, duration, delay)
        .back_out(node, transition, easing, duration, delay)
end

--- Handles messages sent to this widget
---@param message_id hash
---@param message table
---@param sender url
function M:on_message(message_id, message, sender)
    if message_id == monarch.SCREEN_TRANSITION_IN_FINISHED  then
		self.event_transition_done:trigger()
    
	elseif message_id == monarch.TRANSITION.SHOW_OUT or message_id == monarch.TRANSITION.BACK_OUT then
		self:update_transitions(message.next_screen, nil)
		self.event_will_hide:trigger(message.next_screen)
	
	elseif message_id == monarch.TRANSITION.SHOW_IN or message_id == monarch.TRANSITION.BACK_IN then
		self:update_transitions(nil, message.previous_screen)
		self.event_will_show:trigger(message.previous_screen)
	end
end

--- private function to update the transitions
function M:update_transitions(next_screen_id, previous_screen_id)
	local transitions_config = fun_transitions.get_transitions_by_node(self.screen_id, next_screen_id, previous_screen_id)
	if not transitions_config then
		return
	end
	for transition_type, transition_list in pairs(transitions_config) do
		if tablex.contains({"show_in", "show_out", "back_in", "back_out"}, transition_type) then
			for _, t_config in pairs(transition_list) do
				if luax.gui.get_node(t_config.node_name) then
					if gui.is_enabled(gui.get_node(t_config.node_name), false) then
						self.transition[transition_type](gui.get_node(t_config.node_name), M.transitions[t_config.transition], gui[t_config.easing], t_config.duration, t_config.delay)
					end
				else
					logger:error("Node " .. t_config.node_name .. " not found for transition " .. transition_type .. " in screen " .. self.screen_id)
				end
				
			end
		end
	end
end

return M
