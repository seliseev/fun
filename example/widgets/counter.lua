local token = require("token.token")

local animation = require("fun.animation")
local wallet = require("fun.modules.wallet")


---@class widget.counter: druid.widget
local M = {}

local function on_token_visual_change(self, container_id, token_id, amount)
	if token_id == self.token_id then
		self.text:set_text(tostring(wallet.get_visual(token_id)))
	end
end

---@param token_id string
---@param on_click_callback function|event|nil
function M:init(token_id, on_click_callback)
    local token_value = wallet.get(token_id)
	local token_visual = wallet.get_visual(token_id)

	if not token_value then
		error("Token with id '" .. token_id .. "' does not exist")
	end

	self.token_id = token_id
	self.root = self:get_node("root")
	self.text = self.druid:new_text("text", tostring(token_visual))
	if on_click_callback then
		self.button = self.druid:new_button("root", on_click_callback)
	end
	token.on_token_visual_change:subscribe(on_token_visual_change, self)
end

function M:on_remove()
	token.on_token_visual_change:unsubscribe(on_token_visual_change, self)
end


return M
