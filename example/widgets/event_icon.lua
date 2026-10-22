local monarch = require("monarch.monarch")


---@class widget.event_icon: druid.widget
local M = {}


function M:init(text_key, monarch_scene_id)
	assert(text_key, "You must provide a \'text_key\'")
	assert(monarch_scene_id, "You must provide a \'monarch_scene_id\'")

	if monarch.screen_exists(monarch_scene_id) == false then
		assert(false, string.format("Monarch scene '%s' does not exist", monarch_scene_id))
	end

	self.text_key = text_key
	self.monarch_scene_id = monarch_scene_id

	self.root = self:get_node("root")

	--- @type druid.button
	self.button_levelchest = self.druid:new_button("root", function()
		monarch.show(self.monarch_scene_id)
	end)

	--- @type druid.lang_text
	self.text = self.druid:new_lang_text("text", self.text_key)
end


return M
