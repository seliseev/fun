local events = require("event.events")

---@class widget.toggle: druid.widget
local M = {}

local function on_click(self)
	self:toggle()
end


function M:init()
	self.root = self:get_node("root")

	self.disabled_node = self:get_node("disabled")
	self.disabled = self.druid:new_button("disabled", on_click, self)

	self.enabled_node = self:get_node("enabled")
	self.enabled = self.druid:new_button("enabled", on_click, self)
end

function M:is_enabled()
	return gui.get_visible(self.enabled_node)
end

function M:set_on_toggle_function(callback)
	if type(callback) == "function" then
		self.on_toggle = callback
	else
		error("on_toggle must be a function")
	end
end

--- Sets the toggle state of the widget
---@param enabled boolean
function M:set_enabled(enabled)
	if type(enabled) ~= "boolean" then
		error("enabled must be a boolean value")
	end

	if self:is_enabled() == enabled then
		return -- No change needed
	end

	gui.set_visible(self.disabled_node, not enabled)
	gui.set_enabled(self.disabled_node, not enabled)
	gui.set_visible(self.enabled_node, enabled)
	gui.set_enabled(self.enabled_node, enabled)

	if self.on_toggle then
		self.on_toggle(enabled)
	end
end

--- Toggles the enabled state of the widget
function M:toggle()
	self:set_enabled(not gui.get_visible(self.enabled_node))
end


return M
