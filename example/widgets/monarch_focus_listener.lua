local event = require("event.event")
local monarch = require("monarch.monarch")

local logger = require("fun.libs.log").get_logger("monarch_focus_listener")


---@class widget.monarch_focus_listener: druid.widget
local M = {}

--- Initializes the monarch focus listener widget
---@param screen_id hash
function M:init(screen_id)
	assert(screen_id, "screen_id is required")

	self.screen_id = screen_id

	self.on_focus_gained = event.create()
	self.on_focus_lost = event.create()

	local success, err = pcall(function()
		monarch.on_focus_changed(screen_id, function (message_id, message, sender)
			--logger:debug("monarch.on_focus_changed: screen=" .. self.screen_id, {message_id = message_id, message = message, sender = sender})
			if message_id == monarch.FOCUS_GAINED then
				self.on_focus_gained:trigger(message.id)
			elseif message_id == monarch.FOCUS_LOST then
				self.on_focus_lost:trigger(message.id)
			end
		end)
	end)
end


function M:on_remove()
	self.on_focus_gained:clear()
	self.on_focus_lost:clear()
end

return M