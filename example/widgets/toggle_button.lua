
---@class widget.toggle_button: druid.widget
local M = {}

local function on_click(self)
	self:toggle()
end


function M:init()
	self.root = self:get_node("root")
	self.node_disabled = self:get_node("disabled")
	self.node_enabled = self:get_node("enabled")
	self.node_enabled_text = self:get_node("enabled_text")
	self.node_disabled_text = self:get_node("disabled_text")

	self.btn_disabled = self.druid:new_button("disabled", on_click, self)
	self.btn_enabled = self.druid:new_button("enabled", on_click, self)
	self.text_enabled = self.druid:new_lang_text(self.node_enabled_text)
	self.text_disabled = self.druid:new_lang_text(self.node_disabled_text)

	gui.set_enabled(self.node_disabled, false)
end

function M:is_enabled()
	return gui.is_enabled(self.node_enabled)
end

--- Sets the ID of the toggle button, можно использовать для идентификации в callback (set_on_toggle_function)
---@param toggle_id string|number
function M:set_id(toggle_id)
	self.toggle_id = toggle_id
end

function M:get_id()
	if not self.toggle_id then
		error("Toggle ID is not set. Use set_id() to set it.")
	end
	return self.toggle_id
end


--- Sets the callback function for when the toggle button is toggled
---@param callback function|nil
---@param context any|nil
function M:set_on_toggle_function(callback, context)
	if type(callback) == "function" then
		self.on_toggle = callback
		self.on_toggle_context = context
	elseif callback == nil then
		self.on_toggle = nil
		self.on_toggle_context = nil
	else
		error("on_toggle must be a function")
	end
end

function M:set_lang_text(lang_key, ...)
	if type(lang_key) ~= "string" then
		error("lang_key must be a string")
	end

	self.text_enabled:translate(lang_key, ...)
	self.text_disabled:translate(lang_key, ...)
end

function M:set_text(text)
	if type(text) ~= "string" then
		error("text must be a string")
	end

	self.text_enabled:set_text(text)
	self.text_disabled:set_text(text)
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

	gui.set_visible(self.node_disabled, not enabled)
	gui.set_enabled(self.node_disabled, not enabled)
	gui.set_visible(self.node_enabled, enabled)
	gui.set_enabled(self.node_enabled, enabled)

	if self.on_toggle then
		self.on_toggle(self.on_toggle_context, self.toggle_id, enabled)
	end
end

--- Toggles the enabled state of the widget
function M:toggle()
	self:set_enabled(not gui.is_enabled(self.node_enabled))
end


return M
