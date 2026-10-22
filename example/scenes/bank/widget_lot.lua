local token = require("token.token")

local luax = require("fun.luax")
local tablex = require("fun.libs.tablex")
local iapservice = require("fun.modules.iapservice")
local iapevents = require("fun.modules.iap.events")


---@class widget.bank.widget_lot: druid.widget
local M = {}

local function on_list_products(self, success, products, error)
	if success then
		timer.delay(0, false, function()
			if self.lot.product then
				self.price:set_text(self.lot.product.price_string)
				self.button:set_enabled(true)
			else
				self.price:set_text("...")
				self.button:set_enabled(false)
			end
		end)
	end
end

--- 
---@param sku string
function M:init(sku, config)
	assert(sku, "SKU is required")
	self.sku = sku
	self.config = config

	self.lot = iapservice.get_lot(sku)
	assert(self.lot, "Lot not found", {sku = sku})

    local rewards = token.get_token_group(self.lot.reward)
	assert(rewards, "Rewards not found", {reward = self.lot.reward})
	assert(tablex.length(rewards) == 1, "Rewards must be exactly one", {reward = self.lot.reward})	
	local reward_value = tablex.values(rewards)[1]

	self.button = self.druid:new_button("button/button", self.on_button, self)
	self.value = self.druid:new_text("value", luax.string.split_by_rank(tostring(reward_value)))
	self.icon_node = self:get_node("icon")
	gui.play_flipbook(self.icon_node, config.flipbook)

	if self.lot.product then
		self.price = self.druid:new_text("button/text", self.lot.product.price_string)
	else
		self.price = self.druid:new_text("button/text", "...")
		self.button:set_enabled(false)
	end

	iapevents.on_list_products:subscribe(on_list_products, self)
end

function M:on_remove()
	iapevents.on_list_products:unsubscribe(on_list_products, self)
end

function M:on_button()
	iapservice.purchase(self.lot.sku, "bank")
end


return M
