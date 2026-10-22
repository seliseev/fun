--- Кнопка лота. Отображает иконку токена с ценой

local event = require("event.event")
local token = require("token.token")
local luax = require("fun.luax")
local iconfinder = require("example.modules.iconfinder")


---@class widget.button_lot: druid.widget
local M = {}

local ICON_SIZE = 20

--- Инициализация кнопки с ценой
---@param lot_id string @Идентификатор лота из "token.lots" в gamedata.json
function M:init(lot_id, callback)
	assert(lot_id, "lot_id is required")
    self.lot_id = lot_id
	self.callback = callback or function() end

	self.lot_reward = token.get_lot_reward(self.lot_id)
	assert(self.lot_reward, "lot_reward is required")

	self.lot_price = token.get_lot_price(self.lot_id)
	assert(self.lot_price, "lot_price is required")

	self.root = self:get_node("root")
	self.button = self.druid:new_button("root", self.on_button, self)
	self.text = self.druid:new_rich_text("text")

	self:update_text()
end

function M:set_enabled(enabled)
	if type(enabled) ~= "boolean" then
		error("enabled must be a boolean value")
	end

	gui.set_enabled(self.root, enabled)
end

function M:update_text()
    local price_text = ""
	local counter = 0
	for token_id, value in pairs(self.lot_price) do
		if counter > 0 then
			price_text = price_text .. "\n"
		end
		price_text = price_text .. "<img=".. iconfinder.get_icon_for_druid_richtext(token_id) .. "," .. tostring(ICON_SIZE) .. "/> " .. luax.string.split_by_rank(value)
		counter = counter + 1
	end
	self.text:set_text(price_text)
end

function M:on_button()
	self.callback(self, self.lot_id)
end

return M
